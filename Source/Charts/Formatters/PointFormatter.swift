//
//  PointFormatter.swift
//  DGCharts
//
//  Created by Steve Wainwright on 06/04/2023.
//

import Foundation

/// Interface that allows custom formatting of all values inside the chart before they are drawn to the screen.
///
/// Simply create your own formatting class and let it implement PointFormatter. Then override the stringForPoint()
/// method and return whatever you want.

@objc(ChartPointFormatter)
public protocol PointFormatter: AnyObject {
    
    /// Called when a value (from labels inside the chart) is formatted before being drawn.
    ///
    /// For performance reasons, avoid excessive calculations and memory allocations inside this method.
    ///
    /// - Parameters:
    ///   - dataSetIndex:    The index of the DataSet the entry in focus belongs to
    ///   - viewPortHandler: provides information about the current chart state (scale, translation, ...)
    /// - Returns:                   The formatted label ready to be drawn
    func stringForPoint(entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String
}
