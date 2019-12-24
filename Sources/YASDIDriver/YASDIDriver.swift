import Foundation
import ClibYASDI

public class YASDIDriver{
    
    static let ConfigFileName = "YasdiConfigFile.ini"
    static let InverterDataFileName = "InverterData.sqlite"
    
    static let DefaultFilemanager =  FileManager.default
    static let ResourceFolder = Bundle.main.resourceURL?.appendingPathComponent("YASDI")
    static let SupportFolder = DefaultFilemanager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    static let ConfigFile = SupportFolder?.appendingPathComponent(ConfigFileName)
    static let InverterData = SupportFolder?.appendingPathComponent(InverterDataFileName)
    
    
    static var Drivers:[YASDIDriver] = []
    
    enum State:Int {
        case offline = 0
        case online = 1
    }
    
    let number:Int
    let name:String
    var state:State
    
    public class func installDrivers()->Bool{
        
        installResourcesInSupportFolder()
        
        if let numberOfDrivers = readTheConfigFile(){
            
            for driverNumber in 0..<numberOfDrivers{
                let driver = YASDIDriver(driverNumber)
                if !driver.setOnline(){
                    return false
                }
                YASDIDriver.Drivers.append(driver)
            }
            
        }
        return true
    }
    
    public class func unInstallDrivers(){
        
        let numberOfDrivers = YASDIDriver.Drivers.count
        
        for driverNumber in 0..<numberOfDrivers{
            let driver = YASDIDriver(driverNumber)
            driver.setOffline()
        }
        
        
    }
    
    private class func installResourcesInSupportFolder() {
        
        if let supportFolder = SupportFolder {
            
            // Create supportFolder if needed
            var isFolder:ObjCBool = false
            let supportFolderExists = DefaultFilemanager.fileExists(atPath: supportFolder.path, isDirectory: &isFolder) && isFolder.boolValue
            if !supportFolderExists{
                do {
                    try DefaultFilemanager.createDirectory(atPath: supportFolder.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    //TODO: - finish errorHandling
                }
            }
            
            // Install the files in it
            let supportfilesToInstall = [ConfigFile, InverterData]
            
            for supportfile in supportfilesToInstall{
                let allReadyInstalled = DefaultFilemanager.fileExists(atPath:supportfile!.path)
                if !allReadyInstalled {
                    
                    if let resourceFolder = ResourceFolder{
                        
                        let fileName = supportfile?.lastPathComponent
                        let resourceURL = resourceFolder.appendingPathComponent(fileName!)
                                                
                        do {
                            try FileManager.default.copyItem(at: resourceURL, to: supportfile!)
                        } catch {
                            //TODO: - finish errorHandling
                        }
                    }
                }
            }
        }
    }
    
    private class func readTheConfigFile()->Int?{
        
        let errorCode:Int32 = -1
        var resultCode:Int32 = errorCode
        
        let numberOfAvailableDrivers:UnsafeMutablePointer<Handle> = UnsafeMutablePointer<Handle>.allocate(capacity: 1)
        resultCode = yasdiMasterInitialize(ConfigFile?.path, numberOfAvailableDrivers)
        
        if resultCode != errorCode{
            return Int(numberOfAvailableDrivers.pointee)
        }else{
            print("❌ ERROR: Inifile '\(ConfigFile?.path)' not found or not readable!")
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
            self.name = "❌ ERROR: Unknown driver"
        }
        
        self.state = State.offline
        
    }
    
    
    private func setOnline()->Bool{
        
        let errorCode:BOOL = 0
        var resultCode:BOOL = errorCode
        
        resultCode = yasdiMasterSetDriverOnline(Handle(number))
        
        if resultCode != errorCode{
            state = State.online
            print("✅ Driver \(name) is now online")
            return true
        }else{
            state = State.offline
            print("❌ ERROR: Failed to set driver \(name) online")
            return false
        }
        
    }
    
    private func setOffline(){
        
        yasdiMasterSetDriverOffline(Handle(number))
        state = State.offline
        print("ℹ️ Driver \(name) is back offline")
        
    }
    
}
