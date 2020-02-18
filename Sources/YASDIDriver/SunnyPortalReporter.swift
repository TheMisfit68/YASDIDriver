//
//  SunnyPortalReporter.swift
//  
//
//  Created by Jan Verrept on 21/12/2019.
//

import Cocoa
import Foundation
import ClibYASDI
import JVCocoa
import SwiftSMTP


#if DEBUG
let ccReportToLocalMail = true
#endif

@available(OSX 10.15, *)
public class SunnyPortalReporter:SMTPClient{
    
    let disableExternalMails = false
    var sunnyPortalSettings:[String:Any] = [:]
    
    let channelsToReport:[String] = ["E-Total", "h-Total", "h-On", "Netz-Ein", "Event-Cnt", "Seriennummer", "Pac", "Iac-Ist", "Ipv", "Upv max"]
    
    let inverterDbase:JVSQLdbase = YASDIDriver.InvertersDataBase
    var reportTimer:Timer!
    var inverterSerial:Int!
    var reportsPeriod:(start:Double, end:Double)!
    
    var columnNumberTimeStamp:Int!
    var columnNumberDate:Int!
    var columnNumberTime:Int!
    var columnNumberHour:Int!
    var columnNumberChannel:Int!
    var columnNumberValue:Int!
    
    let localDateFormatter = DateFormatter()
    let reportDateFormatter = DateFormatter()
    let fileDateFormatter = DateFormatter()
    let mailDateFormatter = DateFormatter()
    
    var reportData: SQLRecordSet!
    var hourlyDataSet:[Date:[SQLRow]]!
    var reportsFolderURL:URL!
    
    override public init(){
        
        localDateFormatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        localDateFormatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        
        reportDateFormatter.dateFormat = "MM/dd/yyyy"
        reportDateFormatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        
        fileDateFormatter.dateFormat = "yyyyMMdd [HH]"
        fileDateFormatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        
        mailDateFormatter.dateFormat = "dd/MM/yyyy"
        mailDateFormatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        
        let documentsFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        reportsFolderURL = documentsFolderURL.appendingPathComponent("YASDI-reports")
        FileManager.default.checkForDirectory(reportsFolderURL, createIfNeeded: true)
        
        super.init()
        
        sunnyPortalSettings = standardUserDefaults.dictionary(forKey: "SunnyPortalSettings")!
        
        // Try to send a report every hour
        reportTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { timer in self.sendReport() }
        reportTimer.tolerance = 2.0 // Give the processor some slack
        reportTimer.fire()
        
    }
    
    
    private func sendReport(){
        
        let startOfReport = Date(timeIntervalSince1970: sunnyPortalSettings["StartOfNextReport"] as! Double)
        let endOfReport:Date
        let now = Date()
        let minusOneHour = DateComponents(hour: -1)
        var oneHourAgo = Calendar.current.date(byAdding: minusOneHour, to: now)
        oneHourAgo = Calendar.autoupdatingCurrent.date(bySetting: .minute, value: 0, of: oneHourAgo!)
        endOfReport = Calendar.autoupdatingCurrent.date(bySetting: .second, value: 0, of: oneHourAgo!)!
        reportsPeriod = (start:startOfReport.timeIntervalSince1970,
                         end:endOfReport.timeIntervalSince1970)
        sunnyPortalSettings["StartOfNextReport"]  = reportsPeriod.end+1
        standardUserDefaults.set(sunnyPortalSettings, forKey: "SunnyPortalSettings")
        standardUserDefaults.synchronize()
        
        
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
        
        let sqlStatement = "SELECT * FROM ReportData WHERE serialNumber = \(inverterSerial!) AND TimeStamp BETWEEN '\(reportsPeriod.start)' AND '\(reportsPeriod.end)'"
        
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
                    let dateString =  "\($0[columnNumberDate]!) \($0[columnNumberHour]!):00:00"
                    let reportDate = localDateFormatter.date(from:dateString)
                    return reportDate!}
            )
        }
        
    }
    
    private func saveAsCSVFiles(){
        
        for (date, hourOfData) in hourlyDataSet {
            
            // Sort the data by Timstamp
            let sortedData = hourOfData.sorted(by:{
                let firstTimeStamp = ($0[columnNumberTimeStamp] as! Int)
                let secondTimeStamp = ($1[columnNumberTimeStamp] as! Int)
                return firstTimeStamp < secondTimeStamp
            })
            
            // Add the header
            let plantID = sunnyPortalSettings["PlantID"] as! String
            let dateString = reportDateFormatter.string(from: date)
            let channelData = Dictionary(grouping:sortedData, by:{"\($0[columnNumberChannel]!)"})
            
            let sampleTimes = channelData.first!.value.map{"\($0[columnNumberTime]!)"}
            let periodsHeader:String = sampleTimes.joined(separator: "\t")
            
            var csvSource = """
            SUNNY-MAIL
            Version\t1.2
            Source\tSDC\t\(plantID)
            Date\t\(dateString)
            Language\tEN
            
            Type\tSerialnumber\tChannel\tDate\tDailyValue\t\(periodsHeader)\n
            """
            
            // Add the samples themselves
            for channelName in channelsToReport{
                if let samples = channelData[channelName]{
                    var fields = (samples.first![0...2].map{"\($0!)"})
                    fields.append(dateString)
                    fields.append("")
                    fields += (samples.map{"\($0[columnNumberValue]!)"})
                    let row = fields.joined(separator: "\t")+"\n"
                    csvSource += row
                }
            }
            
            csvSource = formatReport(source: csvSource)
            
            // Save the csv-source to Disk
            let fileDateString = fileDateFormatter.string(from: date)
            let csvFilename = "SunnyPortalExport\(fileDateString).csv"
            let csvFileUrl = reportsFolderURL.appendingPathComponent(csvFilename)
            if FileManager.default.fileExists(atPath: csvFileUrl.path){
                try? FileManager.default.removeItem(atPath: csvFileUrl.path)
            }
            
            do {
                try csvSource.write(to: csvFileUrl, atomically: true, encoding: .windowsCP1252)
                
            } catch {
                JVDebugger.shared.log(debugLevel: .Error, "Failed to write Sunny-portal-report:\n\(error)")
            }
            
        }
        
    }
    
    private func sendEmails(){
        
        let filesInReportFolder = FileManager.default.enumerator(atPath: reportsFolderURL.path)
        var emailsToSend:[(mail:Mail, reportFile:URL)] = []
        
        while let fileName = filesInReportFolder?.nextObject() as? String {
            if (fileName.hasSuffix(".csv")){
                let reportName = fileName
                let reportFile = reportsFolderURL.appendingPathComponent(reportName)
                
                let reportDateString = String(reportName[reportName.range(of: "\\d\\d\\d\\d\\d\\d\\d\\d\\s\\[\\d\\d\\]",options: .regularExpression)!])
                let reportDate = fileDateFormatter.date(from: reportDateString)!
                let mailDateString = mailDateFormatter.string(from: reportDate)
                
                let attachmentName = reportName.replace(matchPattern: "\\s\\[\\d\\d\\]", replacementPattern: "", useRegex: true)
                
                let fromAddress = sunnyPortalSettings["Account"] as! String
                let toAddress = "datacenter@sunny-portal.de"
                let replyAddress = fromAddress
                let testAddress = replyAddress
                
                let sender:Mail.User = Mail.User(name: "SunnyPortalAccount", email: fromAddress)
                
                var recepients:[Mail.User] = []
                recepients.append( Mail.User(name: "SunnyPortal", email:toAddress) )
                
                var ccRecepients:[Mail.User] = []
                
                if disableExternalMails{
                    recepients.removeAll()
                }
                
                #if DEBUG
                if recepients.count == 0 {
                    recepients.append( Mail.User(name: "TestUser", email: testAddress))
                }else{
                    ccRecepients.append( Mail.User(name: "TestUser", email: testAddress))
                }
                #endif
                
                let csvAttachment = Attachment(
                    filePath: reportFile.path,
                    name: attachmentName
                )
                
                // Prepare the actual mails
                if recepients.count > 0{
                    let reportMail = Mail(
                        from: sender,
                        to: recepients,
                        cc: ccRecepients,
                        subject: "SUNNY-MAIL \(mailDateString)...",
                        text: "This mail was send automatically by Sunny Data Control 3.9.3.4. Please do not reply...",
                        attachments: [csvAttachment],
                        additionalHeaders: ["REPLY-TO": replyAddress]
                    )
                    
                    emailsToSend.append((mail:reportMail, reportFile:reportFile))
                }
            }
            
        }
        
        if emailsToSend.count > 0 {
            let allEmails = emailsToSend.map{($0.mail)}
            
            smtpConnection.send(allEmails,
                                
                                progress: { (mail, error) in
                                    // This optional callback gets called after each `Mail` is sent.
                                    // `mail` is the attempted `Mail`, `error` is the error if one occured.
                                    if error != nil{
                                        JVDebugger.shared.log(debugLevel: .Error, "Failed to send Sunny-portal-report: \(error!)")
                                    }else{
                                        
                                    }
                                    
            },
                                completion: { (sent, failed) in
                                    // This optional callback gets called after all the mails have been sent.
                                    // `sent` is an array of the successfully sent `Mail`s.
                                    sent.forEach({
                                        // Cleanup Attachment after succesfull send
                                        let finishedMail = $0
                                        let origin = emailsToSend.filter{($0.mail.id==finishedMail.id)}.first
                                        let parsedReport = origin?.reportFile
                                        if FileManager.default.fileExists(atPath: parsedReport!.path){
                                            try? FileManager.default.removeItem(atPath: parsedReport!.path)
                                        }
                                    })
                                    
                                    // `failed` is an array of (Mail, Error)--the failed `Mail`s and their corresponding errors.
                                    failed.forEach({
                                        let failedMail = $0
                                        let error = failedMail.1
                                        JVDebugger.shared.log(debugLevel: .Error, "Failed to send Sunny-portal-report: \(error)")
                                    })
                                    
            }
            )
            
        }
    }
    
    private func formatReport(source:String)->String{
        
        let dataSeperator = ";"
        let reportPrefix = String([Character(UnicodeScalar(0xFF)), Character(UnicodeScalar(0xFE))])
        let nullCharacter = "\0"
        
        var csvSource = source
        csvSource = csvSource.replace(matchPattern: "\t", replacementPattern: dataSeperator) // Don't use Tabs but ";" as separator
        csvSource = Array(csvSource).map({$0.isNewline ? "\r"+nullCharacter+"\n"+nullCharacter : String($0)+nullCharacter}).joined() // Add a null character to every character even newlines
        csvSource = reportPrefix+csvSource // Add bytes 0xFF, 0xFE to the beginning of the report
        return csvSource
        
    }
    
    private func sendDeviceDefinitionFile(){
        //TODO: - Send .dti-file from here
    }
    
}
