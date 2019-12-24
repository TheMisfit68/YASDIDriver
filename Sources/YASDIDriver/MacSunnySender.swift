//
//  MacSunnySender.swift
//  
//
//  Created by Jan Verrept on 21/12/2019.
//

import Foundation
import JVCocoa

public class MacsunnySender{
    
    //        public func saveCsvFile(forDate dateQueried: String){
    //
    //            let dateFormatter = DateFormatter()
    //            dateFormatter.timeZone = TimeZone.current
    //            dateFormatter.dateFormat = "dd-MM-yyyy" // Local date string
    //
    //            var CSVSource = """
    //                    SUNNY-MAIL
    //                    Version    1.2
    //                    Source    SDC
    //                    Date    01/12/2017
    //                    Language    EN
    //
    //                    Type    Serialnumber    Channel    Date    DailyValue    10:47:06    11:02:06
    //            """
    //
    //            let dataSeperator = ";"
    //
    //            if let dailyRecords = searchData(forDate: Date()){
    //            let columNamesToReport = ["Type","SerialNumber","Channel","Date","DailyValue","valueColumns"]
    //
    //                if let firstRecordedTime = dateFormatter.date(from: (dailyRecords.value(columnumber:0, columnName: "samplingTime")!){
    //
    //                    var timeToReport = firstRecordedTime
    //
    //                    for record in dailyRecords{
    //                        let recordedTime = dateFormatter.date(from: (record["samplingTime"])!)
    //
    //                        if recordedTime?.compare(timeToReport) == ComparisonResult.orderedAscending{
    //                            // Not there yet
    //                        }else if recordedTime?.compare(timeToReport) == ComparisonResult.orderedDescending{
    //                            // Shooting past the interval, point to the next higher interval
    //                            while recordedTime?.compare(timeToReport) == ComparisonResult.orderedDescending{
    //                                timeToReport = timeToReport.addingTimeInterval(15*60)
    //                            }
    //                            // and give it a second shot
    //                            if recordedTime?.compare(timeToReport) == ComparisonResult.orderedSame{
    //                               // recordsToReport.append(record)
    //                            }
    //                        }else{
    //                            // When it was recorded at the exact time-interval
    //                            // Put the record in the report
    //                           // recordsToReport.append(record)
    //                        }
    //
    //                    }
    //
    //                }
    //            }
    //            print(CSVSource) // replace with saved CSVFile
    //
    //        }
    //
    
//    private func searchData(forDate reportDate:Date)->SQLRecordSet?{
//
//        let dateFormatter = DateFormatter()
//        dateFormatter.timeZone = TimeZone.current
//        dateFormatter.dateFormat = "dd-MM-yyyy" // Local date string
//
//        let searchRequest = Measurement(
//            measurementID: nil,
////            samplingTime: nil,
//            timeStamp: nil,
//            date: dateFormatter.string(from: reportDate),
//            time: nil,
//            value: nil,
//            channelID: nil
//        )
//
//        return searchRequest.find()
//    }
//
}



