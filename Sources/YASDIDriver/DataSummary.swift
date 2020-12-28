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


public class DataSummary:ObservableObject{
    @Published var linesToDisplay:[String] = []
    @Published var backLightOn:Bool = false
    
    weak private var inverter:SMAInverter?
    private var channelNamesToRead:[String]
    
    public init(inverter:SMAInverter, channelNames:[String]){
        self.inverter = inverter
        self.channelNamesToRead = channelNames
    }
    
    public func update(){
        
        if let inverter = self.inverter{
            
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
                                backLightOn = (doubleValue > 0.000)
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
                if backLightOn{
                    linesToDisplay = currentTextLines
                }
            }
            
        }
    }
}






