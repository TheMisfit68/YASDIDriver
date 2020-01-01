//
//  InverterDisplay.swift
//  
//
//  Created by Jan Verrept on 29/12/2019.
//

import Foundation
import SwiftUI

/**
 Display
 Resembles the fisical display of a SMA-solar inverter
 contains a predefined number of datalines (each a channellabel,  value and unit)
 refreshes itself indepent from the Inverters polling cycle
 */
@available(OSX 10.15, *)
public class InverterDisplay{
    
    public var channelNamesToRead:[String]
    public var view: DisplayView =  DisplayView()

    public struct DisplayView:View{
        public var dataToDisplay:[Data] = []
        public var body: some View {
            List(dataToDisplay, rowContent: DataRow.init)
        }
    }
    
    public var refreshRateInSeconds = 2.0{
        didSet{
            refreshTimer.invalidate()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshRateInSeconds, repeats: true) { timer in self.refreshView() }
            refreshTimer.tolerance = refreshRateInSeconds/2.0 // Give the processor some slack
        }
    }
    
    private unowned var inverter:SMAInverter
    private var refreshTimer:Timer!

    init(forInverter inverter:SMAInverter, channelNames:[String]){
        self.inverter = inverter
        self.channelNamesToRead = channelNames
        
        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshRateInSeconds, repeats: true) { timer in self.refreshView()  }
        self.refreshTimer.tolerance = refreshRateInSeconds/2.0 // Give the processor some slack
    }
    
    public struct Data:Identifiable{
        public var id = UUID()
        let label:String
        let value:Any
        let unit:String
    }
    
    public struct DataRow:View{
        var data: Data
        
        public var body: some View {
            HStack{
                Text(data.label)
                Text(String(describing: data.value))
                Text(data.unit)
            }
        }
        
    }
    
    func refreshView(){
        
        var dataToDisplay:[Data] = []
        for channelName in channelNamesToRead{
                        
            let channels = inverter.spotChannels
            let channel = channels.filter{$0.name == channelName}.first!
            let channelID = channel.channelID
            
            let label = !(channel.description).isEmpty ? channel.description : channel.name
            var value:Any = ""
            let unit = channel.unit
            
            if let availableData = inverter.measurementValues{
                let measurement = availableData.filter{$0.channelID == channelID}.last
                value = measurement?.value as Any
            }
            
            let data = Data(label: label, value: value, unit: unit)
            dataToDisplay.append(data)
        }
        self.view.dataToDisplay = dataToDisplay
    }
    
}


