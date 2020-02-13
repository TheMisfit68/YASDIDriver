//
//  SMTPClient.swift
//  
//
//  Created by Jan Verrept on 21/01/2020.
//

import Foundation

import JVCocoa
import SwiftSMTP


public class SMTPClient{
    
    let standardUserDefaults = UserDefaults.standard
    var smtpSettings:[String:Any]
    let smtpConnection:SMTP
    
    public init(){
        
        smtpSettings = standardUserDefaults.dictionary(forKey: "SMTPsettings")!
        
        self.smtpConnection = SMTP(
            hostname: smtpSettings["Server"] as! String,
            email: smtpSettings["UserName"] as! String,
            password: smtpSettings["Password"] as!String,
            port: Int32(smtpSettings["Port"] as! Int),
            tlsMode: smtpSettings["UseSSL"] as! Bool ? .normal : .ignoreTLS,
            tlsConfiguration: nil,
            authMethods: [.login],
            domainName: "localhost",
            timeout: 5
        )
        
    }
    
    
    
}
