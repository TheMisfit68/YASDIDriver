//
//  File.swift
//  
//
//  Created by Jan Verrept on 02/12/2019.
//

import Foundation
import ClibYASDI

typealias Handle = DWORD
let MAXCSTRINGLENGTH:Int = 32

enum ChannelsType:UInt32{
       case spotChannels
       case parameterChannels
       case testChannels
       case allChannels
}
