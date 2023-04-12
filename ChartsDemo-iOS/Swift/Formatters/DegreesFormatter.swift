//
//  DegreesFormatter.swift
//  ChartsDemo-iOS-Swift
//
//  Created by Steve Wainwright on 10/04/2023.
//  Copyright © 2023 dcg. All rights reserved.
//

import Foundation
import DGCharts


class DegreeFormatter : NumberFormatter, ValueFormatter, AxisValueFormatter {
    
    fileprivate func format(value: Double) -> String {
        var remaining = value

        let degree = remaining.rounded(.towardZero)
        remaining -= value
        remaining *= 60.0

        let minute = remaining.rounded(.towardZero)
        remaining -= minute
        remaining *= 60

        let seconds = remaining

        return "\(Int(degree))°\(Int(minute))'\(self.string(from: seconds as NSNumber)!)"
    }
    
    public func stringForValue(_ value: Double) -> String {
        return format(value: value)
    }
    
    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return format(value: value)
    }
    
    public func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        return format(value: value)
    }
}

