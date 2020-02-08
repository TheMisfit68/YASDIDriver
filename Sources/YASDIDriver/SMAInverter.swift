//
//  SMAInverter
//  MacSunnySender
//
//  Created by Jan Verrept on 24/06/17.
//  Copyright © 2017 OneClick. All rights reserved.
//

import ClibYASDI
import Cocoa
import JVCocoa


//FIXME: - Not used for now, crashes the app
//For handling device searches asynchroniously

var callBackFunctionForYasdiEvents = {
    (event: TYASDIDetectionSub, deviceHandle: UInt32, param1: UInt32)->()  in
    
    switch event{
    case YASDI_EVENT_DEVICE_ADDED:
        JVDebugger.shared.log(debugLevel: .Info, "Device \(deviceHandle) added")
    case YASDI_EVENT_DEVICE_REMOVED:
        JVDebugger.shared.log(debugLevel: .Info, "Device \(deviceHandle) removed")
    case YASDI_EVENT_DEVICE_SEARCH_END:
        JVDebugger.shared.log(debugLevel: .Info, "No more devices found")
    case YASDI_EVENT_DOWNLOAD_CHANLIST:
        JVDebugger.shared.log(debugLevel: .Info, "Channels downloaded")
    default:
        JVDebugger.shared.log(debugLevel: .Error, "Unkwown event occured during async device detection")
    }
}


//Represents the fysical SMA-brand Solar inverter.
//Uses the configured drivers to read values from the device

@available(OSX 10.15, *)
public class SMAInverter{
    
    public static var OnlineInverters:[SMAInverter] = []
    public static var ArchivedInverters:[Int]?{
        let InvertersDataBase:JVSQLdbase! = YASDIDriver.InvertersDataBase
        let sqlStatement = "SELECT DISTINCT Serial FROM Inverter"
        let archivedInverters = InvertersDataBase.select(statement: sqlStatement)?.data.map{$0[0] as! Int}
        return archivedInverters
    }
    
    private static var ExpectedToBeOnline:Bool{
        // Determines the hours between wich enough sun is expected to get the devices powered up
        let sunnyHours = (6...22)
        let systemTimeStamp = Date()
        let currentLocalHour = Calendar.current.component(Calendar.Component.hour, from: systemTimeStamp)
        return sunnyHours ~= currentLocalHour
    }
    
    var serial: Int?{return inverterRecord.serial}
    var number: Handle?{return inverterRecord.number}
    var name: String?{return inverterRecord.name}
    var type: String?{return inverterRecord.type}
    
    public var inverterRecord:Inverter!
    
    public var spotChannels:[Channel] = []
    public var parameterChannels:[Channel] = []
    public var testChannels:[Channel] = []
    
    public let display:DigitalDisplayView
    public var measurementValues:[Measurement]? = nil
    public var parameterValues:[Measurement]? = nil // These values will not be used for now
    public var testValues:[Measurement]? = nil // These values will not be used for now
    
    private let dataToDisplay:DataSummary
    private var pollingTimer: Timer! = nil
    
    // MARK: - Inverter setup
    public class func handleAllYasdiEvents(){
        yasdiMasterAddEventListener(&callBackFunctionForYasdiEvents, YASDI_EVENT_DEVICE_DETECTION)
    }
    
    public class func createInverters(maxNumberToSearch maxNumber:Int){
        if SMAInverter.ExpectedToBeOnline{
            
            if let devices:[Handle] = searchDevices(maxNumberToSearch:maxNumber){
                for device in devices{
                    let inverter = SMAInverter(device)
                    OnlineInverters.append(inverter)
                }
            }
        }
    }
    
    init(_ device: Handle){
        
        self.dataToDisplay = DataSummary(channelNames: ["Pac", "Upv-Ist", "E-Total"])
        self.display = DigitalDisplayView(model:dataToDisplay)
        
        composeInverterRecord(fromDevice:device)
        
        // Read all channels just once
        readChannels(maxNumberToSearch: 30, channelType: .allChannels)
        
        // Sample spotvalues at a fixed time interval (30seconds here)
        self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { timer in self.readValues(channelType: .spotChannels) }
        self.pollingTimer.tolerance = 1.0 // Give the processor some slack
        self.pollingTimer.fire()
        
        JVDebugger.shared.log(debugLevel: .Succes, "Inverter \(name!) found online")
    }
    
    private class func searchDevices(maxNumberToSearch maxNumber:Int)->[Handle]?{
        
        var devices:[Handle]? = nil
        
        let errorCode:Int32 = -1
        var resultCode:Int32 = errorCode
        
        resultCode = DoStartDeviceDetection(CInt(maxNumber), 1);
        
        if resultCode != errorCode {
            
            let errorCode:DWORD = 0
            var resultCode:DWORD = errorCode
            
            let deviceHandles:UnsafeMutablePointer<Handle> = UnsafeMutablePointer<Handle>.allocate(capacity:maxNumber)
            resultCode = GetDeviceHandles(deviceHandles, DWORD(maxNumber))
            if resultCode != errorCode {
                
                // convert to a swift array of devicehandles
                devices = []
                let numberOfDevices = resultCode
                for _ in 0..<numberOfDevices{
                    devices!.append(deviceHandles.pointee)
                    _ = deviceHandles.advanced(by: 1)
                }
            }
        }
        
        return devices
    }
    
    private func composeInverterRecord(fromDevice deviceHandle:Handle){
        
        var deviceSN:DWORD = 2000814023
        var deviceName:String = "WR46A-01 SN:2000814023"
        var deviceType:String = "WR46A-01"
        
        let errorCode:Int32 = -1
        var resultCode:Int32 = errorCode
        
        let deviceSNvar: UnsafeMutablePointer<DWORD> = UnsafeMutablePointer<DWORD>.allocate(capacity: 1)
        resultCode = errorCode
        resultCode = GetDeviceSN(deviceHandle,
                                 deviceSNvar)
        if resultCode != errorCode {
            deviceSN = deviceSNvar.pointee
        }
        
        let deviceNameVar: UnsafeMutablePointer<CChar> = UnsafeMutablePointer<CChar>.allocate(capacity: MAXCSTRINGLENGTH)
        resultCode = errorCode
        resultCode = GetDeviceName(deviceHandle,
                                   deviceNameVar,
                                   Int32(MAXCSTRINGLENGTH))
        if resultCode != errorCode {
            deviceName = String(cString:deviceNameVar)
        }
        
        let deviceTypeVar: UnsafeMutablePointer<CChar> = UnsafeMutablePointer<CChar>.allocate(capacity: MAXCSTRINGLENGTH)
        resultCode = errorCode
        resultCode = GetDeviceType(deviceHandle,
                                   deviceTypeVar,
                                   Int32(MAXCSTRINGLENGTH))
        if resultCode != errorCode {
            deviceType = String(cString: deviceTypeVar)
        }
        
        // Create the inverter-record
        inverterRecord = Inverter(
            inverterID: -1,
            serial: Int(deviceSN),
            number: deviceHandle,
            name: deviceName,
            type: deviceType
        )
        
        // Archive in SQL and
        // complete the inverter-record with the PK from the dbase
        inverterRecord.dbase = YASDIDriver.InvertersDataBase
        let dbaseRecord = inverterRecord.updateOrAdd(matchFields: ["serial"])
        dbaseRecord?.value(rowNumber: 0, columnName: "inverterID", copyInto:&inverterRecord.inverterID)
    }
    
    private func readChannels(maxNumberToSearch:Int, channelType:ChannelsType = .allChannels){
        
        var channelTypesToRead = [channelType]
        if channelType == .allChannels{
            channelTypesToRead = [.spotChannels, .parameterChannels, .testChannels]
        }
        for typeToRead in channelTypesToRead{
            
            let errorCode:DWORD = 0
            var resultCode:DWORD = errorCode
            var channelHandles:UnsafeMutablePointer<Handle> = UnsafeMutablePointer<Handle>.allocate(capacity: maxNumberToSearch)
            
            resultCode = GetChannelHandlesEx(number!,
                                             channelHandles,
                                             DWORD(maxNumberToSearch),
                                             TChanType(typeToRead.rawValue)
            )
            
            if resultCode != errorCode {
                let numberOfChannels = resultCode
                
                
                for _ in 0..<numberOfChannels{
                    
                    let channelNumber = Int(channelHandles.pointee) //channelNumber is the ChannelHandle of the particular channel
                    
                    let errorCode:Int32 = -1
                    var resultCode:Int32 = errorCode
                    
                    let channelName: UnsafeMutablePointer<CChar> = UnsafeMutablePointer<CChar>.allocate(capacity: MAXCSTRINGLENGTH)
                    resultCode = GetChannelName(
                        DWORD(channelNumber),
                        channelName,
                        DWORD(MAXCSTRINGLENGTH)
                    )
                    
                    if resultCode != errorCode {
                        
                        let unit: UnsafeMutablePointer<CChar> = UnsafeMutablePointer<CChar>.allocate(capacity: MAXCSTRINGLENGTH)
                        GetChannelUnit(Handle(channelNumber), unit, DWORD(MAXCSTRINGLENGTH))
                        
                        // Create the channel-record
                        var channelRecord = Channel(
                            channelID: nil,
                            type: Int(typeToRead.rawValue),
                            number: channelNumber,
                            name: String(cString: channelName),
                            description: "",
                            unit: String(cString: unit),
                            inverterID: inverterRecord.inverterID!
                        )
                        
                        // Archive in SQL and
                        // complete the channel-record with the PK from the dbase
                        channelRecord.dbase = YASDIDriver.InvertersDataBase
                        let dbaseRecord = channelRecord.updateOrAdd(matchFields:["type","name"])
                        dbaseRecord?.value(rowNumber: 0, columnName: "channelID", copyInto:&channelRecord.channelID)
                        
                        // Divide all channels found by their channeltype
                        switch typeToRead{
                        case .spotChannels:
                            spotChannels.append(channelRecord)
                        case .parameterChannels:
                            parameterChannels.append(channelRecord)
                        case .testChannels:
                            testChannels.append(channelRecord)
                        default:
                            break
                        }
                    }
                    
                    channelHandles = channelHandles.advanced(by: 1)
                }
                
            }
        }
        
    }
    
    // MARK: -  Callbackfunction for the pollingtimer
    private func readValues(channelType:ChannelsType){
        
        // Only record dat between 06:00 and 22:59
        if SMAInverter.ExpectedToBeOnline{
            
            var channelTypesToRead = [channelType]
            if channelType == .allChannels{
                channelTypesToRead = [ChannelsType.allChannels, ChannelsType.parameterChannels, ChannelsType.testChannels]
            }
                        
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.dateFormat = "dd-MM-yyyy" // Local date string
            
            let timeFormatter = DateFormatter()
            timeFormatter.timeZone = TimeZone.current
            timeFormatter.dateFormat = "HH:mm:ss" // Local time string
            
            // Use timestamp from beginning of this pollingcycle as the default
            var recordedTimeStamp = Date().timeIntervalSince1970
            
            for typeToRead in channelTypesToRead{
                
                let channelsToRead:[Channel]
                switch  typeToRead{
                case .spotChannels:
                    channelsToRead = spotChannels
                case .parameterChannels:
                    channelsToRead = parameterChannels
                case .testChannels:
                    channelsToRead = testChannels
                default:
                    channelsToRead = spotChannels + parameterChannels + testChannels
                }
                
                var currentValues:[Measurement] = []
                
                for channel in channelsToRead{
                    let channelNumber = channel.number
                    
                    // replace timestamp with more accurate online version if possible
                    let onlineTimeStamp = GetChannelValueTimeStamp(Handle(channelNumber), number!)
                    if onlineTimeStamp > 0{
                        recordedTimeStamp = TimeInterval(onlineTimeStamp)
                    }
                    
                    let currentValue:UnsafeMutablePointer<Double> = UnsafeMutablePointer<Double>.allocate(capacity: 1)
                    let currentValueAsText: UnsafeMutablePointer<CChar> = UnsafeMutablePointer<CChar>.allocate(capacity: MAXCSTRINGLENGTH)
                    let maxChannelAgeInSeconds:DWORD = 5
                    
                    let errorCode:Int32 = -1
                    var  resultCode:Int32 = errorCode
                    
                    resultCode = GetChannelValue(Handle(channelNumber),
                                                 number!,
                                                 currentValue,
                                                 currentValueAsText,
                                                 DWORD(MAXCSTRINGLENGTH),
                                                 maxChannelAgeInSeconds
                    )
                    
                    var channelRequest = Channel(
                        type: -1,
                        number: channelNumber,
                        name: "",
                        description: "",
                        unit: "",
                        inverterID: -1)
                    channelRequest.dbase = YASDIDriver.InvertersDataBase
                    let channel = channelRequest.find(matchFields: ["number"])
                    var channelID:SQLID?
                    channel?.value(rowNumber: 0, columnName: "channelID", copyInto:&channelID)
                    
                    if let channelID = channelID{
                        
                        if resultCode != errorCode {
                            
                            // Create the measurement-record
                            var measurementRecord = Measurement(
                                measurementID: nil,
                                timeStamp: recordedTimeStamp,
                                date: dateFormatter.string(from: Date(timeIntervalSince1970: recordedTimeStamp)),
                                time: timeFormatter.string(from: Date(timeIntervalSince1970: recordedTimeStamp)),
                                value: currentValue.pointee,
                                channelID: channelID
                            )
                            
                            // Archive in SQL and
                            // complete the measurement-record with the PK from the dbase
                            measurementRecord.dbase = YASDIDriver.InvertersDataBase
                            let dbaseRecord = measurementRecord.add()
                            dbaseRecord?.value(rowNumber: 0, columnName: "measurementID", copyInto: &measurementRecord.measurementID)
                            
                            currentValues.append(measurementRecord)
                            
                            
                        }
                        
                    }
                }
                
                // Divide all channels found, by channeltype
                if currentValues.count > 0{
                    switch  typeToRead{
                    case .spotChannels:
                        measurementValues = currentValues
                    case .parameterChannels:
                        parameterValues = currentValues
                    case .testChannels:
                        testValues = currentValues
                    default:
                        break
                    }
                }
                
            }
        }
        dataToDisplay.createTextLines(fromInverter: self)
    }
    
}




