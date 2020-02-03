//
//  GSCNotifier.swift
//  HAPiNest
//
//  Created by Jan Verrept on 19/01/2020.
//  Copyright © 2020 Jan Verrept. All rights reserved.
//

import Foundation
import Cocoa
import JVCocoa
import SwiftSMTP


@available(OSX 10.15, *)
public class GSCNotifier:SMTPClient{
    
    let inverterDbase:JVSQLdbase = YASDIDriver.InvertersDataBase
    var checkForGSCtimer:Timer!
    
    override public init() {
        super.init()
        // Check every hour for a new GSC and report if so
        checkForGSCtimer = Timer.scheduledTimer(withTimeInterval: 3600.0, repeats: true) { timer in self.checkForGSC() }
        checkForGSCtimer.tolerance = 60.0 // Give the processor some slack
        checkForGSCtimer.fire()
    }
    
    
    public func checkForGSC(){
        
        if let inverters = SMAInverter.ArchivedInverters{
            
            inverters.forEach{
                
                let deviceSerial = $0
                
                let sqlStatement = "SELECT MAX(Measurement.value) from Inverter JOIN Channel USING(InverterID) JOIN Measurement USING(channelID) WHERE Inverter.serial = \(deviceSerial) AND Channel.name='E-Total'"
                
                if let totalInverterYield = inverterDbase.select(statement: sqlStatement)?.data.first?.first{
                    if totalInverterYield is Double{
                        let compensatedInverterYield = (totalInverterYield as! Double)*inverterYieldFaultPercentage
                        
                        let previousGSC = standardUserDefaults.integer(forKey: "PreviousGSC")
                        let currentGSC = Int(compensatedInverterYield/1000)
                        
                        if currentGSC > previousGSC{
                            sendEmailNotification(totalInverterYield: compensatedInverterYield, yieldPerGSC: 1000, revenuePerGSC: 450)
                            standardUserDefaults.set(currentGSC, forKey: "PreviousGSC")
                        }
                    }
                }
                
            }
        }
    }
    
    
    private func sendEmailNotification(totalInverterYield:Double, yieldPerGSC:Int, revenuePerGSC:Int) {
        
        let totalRevenue = Int(totalInverterYield)/yieldPerGSC*revenuePerGSC
        let inverterYield = String(format: "%.0f", totalInverterYield)
        
        let publisher:Mail.User = Mail.User(name: "Publisher", email: standardUserDefaults.string(forKey: "SMTPusername") ?? "")
        
        var subscribers:[Mail.User] = []
        let subscriberEmails = standardUserDefaults.stringArray(forKey: "Subscribers")!
        for (subscriberNumber, subscriberEmail) in subscriberEmails.enumerated(){
            subscribers.append( Mail.User(name: "Subscriber\(subscriberNumber)", email:subscriberEmail) )
        }
        
        let mailNotification = Mail(
            from: publisher,
            to: subscribers,
            subject: "FYI: Nieuw Groen Stroom Certificaat op ☀️ \(inverterYield) kWh ☀️ [EOM]",
            text: "Totale opbrengst certificaten = \(totalRevenue)€ 🤑"
        )
        
        smtpConnection.send(mailNotification) { (error) in
            if let error = error {
                JVDebugger.shared.log(debugLevel: .Error, "Failed to send GSC-emailnotification:\n\(error)")
            }
        }
        
    }
    
    
    
}
