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
    let smtpConnection:SMTP
    
    public init(){
        
        // Read all SMTP-settings from the UserDefaults
        self.smtpConnection = SMTP(
            hostname: standardUserDefaults.string(forKey: "SMTPserver") ?? "",
            email: standardUserDefaults.string(forKey: "SMTPusername") ?? "",
            password: standardUserDefaults.string(forKey: "SMTPpassword") ?? "",
            port: Int32(standardUserDefaults.integer(forKey: "SMTPport")),
            tlsMode: standardUserDefaults.bool(forKey: "SMTPusesSSL") ? .normal : .ignoreTLS,
            tlsConfiguration: nil,
            authMethods: [.login],
            domainName: "localhost",
            timeout: 5
        )
        
    }
    
}
