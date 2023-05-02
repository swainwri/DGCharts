//
//  VectorFieldChartView.swift
//  DGCharts
//
//  Created by Steve Wainwright on 09/04/2023.
//

import Foundation
import CoreGraphics

@objc
public protocol VectorFieldChartViewDelegate: NSObjectProtocol {
    /// Called when a value has been selected inside the chart.
    ///
    /// - Parameters:
    ///   - entry: The selected Entry.
    ///   - vectorWidth: The vectorWidth at this entry.
    ///   - color: The color at this entry
    ///   - fill: The fill at this entry
    @objc optional func chartValueStyle(entry: FieldChartDataEntry, vectorWidth: UnsafeMutablePointer<CGFloat>, color: UnsafeMutablePointer<NSUIColor>, fill: UnsafeMutablePointer<ColorFill>) -> Void

}

public class VectorFieldChartView: BarLineChartViewBase, VectorFieldChartDataProvider, VectorFieldChartViewDelegate {
    
    public override func initialize() {
        super.initialize()
        
        renderer = VectorFieldChartRenderer(dataProvider: self, animator: chartAnimator, viewPortHandler: viewPortHandler)
        
        
        xAxis.spaceMin = 0.5
        xAxis.spaceMax = 0.5
        
        self.highlighter = ChartHighlighter(chart: self)
    }
    
    public override var delegate: ChartViewDelegate? {
        didSet {
            if let _renderer = renderer as? VectorFieldChartRenderer {
                _renderer.delegate = delegate as? any VectorFieldChartViewDelegate
            }
        }
    }
    
    /// The lowest y-index (value on the y-axis) that is still visible on he chart.
    public var lowestVisibleY: Double {
        var pt = CGPoint(x: viewPortHandler.contentLeft, y: viewPortHandler.contentBottom)
        
        getTransformer(forAxis: .left).pixelToValues(&pt)
        
        return max(leftAxis._axisMinimum, Double(pt.y))
    }
    
    /// The highest x-index (value on the x-axis) that is still visible on the chart.
    public var highestVisibleY: Double {
        var pt = CGPoint(x: viewPortHandler.contentRight, y: viewPortHandler.contentBottom)
        
        getTransformer(forAxis: .left).pixelToValues(&pt)

        return min(leftAxis._axisMaximum, Double(pt.y))
    }
    
    // MARK: - ScatterChartDataProvider
    
    public var vectorFieldData: VectorFieldChartData? { return data as? VectorFieldChartData }
}
