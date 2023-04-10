//
//  MajorAxisRenderer.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics


@objc(ChartMajorAxisRenderer)
public class MajorAxisRenderer: NSObject, AxisRenderer {

    @objc public let viewPortHandler: ViewPortHandler
    @objc public let axis: MajorAxis
    @objc public let transformer: Transformer?
    
    private weak var chart: PolarChartView?
    
    @objc public init(viewPortHandler: ViewPortHandler, axis: MajorAxis, chart: PolarChartView?) {
        self.viewPortHandler = viewPortHandler
        self.axis = axis
        self.chart = chart
        
        if axis.outerCircleRadius > 0 {
            axis.axisMinimum = -axis.outerCircleRadius
            axis.axisMaximum = axis.outerCircleRadius
            axis.axisRange = 2 * axis.outerCircleRadius
        }
        if axis.gridLinesToChartRectEdges,
           let chart = self.chart {
            let factor = chart.factor
            let radius: CGFloat = sqrt(pow(chart.contentRect.width, 2) + pow(chart.contentRect.height, 2)) / 2 / factor
            axis.axisMinimum = -radius
            axis.axisMaximum = radius
            axis.axisRange = 2 * radius
        }
        
        let axisTransformer = Transformer(viewPortHandler: viewPortHandler)
        axisTransformer.prepareMatrixValuePx(chartXMin: axis.axisMinimum, deltaX: CGFloat(axis.axisRange), deltaY: CGFloat(axis.axisRange), chartYMin: axis.axisMinimum)
        self.transformer = axisTransformer
        
        super.init()
    }
    
    public func computeAxis(min: Double, max: Double, inverted: Bool) {
        var min = min, max = max
        
        if let transformer = self.transformer,
            viewPortHandler.contentWidth > 10,
            !viewPortHandler.isFullyZoomedOutX {
            // calculate the starting and entry point of the y-labels (depending on
            // zoom / contentrect bounds)
            let p1 = transformer.valueForTouchPoint(CGPoint(x: viewPortHandler.contentLeft, y: viewPortHandler.contentCenter.y))
            let p2 = transformer.valueForTouchPoint(CGPoint(x: viewPortHandler.contentRight, y: viewPortHandler.contentCenter.y))

            min = inverted ? Double(p2.x) : Double(p1.x)
            max = inverted ? Double(p1.x) : Double(p2.x)
        }
        
        computeAxisValues(min: min, max: max)
    }
    
    public func computeAxisValues(min: Double, max: Double) {
        let xMin = min
        let xMax = max

        let labelCount = axis.labelCount
        let range = abs(xMax - xMin)

        if labelCount != 0,
            range > 0,
           range.isFinite {
            // Find out how much spacing (in y value space) between axis values
            let rawInterval = range / Double(labelCount)
            var interval = rawInterval.roundedToNextSignificant()

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

                let values = stride(from: xMin, to: Double(labelCount) * interval + xMin, by: interval)
                axis.entries.append(contentsOf: values)

                n = labelCount
            }
            else {
                // no forced count

                var first = interval == 0.0 ? 0.0 : ceil(xMin / interval) * interval

                if axis.centerAxisLabelsEnabled {
                    first -= interval
                }

                let last = interval == 0.0 ? 0.0 : (floor(xMax / interval) * interval).nextUp

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
        else {
            axis.entries = []
            axis.centeredEntries = []
        }
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
    
    private var axisLineSegmentsBuffer = [CGPoint](repeating: .zero, count: 2)
    
    /// Draws the line that goes alongside the axis.
    public func renderAxisLine(context: CGContext) {
        if axis.isEnabled,
           axis.isDrawAxisLineEnabled {
            
            context.saveGState()
            defer { context.restoreGState() }
            
            context.setStrokeColor(axis.axisLineColor.cgColor)
            context.setLineWidth(axis.axisLineWidth)
            if let _axisLineDashLengths = axis.axisLineDashLengths {
                context.setLineDash(phase: axis.axisLineDashPhase, lengths: _axisLineDashLengths)
            }
            else {
                context.setLineDash(phase: 0.0, lengths: [])
            }
            
            if axis.labelPosition == .top || axis.labelPosition == .topInside || axis.labelPosition == .bothSided {
                axisLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
                axisLineSegmentsBuffer[0].y = viewPortHandler.contentTop
                axisLineSegmentsBuffer[1].x = viewPortHandler.contentRight
                axisLineSegmentsBuffer[1].y = viewPortHandler.contentTop
                context.strokeLineSegments(between: axisLineSegmentsBuffer)
            }
            
            if axis.labelPosition == .bottom || axis.labelPosition == .bottomInside || axis.labelPosition == .bothSided {
                axisLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
                axisLineSegmentsBuffer[0].y = viewPortHandler.contentBottom
                axisLineSegmentsBuffer[1].x = viewPortHandler.contentRight
                axisLineSegmentsBuffer[1].y = viewPortHandler.contentBottom
                context.strokeLineSegments(between: axisLineSegmentsBuffer)
            }
        }
    }
    
    public func renderAxisLabels(context: CGContext) {
        guard
            axis.isEnabled,
            axis.isDrawLabelsEnabled
            else { return }

        let yOffset = axis.yOffset
        
        switch axis.labelPosition {
        case .top:
            drawLabels(context: context, pos: viewPortHandler.contentCenter.y - yOffset, anchor: CGPoint(x: 0.5, y: 1.0))

        case .topInside:
            drawLabels(context: context, pos: viewPortHandler.contentCenter.y + yOffset + axis.labelRotatedHeight, anchor: CGPoint(x: 0.5, y: 1.0))

        case .bottom:
            drawLabels(context: context, pos: viewPortHandler.contentCenter.y + yOffset, anchor: CGPoint(x: 0.5, y: 0.0))

        case .bottomInside:
            drawLabels(context: context, pos: viewPortHandler.contentCenter.y - yOffset - axis.labelRotatedHeight, anchor: CGPoint(x: 0.5, y: 0.0))

        case .bothSided:
            drawLabels(context: context, pos: viewPortHandler.contentCenter.y - yOffset, anchor: CGPoint(x: 0.5, y: 1.0))
            drawLabels(context: context, pos: viewPortHandler.contentCenter.y + yOffset, anchor: CGPoint(x: 0.5, y: 0.0))
        }
    }
    
    /// draws the major axis -labels on the specified y-position
    public func drawLabels(context: CGContext, pos: CGFloat, anchor: CGPoint) {
        guard let transformer = self.transformer else { return }
        
        let paraStyle = ParagraphStyle.default.mutableCopy() as! MutableParagraphStyle
        paraStyle.alignment = .center
        
        let labelAttrs: [NSAttributedString.Key : Any] = [.font: axis.labelFont, .foregroundColor: axis.labelTextColor, .paragraphStyle: paraStyle]

        let labelRotationAngleRadians = axis.labelRotationAngle.DEG2RAD
        let valueToPixelMatrix = transformer.valueToPixelMatrix

        var position = CGPoint.zero
        var labelMaxSize = CGSize.zero
        
        if axis.isWordWrapEnabled {
            labelMaxSize.width = axis.wordWrapWidthPercent * valueToPixelMatrix.a
        }
        
        let centeringEnabled = axis.isCenterAxisLabelsEnabled
        
        
        for i in 0..<axis.entryCount {
            // only fill x values
            position.x = centeringEnabled ? CGFloat(axis.centeredEntries[i]) : CGFloat(axis.entries[i])
            position.y = 0

            transformer.pointValueToPixel(&position)
            position.y = pos
            
            if viewPortHandler.isInBounds(point: position),
                let label = axis.valueFormatter?.stringForValue(axis.entries[i], axis: axis) {
                drawLabel(context: context, formattedLabel: label, x: pos, y: position.y, attributes: labelAttrs, constrainedTo: labelMaxSize, anchor: anchor, angleRadians: labelRotationAngleRadians)
            }
        }
    }
    
    @objc open func drawLabel(context: CGContext, formattedLabel: String, x: CGFloat, y: CGFloat, attributes: [NSAttributedString.Key : Any], constrainedTo size: CGSize, anchor: CGPoint, angleRadians: CGFloat) {
        context.drawMultilineText(formattedLabel, at: CGPoint(x: x, y: y), constrainedTo: size, anchor: anchor, angleRadians: angleRadians, attributes: attributes)
    }
    
    /// Draws the grid lines belonging to the axis.
    @objc public func renderGridLines(context: CGContext) {
        
        if let _chart = chart {
            // calculate the factor that is needed for transforming the value to
            // pixels
            let factor = _chart.factor
            
            let center = _chart.centerOffsets
            
            context.saveGState()
            // draw the inner-web
            context.setLineWidth(axis.axisLineWidth)
            context.setStrokeColor(axis.axisLineColor.cgColor)
            
            let labelCount = axis.entryCount
            for j in 0 ..< labelCount {
                if axis.entries[j] > 0 {  // don't need negative entries as psoitive one with take care of concentric circles
                    let diameter: CGFloat = CGFloat(axis.entries[j]) * factor * 2
                    context.strokeEllipse(in: CGRect(x: -diameter / 2 + center.x, y: -diameter / 2 + center.y, width: diameter, height: diameter))
                }
            }
            
            if axis.granularityEnabled {
                context.setLineWidth(axis.gridLineWidth)
                context.setStrokeColor(axis.gridColor.cgColor)
                
                let granularityInterval = (axis.axisMaximum - axis.axisMinimum) / Double(axis.entryCount) / axis.granularity
                let granularityCount = Int(axis.granularity)
                for j in 0 ..< labelCount {
                    if axis.entries[j] > 0 {
                        for i in 1...granularityCount {
                            let diameter: CGFloat = CGFloat(axis.entries[j] + Double(i) * granularityInterval) * factor * 2
                            context.strokeEllipse(in: CGRect(x: -diameter / 2 + center.x, y: -diameter / 2 + center.y, width: diameter, height: diameter))
                        }
                    }
                }
            }
            
            context.restoreGState()
        }
    }
    
    
    @objc public func renderLimitLines(context: CGContext) {
        /// MajorAxis LimitLines on PolarChart not yet supported.
    }
}
