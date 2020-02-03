//
//  SunnyPortalReporter.swift
//  
//
//  Created by Jan Verrept on 21/12/2019.
//

import Foundation
import ClibYASDI
import JVCocoa
import SwiftSMTP

@available(OSX 10.15, *)
public class SunnyPortalReporter:SMTPClient{
    
    let channelsToReport:[String]
    let inverterDbase:JVSQLdbase = YASDIDriver.InvertersDataBase
    
    var reportTimer:Timer!
    let localDateFormatter = DateFormatter()
    let localTimeFormatter = DateFormatter()
    let reverseDateFormatter = DateFormatter()
    var reportDateString:String!
    var reverseDateString:String!
    
    var inverterSerial:Int!
    var reportPeriod:(start:Double, end:Double)!
    
    var columnNumberTimeStamp:Int!
    var columnNumberDate:Int!
    var columnNumberTime:Int!
    var columnNumberHour:Int!
    
    var columnNumberChannel:Int!
    var columnNumberValue:Int!
    
    var reportData: SQLRecordSet!
    var hourlyDataSet:[[String]:[SQLRow]]!
        
    override public init(){
        
        self.channelsToReport = ["E-Total", "h-Total", "h-On", "Netz-Ein", "Event-Cnt", "Seriennummer", "Pac", "Iac-Ist", "Ipv", "Upv max"]
        
        localDateFormatter.dateFormat = "dd-MM-yyyy"
        localDateFormatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        
        localTimeFormatter.dateFormat = "HH:mm:ss"
        localTimeFormatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        
        reverseDateFormatter.dateFormat = "yyyy-MM-dd"
        reverseDateFormatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        
        super.init()
        
        // Try to send a report every hour
        reportTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { timer in self.sendReport() }
        reportTimer.tolerance = 2.0 // Give the processor some slack
        reportTimer.fire()
    }
    
    
    private func sendReport(){
        
        let startOfReport = Date(timeIntervalSince1970: standardUserDefaults.double(forKey: "startOfNextReport"))
        
        let endOfReport:Date
        let now = Date()
        let minusOneHour = DateComponents(hour: -1)
        var oneHourAgo = Calendar.current.date(byAdding: minusOneHour, to: now)
        oneHourAgo = Calendar.autoupdatingCurrent.date(bySetting: .minute, value: 0, of: oneHourAgo!)
        endOfReport = Calendar.autoupdatingCurrent.date(bySetting: .second, value: 0, of: oneHourAgo!)!
        
        reportPeriod = (start:startOfReport.timeIntervalSince1970,
                        end:endOfReport.timeIntervalSince1970)
        
        if let inverters = SMAInverter.ArchivedInverters{
            
            inverters.forEach{
                inverterSerial = $0
                
                reportData = nil
                searchUnarchivedData()
                if reportData != nil {
                    saveAsCSVFiles()
                    sendEmails()
                }
            }
        }
        
    }
    
    private func searchUnarchivedData(){
        
        let sqlStatement = "SELECT * FROM ReportData WHERE serialNumber = \(inverterSerial!) AND TimeStamp BETWEEN '\(reportPeriod.start)' AND '\(reportPeriod.end)'"
        
        reportData = inverterDbase.select(statement: sqlStatement)
        
        if let dataSet = reportData{
            
            columnNumberTimeStamp = dataSet.header.firstIndex(of: "TimeStamp")
            columnNumberDate = dataSet.header.firstIndex(of: "Date")
            columnNumberTime = dataSet.header.firstIndex(of: "Time")
            columnNumberHour = dataSet.header.firstIndex(of: "Hour")
            
            columnNumberChannel = dataSet.header.firstIndex(of: "Channel")
            columnNumberValue = dataSet.header.firstIndex(of: "Value")
            
            // Split into unique periods (and label them with a proper key)
            hourlyDataSet = Dictionary(
                grouping:dataSet.data,
                by: {
                    let dateKey = "\($0[columnNumberDate]!)"
                    let hourKey = "\($0[columnNumberHour]!)"
                    
                    return [dateKey, hourKey]   }
            )
        }
        
    }
    
    private func saveAsCSVFiles(){
                
        for (dateAndHour, hourOfData) in hourlyDataSet {
            
            // Sort the data by Timstamp
            let sortedData = hourOfData.sorted(by:{
                let firstTimeStamp = ($0[columnNumberTimeStamp] is Double ? Int($0[columnNumberTimeStamp]! as! Double) : $0[columnNumberTimeStamp]! as! Int)
                let secondTimeStamp = ($1[columnNumberTimeStamp] is Double ? Int($1[columnNumberTimeStamp]! as! Double) : $1[columnNumberTimeStamp]! as! Int)
                return firstTimeStamp < secondTimeStamp
            })
            
            // Add the header
            let plantID = standardUserDefaults.string(forKey: "PlantID")!
            reportDateString = dateAndHour.first!.replace(matchPattern: "-", replacementPattern: "/") // Compensate for different seperator in database
            
            let channelData = Dictionary(grouping:sortedData, by:{"\($0[columnNumberChannel]!)"})
            
            let sortedTimes = channelData.first!.value.map{"\($0[columnNumberTime]!)"}
            let periodsHeader:String = sortedTimes.joined(separator: "\t")
            
            var csvSource = """
            SUNNY-MAIL
            Version\t1.2
            Source\tSDC\t\(plantID)
            Date\t\(reportDateString!)
            Language\tEN
            
            Type\tSerialnumber\tChannel\tDate\tDailyValue\t\(periodsHeader)\n
            """
            
            // Add the samples themselves
            for channelName in channelsToReport{
                if let samples = channelData[channelName]{
                    var fields = (samples.first![0...4].map{"\($0!)"})
                    fields += (samples.map{"\($0[columnNumberValue]!)"})
                    let row = fields.joined(separator: "\t")+"\n"
                    csvSource += row
                }
            }
            
            csvSource = formatReport(source: csvSource)
            
            // Save the csv-source to Disk
            let documentsFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let reportsFolderURL = documentsFolderURL.appendingPathComponent("YASDI-reports")
            FileManager.default.checkForDirectory(reportsFolderURL, createIfNeeded: true)
            
            let reportDate = localDateFormatter.date(from: dateAndHour.first!)!
            reverseDateString = reverseDateFormatter.string(from: reportDate)
            let csvFilename = "SunnyPortalExport\(reverseDateString!).csv"
            let csvFileUrl = reportsFolderURL.appendingPathComponent(csvFilename)
            do {
                try csvSource.write(to: csvFileUrl, atomically: true, encoding: .windowsCP1252)
                
            } catch {
                print(error)
                // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            }
            
        }
        
    }
    
    private func formatReport(source:String)->String{
        
        let dataSeperator = ";"
        let reportPrefix = String([Character(UnicodeScalar(0xFF)), Character(UnicodeScalar(0xFE))])
        let nullCharacter = "\0"
        
        var csvSource = source
        csvSource = csvSource.replace(matchPattern: "\t", replacementPattern: dataSeperator)
        csvSource = Array(csvSource).map({$0.isNewline ? "\r"+nullCharacter+"\n"+nullCharacter : String($0)+nullCharacter}).joined()
        csvSource = reportPrefix+csvSource
        return csvSource
        
    }
    
    private func sendEmails(){
        
//        var emailsToSend:[Mail] = []
//        var emailAttachment:String = ""
//
//        for csvFile in csvFiles{
//
//            emailAttachment = csvFile.relativePath.replace(matchPattern: "\\s\\[.*\\]", replacementPattern: "", useRegex: true)
//            do {
//                try FileManager.default.moveItem(atPath: csvFile.relativePath, toPath: emailAttachment)
//            }catch let error as NSError {
//                print("Couldn't prepare email-attachement \(error)")
//            }
//
//            let user:Mail.User = Mail.User(name: "User", email: standardUserDefaults.string(forKey: "SMTPusername") ?? "")
//            var recepients:[Mail.User] = []
//            #if DEBUG
//            recepients.append( Mail.User(name: "Testuser", email:"janverrept@me.com") )
//            #else
//            //TODO: - Reenable this address after tetsting the report
//            //        recepients.append( Mail.User(name: "Sunnyportal", email:"datacenter@sunny-portal.de") )
//            #endif
//
//            //TODO: - Makes this work for multiple files and dates
//            let csvAttachment = Attachment(
//                filePath: emailAttachment
//            )
//
//            let reportMail = Mail(
//                from: user,
//                to: recepients,
//                subject: "SUNNY-MAIL \(reportDateString!)...",
//                text: "This mail was send automatically by Sunny Data Control 3.9.3.4. Please do not reply...",
//                attachments: [csvAttachment]
//            )
//
//            emailsToSend.append(reportMail)
//
//        }
//
//        smtpConnection.send(emailsToSend,
//            // This optional callback gets called after each `Mail` is sent.
//            // `mail` is the attempted `Mail`, `error` is the error if one occured.
//            progress: { (mail, error) in
//                JVDebugger.shared.log(debugLevel: .Error, "Failed to send Sunny-portal-report:\n\(error!)")
//            },
//
//            // This optional callback gets called after all the mails have been sent.
//            // `sent` is an array of the successfully sent `Mail`s.
//            // `failed` is an array of (Mail, Error)--the failed `Mail`s and their corresponding errors.
//            completion: { (sent, failed) in
//            }
//        )
//
//
//        do {
//            try FileManager.default.removeItem(atPath: emailAttachment)
//        }catch let error as NSError {
//            print("Couldn't remove email-attachement \(error)")
//        }
  }
    
}


