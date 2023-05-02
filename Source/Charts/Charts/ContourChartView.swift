//
//  ContourChartView.swift
//  Charts
//
//  Created by Steve Wainwright on 15/04/2023.
//

import Foundation
import CoreGraphics

@objc
public protocol ContourChartViewDelegate: NSObjectProtocol {
    /// Called when a isocurve need customised line style .
    ///
    /// - Parameters:
    ///   - plane: isoCurve plane index
    ///   - dataSet: The selected dataSet.
    ///   - lineColour: The color of this isocurve
    ///
    
    @objc optional func chartIsoCurvesLineColour(at plane: Int, dataSet: ContourChartDataSetProtocol, lineColour: UnsafeMutablePointer<NSUIColor>) -> Void
    
    /// Called when all the isocurves need customised line style .
    ///
    /// - Parameters:
    ///   - dataSet: The selected dataSet.
    ///   - lineColours: The colors of all the isocurves
    ///
    
    @objc optional func chartIsoCurvesLineColours(dataSet: ContourChartDataSetProtocol, lineColours: UnsafeMutablePointer<NSUIColor>) -> Void

    /// Called when fill between  isocurves need customised  .
    ///
    /// - Parameters:
    ///   - plane: isoCurve plane index
    ///   - dataSet: The selected dataSet.
    ///   - fill: the fill is ColorFill
    ///
    @objc optional func chartIsoCurvesColourFill(at plane: Int, dataSet: ContourChartDataSetProtocol, fill: UnsafeMutablePointer<ColorFill>) -> Void
    
    /// Called when fills between  isocurves need customised  .
    ///
    /// - Parameters:
    ///   - dataSet: The selected dataSet.
    ///   - fills: all the fills are ColorFill
    ///
    @objc optional func chartIsoCurvesColourFills(dataSet: ContourChartDataSetProtocol, fills: UnsafeMutablePointer<ColorFill>) -> Void
    
    /// Called when fill between  isocurves need customised  .
    ///
    /// - Parameters:
    ///   - plane: isoCurve plane index
    ///   - dataSet: The selected dataSet.
    ///   - fill: the fill is ImageFill
    ///
    @objc optional func chartIsoCurvesImageFill(at plane: Int, dataSet: ContourChartDataSetProtocol, fill: UnsafeMutablePointer<ImageFill>) -> Void
    
    /// Called when fills between  isocurves need customised  .
    ///
    /// - Parameters:
    ///   - dataSet: The selected dataSet.
    ///   - fills: all the fills are ImageFill
    ///
    @objc optional func chartIsoCurvesImageFills(dataSet: ContourChartDataSetProtocol, fills: UnsafeMutablePointer<ImageFill>) -> Void

}

public class ContourChartView: BarLineChartViewBase, ContourChartDataProvider, ContourChartViewDelegate {
    
    public override func initialize() {
        super.initialize()
        
        renderer = ContourChartRenderer(dataProvider: self, animator: chartAnimator, viewPortHandler: viewPortHandler)
        
        xAxis.spaceMin = 0.5
        xAxis.spaceMax = 0.5
        
        self.highlighter = ChartHighlighter(chart: self)
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
    
    public override func notifyDataSetChanged() {
        
        calcMinMax()
        
        if let data = data {
            legendRenderer.computeLegend(data: data)
            
            if let dataSets = data.dataSets as? [ContourChartDataSet] {
                for set in dataSets {
                    set.firstRendition = true
                    set.renderer = self.renderer as? ContourChartRenderer
                    set.calculateContourLines(plotAreaSize: self.bounds.size)
                    set.delegate = delegate as? any ContourChartViewDelegate
                    set.setupCustomisedColoursEtc()
                }
            }
        }
        
        calculateOffsets()
        
        setNeedsDisplay()
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        if let _ = self.contourData,
           let renderer = renderer {
            
            let optionalContext = NSUIGraphicsGetCurrentContext()
            if let context = optionalContext {
                
                xAxisRenderer.transformer?.prepareMatrixValuePx(chartXMin: xAxis.axisMinimum, deltaX: CGFloat(xAxis.axisRange), deltaY: CGFloat(leftAxis.axisRange), chartYMin: leftAxis.axisMinimum)
                leftYAxisRenderer.transformer?.prepareMatrixValuePx(chartXMin: xAxis.axisMinimum, deltaX: CGFloat(xAxis.axisRange), deltaY: CGFloat(leftAxis.axisRange), chartYMin: leftAxis.axisMinimum)
                
            
                if xAxis.isEnabled {
                    xAxisRenderer.computeAxis(min: xAxis.axisMinimum, max: xAxis.axisMaximum, inverted: false)
                    xAxisRenderer.renderAxisLabels(context: context)
                    xAxisRenderer.renderGridLines(context: context)
                }
                
                if leftAxis.isEnabled {
                    leftYAxisRenderer.computeAxis(min: leftAxis.axisMinimum.rounded(.awayFromZero), max: leftAxis.axisMaximum.rounded(.awayFromZero), inverted: leftAxis.inverted)
                    leftYAxisRenderer.renderAxisLabels(context: context)
                    leftYAxisRenderer.renderGridLines(context: context)
                    if !leftAxis.isDrawLimitLinesBehindDataEnabled {
                        leftYAxisRenderer.renderLimitLines(context: context)
                    }
                }
                
                if rightAxis.isEnabled {
                    rightYAxisRenderer.computeAxis(min: leftAxis.axisMinimum.rounded(.awayFromZero), max: leftAxis.axisMaximum.rounded(.awayFromZero), inverted: leftAxis.inverted)
                    rightYAxisRenderer.renderAxisLabels(context: context)
                }
                
                renderer.drawData(context: context)
                
                if valuesToHighlight() {
                    renderer.drawHighlighted(context: context, indices: highlighted)
                }
                
                renderer.drawValues(context: context)
                
                renderer.drawExtras(context: context)
                
                legendRenderer.renderLegend(context: context)
                
                drawDescription(in: context)
                
                drawMarkers(context: context)
            }
        }
    }
    
    // MARK: - ContourChartDataProvider
    
    public var contourData: ContourChartData? {
        get {
            return data as? ContourChartData
        }
        set {
            data = newValue
            if let dataSets = data?.dataSets as? [ContourChartDataSet] {
                for set in dataSets {
                    set.renderer = self.renderer as? ContourChartRenderer
                    set.calculateContourLines(plotAreaSize: self.bounds.size)
                    set.setupCustomisedColoursEtc()
                }
            }
        }
    }
}

