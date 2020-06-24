import Foundation
import ClibYASDI
import JVCocoa


@available(OSX 10.15, *)
public class YASDIDriver{
    
    
    static let ConfigFileName = "YasdiConfigFile.ini"
    static let InvertersDataFileName = "InvertersData.sqlite"
    
    static let DefaultFilemanager =  FileManager.default
    static let ResourceFolder = Bundle.module
    
    static let SupportFolder = DefaultFilemanager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("YASDI")
    static let ConfigFile = SupportFolder?.appendingPathComponent(ConfigFileName)
    static let InvertersDataFile = SupportFolder?.appendingPathComponent(InvertersDataFileName)
    public static var InvertersDataBase:JVSQLdbase! = nil
    
    static var Drivers:[YASDIDriver] = []
    
    enum State:Int {
        case offline = 0
        case online = 1
    }
    
    let number:Int
    let name:String
    var state:State
    
    public class func InstallDrivers()->[YASDIDriver]{
        
        installResourcesInSupportFolder()
        if let dbasePath =  InvertersDataFile?.path, DefaultFilemanager.fileExists(atPath: dbasePath){
            InvertersDataBase = JVSQLdbase.Open(file:dbasePath)
        }
        
        if let numberOfDrivers = loadDriversFromConfigFile(){
            
            for driverNumber in 0..<numberOfDrivers{
                let driver = YASDIDriver(driverNumber)
                if driver.setOnline(){
                    YASDIDriver.Drivers.append(driver)
                }
            }
        }
        return YASDIDriver.Drivers
    }
    
    public class func UnInstallDrivers(){
        
        let numberOfDrivers = YASDIDriver.Drivers.count
        
        for driverNumber in 0..<numberOfDrivers{
            let driver = YASDIDriver(driverNumber)
            driver.setOffline()
        }
        InvertersDataBase.close()
    }
    
    private class func installResourcesInSupportFolder() {
        
        if let supportFolder = SupportFolder {
            
            // Create supportFolder if needed
            DefaultFilemanager.checkForDirectory(supportFolder, createIfNeeded: true)
            
            // Install the files in it
            let supportfilesToInstall = [ConfigFile, InvertersDataFile]
            
            for supportfile in supportfilesToInstall{
                
                let allReadyInstalled = DefaultFilemanager.fileExists(atPath:supportfile!.path)
                if !allReadyInstalled,
                   let fileName = supportfile?.lastPathComponent,
                   let resourceURL = ResourceFolder.url(forResource: fileName, withExtension: ""){
                    
                    do {
                        try FileManager.default.copyItem(at: resourceURL, to: supportfile!)
                    } catch {
                        //TODO: - finish errorHandling
                    }
                    
                }
            }
        }
        
    }
    
    private class func loadDriversFromConfigFile()->Int?{
        
        let errorCode:Int32 = -1
        var resultCode:Int32 = errorCode
        
        let numberOfAvailableDrivers:UnsafeMutablePointer<Handle> = UnsafeMutablePointer<Handle>.allocate(capacity: 1)
        resultCode = yasdiMasterInitialize(ConfigFile?.path, numberOfAvailableDrivers)
        
        if resultCode != errorCode{
            return Int(numberOfAvailableDrivers.pointee)
        }else{
            JVDebugger.shared.log(debugLevel: .Error, "Not able to load any drivers from '\(ConfigFile?.path ?? "")'")
            return nil
        }
        
    }
    
    init(_ number:Int){
        self.number = number
        
        let errorCode:BOOL = 0
        var resultCode:BOOL = errorCode
        
        let driverName:UnsafeMutablePointer<CHAR> = UnsafeMutablePointer<CHAR>.allocate(capacity:MAXCSTRINGLENGTH)
        resultCode = yasdiMasterGetDriverName(Handle(number),driverName,DWORD(MAXCSTRINGLENGTH))
        
        if resultCode != errorCode{
            self.name = String(cString: driverName)
        }else{
            self.name = "Unknown driver"
            JVDebugger.shared.log(debugLevel: .Error, "Unknown driver")
        }
        
        self.state = State.offline
        
    }
    
    
    private func setOnline()->Bool{
        
        let errorCode:BOOL = 0
        var resultCode:BOOL = errorCode
        
        resultCode = yasdiMasterSetDriverOnline(Handle(number))
        
        if resultCode != errorCode{
            state = State.online
            JVDebugger.shared.log(debugLevel: .Succes, "Driver \(name) is now online")
            return true
        }else{
            state = State.offline
            JVDebugger.shared.log(debugLevel: .Error, "Failed to set driver \(name) online")
            return false
        }
        
    }
    
    private func setOffline(){
        yasdiMasterSetDriverOffline(Handle(number))
        state = State.offline
        JVDebugger.shared.log(debugLevel: .Info, "Driver \(name) is back offline")
    }
    
}
