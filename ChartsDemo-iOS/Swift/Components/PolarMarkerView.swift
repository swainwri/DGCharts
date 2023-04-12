//
//  PolarMarkerView.swift
//  ChartsDemo-iOS-Swift
//
//  Created by Steve Wainwright on 12/04/2023.
//  Copyright © 2023 dcg. All rights reserved.
//

import Foundation
import DGCharts
#if canImport(UIKit)
    import UIKit
#endif

public class PolarMarkerView: BalloonMarker {

    public var angleValueFormatter: NumberFormatter?
    fileprivate var radialValueFormatter = NumberFormatter()
    
    public init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets,
                angleValueFormatter: NumberFormatter?) {
        if angleValueFormatter is DegreeFormatter,
           let _angleValueFormatter = angleValueFormatter as? DegreeFormatter {
            self.angleValueFormatter = _angleValueFormatter
        }
        else if let _angleValueFormatter = angleValueFormatter  {
            self.angleValueFormatter = _angleValueFormatter
        }
        radialValueFormatter.maximumFractionDigits = 3
        
        super.init(color: color, font: font, textColor: textColor, insets: insets)
    }
    
    public override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        
        var string = "radial: "
        + radialValueFormatter.string(from: NSNumber(floatLiteral: entry.y))!
        
        if angleValueFormatter is DegreeFormatter,
            let _angleValueFormatter = angleValueFormatter as? DegreeFormatter {
            string += ", angle: " + _angleValueFormatter.stringForValue(entry.x)
        }
        else if let _angleValueFormatter = angleValueFormatter {
            _angleValueFormatter.maximumFractionDigits = 3
            string += ", angle: " + _angleValueFormatter.string(from: NSNumber(floatLiteral: entry.x))!
            string += " rads"
        }
        
        setLabel(string)
    }
}
