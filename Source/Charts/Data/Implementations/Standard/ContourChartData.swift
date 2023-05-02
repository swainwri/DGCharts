//
//  ContourChartData.swift
//  DGCharts
//
//  Created by Steve Wainwright on 16/04/2023.
//

import Foundation
import CoreGraphics

public class ContourChartData: BarLineScatterCandleBubbleChartData {
   public required init() {
       super.init()
   }
   
   public override init(dataSets: [ChartDataSetProtocol]) {
       super.init(dataSets: dataSets)
   }

   public required init(arrayLiteral elements: ChartDataSetProtocol...) {
       super.init(dataSets: elements)
   }
   
}
