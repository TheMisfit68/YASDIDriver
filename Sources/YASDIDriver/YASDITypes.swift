//
//  File.swift
//  
//
//  Created by Jan Verrept on 02/12/2019.
//

import Foundation
import ClibYASDI
import JVCocoa

typealias Handle = DWORD
let MAXCSTRINGLENGTH:Int = 32

enum ChannelsType:UInt32{
       case spotChannels
       case parameterChannels
       case testChannels
       case allChannels
}


public struct Inverter:SQLRecordable{

    var inverterID: SQLID?
    var serial: Int
    var number: Handle
    var name: String
    var type: String
}


public struct Channel:SQLRecordable{

    var channelID: SQLID?
    var type: Int
    var number:Int
    var name: String
    var description: String
    var unit: String
    var inverterID: Int
}


public struct Measurement:SQLRecordable{
    
    var measurementID: SQLID?
//    var samplingTime:String
    var timeStamp:String
    var date: String
    var time: String
    var value: Double
    var channelID:Int
    
}
