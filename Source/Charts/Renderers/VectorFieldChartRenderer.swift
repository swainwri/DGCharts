//
//  VectorFieldChartRenderer.swift
//  DGCharts
//
//  Created by Steve Wainwright on 09/04/2023.
//

import Foundation
import CoreGraphics

public class VectorFieldChartRenderer: LineScatterCandleRadarRenderer {
    
    @objc public weak var dataProvider: FieldChartDataProvider?
    
    @objc public weak var delegate: VectorFieldChartViewDelegate?
    
    @objc public init(dataProvider: FieldChartDataProvider, animator: Animator, viewPortHandler: ViewPortHandler) {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    /// Checks if the provided entry object is in bounds for drawing considering the current animation phase.
    internal func isInBoundsY(entry e: ChartDataEntry, dataSet: VectorFieldChartDataSetProtocol) -> Bool {
        let entryIndex = dataSet.entryIndex(entry: e)
        // since dataset is sorted by x and then by y in each x column
        
        if let columnFirstLast = dataSet.getFirstLastIndexInEntries(forEntryX: e) {
            return Double(entryIndex) > Double(columnFirstLast[0]) * animator.phaseY && Double(entryIndex) < Double(columnFirstLast[1]) * animator.phaseY
        }
        else {
            return false
        }
    }

    public override func drawData(context: CGContext) {
        if let vectorFieldData = dataProvider?.vectorFieldData {
            
            // If we redraw the data, remove and repopulate accessible elements to update label values and frames
            accessibleChartElements.removeAll()
            
            if let chart = dataProvider as? VectorFieldChartView {
                // Make the chart header the first element in the accessible elements array
                let element = createAccessibleHeader(usingChart: chart, andData: vectorFieldData, withDefaultDescription: "Vector Field Chart")
                accessibleChartElements.append(element)
            }
            
            // TODO: Due to the potential complexity of data presented in Scatter charts, a more usable way
            // for VO accessibility would be to use axis based traversal rather than by dataset.
            // Hence, accessibleChartElements is not populated below. (Individual renderers guard against dataSource being their respective views)
            let sets = vectorFieldData.dataSets as? [VectorFieldChartDataSet]
            assert(sets != nil, "Datasets for VectorFieldChartRenderer must conform to IVectorFieldChartDataSet")
            
            let drawDataSet = { self.drawDataSet(context: context, dataSet: $0) }
            sets!.lazy.filter(\.isVisible).forEach(drawDataSet)
        }
    }
    
    private var _lineSegments = [CGPoint](repeating: CGPoint(), count: 2)
    
    @objc public func drawDataSet(context: CGContext, dataSet: VectorFieldChartDataSetProtocol) {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        let entryCount = dataSet.entryCount
        
        var base = CGPoint(), tip = CGPoint()
        var length: CGFloat = 0
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        let maxVectorLength = dataSet.maxVectorMagnitude
        let factor = dataSet.normalisedVectorLength / maxVectorLength
                
        var vectorWidth = dataSet.vectorWidth
        var color = dataSet.color(atIndex: 0)
        var theFill: ColorFill = ColorFill(cgColor: color.cgColor)
        
        // tip
        context.saveGState()
            
        for j in 0 ..< Int(min(ceil(Double(entryCount) * animator.phaseX), Double(entryCount))) {
            if let e = dataSet.entryForIndex(j) as? FieldChartDataEntry {
                
                base.x = CGFloat(e.x)
                base.y = CGFloat(e.y * phaseY)
                base = base.applying(valueToPixelMatrix)
                
                length = CGFloat(e.magnitude * factor)
                tip.x = base.x + length * sin(e.direction)
                tip.y = base.y + length * cos(e.direction)
                
//                tip = tip.applying(valueToPixelMatrix)
                
//                if !viewPortHandler.isInBoundsRight(base.x) {
//                    break
//                }
                
                if !viewPortHandler.isInBoundsX(base.x) ||
                    !viewPortHandler.isInBoundsY(base.y) {
                    continue
                }
                
                let theArrowHeadPath = arrowHeadPath(dataSet: dataSet)
                
                context.saveGState()
                
                if let _delegate = self.delegate,
                   _delegate.responds(to: #selector(VectorFieldChartViewDelegate.chartValueStyle(entry:vectorWidth:color:fill:))) {
                    _delegate.chartValueStyle!(entry: e, vectorWidth: &vectorWidth, color: &color, fill: &theFill)
                }
                
                if !tip.x.isNaN && !tip.y.isNaN {
                    
                    let vectorPath = CGMutablePath()
                    if base.equalTo(tip) {
                        vectorPath.move(to: CGPoint(x: base.x - 1, y: base.y - 1))
                        vectorPath.addEllipse(in: CGRect(x: base.x - 1, y: base.y - 1, width: 2, height: 2))
                        context.beginPath()
                        context.addPath(vectorPath)
                        context.setLineWidth(vectorWidth)
                        context.setStrokeColor(color.cgColor)
                        context.strokePath()
                    }
                    else {
                        vectorPath.move(to: CGPoint(x: base.x - 1, y: base.y - 1))
                        vectorPath.addEllipse(in: CGRect(x: base.x - 1, y: base.y - 1, width: 2, height: 2))
                        vectorPath.move(to: base)
                        vectorPath.addLine(to: tip)
                        
                        let direction = atan((tip.y - base.y) / (tip.x - base.x)) + ((tip.x - base.x) < 0.0 ? .pi : 0.0)
                        
                        context.beginPath()
                        context.addPath(vectorPath)
                        context.setLineWidth(vectorWidth)
                        context.setStrokeColor(color.cgColor)
                        context.strokePath()
                        
                        context.saveGState()
                        context.translateBy(x: tip.x, y: tip.y)
                        context.rotate(by:  direction - .pi / 2)
                        
                        // use fillRect instead of fillPath so that images and gradients are properly centered in the symbol
                        let arrowHeadSize: CGFloat = dataSet.arrowSize
                        let halfSize: CGFloat = arrowHeadSize / 2.0
                        let bounds = CGRect(x: -halfSize, y: -halfSize, width: arrowHeadSize, height: arrowHeadSize)
                        
                        context.saveGState()
                        if !theArrowHeadPath.isEmpty  {
                            context.beginPath()
                            context.addPath(theArrowHeadPath)
                            
                            if dataSet.usesEvenOddClipRule {
                                context.clip(using: .evenOdd)
                            }
                            else {
                                context.clip(using: .winding)
                            }
                        }
                        theFill.fillPath(context: context, rect: bounds)
                        context.restoreGState()
                        
                        if !theArrowHeadPath.isEmpty  {
                            context.setLineWidth(vectorWidth)
                            context.setStrokeColor(color.cgColor)
                            context.beginPath()
                            context.addPath(theArrowHeadPath)
                            context.strokePath()
                        }
                        
                        context.restoreGState()
                        
//#if DEBUG
//                        if let imgRef: CGImage = context.makeImage() {
//#if os(OSX)
//                            //                NSImage* img = [[NSImage alloc] initWithCGImage:imgRef size: NSZeroSize];
//                            //
//                            //                NSImage* __unused flippedImage = [NSImage imageWithSize:img.size flipped:YES drawingHandler:^BOOL(NSRect dstRect) {
//                            //                    [img drawInRect:dstRect];
//                            //                    return YES;
//                            //                }];
//#else
//                            let img = UIImage(cgImage: imgRef)
//                            let size = img.size
//                            UIGraphicsBeginImageContext(size)
//                            UIImage(cgImage: imgRef, scale: 1, orientation: .downMirrored).draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
//                            let flippedImage = UIGraphicsGetImageFromCurrentImageContext()
//                            UIGraphicsEndImageContext()
//#endif
//                        }
//#endif
                    }
                }
                context.restoreGState()
            }
        }
        
        context.restoreGState()
    }
    
//    public func drawValues(context: CGContext) {
//        guard
//            let dataProvider = dataProvider,
//            let scatterData = dataProvider.scatterData
//            else { return }
//
//        // if values are drawn
//        if isDrawingValuesAllowed(dataProvider: dataProvider)
//        {
//            let phaseY = animator.phaseY
//
//            var pt = CGPoint()
//
//            for i in scatterData.indices
//            {
//                guard let dataSet = scatterData[i] as? ScatterChartDataSetProtocol,
//                      shouldDrawValues(forDataSet: dataSet)
//                    else { continue }
//
//                let valueFont = dataSet.valueFont
//
//                let formatter = dataSet.valueFormatter
//
//                let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
//                let valueToPixelMatrix = trans.valueToPixelMatrix
//
//                let iconsOffset = dataSet.iconsOffset
//
//                let angleRadians = dataSet.valueLabelAngle.DEG2RAD
//
//                let shapeSize = dataSet.scatterShapeSize
//                let lineHeight = valueFont.lineHeight
//
//                _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
//
//                for j in _xBounds
//                {
//                    guard let e = dataSet.entryForIndex(j) else { break }
//
//                    pt.x = CGFloat(e.x)
//                    pt.y = CGFloat(e.y * phaseY)
//                    pt = pt.applying(valueToPixelMatrix)
//
//                    if (!viewPortHandler.isInBoundsRight(pt.x))
//                    {
//                        break
//                    }
//
//                    // make sure the lines don't do shitty things outside bounds
//                    if (!viewPortHandler.isInBoundsLeft(pt.x)
//                        || !viewPortHandler.isInBoundsY(pt.y))
//                    {
//                        continue
//                    }
//
//                    let text = formatter.stringForValue(
//                        e.y,
//                        entry: e,
//                        dataSetIndex: i,
//                        viewPortHandler: viewPortHandler)
//
//                    if dataSet.isDrawValuesEnabled
//                    {
//                        context.drawText(text,
//                                         at: CGPoint(x: pt.x,
//                                                     y: pt.y - shapeSize - lineHeight),
//                                         align: .center,
//                                         angleRadians: angleRadians,
//                                         attributes: [.font: valueFont,
//                                                      .foregroundColor: dataSet.valueTextColorAt(j)]
//                        )
//                    }
//
//                    if let icon = e.icon, dataSet.isDrawIconsEnabled
//                    {
//                        context.drawImage(icon,
//                                          atCenter: CGPoint(x: pt.x + iconsOffset.x,
//                                                          y: pt.y + iconsOffset.y),
//                                          size: icon.size)
//                    }
//                }
//            }
//        }
//    }
    
 //   public func drawExtras(context: CGContext) {
    
//    }
    
    public override func drawHighlighted(context: CGContext, indices: [Highlight]) {
        guard
            let dataProvider = dataProvider,
            let vectorFieldData = dataProvider.vectorFieldData
            else { return }

        context.saveGState()

        for high in indices {
            guard
                let set = vectorFieldData[high.dataSetIndex] as? VectorFieldChartDataSetProtocol,
                set.isHighlightEnabled
                else { continue }

            guard let entry = set.entryForXValue(high.x, closestToY: high.y) else { continue }

            if !isInBoundsX(entry: entry, dataSet: set) || !isInBoundsY(entry: entry, dataSet: set) { continue }

            context.setStrokeColor(set.highlightColor.cgColor)
            context.setLineWidth(set.highlightLineWidth)
            if let _highlightLineDashLengths = set.highlightLineDashLengths {
                context.setLineDash(phase: set.highlightLineDashPhase, lengths: _highlightLineDashLengths)
            }
            else {
                context.setLineDash(phase: 0.0, lengths: [])
            }

            let x = entry.x // get the x-position
            let y = entry.y * Double(animator.phaseY)

            let trans = dataProvider.getTransformer(forAxis: set.axisDependency)

            let pt = trans.pixelForValues(x: x, y: y)

            high.setDraw(pt: pt)

            // draw the lines
            drawHighlightLines(context: context, point: pt, set: set)
        }

        context.restoreGState()
}
            
    private func arrowHeadPath(dataSet: VectorFieldChartDataSetProtocol) -> CGMutablePath {
            
        let arrowType = dataSet.arrowType
        let shapeSize = dataSet.arrowSize
        let shapeHalf = shapeSize / 2.0
        
        let arrowHeadPath: CGMutablePath = CGMutablePath()
        switch arrowType {
            case .none:
                break
                
            case .open:
                arrowHeadPath.move(to: CGPoint(x: -shapeHalf, y: -shapeHalf))
                arrowHeadPath.addLine(to: CGPoint(x: 0, y: 0))
                arrowHeadPath.addLine(to: CGPoint(x: shapeHalf, y: -shapeHalf))
            
            case .solid:
                arrowHeadPath.move(to: CGPoint(x: -shapeHalf, y: -shapeHalf))
                arrowHeadPath.addLine(to: CGPoint(x: 0, y: 0))
                arrowHeadPath.addLine(to: CGPoint(x: shapeHalf, y: -shapeHalf))
                arrowHeadPath.closeSubpath()
                
            case .swept:
                arrowHeadPath.move(to: CGPoint(x: -shapeHalf, y: -shapeHalf))
                arrowHeadPath.addLine(to: CGPoint(x: 0, y: 0))
                arrowHeadPath.addLine(to: CGPoint(x: shapeHalf, y: -shapeHalf))
                arrowHeadPath.addLine(to: CGPoint(x: 0, y: -shapeSize * 0.375))
                arrowHeadPath.closeSubpath()
        }
        return arrowHeadPath
    }
    
    /// Class representing the bounds of the current viewport in terms of indices in the values array of a DataSet.
    public class YBounds {
        /// minimum visible entry index
        public var min: Int = 0

        /// maximum visible entry index
        public var max: Int = 0

        /// range of visible entry indices
        public var range: Int = 0

        public init()  {
            
        }
        
        public init(chart: FieldChartDataProvider, dataSet: VectorFieldChartDataSetProtocol, animator: Animator?){
            self.set(chart: chart, dataSet: dataSet, animator: animator)
        }
        
        /// Calculates the minimum and maximum x values as well as the range between them.
        public func set(chart: FieldChartDataProvider, dataSet: VectorFieldChartDataSetProtocol, animator: Animator?) {
            let phaseY = Swift.max(0.0, Swift.min(1.0, animator?.phaseY ?? 1.0))
            
            let low = chart.lowestVisibleX
            let high = chart.highestVisibleX
            
            let lowY = chart.lowestVisibleY
            let highY = chart.highestVisibleY
            
            let entryFrom = dataSet.entryForXValue(low, closestToY: lowY, rounding: .down)
            let entryTo = dataSet.entryForXValue(high, closestToY: highY, rounding: .up)
            
            self.min = entryFrom == nil ? 0 : dataSet.entryIndex(entry: entryFrom!)
            self.max = entryTo == nil ? 0 : dataSet.entryIndex(entry: entryTo!)
            range = Int(Double(self.max - self.min) * phaseY)
        }
    }
}


