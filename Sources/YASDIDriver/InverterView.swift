//
//  InverterView.swift
//  
//
//  Created by Jan Verrept on 05/12/2020.
//

import JVCocoa
import SwiftUI

public struct InverterView: View{
    @ObservedObject var dataSummary:DataSummary
    
    public var body: some View {
        DigitalDisplayView(dataSummary: dataSummary)
            .onAppear(perform: {dataSummary.update()})
    }
    
}

// Make DigitalDisplayView compatible with DataSummary
extension DigitalDisplayView{
    
    init(dataSummary:DataSummary){
        self.init(linesToDisplay:dataSummary.linesToDisplay, backLightOn: dataSummary.backLightOn, color: Color(#colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)))
    }
    
}
