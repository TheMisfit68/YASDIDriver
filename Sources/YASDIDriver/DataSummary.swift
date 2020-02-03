//
//  DataSummary.swift
//  
//
//  Created by Jan Verrept on 29/12/2019.
//

import Foundation
import SwiftUI
import JVCocoa
import Combine

@available(OSX 10.15, *)
public class DataSummary:DigitalDisplayModel{
    
    weak private var inverter:SMAInverter?
    private var channelNamesToRead:[String]
    
    public init(channelNames:[String]){
        self.channelNamesToRead = channelNames
        super.init()
    }
    
    public func createTextLines(fromInverter inverter:SMAInverter){
        self.inverter = inverter
        
        var currentTextLines:[String] = []
        
        for channelName in channelNamesToRead{
            
            let channels = inverter.spotChannels
            let channel = channels.filter{$0.name == channelName}.first!
            let channelID = channel.channelID
            
            let label = !(channel.description).isEmpty ? channel.description : channel.name
            var value:Any = ""
            let unit = channel.unit
            
            if let availableData = inverter.measurementValues{
                let measurement = availableData.filter{$0.channelID == channelID}.last
                if measurement != nil{
                    value = measurement!.value as Any
                    if value is Double{
                        var doubleValue:Double = value as! Double
                        switch channelName {
                        case "Pac":
                            super.backLightOn = (doubleValue > 0.000)
                        case "E-Total":
                            doubleValue = doubleValue*inverterYieldFaultPercentage // Compensate for the deviation on my inverter
                        default:
                            break
                        }
                        value = String(format: "%.0f", doubleValue)
                    }
                }
            }
            let textLine = "\(label):\t\t\(value)\t\(unit)"
            currentTextLines.append(textLine)
            
            // Only update when display is active
            if super.backLightOn{
                super.textLines = currentTextLines
            }
        }
        
    }
}






