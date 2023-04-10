//
//  VectorFieldChartDataProvider.swift
//  DGCharts
//
//  Created by Steve Wainwright on 09/04/2023.
//

import Foundation
import CoreGraphics

@objc
public protocol VectorFieldChartDataProvider: BarLineScatterCandleBubbleChartDataProvider {
    var vectorFieldData: VectorFieldChartData? { get }
}
