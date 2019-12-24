//
//  Model.swift
//  
//
//  Created by Jan Verrept on 09/12/2019.
//

import Foundation
import Cocoa
import JVCocoa

let inverterData:JVSQLdbase = JVSQLdbase.open(file: "InverterData.sqlite")

public struct Inverter:SQLRecordable{

    var inverterID: SQLID! = nil
    var serial: Int! = nil
    var number: Handle! = nil
    var name: String! = nil
    var type: String! = nil
}


public struct Channel:SQLRecordable{

    var channelID: SQLID! = nil
    var type: Int! = nil
    var number:Int! = nil
    var name: String! = nil
    var unit: String! = nil
    var inverterID: Int! = nil
}


public struct Measurement:SQLRecordable{
    
    var measurementID: SQLID! = nil
//    var samplingTime:String! = nil
    var timeStamp:String! = nil
    var date: String! = nil
    var time: String! = nil
    var value: Double! = nil
    var channelID:Int! = nil
    
}
