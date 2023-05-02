//
//  ContourMarkerView.swift
//  ChartsDemo-iOS-Swift
//
//  Created by Steve Wainwright on 25/04/2023.
//  Copyright © 2023 dcg. All rights reserved.
//

import Foundation
import DGCharts
#if canImport(UIKit)
    import UIKit
#endif

public class ContourMarkerView: BalloonMarker {
    public var xAxisValueFormatter: AxisValueFormatter
    public var yAxisValueFormatter: AxisValueFormatter
    fileprivate var fxyFormatter = NumberFormatter()
    
    
    public init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets,
                xAxisValueFormatter: AxisValueFormatter, yAxisValueFormatter: AxisValueFormatter) {
        self.xAxisValueFormatter = xAxisValueFormatter
        self.yAxisValueFormatter = yAxisValueFormatter
        self.fxyFormatter = NumberFormatter()
        self.fxyFormatter.maximumFractionDigits = 3
        
        super.init(color: color, font: font, textColor: textColor, insets: insets)
    }
    
    public override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        if let _entry = entry as? FieldChartDataEntry {
            var string = "x: "
            + xAxisValueFormatter.stringForValue(_entry.x, axis: XAxis())
            + ", y: "
            + yAxisValueFormatter.stringForValue(_entry.y, axis: YAxis())
            + "\nf(x,y): "
            + fxyFormatter.string(from: NSNumber(floatLiteral: _entry.fxy))!
            
            setLabel(string)
        }
    }
    
}
