//
//  ContourChartDataProvider.swift
//  Charts
//
//  Created by Steve Wainwright on 16/04/2023.
//

import Foundation
import CoreGraphics

@objc
public protocol ContourChartDataProvider: BarLineScatterCandleBubbleChartDataProvider {
    var contourData: ContourChartData? { get set }
    
    var lowestVisibleY: Double { get }
    var highestVisibleY: Double { get }
    
}
