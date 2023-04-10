//
//  PolarFillFormatter.swift
//  DGCharts
//
//  Created by Steve Wainwright on 04/04/2023.
//

import Foundation
import CoreGraphics

/// Protocol for providing a custom logic to where the filling line of a LineDataSet should end. This of course only works if setFillEnabled(...) is set to true.
@objc(ChartPolarFillFormatter)
public protocol PolarFillFormatter {
    /// - Returns: The major-axis position or radius where the filled-line of the LineDataSet should end.
    func getFillLineRadius(dataSet: PolarChartDataSetProtocol, dataProvider: PolarChartDataProvider) -> CGFloat
}
