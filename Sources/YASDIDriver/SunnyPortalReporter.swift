//
//  SunnyPortalReporter.swift
//  
//
//  Created by Jan Verrept on 21/12/2019.
//

import Foundation
import JVCocoa

@available(OSX 10.12, *)
public class SunnyPortalReporter{
    
    let localDateFormatter:DateFormatter = DateFormatter()
    var reportTimer:Timer!
    
    init(){
        localDateFormatter.timeZone = TimeZone.current
        localDateFormatter.dateFormat = "dd-MM-yyyy" // Local date string
        
        let today = Date()
        let calendar:Calendar = Calendar(identifier: .gregorian)
        if let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: today){
            reportTimer = Timer.init(fire: midnight, interval: 86400, repeats: true, block: { timer in self.sendReport() })
            reportTimer.tolerance = 60.0 // Give the processor some slack
        }
    }
    
    public func sendReport(){
        JVDebugger.shared.log(debugLevel: .Event, "Report would be generated")
    }
    
    private func saveCsvFile(forDate dateQueried: String){
        
        var CSVSource = """
                        SUNNY-MAIL
                        Version    1.2
                        Source    SDC
                        Date    01/12/2017
                        Language    EN
                
                        Type    Serialnumber    Channel    Date    DailyValue    10:47:06    11:02:06
                """
        
        let dataSeperator = ";"
        
        
        if let dailyRecords = searchData(forDate: Date()){
            let columNamesToReport = ["Type","SerialNumber","Channel","Date","DailyValue","valueColumns"]
            
//            if let firstRecordedTime = localDateFormatter.date(from: dailyRecords.value(rowNumber:0, columnName: "samplingTime") as! String){
//                
//                var timeToReport = firstRecordedTime
//                let dateColumnNumber = dailyRecords.header.firstIndex(of: "samplingTime")!
//                
//                for record in dailyRecords.data{
//                    if  let recordedTime = localDateFormatter.date(from: (record[dateColumnNumber] as! String )){
//                        
//                        if recordedTime.compare(timeToReport) == ComparisonResult.orderedAscending{
//                            // Not there yet
//                        }else if recordedTime.compare(timeToReport) == ComparisonResult.orderedDescending{
//                            // Shooting past the interval, point to the next higher interval
//                            while recordedTime.compare(timeToReport) == ComparisonResult.orderedDescending{
//                                timeToReport = timeToReport.addingTimeInterval(15*60)
//                            }
//                            // and give it a second shot
//                            if recordedTime.compare(timeToReport) == ComparisonResult.orderedSame{
//                                //                                recordsToReport.append(record)
//                            }
//                        }else{
//                            // When it was recorded at the exact time-interval
//                            // Put the record in the report
//                            //                            recordsToReport.append(record)
//                        }
//                        
//                    }
//                    
//                }
//            }
            print(CSVSource) // replace with saved CSVFile
            
        }
    }
    
    private func searchData(forDate reportDate:Date)->SQLRecordSet?{
        
        let searchRequest = Measurement(
            measurementID: nil,
            //            samplingTime: nil,
            timeStamp: "",
            date: localDateFormatter.string(from: reportDate),
            time: "",
            value: 0.0,
            channelID: -1
        )
        
        return searchRequest.find(matchFields: ["date"])
    }
    
}
