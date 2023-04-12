//
//  PolarChartView.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics


/// Implementation of the RadarChart, a "spidernet"-like chart. It works best
/// when displaying 5-10 entries per DataSet.
public class PolarChartView: PieRadarChartViewBase, PolarChartDataProvider, ChartViewDelegate {
    
    /// flag indicating if the polar grid lines should be drawn or not
    @objc public var drawGridlines = true
    
    /// the object reprsenting the major/minor & radial-axes labels
    @objc public var majorAxis: MajorAxis = MajorAxis()
    @objc public var minorAxis: MinorAxis = MinorAxis()
    @objc public var radialAxis: RadialAxis = RadialAxis()

    private var _majorAxisRenderer: MajorAxisRenderer?
    private var _minorAxisRenderer: MinorAxisRenderer?
    private var _radialAxisRenderer: RadialAxisRenderer?
    
    private var _axisTransformer: Transformer?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    internal override func initialize() {
        super.initialize()
        
        renderer = PolarChartRenderer(dataProvider: self, chart: self, animator: chartAnimator, viewPortHandler: viewPortHandler)
        
        _axisTransformer = Transformer(viewPortHandler: viewPortHandler)
        
        _majorAxisRenderer = MajorAxisRenderer(viewPortHandler: viewPortHandler, axis: majorAxis, transformer: _axisTransformer)
        _minorAxisRenderer = MinorAxisRenderer(viewPortHandler: viewPortHandler, axis: minorAxis, associatedMajorAxis: majorAxis, transformer: _axisTransformer)
        _radialAxisRenderer = RadialAxisRenderer(viewPortHandler: viewPortHandler, axis: radialAxis, chart: self, transformer: _axisTransformer)
        
        self.highlighter = PolarHighlighter(chart: self)
    }
    
    /// The default IValueFormatter that has been determined by the chart considering the provided minimum and maximum values.
    internal lazy var defaultPointFormatter: PointFormatter = DefaultPointFormatter(decimals: 1)

    @objc public override var data: ChartData? {
        
        didSet {
            calculateOffsets()

            if let data = polarData {
                
                // calculate how many digits are needed
                setupDefaultFormatter(min: data.radialMin, max: data.radialMax)
 
                for case let set as PolarChartDataSetProtocol in (data as ChartData) where set.pointFormatter is DefaultPointFormatter {
                    set.pointFormatter = defaultPointFormatter
                }
                
                // let the chart know there is new data
                notifyDataSetChanged()
            }
        }
    }

    /// The minimum theta-value of the chart, regardless of zoom or translation.
    public var chartThetaMin: Double {
        get {
            return polarData?.thetaMin ?? 0
        }
    }
    
    /// The maximum theta-value of the chart, regardless of zoom or translation.
    public var chartThetaMax: Double {
        get {
            return polarData?.thetaMax ?? 0
        }
    }
    
    /// The minimum radial-value of the chart, regardless of zoom or translation.
    public var chartRadialMin: Double {
        get {
            return polarData?.radialMin ?? 0
        }
    }
    
    /// The maximum radial-value of the chart, regardless of zoom or translation.
    public var chartRadialMax: Double {
        get {
            return polarData?.radialMax ?? 0
        }
    }
    
    public var maxHighlightRadius: CGFloat {
        get {
            return polarData?.radialMax ?? 0
        }
    }
    
    public var thetaRange: Double {
        get {
            return polarData?.thetaRange ?? 0
        }
    }
    
    public func isInverted() -> Bool {
        return  self.radialAxis.reversed // is the radial axis ploted clockwise or anticlockwise
    }
    
    public override var maxVisibleCount: Int {
        get {
            return polarData?.entryCount ?? 0
        }
    }

    internal override func calcMinMax() {
        super.calcMinMax()
        
        if let data = polarData {
            majorAxis.calculate(min: -data.radialMax, max: data.radialMax)
            minorAxis.calculate(min: -data.radialMax, max: data.radialMax)
        }
    }
    
    public override func notifyDataSetChanged() {
        
        calcMinMax()
        
//        if majorAxis.outerCircleRadius > 0 {
//            majorAxis.axisMinimum = -majorAxis.outerCircleRadius
//            majorAxis.axisMaximum = majorAxis.outerCircleRadius
//            majorAxis.axisRange = 2 * majorAxis.outerCircleRadius
//        }
        let factor = self.factor
        if majorAxis.gridLinesToChartRectEdges {
            let radius: CGFloat = sqrt(pow(self.contentRect.width, 2) + pow(self.contentRect.height, 2)) / 2 / factor
            majorAxis.axisMinimum = -radius
            majorAxis.axisMaximum = radius
            majorAxis.axisRange = 2 * radius
        }
//        if minorAxis.outerCircleRadius > 0 {
//            minorAxis.axisMinimum = -minorAxis.outerCircleRadius
//            minorAxis.axisMaximum = minorAxis.outerCircleRadius
//            minorAxis.axisRange = 2 * minorAxis.outerCircleRadius
//        }
        if minorAxis.gridLinesToChartRectEdges {
            let radius: CGFloat = sqrt(pow(self.contentRect.width, 2) + pow(self.contentRect.height, 2)) / 2 / factor
            minorAxis.axisMinimum = -radius
            minorAxis.axisMaximum = radius
            minorAxis.axisRange = 2 * radius
        }
        
//        _axisTransformer?.prepareMatrixValuePx(chartXMin: majorAxis.axisMinimum, deltaX: majorAxis.axisRange, deltaY: minorAxis.axisRange, chartYMin: minorAxis.axisMinimum)
        _axisTransformer?.prepareMatrixValuePx(chartXMin: 0, deltaX: majorAxis.axisRange, deltaY: minorAxis.axisRange, chartYMin: 0)
        _axisTransformer?.prepareMatrixOffset(inverted: majorAxis.isInverted)
        
        
        _majorAxisRenderer?.computeAxis(min: majorAxis.axisMinimum.rounded(.awayFromZero), max: majorAxis.axisMaximum.rounded(.awayFromZero), inverted: false)
    
        _minorAxisRenderer?.computeAxis(min: minorAxis.axisMinimum.rounded(.awayFromZero), max: minorAxis.axisMaximum.rounded(.awayFromZero), inverted: false)
        
        if majorAxis.isEnabled {
            radialAxis.axisDependency = .major
            if majorAxis.gridLinesToChartRectEdges {
                radialAxis.gridLinesToChartRectEdges = true
                let radius: CGFloat = sqrt(pow(self.contentRect.width, 2) + pow(self.contentRect.height, 2)) / 2 / self.factor
                radialAxis.outerCircleRadius = radius
            }
            else {
                radialAxis.outerCircleRadius = majorAxis.axisMaximum
            }
        }
        else if minorAxis.isEnabled {
            radialAxis.axisDependency = .minor
            if minorAxis.gridLinesToChartRectEdges {
                radialAxis.gridLinesToChartRectEdges = true
                let radius: CGFloat = sqrt(pow(self.contentRect.width, 2) + pow(self.contentRect.height, 2)) / 2 / self.factor
                radialAxis.outerCircleRadius = radius
            }
            else {
                radialAxis.outerCircleRadius = minorAxis.axisMaximum
            }
        }
        else {
            radialAxis.axisDependency = .none
        }
        
        _radialAxisRenderer?.computeAxis(min: radialAxis.axisMinimum, max: radialAxis.axisMaximum, inverted: radialAxis.reversed)
        
        if let data = polarData,
            !legend.isLegendCustom  {
            legendRenderer.computeLegend(data: data)
        }
        
        calculateOffsets()
        
        setNeedsDisplay()
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        if let _ = self.polarData,
           let renderer = renderer {
            
            let optionalContext = NSUIGraphicsGetCurrentContext()
            if let context = optionalContext {
                
                _majorAxisRenderer?.transformer?.prepareMatrixValuePx(chartXMin: majorAxis.axisMinimum, deltaX: CGFloat(majorAxis.axisRange), deltaY: CGFloat(minorAxis.axisRange), chartYMin: minorAxis.axisMinimum)
                _minorAxisRenderer?.transformer?.prepareMatrixValuePx(chartXMin: majorAxis.axisMinimum, deltaX: CGFloat(majorAxis.axisRange), deltaY: CGFloat(minorAxis.axisRange), chartYMin: minorAxis.axisMinimum)
                _radialAxisRenderer?.transformer?.prepareMatrixValuePx(chartXMin: majorAxis.axisMinimum, deltaX: CGFloat(majorAxis.axisRange), deltaY: CGFloat(minorAxis.axisRange), chartYMin: minorAxis.axisMinimum)
                
            
                if radialAxis.isEnabled {
                    _radialAxisRenderer?.computeAxis(min: radialAxis.axisMinimum, max: radialAxis.axisMaximum, inverted: radialAxis.reversed)
                    _radialAxisRenderer?.renderAxisLabels(context: context)
                    _radialAxisRenderer?.renderGridLines(context: context)
                }
                
                if majorAxis.isEnabled {
                    _majorAxisRenderer?.computeAxis(min: majorAxis.axisMinimum.rounded(.awayFromZero), max: majorAxis.axisMaximum.rounded(.awayFromZero), inverted: false)
                    _majorAxisRenderer?.renderAxisLabels(context: context)
                    _majorAxisRenderer?.renderGridLines(context: context)
                    if !minorAxis.isDrawLimitLinesBehindDataEnabled {
                        _minorAxisRenderer?.renderLimitLines(context: context)
                    }
                }
                
                if minorAxis.isEnabled {
                    _minorAxisRenderer?.computeAxis(min: minorAxis.axisMinimum.rounded(.awayFromZero), max: minorAxis.axisMaximum.rounded(.awayFromZero), inverted: false)
                    _minorAxisRenderer?.renderAxisLabels(context: context)
                    if minorAxis.isDrawLimitLinesBehindDataEnabled {
                        _minorAxisRenderer?.renderLimitLines(context: context)
                    }
                }
                
                renderer.drawData(context: context)
                
                
                if valuesToHighlight() {
                    renderer.drawHighlighted(context: context, indices: highlighted)
                }
                
                renderer.drawValues(context: context)
                
                legendRenderer.renderLegend(context: context)
                
                drawDescription(in: context)
                
                drawMarkers(context: context)
            }
        }
    }

    /// The factor that is needed to transform values into pixels.
    @objc public var factor: CGFloat {
        let content = viewPortHandler.contentRect
        return min(content.width / 2.0, content.height / 2.0) / CGFloat(majorAxis.axisRange / 2.0)
    }

    /// The angle that each slice in the radar chart occupies.
    @objc public var sliceAngle: CGFloat {
        return 360.0 / CGFloat(polarData?.maxEntryCountSet?.entryCount ?? 0)
    }

    public override func indexForAngle(_ angle: CGFloat) -> Int {
        // take the current angle of the chart into consideration
        let a = (angle - self.rotationAngle).normalizedAngle
        
        let sliceAngle = self.sliceAngle
        
        let max = polarData?.maxEntryCountSet?.entryCount ?? 0
        return (0..<max).firstIndex { sliceAngle * CGFloat($0 + 1) - sliceAngle / 2.0 > a } ?? 0
    }

    
    internal override var requiredLegendOffset: CGFloat  {
        return legend.font.pointSize * 4.0
    }

    internal override var requiredBaseOffset: CGFloat {
        return majorAxis.isEnabled && majorAxis.isDrawLabelsEnabled ? majorAxis.labelRotatedWidth : 10.0
    }

    public override var radius: CGFloat {
        let content = viewPortHandler.contentRect
        return min(content.width / 2.0, content.height / 2.0)
    }
    
    /// The lowest theta-index (value on the radial-axis) that is still visible on he chart.
    public var lowestVisibleTheta: Double {
//        var pt = CGPoint(x: viewPortHandler.contentLeft, y: viewPortHandler.contentBottom)
//
//        getTransformer(forAxis: .major).pixelToValues(&pt)
//
//        return max(radialAxis.axisMinimum, Double(pt.x))
        return radialAxis.axisMinimum
    }
    
    /// The highest theta-index (value on the radial-axis) that is still visible on the chart.
    public var highestVisibleTheta: Double {
//        var pt = CGPoint(x: viewPortHandler.contentRight, y: viewPortHandler.contentBottom)
//
//        getTransformer(forAxis: .major).pixelToValues(&pt)
//
//        return min(radialAxis.axisMaximum, Double(pt.x))
        return radialAxis.axisMaximum
    }
    
    // MARK: Transformer
    
    public func getTransformer(forAxis: RadialAxis.PolarAxisDependency) -> Transformer {
        return _axisTransformer ?? Transformer(viewPortHandler: self.viewPortHandler)
    }
    
    
    // MARK: - LineChartDataProvider
    
    public var polarData: PolarChartData? { return data as? PolarChartData }
}
