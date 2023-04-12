//
//  MinorAxisRenderer.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics


@objc(ChartMinorAxisRenderer)
public class MinorAxisRenderer: NSObject, AxisRenderer {
    
    @objc public let viewPortHandler: ViewPortHandler
    @objc public let axis: MinorAxis
    @objc public let transformer: Transformer?
    
    private weak var majorAxis: MajorAxis?

    @objc public init(viewPortHandler: ViewPortHandler, axis: MinorAxis, associatedMajorAxis: MajorAxis? = nil, transformer: Transformer?) {
        self.viewPortHandler = viewPortHandler
        self.axis = axis
        self.majorAxis = associatedMajorAxis
        self.transformer = transformer
        
        super.init()
    }
    
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
    
    public func computeAxisValues(min: Double, max: Double) {
        let yMin = min
        let yMax = max

        let labelCount = axis.labelCount
        let range = abs(yMax - yMin)

        guard
            labelCount != 0,
            range > 0,
            range.isFinite
            else
        {
            axis.entries = []
            axis.centeredEntries = []
            return
        }

        // Find out how much spacing (in y value space) between axis values
        let rawInterval = range / Double(labelCount)
        var interval = rawInterval.roundedToNextSignificant()

        // If granularity is enabled, then do not allow the interval to go below specified granularity.
        // This is used to avoid repeated values when rounding values for display.
        if axis.granularityEnabled
        {
            interval = Swift.max(interval, axis.granularity)
        }

        // Normalize interval
        let intervalMagnitude = pow(10.0, Double(Int(log10(interval)))).roundedToNextSignificant()
        let intervalSigDigit = Int(interval / intervalMagnitude)
        if intervalSigDigit > 5
        {
            // Use one order of magnitude higher, to avoid intervals like 0.9 or 90
            interval = floor(10.0 * Double(intervalMagnitude))
        }

        var n = axis.centerAxisLabelsEnabled ? 1 : 0

        // force label count
        if axis.isForceLabelsEnabled
        {
            interval = range / Double(labelCount - 1)

            // Ensure stops contains at least n elements.
            axis.entries.removeAll(keepingCapacity: true)
            axis.entries.reserveCapacity(labelCount)

            let values = stride(from: yMin, to: Double(labelCount) * interval + yMin, by: interval)
            axis.entries.append(contentsOf: values)

            n = labelCount
        }
        else {
            // no forced count

            var first = interval == 0.0 ? 0.0 : ceil(yMin / interval) * interval

            if axis.centerAxisLabelsEnabled
            {
                first -= interval
            }

            let last = interval == 0.0 ? 0.0 : (floor(yMax / interval) * interval).nextUp

            if interval != 0.0, last != first
            {
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
        if interval < 1
        {
            axis.decimals = Int(ceil(-log10(interval)))
        }
        else
        {
            axis.decimals = 0
        }

        if axis.centerAxisLabelsEnabled
        {
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
    
    private var axisLineSegmentsBuffer = [CGPoint](repeating: .zero, count: 2)
    
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
            
            axisLineSegmentsBuffer[0].x = viewPortHandler.contentCenter.x
            axisLineSegmentsBuffer[0].y = viewPortHandler.contentTop
            axisLineSegmentsBuffer[1].x = viewPortHandler.contentCenter.x
            axisLineSegmentsBuffer[1].y = viewPortHandler.contentBottom
            context.strokeLineSegments(between: axisLineSegmentsBuffer)
        }
    }
    
    public func renderAxisLabels(context: CGContext) {
        if axis.isEnabled,
           axis.isDrawLabelsEnabled {
            
            let xOffset = axis.xOffset
//            let yoffset = axis.labelFont.lineHeight / 2.5 + axis.yOffset
            
            switch axis.labelPosition {
            case .left:
                drawLabels(context: context, pos: viewPortHandler.contentCenter.x - xOffset, anchor: CGPoint(x: 0.5, y: 1.0))
                
            case .leftInside:
                drawLabels(context: context, pos: viewPortHandler.contentCenter.x + xOffset + axis.labelRotatedHeight, anchor: CGPoint(x: 0.5, y: 1.0))
                
            case .right:
                drawLabels(context: context, pos: viewPortHandler.contentCenter.x + xOffset, anchor: CGPoint(x: 0.5, y: 0.0))
                
            case .rightInside:
                drawLabels(context: context, pos: viewPortHandler.contentCenter.x - xOffset - axis.labelRotatedHeight, anchor: CGPoint(x: 0.5, y: 0.0))
                
            case .bothSided:
                drawLabels(context: context, pos: viewPortHandler.contentCenter.x - xOffset, anchor: CGPoint(x: 0.5, y: 1.0))
                drawLabels(context: context, pos: viewPortHandler.contentCenter.x + xOffset, anchor: CGPoint(x: 0.5, y: 0.0))
            }
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
            position.y = centeringEnabled ? CGFloat(axis.centeredEntries[i]) : CGFloat(axis.entries[i])
            position.x = 0

            transformer.pointValueToPixel(&position)
            position.x = pos
            
            if viewPortHandler.isInBounds(point: position),
                let label = axis.valueFormatter?.stringForValue(axis.entries[i], axis: axis) {
                drawLabel(context: context, formattedLabel: label, x: pos, y: position.y, attributes: labelAttrs, constrainedTo: labelMaxSize, anchor: anchor, angleRadians: labelRotationAngleRadians)
            }
        }
    }
    
    @objc open func drawLabel( context: CGContext, formattedLabel: String, x: CGFloat, y: CGFloat, attributes: [NSAttributedString.Key : Any], constrainedTo size: CGSize, anchor: CGPoint, angleRadians: CGFloat) {
        context.drawMultilineText(formattedLabel, at: CGPoint(x: x, y: y), constrainedTo: size, anchor: anchor, angleRadians: angleRadians, attributes: attributes)
    }
    
    /// Draws the grid lines belonging to the axis.
    @objc public func renderGridLines(context: CGContext) {
        
        // no need as major axis renderer does this, although if don't want major axis need to render gridlines for minor
        if let _majorAxis = self.majorAxis,
           _majorAxis.drawGridLinesEnabled {
    
        }
        else if let _transformer = self.transformer {
            // calculate the factor that is needed for transforming the value to
            // pixels
            var valueToPixelMatrix = _transformer.valueToPixelMatrix
            let center: CGPoint = .zero
            
            context.saveGState()
            // draw the inner-web
            context.setLineWidth(axis.axisLineWidth)
            context.setStrokeColor(axis.axisLineColor.cgColor)
            
            let labelCount = axis.entryCount
            for j in 0 ..< labelCount {
                if axis.entries[j] > 0 {  // don't need negative entries as psoitive one with take care of concentric circles
                    let diameter: CGFloat = CGFloat(axis.entries[j]) * 2
                    let circle = CGPath(ellipseIn: CGRect(x: -diameter / 2 + center.x, y: -diameter / 2 + center.y, width: diameter, height: diameter), transform: &valueToPixelMatrix)
                    context.addPath(circle)
                    context.strokePath()
                }
            }
            
            if axis.granularityEnabled {
                context.setLineWidth(axis.gridLineWidth)
                context.setStrokeColor(axis.gridColor.cgColor)
                
                for j in 0..<labelCount-1 {
                    if axis.entries[j] > 0 {
                        let granularityCount = Int((axis.entries[j] - axis.entries[j-1]) / axis.granularity)
                        for i in 1..<granularityCount {
                            let diameter: CGFloat = CGFloat(axis.entries[j] + Double(i) * axis.granularity) * 2
                            let circle = CGPath(ellipseIn: CGRect(x: -diameter / 2 + center.x, y: -diameter / 2 + center.y, width: diameter, height: diameter), transform: &valueToPixelMatrix)
                            context.addPath(circle)
                            context.strokePath()
                        }
                    }
                }
            }
            
            context.restoreGState()
        }
    }
    
    @objc public func renderLimitLines(context: CGContext) {
        /// MinorAxis LimitLines on PolarChart not yet supported.
    }
}
