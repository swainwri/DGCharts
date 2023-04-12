//
//  VectorFieldMarkerView.swift
//  ChartsDemo-iOS-Swift
//
//  Created by Steve Wainwright on 10/04/2023.
//  Copyright © 2023 dcg. All rights reserved.
//

import Foundation
import DGCharts
#if canImport(UIKit)
    import UIKit
#endif

public class VectorFieldMarkerView: BalloonMarker {
    public var xAxisValueFormatter: AxisValueFormatter
    public var yAxisValueFormatter: AxisValueFormatter
    fileprivate var mgnFormatter = NumberFormatter()
    fileprivate var dirFormatter: NumberFormatter?
    
    public init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets,
                xAxisValueFormatter: AxisValueFormatter, yAxisValueFormatter: AxisValueFormatter, directionFormatter: NumberFormatter?) {
        self.xAxisValueFormatter = xAxisValueFormatter
        self.yAxisValueFormatter = yAxisValueFormatter
        self.dirFormatter = directionFormatter
        self.mgnFormatter.maximumFractionDigits = 3
        
        super.init(color: color, font: font, textColor: textColor, insets: insets)
    }
    
    public override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        if let _entry = entry as? FieldChartDataEntry {
            var string = "x: "
            + xAxisValueFormatter.stringForValue(_entry.x, axis: XAxis())
            + ", y: "
            + yAxisValueFormatter.stringForValue(_entry.y, axis: YAxis())
            + "\nmgn: "
            + mgnFormatter.string(from: NSNumber(floatLiteral: _entry.magnitude))!
            
            if dirFormatter is DegreeFormatter,
                let _dirFormatter = dirFormatter as? DegreeFormatter {
                string += ", angle: " + _dirFormatter.stringForValue(_entry.direction)
            }
            else if let _dirFormatter = dirFormatter {
                _dirFormatter.maximumFractionDigits = 3
                string += ", angle: " + _dirFormatter.string(from: NSNumber(floatLiteral: _entry.direction))!
                string += " rads"
            }
            
            setLabel(string)
        }
    }
    
}
