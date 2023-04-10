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
        
    }
    
    public override var delegate: ChartViewDelegate? {
        didSet {
            if let _renderer = renderer as? VectorFieldChartRenderer {
                _renderer.delegate = delegate as? any VectorFieldChartViewDelegate
            }
        }
    }
    
    // MARK: - ScatterChartDataProvider
    
    public var vectorFieldData: VectorFieldChartData? { return data as? VectorFieldChartData }
}
