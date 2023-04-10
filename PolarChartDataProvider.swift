//
//  PolarChartDataProvider.swift
//  DGCharts
//
//  Created by Steve Wainwright on 04/04/2023.
//

import Foundation
import CoreGraphics

@objc
public protocol PolarChartDataProvider {
    
    /// The minimum theta-value of the chart, regardless of zoom or translation.
    var chartThetaMin: Double { get }
    
    /// The maximum theta-value of the chart, regardless of zoom or translation.
    var chartThetaMax: Double { get }
    
    /// The minimum radial-value of the chart, regardless of zoom or translation.
    var chartRadialMin: Double { get }
    
    /// The maximum radial-value of the chart, regardless of zoom or translation.
    var chartRadialMax: Double { get }
    
    var maxHighlightRadius: CGFloat { get }
    
    var thetaRange: Double { get }
    
    var centerOffsets: CGPoint { get }

    var maxVisibleCount: Int { get }
    
    var polarData: PolarChartData? { get }
    
    func getTransformer(forAxis: RadialAxis.PolarAxisDependency) -> Transformer
    func isInverted() -> Bool
    
    var lowestVisibleTheta: Double { get }
    var highestVisibleTheta: Double { get }
    
}
