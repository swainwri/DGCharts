//
//  RadialAxisRender.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics


@objc(ChartRadialAxisRenderer)
public class RadialAxisRenderer: NSObject, AxisRenderer {

    @objc public let viewPortHandler: ViewPortHandler
    @objc public let axis: RadialAxis
    @objc public let transformer: Transformer?
    
    private weak var majorAxis: MajorAxis?
    private weak var minorAxis: MinorAxis?
    private weak var chart: PolarChartView?
    
    @objc public init(viewPortHandler: ViewPortHandler, axis: RadialAxis, associatedMajorMinorAxis: Any?, chart: PolarChartView?) {
        self.viewPortHandler = viewPortHandler
        self.axis = axis
        self.chart = chart
        
        if associatedMajorMinorAxis is MajorAxis,
           let _associatedMajorMinorAxis = associatedMajorMinorAxis as? MajorAxis {
            self.majorAxis = _associatedMajorMinorAxis
            self.axis.axisDependency = .major
            if _associatedMajorMinorAxis.gridLinesToChartRectEdges {
                axis.gridLinesToChartRectEdges = true
            }
        }
        else if associatedMajorMinorAxis is MinorAxis,
            let _associatedMajorMinorAxis = associatedMajorMinorAxis as? MinorAxis {
            self.minorAxis = _associatedMajorMinorAxis
            self.axis.axisDependency = .minor
            if _associatedMajorMinorAxis.gridLinesToChartRectEdges {
                axis.gridLinesToChartRectEdges = true
            }
        }
        else {
            self.axis.axisDependency = .none
        }
        
        if axis.gridLinesToChartRectEdges,
           let chart = self.chart {
            let factor = chart.factor
            let radius: CGFloat = sqrt(pow(chart.contentRect.width, 2) + pow(chart.contentRect.height, 2)) / 2 / factor
            axis.outerCircleRadius = radius
        }
        
        let axisTransformer = Transformer(viewPortHandler: viewPortHandler)
        axisTransformer.prepareMatrixValuePx(chartXMin: axis.axisMinimum, deltaX: CGFloat(axis.axisRange), deltaY: CGFloat(axis.axisRange), chartYMin: axis.axisMinimum)
        self.transformer = axisTransformer
        
        super.init()
    }

    private var _webLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    /// Draws the grid lines belonging to the axis.
    public func renderGridLines(context: CGContext) {
        
        if let _chart = chart {
            var sliceangle = axis.radialAngleMode == .radians ? axis.webInterval : axis.webInterval * .pi / 180 // needs to be in degrees
            
            context.saveGState()
            
            // calculate the factor that is needed for transforming the value to
            // pixels
            let rotationangle = _chart.rotationAngle.DEG2RAD
            let factor = _chart.factor
            let center = _chart.centerOffsets
            
            // draw the web lines that come from the center
            context.setLineWidth(axis.axisLineWidth)
            context.setStrokeColor(axis.axisLineColor.cgColor)
            //context.setAlpha(axis.axisLineColor.)
            
            let radius: CGFloat = axis.outerCircleRadius * factor
            let maxEntryCount = axis.entryCount
            
            for i in 0..<maxEntryCount {
                let p = center.moving(distance: radius, atAngle: sliceangle * CGFloat(i) + rotationangle)
                
                _webLineSegmentsBuffer[0].x = center.x
                _webLineSegmentsBuffer[0].y = center.y
                _webLineSegmentsBuffer[1].x = p.x
                _webLineSegmentsBuffer[1].y = p.y
                
                context.strokeLineSegments(between: _webLineSegmentsBuffer)
            }
            
            if axis.granularityEnabled {
                context.setLineWidth(axis.axisLineWidth / 2)
                context.setStrokeColor(axis.axisLineColor.cgColor)
                context.setAlpha(axis.axisLineColor.cgColor.alpha / 2)
                let maxEntryCount = Int(axis.webInterval / axis.granularity) * (axis.entryCount - 1) + 1
                sliceangle = axis.radialAngleMode == .radians ? axis.granularity : axis.granularity * .pi / 180 // needs to be in degrees
                for i in 0..<maxEntryCount {
                    let p = center.moving(distance: radius, atAngle: sliceangle * CGFloat(i) + rotationangle)
                    
                    _webLineSegmentsBuffer[0].x = center.x
                    _webLineSegmentsBuffer[0].y = center.y
                    _webLineSegmentsBuffer[1].x = p.x
                    _webLineSegmentsBuffer[1].y = p.y
                    
                    context.strokeLineSegments(between: _webLineSegmentsBuffer)
                }
            }
            
            context.restoreGState()
        }
    }
    
    /// Draws the label that goes alongside the axis spoke.
    public func renderAxisLabels(context: CGContext) {
        if axis.isEnabled,
           axis.isDrawLabelsEnabled {
        
            let xOffset = axis.xOffset
            let yOffset = axis.yOffset
            
            switch axis.labelPosition {
            case .top:
                drawLabels(context: context, pos: CGPoint(x: viewPortHandler.contentCenter.x + xOffset, y: viewPortHandler.contentTop - yOffset - axis.labelRotatedHeight), anchor: CGPoint(x: 0.5, y: 1.0))
                
            case .bottom:
                drawLabels(context: context, pos: CGPoint(x: viewPortHandler.contentCenter.x + xOffset, y: viewPortHandler.contentBottom + yOffset), anchor: CGPoint(x: 0.5, y: 0.0))
                
            case .left:
                drawLabels(context: context, pos: CGPoint(x: viewPortHandler.contentLeft + xOffset, y: viewPortHandler.contentCenter.y + yOffset), anchor: CGPoint(x: 0.0, y: 0.5))
                
            case .right:
                drawLabels(context: context, pos: CGPoint(x: viewPortHandler.contentRight - xOffset - axis.labelRotatedHeight, y: viewPortHandler.contentCenter.y + yOffset), anchor: CGPoint(x: 1.0, y: 0.5))
                
            case .centre:
                drawLabels(context: context, pos: CGPoint(x: viewPortHandler.contentCenter.x + xOffset, y: viewPortHandler.contentCenter.y + yOffset), anchor: CGPoint(x: 0.5, y: 0.5))
                
            }
        }
    }
    
    /// Draws the line that goes alongside the axis. not needed for radial axis
    public func renderAxisLine(context: CGContext) {
        
    }

    /// Draws the LimitLines associated with this axis to the screen.
    public func renderLimitLines(context: CGContext) {
        
    }

    /// Computes the axis values.
    /// - parameter min: the minimum value in the data object for this axis
    /// - parameter max: the maximum value in the data object for this axis
    public func computeAxis(min: Double, max: Double, inverted: Bool) {
        var min = min, max = max
        
        if let transformer = self.transformer,
            viewPortHandler.contentWidth > 10,
            !viewPortHandler.isFullyZoomedOutX {
            // calculate the starting and entry point of the y-labels (depending on
            // zoom / contentrect bounds)
            let p1 = transformer.valueForTouchPoint(CGPoint(x: viewPortHandler.contentLeft, y: viewPortHandler.contentTop))
            let p2 = transformer.valueForTouchPoint(CGPoint(x: viewPortHandler.contentRight, y: viewPortHandler.contentTop))

            min = inverted ? Double(p2.x) : Double(p1.x)
            max = inverted ? Double(p1.x) : Double(p2.x)
        }
        
        computeAxisValues(min: min, max: max)
    }

    /// Sets up the axis values. Computes the desired number of labels between the two given extremes.
    public func computeAxisValues(min: Double, max: Double) {
        let thetaMin = min
        let thetaMax = max

        let labelCount = axis.labelCount
        let range = abs(thetaMax - thetaMin)

        guard
            labelCount != 0,
            range > 0,
            range.isFinite
            else {
                axis.entries = []
                axis.centeredEntries = []
                return
            }

        // Find out how much spacing (in y value space) between axis values
        let rawInterval = range / Double(labelCount)
        var interval = rawInterval

        // If granularity is enabled, then do not allow the interval to go below specified granularity.
        // This is used to avoid repeated values when rounding values for display.
        if axis.granularityEnabled {
            interval = Swift.max(interval, axis.granularity)
        }

        // Normalize interval
        let intervalMagnitude = pow(10.0, Double(Int(log10(interval)))).roundedToNextSignificant()
        let intervalSigDigit = Int(interval / intervalMagnitude)
        if intervalSigDigit > 5 {
            // Use one order of magnitude higher, to avoid intervals like 0.9 or 90
            interval = floor(10.0 * Double(intervalMagnitude))
        }

        var n = axis.centerAxisLabelsEnabled ? 1 : 0

        // force label count
        if axis.isForceLabelsEnabled {
            interval = range / Double(labelCount - 1)

            // Ensure stops contains at least n elements.
            axis.entries.removeAll(keepingCapacity: true)
            axis.entries.reserveCapacity(labelCount)

            let values = stride(from: thetaMin, to: Double(labelCount) * interval + thetaMin, by: interval)
            axis.entries.append(contentsOf: values)

            n = labelCount
        }
        else {
            // no forced count

            var first = interval == 0.0 ? 0.0 : ceil(thetaMin / interval) * interval

            if axis.centerAxisLabelsEnabled {
                first -= interval
            }

            let last = interval == 0.0 ? 0.0 : (floor(thetaMax / interval) * interval).nextUp

            if interval != 0.0, last != first {
                stride(from: first, through: last, by: interval).forEach { _ in n += 1 }
            }

            // Ensure stops contains at least n elements.
            axis.entries.removeAll(keepingCapacity: true)
            axis.entries.reserveCapacity(labelCount)

            let start = first, end = first + Double(n) * interval

            // Fix for IEEE negative zero case (Where value == -0.0, and 0.0 == -0.0)
            let values = stride(from: start, to: end, by: interval).map { $0 == 0.0 ? 0.0 : $0 }
            axis.entries.append(contentsOf: values)
        }

        // set decimals
        if interval < 1 {
            axis.decimals = Int(ceil(-log10(interval)))
        }
        else {
            axis.decimals = 0
        }

        if axis.centerAxisLabelsEnabled {
            let offset: Double = interval / 2.0
            axis.centeredEntries = axis.entries[..<n]
                .map { $0 + offset }
        }
        
        computeSize()
    }
    
    @objc public func computeSize() {
        let longest = axis.getLongestLabel()
        
        let labelSize = longest.size(withAttributes: [.font: axis.labelFont])

        let labelWidth = labelSize.width
        let labelHeight = labelSize.height
        
        let labelRotatedSize = labelSize.rotatedBy(degrees: axis.labelRotationAngle)
        
        axis.labelWidth = labelWidth
        axis.labelHeight = labelHeight
        axis.labelRotatedWidth = labelRotatedSize.width
        axis.labelRotatedHeight = labelRotatedSize.height
    }
    
    /// draws the x-labels on the specified y-position
    @objc public func drawLabels(context: CGContext, pos: CGPoint, anchor: CGPoint) {
        guard let transformer = self.transformer else { return }
        
        let paraStyle = ParagraphStyle.default.mutableCopy() as! MutableParagraphStyle
        paraStyle.alignment = .center
        
        let labelAttrs: [NSAttributedString.Key : Any] = [.font: axis.labelFont, .foregroundColor: axis.labelTextColor, .paragraphStyle: paraStyle]

        let labelRotationAngleRadians = axis.labelRotationAngle.DEG2RAD
        let isCenteringEnabled = axis.isCenterAxisLabelsEnabled
        let valueToPixelMatrix = transformer.valueToPixelMatrix

        var position = CGPoint.zero
        var labelMaxSize = CGSize.zero
        
        if axis.isWordWrapEnabled {
            labelMaxSize.width = axis.wordWrapWidthPercent * valueToPixelMatrix.a
        }
        
        let entries = axis.entries
        var rotationAngle: CGFloat = 0
        var factor: CGFloat = 1
        if let _chart = self.chart {
            rotationAngle = _chart.rotationAngle / 180 * .pi
            factor = _chart.factor
        }
        for i in entries.indices {
            var angle = isCenteringEnabled ? CGFloat(axis.centeredEntries[i]) : CGFloat(entries[i])
            angle = axis.radialAngleMode == .radians ? angle : angle / 180 * .pi
            let radius = axis.outerCircleRadius * axis.labelPositionRadiusRatio * factor
            position = pos.moving(distance: radius, atAngle: angle + rotationAngle)//.applying(valueToPixelMatrix)

            guard viewPortHandler.isInBoundsX(position.x), viewPortHandler.isInBoundsY(position.y) else { continue }
            
            let label = axis.valueFormatter?.stringForValue(axis.entries[i], axis: axis) ?? ""
            let labelns = label as String
            
            if axis.isAvoidFirstLastClippingEnabled {
                // avoid clipping of the last
                if i == axis.entryCount - 1 && axis.entryCount > 1
                {
                    let size = labelns.boundingRect(with: labelMaxSize, options: .usesLineFragmentOrigin, attributes: labelAttrs, context: nil).size
                    
                    if size.width > viewPortHandler.offsetRight * 2.0,
                       position.x + size.width > viewPortHandler.chartWidth {
                        position.x -= size.width / 2.0
                    }
                    if size.height > viewPortHandler.offsetTop * 2.0,
                        position.y + size.height > viewPortHandler.chartHeight {
                        position.y -= size.height / 2.0
                    }
                }
                else if i == 0 { // avoid clipping of the first
                    let size = labelns.boundingRect(with: labelMaxSize, options: .usesLineFragmentOrigin, attributes: labelAttrs, context: nil).size
                    position.x += size.width / 2.0
                    position.y += size.height / 2.0
                }
            }
            
            drawLabel(context: context, formattedLabel: label, x: position.x,
                      y: position.y, attributes: labelAttrs,  constrainedTo: labelMaxSize,  anchor: anchor, angleRadians: labelRotationAngleRadians)
        }
    }

    @objc open func drawLabel(context: CGContext, formattedLabel: String, x: CGFloat, y: CGFloat, attributes: [NSAttributedString.Key : Any], constrainedTo size: CGSize, anchor: CGPoint, angleRadians: CGFloat) {
        context.drawMultilineText(formattedLabel, at: CGPoint(x: x, y: y), constrainedTo: size, anchor: anchor, angleRadians: angleRadians, attributes: attributes)
    }
}
