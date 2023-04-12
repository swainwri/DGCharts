//
//  FieldChartDataProvider.swift
//  DGCharts
//
//  Created by Steve Wainwright on 09/04/2023.
//

import Foundation
import CoreGraphics

@objc
public protocol FieldChartDataProvider: BarLineScatterCandleBubbleChartDataProvider {
    var vectorFieldData: VectorFieldChartData? { get }
    
    var lowestVisibleY: Double { get }
    var highestVisibleY: Double { get }
}
