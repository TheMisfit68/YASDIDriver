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

// C-callback functions
// Should always be declared global!!!
var callBackFunctionForYasdiEvents = {
    (event: TYASDIDetectionSub, deviceHandle: UInt32, param1: UInt32)->()  in
    
    switch event{
    case YASDI_EVENT_DEVICE_ADDED:
        print("ℹ️ Device \(deviceHandle) added")
    case YASDI_EVENT_DEVICE_REMOVED:
        print("ℹ️ Device \(deviceHandle) removed")
    case YASDI_EVENT_DEVICE_SEARCH_END:
        print("ℹ️ No more devices found")
    case YASDI_EVENT_DOWNLOAD_CHANLIST:
        print("ℹ️ Channels downloaded")
    default:
        print("❌ Unkwown event occured during async device detection")
    }
}

public class SMAInverter{
    
    public static var Inverters:[SMAInverter] = []
    public var inverterRecord:Inverter!
    
    var serial: Int?{return inverterRecord.serial}
    var number: Handle?{return inverterRecord.number}
    var name: String?{return inverterRecord.name}
    var type: String?{return inverterRecord.type}
    
    public var measurementValues:[Measurement]? = nil // These values will eventually be displayed by the MainViewcontroller
    public var parameterValues:[Measurement]? = nil // These values will eventually be displayed by the parameterViewcontroller
    public var testValues:[Measurement]? = nil // These values will not be displayed for now
    
    private var pollingTimer: Timer! = nil
    
    private var spotChannels:[Channel] = []
    private var parameterChannels:[Channel] = []
    private var testChannels:[Channel] = []
    
    // MARK: - Inverter setup

    public class func handleAllYasdiEvents(){
        yasdiMasterAddEventListener(&callBackFunctionForYasdiEvents, YASDI_EVENT_DEVICE_DETECTION)
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
    
    public class func createInverters(maxNumberToSearch maxNumber:Int){
        if let devices:[Handle] = searchDevices(maxNumberToSearch:maxNumber){
            for device in devices{
                let inverter = SMAInverter(device)
                Inverters.append(inverter)
            }
        }
    }
    
    init(_ device: Handle){
        
        composeInverterRecord(fromDevice:device)
        
        // Read all channels just once
        readChannels(maxNumberToSearch: 30, channelType: .allChannels)
        
        // Sample spotvalues at a fixed time interval (30seconds here)
        pollingTimer = Timer.scheduledTimer(timeInterval: 30,
                                            target: self,
                                            selector: #selector(self.readValues),
                                            userInfo: ChannelsType.spotChannels,
                                            repeats: true
        )
        
        print("✅ Inverter \(name!) found online")
        
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
        inverterRecord.dbase = inverterData
        let dbaseRecord = inverterRecord.update(matchFields: ["serial"])
        inverterRecord.inverterID = dbaseRecord?.value(rowNumber: 0, columnName: "inverterID") as? SQLID ?? -1
    }
    
    private func readChannels(maxNumberToSearch:Int, channelType:ChannelsType = .allChannels){
        
        var channelTypesToRead = [channelType]
        if channelType == .allChannels{
            channelTypesToRead = [ChannelsType.spotChannels, ChannelsType.parameterChannels, ChannelsType.testChannels]
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
                    
                    let channelNumber = Int(channelHandles.pointee)
                    
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
                            unit: String(cString: unit),
                            inverterID: inverterRecord.inverterID
                        )
                        
                        
                        // Archive in SQL and
                        // complete the channel-record with the PK from the dbase
                        channelRecord.dbase = inverterData
                        let dbaseRecord = channelRecord.update(matchFields:["type","name"])
                        channelRecord.channelID = dbaseRecord?.value(rowNumber: 0, columnName: "channelID") as? SQLID
                        
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
    
// MARK: -     Callbackfunction for the timer

    @objc private func readValues(timer:Timer){
        
        let channelType = timer.userInfo as! ChannelsType

        let sqlTimeStampFormatter = DateFormatter()
        sqlTimeStampFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ" // GMT date string in SQL-format

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "dd-MM-yyyy" // Local date string

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = TimeZone.current
        timeFormatter.dateFormat = "HH:mm:ss" // Local time string

        let systemTimeStamp = Date()
        let currentLocalHour = Calendar.current.component(Calendar.Component.hour, from: systemTimeStamp)

        // Only record dat between 06:00 and 22:59
        if (6...22) ~= currentLocalHour{

            var channelTypesToRead = [channelType]
            if channelType == .allChannels{
                channelTypesToRead = [ChannelsType.allChannels, ChannelsType.parameterChannels, ChannelsType.testChannels]
            }
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
                    let channelNumber = channel.number!

                    var recordedTimeStamp = systemTimeStamp
                    let onlineTimeStamp = GetChannelValueTimeStamp(Handle(channelNumber), number!)
                    if onlineTimeStamp > 0{
                        recordedTimeStamp = Date(timeIntervalSince1970:TimeInterval(onlineTimeStamp))
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

                    if resultCode != errorCode {

                        // Create the measurement-record
                        var measurementRecord = Measurement(
                            measurementID: nil,
//                            samplingTime: timeFormatter.string(from: systemTimeStamp),
                            timeStamp: sqlTimeStampFormatter.string(from: recordedTimeStamp),
                            date: dateFormatter.string(from: recordedTimeStamp),
                            time: timeFormatter.string(from: recordedTimeStamp),
                            value: currentValue.pointee,
                            channelID: channel.channelID
                        )
                        
                        print(measurementRecord)

                        // Archive in SQL and
                        // complete the measurement-record with the PK from the dbase
                        measurementRecord.dbase = inverterData
                        let dbaseRecord = measurementRecord.add()
                        measurementRecord.channelID = dbaseRecord?.value(rowNumber: 0, columnName: "measurementID") as? SQLID

                        currentValues.append(measurementRecord)
                        

                    }

                }

                // Divide all channels found, by channeltype
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
}


