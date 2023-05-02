//
//  ContourChartRenderer.swift
//  Charts
//
//  Created by Steve Wainwright on 16/04/2023.
//

import Foundation
import CoreGraphics
import KDTree

public class ContourChartRenderer: LineScatterCandleRadarRenderer {
    
    
    @objc public weak var dataProvider: ContourChartDataProvider?
    
    @objc public init(dataProvider: ContourChartDataProvider, animator: Animator, viewPortHandler: ViewPortHandler) {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    /// Checks if the provided entry object is in bounds for drawing considering the current animation phase.
    private func isInBoundsY(entry e: ChartDataEntry, dataSet: ContourChartDataSetProtocol) -> Bool {
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
        if let contourData = dataProvider?.contourData {
            
            // If we redraw the data, remove and repopulate accessible elements to update label values and frames
            accessibleChartElements.removeAll()
            
            if let chart = dataProvider as? ContourChartView {
                // Make the chart header the first element in the accessible elements array
                let element = createAccessibleHeader(usingChart: chart, andData: contourData, withDefaultDescription: "Contour Chart")
                accessibleChartElements.append(element)
            }
            
            // TODO: Due to the potential complexity of data presented in Scatter charts, a more usable way
            // for VO accessibility would be to use axis based traversal rather than by dataset.
            // Hence, accessibleChartElements is not populated below. (Individual renderers guard against dataSource being their respective views)
            let sets = contourData.dataSets as? [ContourChartDataSet]
            assert(sets != nil, "Datasets for ContourChartRenderer must conform to IContourChartDataSet")
            
            if let _sets = sets {
                var i: Int = 0
                for var _set: ContourChartDataSetProtocol in _sets {
                    if _set.isVisible && !_set.firstRendition {
                        drawDataSet(context: context, dataSet: &_set)
                        contourData.dataSets[i] = _set
                    }
                    i += 1
                }
            }
        }
    }
    
    private func drawDataSet(context: CGContext, dataSet: inout ContourChartDataSetProtocol) {
        if let dataProvider = dataProvider {
            
            let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
            let valueToPixelMatrix = trans.valueToPixelMatrix
            let pixelToValueMatrix = trans.pixelToValueMatrix
            let phaseY = animator.phaseY
            
            var currentContext: CGContext = context
            
            if dataSet.needsIsoCurvesUpdate {
                
//                // if you require actual input data to be shown in contour chart
//                if !dataSet.functionPlot,
//                   let renderer = dataSet.shapeRenderer {
//                    context.saveGState()
//
//                    var pt = CGPoint()
//
//                    for j in 0..<dataSet.entryCount  {
//                        if let entry = dataSet.entryForIndex(j) {
//
//                            pt.x = CGFloat(entry.x)
//                            pt.y = CGFloat(entry.y * phaseY)
//                            pt = pt.applying(valueToPixelMatrix)
//
//                            if viewPortHandler.isInBoundsLeft(pt.x) && viewPortHandler.isInBoundsRight(pt.x) && viewPortHandler.isInBoundsY(pt.y) {
//
//                                renderer.renderShape(context: context, dataSet: dataSet, viewPortHandler: viewPortHandler, point: pt, color: dataSet.color(atIndex: j))
//                            }
//                        }
//                    }
//                    context.restoreGState()
//                }
//                else {
//                    print("Not a real data contour chart and there's no ShapeRenderer specified for ContourDataSet", terminator: "\n")
//                }
                
                var limits: [CGFloat] = [ -.greatestFiniteMagnitude, .greatestFiniteMagnitude, -.greatestFiniteMagnitude, .greatestFiniteMagnitude ]
                context.saveGState()
                
                var currentMaxWidthPixels: CGFloat = 0, currentMaxHeightPixels: CGFloat = 0
                
                if !dataSet.extrapolateToLimits && !dataSet.functionPlot {
                    
                    currentMaxWidthPixels = dataSet.greatestContourBox.width + dataSet.extraWidth * 2
                    currentMaxHeightPixels = dataSet.greatestContourBox.height + dataSet.extraHeight * 2
#if os(OSX)
                    let size = NSSize(width: currentMaxWidthPixels, height: currentMaxHeightPixels)
                    dataSet.macOSImage = NSImage(size: size)
                    if let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: Int(size.width) * 4, bitsPerPixel: 32) {
                        dataSet.macOSImage?.addRepresentation(rep)
                        
                        dataSet.macOSImage?.lockFocus()
                        
                        if let _context = NSGraphicsContext.current?.cgContext {
                            currentContext = _context
                        }
                        dataSet.scaleOfContext = 1.0
//                        if let bitmapContext = NSGraphicsContext(bitmapImageRep: rep) {
//                            currentContext = bitmapContext.cgContext
//                        }
                    }
#else
                    UIGraphicsBeginImageContextWithOptions(dataSet.greatestContourBox.size, false, 0)
                    if let _context = UIGraphicsGetCurrentContext() {
                        currentContext = _context
                    }
#endif
                    var viewPoints: [CGPoint] = [ dataSet.greatestContourBox.origin, CGPoint(x: dataSet.greatestContourBox.maxX, y: dataSet.greatestContourBox.maxY) ]
                    if dataSet.alignsPointsToPixels {
                        alignViewPointsToUserSpace(&viewPoints, withContext: currentContext, lineWidth: dataSet.isoCurvesLineWidth)
                    }
                        
                    dataSet.originOfContext = CGPoint(x: viewPoints[0].x, y: viewPoints[1].y)
                    let limitPoint0 = viewPoints[0].applying(pixelToValueMatrix)
                    let limitPoint1 = viewPoints[1].applying(pixelToValueMatrix)
                    limits[0] = limitPoint0.x
                    limits[1] = limitPoint1.y
                    limits[2] = limitPoint1.x
                    limits[3] = limitPoint0.y
                }
                else {
                    var viewPoints: [CGPoint] = [ CGPoint(x: dataSet.limits[0], y: dataSet.limits[2]).applying(valueToPixelMatrix), CGPoint(x: dataSet.limits[1], y: dataSet.limits[3]).applying(valueToPixelMatrix) ]
                    if dataSet.alignsPointsToPixels {
                        alignViewPointsToUserSpace(&viewPoints, withContext: currentContext, lineWidth: dataSet.isoCurvesLineWidth)
                    }
                    limits[0] = dataSet.limits[0]
                    limits[1] = dataSet.limits[1]
                    limits[2] = dataSet.limits[2]
                    limits[3] = dataSet.limits[3]
                    currentMaxWidthPixels = viewPoints[1].x - viewPoints[0].x + dataSet.extraWidth * 2
                    currentMaxHeightPixels = viewPoints[0].y - viewPoints[1].y + dataSet.extraHeight * 2
                    dataSet.originOfContext = CGPoint(x: viewPoints[0].x - dataSet.extraWidth, y: viewPoints[1].y - dataSet.extraHeight)
#if os(OSX)
                    let size = NSSize(width: currentMaxWidthPixels, height: currentMaxHeightPixels)
                    dataSet.macOSImage = NSImage(size: size)
                    if let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: Int(size.width) * 4, bitsPerPixel: 32) {
                        dataSet.macOSImage?.addRepresentation(rep)
                        
                        dataSet.macOSImage?.lockFocus()
                        
                        if let _context = NSGraphicsContext.current?.cgContext {
                            currentContext = _context
                        }
                        dataSet.scaleOfContext = 1.0
//                        if let bitmapContext = NSGraphicsContext(bitmapImageRep: rep) {
//                            currentContext = bitmapContext.cgContext
//                        }
                    }
#else
                    UIGraphicsBeginImageContextWithOptions(CGSize(width: currentMaxWidthPixels, height: currentMaxHeightPixels), false, 0)
                    if let _context = UIGraphicsGetCurrentContext() {
                        currentContext = _context
                    }
#endif
                }
                //        double __unused v = [contours getFieldValueForX:1.0 Y:0.1];
#if DEBUG        // debug
                if let lists = dataSet.contours?.getIsoCurvesLists() {
                    print(String(format: "No of IsoCurves: %ld", lists.count))
                }
#endif
                
                if let contours = dataSet.contours {
                    
                    var cornerPoints: [CGPoint] = [ CGPoint(x: limits[0], y: limits[2]).applying(valueToPixelMatrix), CGPoint(x: limits[1], y: limits[3]).applying(valueToPixelMatrix) ]
                    if dataSet.alignsPointsToPixels {
                        Utilities.alignPointsToUserSpace(context, points: &cornerPoints)
                    }
                    // easier naming edges
                    let boundary = Boundary(leftEdge: cornerPoints[0].x, bottomEdge: cornerPoints[1].y, rightEdge: cornerPoints[1].x, topEdge: cornerPoints[0].y)
                    
                    var boundaryLimitsDataLinePaths: [CGMutablePath]?
                    var discontinuityBorderStrips: [Strip] = []
                    if dataSet.functionPlot {
                        // Attend to any discontinuities in the 3D function, by creating out of bounds
                        // CGPaths, use the already accummulated discontinuity points from 'contours'
                        boundaryLimitsDataLinePaths = pathsDiscontinuityRegions(context: context, dataSet: &dataSet, discontinuityStrips: &discontinuityBorderStrips, boundary: boundary)
                    }
                    
                    // Fill between the isocurves
                    if dataSet.fillIsoCurves,
                       let _isoCurvesColourFills = dataSet.isoCurvesColourFills,
                       let _isoCurvesLineColours = dataSet.isoCurvesLineColours,
                       _isoCurvesColourFills.count > 0 || _isoCurvesLineColours.count > 0  {
                        
                        var usedExtraLineStripLists: [Bool] = Array(repeating: false, count: dataSet.noActualIsoCurves)
                        var allEdgeBorderStrips = collectStripsForBorders(context: context, dataSet: dataSet, usedExtraLineStripLists: &usedExtraLineStripLists, boundary: boundary)
                        
                        // if there are discontinuity boundaries include the edges if any
                        if let _boundaryLimitsDataLinePaths = boundaryLimitsDataLinePaths,
                           !_boundaryLimitsDataLinePaths.isEmpty {
                            let collected = collectBorderDiscontinuityStrips(discontinuityStrips: discontinuityBorderStrips, boundary: boundary)
                            for i in 0..<4 {
                                allEdgeBorderStrips[i].append(contentsOf: collected[i])
                            }
                        }
                        
                        allEdgeBorderStrips[0].sortStripsByBorderDirection(.xForward)
                        allEdgeBorderStrips[1].sortStripsByBorderDirection(.yForward)
                        allEdgeBorderStrips[2].sortStripsByBorderDirection(.xBackward)
                        allEdgeBorderStrips[3].sortStripsByBorderDirection(.yBackward)
                        
                        var combinedBorderStrips: [Strip] = []
                        combinedBorderStrips.reserveCapacity(allEdgeBorderStrips[0].count + allEdgeBorderStrips[1].count + allEdgeBorderStrips[2].count + allEdgeBorderStrips[3].count)
                        for i in 0..<4 {
                            combinedBorderStrips.append(contentsOf: allEdgeBorderStrips[i])
                            allEdgeBorderStrips[i].removeAll()
                        }
                        
                        // check Strips based on extraLineStripList to see that only 2 points touch the border,
                        // rid LineStrip of points on same boundary except the one joining to another boundary
                        if !combinedBorderStrips.isEmpty {
                            combinedBorderStrips.removeDuplicates()
                            for i in 0..<combinedBorderStrips.count {
                                // if combinedBorderStrips[i].plane == NSNotFound, then a discontinuity strip
                                if combinedBorderStrips[i].plane != NSNotFound,
                                   usedExtraLineStripLists[combinedBorderStrips[i].plane],
                                   let stripList = combinedBorderStrips[i].stripList,
                                   stripList == contours.getExtraIsoCurvesList(atIsoCurve: combinedBorderStrips[i].plane) {
                                    let pos = combinedBorderStrips[i].index
                                    if pos < stripList.count {
                                        var strip = stripList[pos]
                                        if contours.removeExcessBoundaryNodeFromExtraLineStrip(&strip) {
                                            let indexStart = strip[0]
                                            let indexEnd = strip[strip.count - 1]
                                            let startX = contours.getX(at: indexStart)
                                            let startY = contours.getY(at: indexStart)
                                            let endX = contours.getX(at: indexEnd)
                                            let endY = contours.getY(at: indexEnd)
                                            var startPoint = CGPoint(x: startX, y: startY).applying(valueToPixelMatrix)
                                            var endPoint = CGPoint(x: endX, y: endY).applying(valueToPixelMatrix)
                                            var convertPoints: [CGPoint] = [ startPoint, endPoint ]
                                            if dataSet.alignsPointsToPixels {
                                                Utilities.alignPointsToUserSpace(context, points: &convertPoints)
                                            }
                                            startPoint = convertPoints[0]
                                            endPoint = convertPoints[1]
                                            if combinedBorderStrips[i].reverse {
                                                startPoint = endPoint
                                                endPoint = convertPoints[0]
                                            }
                                            if !combinedBorderStrips[i].startPoint.equalTo(startPoint) {
                                                combinedBorderStrips[i].startPoint = startPoint
                                                combinedBorderStrips[i].startBorderdirection = findPointBorderDirection(startPoint, boundary: boundary)
                                            }
                                            if !combinedBorderStrips[i].endPoint.equalTo(endPoint) {
                                                combinedBorderStrips[i].endPoint = endPoint
                                                combinedBorderStrips[i].endBorderdirection = findPointBorderDirection(endPoint, boundary: boundary)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // MARK: - Fill contours
                            
                            var startEndPointIndices: [BorderIndex] = []
                            combinedBorderStrips.sortStripsIntoStartEndPointPositions(&startEndPointIndices)
                            if !dataSet.extrapolateToLimits && !dataSet.functionPlot {
                                joinBorderStripsToCreateClosedStrips(&combinedBorderStrips, borderIndices: &startEndPointIndices, usedExtraLineStripLists: &usedExtraLineStripLists, context: context, dataSet: dataSet, boundary: boundary)
                            }
                            else {
                                drawFillBetweenBorderIsoCurves(context, dataSet: dataSet, borderStrips: combinedBorderStrips, borderIndices: &startEndPointIndices, outerBoundaryLimitsCGPaths: boundaryLimitsDataLinePaths, usedExtraLineStripLists: usedExtraLineStripLists, boundary: boundary)
                            }
                            startEndPointIndices.removeAll()
                        }
                        combinedBorderStrips.removeAll()
                        
                        drawFillBetweenClosedIsoCurves(context, dataSet: dataSet, usedExtraLineStripLists: usedExtraLineStripLists, boundary: boundary)
                        
                        usedExtraLineStripLists.removeAll()
                    }
                    discontinuityBorderStrips.removeAll()
                    
                    
                    // draw the contours with a CPTLinestyle if available
                    var stripContours: [CGPoint] = []
                    stripContours.reserveCapacity(128)
#if DEBUG
#if os(OSX)
                    let bezierPath = NSBezierPath()
#else
                    let bezierPath = UIBezierPath()
#endif
#endif
                    let maxIndicesSize = (contours.noRowsSecondary + 1) * (contours.noColumnsSecondary + 1)
                    for iPlane in 0..<dataSet.isoCurvesIndices.count {
                        //                    if ( !(iPlane == 1 /*|| iPlane == 2*/) ) continue;
                        let plane = dataSet.isoCurvesIndices[iPlane]
//    #if DEBUG
                        //                    contours.dumpPlane(plane)
//    #endif
                        var theContourLineColour = dataSet.isoCurvesLineColours?[plane] ?? .clear
                        if theContourLineColour == .clear {
                            theContourLineColour = NSUIColor(red: CGFloat(plane) / CGFloat(contours.noPlanes), green: 1 - CGFloat(plane) / CGFloat(contours.noPlanes), blue: 0.0, alpha: 1)
                        }
                        
                        if let stripList = contours.getStripList(forIsoCurve: plane) {
                            for pos in 0..<stripList.count {
                                let strip = stripList[pos]
                                if !strip.isEmpty {
                                    for pos2 in 0..<strip.count {
                                        let index = strip[pos2] // retrieving index
                                        if index < maxIndicesSize {
                                            // drawing
                                            let point = CGPoint(x: contours.getX(at: index), y: contours.getY(at: index))
                                            stripContours.append(point)
                                        }
                                    }
                                    
                                    if stripContours.count > 0 {
                                        var endPoints: [CGPoint] = [ stripContours[0].applying(valueToPixelMatrix), stripContours[stripContours.count - 1].applying(valueToPixelMatrix) ]
                                        
                                        if dataSet.alignsPointsToPixels {
                                            Utilities.alignPointsToUserSpace(context, points: &endPoints)
                                        }
                                        
                                        // if a border contour, recheck that start & end are on border, else make contour closed
                                        if !endPoints[0].equalTo(endPoints[1]) {
//                                            if (abs(endPoints[0].x - (boundary.leftEdge - dataSet.originOfContext.x)) < 0.5 || abs(endPoints[0].x - (boundary.rightEdge - dataSet.originOfContext.x)) < 0.5 ||  abs(endPoints[0].y - (boundary.bottomEdge - dataSet.originOfContext.y)) < 0.5 || abs(endPoints[0].y - (boundary.topEdge - dataSet.originOfContext.y)) < 0.5) && (abs(endPoints[1].x - (boundary.leftEdge - dataSet.originOfContext.x)) < 0.5 || abs(endPoints[1].x - (boundary.rightEdge - dataSet.originOfContext.x)) < 0.5 || abs(endPoints[1].y - (boundary.bottomEdge - dataSet.originOfContext.y)) < 0.5 || abs(endPoints[1].y - (boundary.topEdge - dataSet.originOfContext.y)) < 0.5)  {
//                                            }
                                            if (abs(endPoints[0].x - boundary.leftEdge) < 0.5 || abs(endPoints[0].x - boundary.rightEdge) < 0.5 ||  abs(endPoints[0].y - boundary.bottomEdge) < 0.5 || abs(endPoints[0].y - boundary.topEdge) < 0.5) && (abs(endPoints[1].x - boundary.leftEdge) < 0.5 || abs(endPoints[1].x - boundary.rightEdge) < 0.5 || abs(endPoints[1].y - boundary.bottomEdge) < 0.5 || abs(endPoints[1].y - boundary.topEdge) < 0.5)  {
                                            }
                                            else {
                                                stripContours.append(stripContours[0])
                                            }
                                        }
                                        let dataLinePath = newDataLinePath(forViewPoints: stripContours, dataSet: dataSet, useExtraStripList: false)
                                        if !dataSet.extrapolateToLimits && !dataSet.functionPlot && !dataLinePath.currentPoint.equalTo(stripContours[0].applying(valueToPixelMatrix)) /*&& self.joinContourLineStartToEnd*/ {
                                            dataLinePath.addLine(to: stripContours[0].applying(valueToPixelMatrix))
                                            
                                        }
                                        // Draw line
                                        if theContourLineColour != .clear && !dataLinePath.isEmpty {
                                            context.saveGState()
                                            context.beginPath()
                                            context.addPath(dataLinePath)
                                            context.setStrokeColor(theContourLineColour.cgColor)
                                            context.setLineWidth(dataSet.isoCurvesLineWidth)
                                            context.strokePath()
                                            context.restoreGState()
#if DEBUG
#if os(OSX)
                                            let bezierPath1 = NSBezierPath(cgPath: dataLinePath)
                                            bezierPath.append(bezierPath1)
#else
                                            let bezierPath1 = UIBezierPath(cgPath: dataLinePath)
                                            bezierPath.append(bezierPath1)
#endif
#endif
                                        }
                                        
                                    }
                                    stripContours.removeAll()
#if DEBUG
                                    if let imgRef = context.makeImage() {
#if os(OSX)
                                        let img = NSImage(cgImage: imgRef, size: .zero)
                                        
                                        let flippedImage = NSImage(size: img.size, flipped: true, drawingHandler: { dstRect in img.draw(in: dstRect)
                                            return true
                                        })
#else
                                        let img = UIImage(cgImage: imgRef)
                                        let size = img.size
                                        UIGraphicsBeginImageContext(size)
                                        UIImage(cgImage: imgRef, scale: 1, orientation: .downMirrored).draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                                        if let flippedImage = UIGraphicsGetImageFromCurrentImageContext() {
                                            print(flippedImage.size)
                                        }
                                        UIGraphicsEndImageContext()
#endif
                                    }
#endif
                                }
                            }
                        }
                    }
                    stripContours.removeAll()
                    
                    // show & clean up discontinuity boundary memory
                    if let _boundaryLimitsDataLinePaths = boundaryLimitsDataLinePaths {
                        for path in _boundaryLimitsDataLinePaths {
                            let theContourLineColour: NSUIColor = .black
                            if !path.isEmpty {
                                context.saveGState()
                                context.beginPath()
                                context.addPath(path)
                                context.setLineWidth(dataSet.isoCurvesLineWidth / 2)
                                context.setStrokeColor(theContourLineColour.cgColor)
                                context.strokePath()
                                context.restoreGState()
#if DEBUG
#if os(OSX)
                                let bezierPath1 = NSBezierPath(cgPath: path)
                                print(bezierPath1.bounds)
#else
                                let bezierPath1 = UIBezierPath(cgPath: path)
                                print(bezierPath1.bounds)
#endif
#endif
                            }
                        }
                    }
                }
                if dataSet.fillIsoCurves {
                   if dataSet.isIsoCurveFillsUsingColour,
                       var fillings = dataSet.isoCurvesFillings,
                       fillings.count > 1 {
                        fillings.sort(by: { filling1, filling2 in
                            if let fill1 = filling1.fill as? ColorFill,
                               let fill2 = filling2.fill as? ColorFill,
                               let colour1 = fill1.color.components,
                               let colour2 = fill2.color.components {
                                let numComponents1 = fill1.color.numberOfComponents
                                let numComponents2 = fill2.color.numberOfComponents
                                var red1: CGFloat, red2: CGFloat
                                var green1: CGFloat, green2: CGFloat
                                var blue1: CGFloat, blue2: CGFloat
                                var alpha1: CGFloat, alpha2: CGFloat
                                if numComponents1 == 2 {
                                    red1 = colour1[0]
                                    green1 = colour1[0]
                                    blue1 = colour1[0]
                                    alpha1 = colour1[1]
                                }
                                else {
                                    red1 = colour1[0]
                                    green1 = colour1[1]
                                    blue1 = colour1[2]
                                    alpha1 = colour1[3]
                                }
                                if numComponents2 == 2 {
                                    red2 = colour2[0]
                                    green2 = colour2[0]
                                    blue2 = colour2[0]
                                    alpha2 = colour2[1]
                                }
                                else {
                                    red2 = colour2[0]
                                    green2 = colour2[1]
                                    blue2 = colour2[2]
                                    alpha2 = colour2[3]
                                }
                                let truple1 = Utilities.ColorRGBtoHSL(red: red1, green: green1, blue: blue1)
                                let truple2 = Utilities.ColorRGBtoHSL(red: red2, green: green2, blue: blue2)
                                
                                if truple1.hue == truple2.hue {
                                    return alpha1 < alpha2
                                }
                                else {
                                    return truple1.hue > truple2.hue
                                }
                            }
                            else {
                                return false
                            }
                        })
                        for filling in fillings {
                            if let fill = filling.fill as? ColorFill,
                               let colour = fill.color.components {
                                if filling.first == nil,
                                   let second = filling.second {
                                    print("<%f\t\t%f %f %f %f\n", second, colour[0], colour[1], colour[2], colour[3])
                                }
                                else if filling.second == nil,
                                    let first = filling.first {
                                    print(">%f\t\t%f %f %f %f\n", first, colour[0], colour[1], colour[2], colour[3])
                                }
                                else if let first = filling.first,
                                    let second = filling.second {
                                    if second < first {
                                        print("%f\t%f\t%f %f %f %f\n", second, first, colour[0], colour[1], colour[2], colour[3])
                                    }
                                    else {
                                        print("%f\t%f\t%f %f %f %f\n", first, second, colour[0], colour[1], colour[2], colour[3])
                                    }
                                }
                            }
                        }
                    }
                }
                
                // make image of contours
                if let imageRef = context.makeImage() {
#if os(OSX)
                    if let macOSImage = dataSet.macOSImage {
                        macOSImage.unlockFocus()
                        let image = NSImage(cgImage: imageRef, size: .zero)
                        let flippedImage = NSImage(size: image.size, flipped: true, drawingHandler: { dstRect in
                            image.draw(in: dstRect)
                            return true
                        })
                        if let tiffData = flippedImage.tiffRepresentation,
                           let imageRep = NSBitmapImageRep(data: tiffData),
                           let imageData = imageRep.representation(using: .png, properties: [.compressionFactor: 1]) {
                            let url = URL(fileURLWithPath: dataSet.imageFilePath)
                            do {
                                try imageData.write(to: url, options: .atomic)
                            }
                            catch {
                                print("File could not be written")
                            }
                        }
                    }
#else
                    // Convert back to UIImage and flip to correct way up
                    let image = UIImage(cgImage: imageRef)
                    let size = image.size
                    UIGraphicsBeginImageContext(size)
                    UIImage(cgImage: imageRef, scale: 1, orientation: .downMirrored).draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    if let flippedImage = UIGraphicsGetImageFromCurrentImageContext(),
                       let imageData = flippedImage.pngData() {
                        let url = URL(fileURLWithPath: dataSet.imageFilePath)
                        do {
                            try imageData.write(to: url, options: .atomic)
                        }
                        catch {
                            print("File could not be written")
                        }
                            
                    }
                    // clear up working CGContext(currentContext) if no extrapolate to corners and a data based contour plot
                    // size will be bigger than Device screen size
                    UIGraphicsEndImageContext();
#endif
                }
                context.restoreGState()
                
                
                dataSet.initialXRange = dataSet.xRange
                dataSet.initialYRange = dataSet.yRange
                dataSet.previousLimits = limits
            }
        
            if !dataSet.needsIsoCurvesUpdate {
                context.saveGState()
            
                var imageScaleX: CGFloat = 1.0, imageScaleY: CGFloat = 1.0
#if os(OSX)
                let image = NSImage(contentsOfFile: dataSet.imageFilePath)
                
                imageScaleX = 1 / dataSet.scaleX
                imageScaleY = 1 / dataSet.scaleY
                let _imageRef = image?.cgImage(forProposedRect: nil, context: NSGraphicsContext(cgContext: context, flipped: false), hints: nil)
#else
                let image = UIImage(contentsOfFile: dataSet.imageFilePath)
            
                var display: CGFloat = 0; // standard display
                if UIScreen.main.scale == 2.0 {
                    display = 1 // is retina display
                }
                else if UIScreen.main.scale == 3.0 {
                    display = 4 // is retina display
                }
                if UIDevice.current.userInterfaceIdiom == .pad {
                    display += 2
                }
                
                if display == 1 || display == 3 {
                    imageScaleX = 0.5
                    imageScaleY = 0.5
                }
                else if display == 4 {
                    imageScaleX = 1.0 / 3.0
                    imageScaleY = 1.0 / 3.0
                }
                let _imageRef = image?.cgImage
#endif
                if let imageRef = _imageRef {
                    var plotLimits: [CGPoint] = [ CGPoint(x: dataSet.limits[0], y: dataSet.limits[2]).applying(valueToPixelMatrix), CGPoint(x: dataSet.limits[1], y: dataSet.limits[3]).applying(valueToPixelMatrix) ]
                    if dataSet.alignsPointsToPixels {
                        alignViewPointsToUserSpace(&plotLimits, withContext: context, lineWidth: dataSet.isoCurvesLineWidth)
                    }
                    
                    var xOffset: CGFloat = 0, yOffset: CGFloat = 0
                    var xWidth = CGFloat(imageRef.width), yHeight = CGFloat(imageRef.height)
                    let xWidthOriginal: CGFloat = xWidth, yHeightOriginal: CGFloat = yHeight
                    if dataSet.limits[0] < dataSet.xRange.minLimit {
                        xOffset = (-plotLimits[0].x - dataSet.extraWidth) / imageScaleX
                        xWidth =  plotLimits[1].x / imageScaleX
                    }
                    else if dataSet.limits[2] > dataSet.xRange.maxLimit  {
                        xWidth -= (plotLimits[1].x - dataSet.maxWidthPixels - dataSet.extraWidth) / imageScaleX
                    }
                    if dataSet.limits[1] < dataSet.yRange.minLimit  {
                        yHeight = (plotLimits[1].y + dataSet.extraHeight) / imageScaleY
                    }
                    else if dataSet.limits[3] > dataSet.yRange.maxLimit {
                        yOffset = (plotLimits[1].y - dataSet.maxHeightPixels - dataSet.extraHeight) / imageScaleY
                        yHeight -= yOffset
                    }
                    let rect = CGRect(x: plotLimits[0].x - dataSet.extraWidth < 0 ? 0 : plotLimits[0].x - dataSet.extraWidth, y: plotLimits[0].y - dataSet.extraHeight < 0 ? 0 : plotLimits[0].y - dataSet.extraHeight, width: xWidth, height: yHeight)
                    context.scaleBy(x: imageScaleX, y: imageScaleY)
                    context.translateBy(x: plotLimits[0].x - dataSet.extraWidth < 0 ? 0 : plotLimits[0].x - dataSet.extraWidth, y: plotLimits[0].y - dataSet.extraHeight < 0 ? 0 : plotLimits[0].y - dataSet.extraHeight)
                    if xOffset != 0.0 || yOffset != 0.0 || xWidth != xWidthOriginal || yHeight != yHeightOriginal {
                        let imageArea = CGRect(x: xOffset, y: yOffset, width: xWidth, height: yHeight)
                        if let subImageRef = imageRef.cropping(to: imageArea) {
                            context.draw(subImageRef, in: rect)
                        }
                    }
                    else {
                        context.draw(imageRef, in: rect)
                    }
                }
                context.restoreGState()
            
            }
            dataSet.previousFillIsoCurves = dataSet.fillIsoCurves
        }
    }
    
    public override func drawValues(context: CGContext) {
        if let dataProvider = dataProvider,
           let contourData = dataProvider.contourData {
            
            // if values are drawn
            if isDrawingValuesAllowed(dataProvider: dataProvider) {
                let phaseY = animator.phaseY
                
                var pt = CGPoint()
                
                for i in contourData.indices {
                    if let dataSet = contourData[i] as? ContourChartDataSetProtocol,
                       shouldDrawValues(forDataSet: dataSet) {
                        
                        let valueFont = dataSet.valueFont
                        let formatter = dataSet.pointFormatter
                        
                        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
                        let valueToPixelMatrix = trans.valueToPixelMatrix
                        
                        let iconsOffset = dataSet.iconsOffset

                        let angleRadians = dataSet.valueLabelAngle.DEG2RAD
                        
                        let lineHeight = valueFont.lineHeight
                        
                        for j in 0..<dataSet.entryCount  {
                            if let entry = dataSet.entryForIndex(j) {
                                
                                pt.x = CGFloat(entry.x)
                                pt.y = CGFloat(entry.y * phaseY)
                                pt = pt.applying(valueToPixelMatrix)
                                
                                if viewPortHandler.isInBoundsLeft(pt.x) && viewPortHandler.isInBoundsRight(pt.x) && viewPortHandler.isInBoundsY(pt.y) {
                                    
                                    let text = formatter.stringForDataAtPoint(entry: entry, dataSetIndex: i, viewPortHandler: viewPortHandler)
                                    
                                    if dataSet.isDrawValuesEnabled {
                                        context.drawText(text,at: CGPoint(x: pt.x, y: pt.y - lineHeight), align: .center, angleRadians: angleRadians, attributes: [.font: valueFont, .foregroundColor: dataSet.valueTextColorAt(j)]
                                        )
                                    }
                                    
                                    if let icon = entry.icon, dataSet.isDrawIconsEnabled {
                                        context.drawImage(icon, atCenter: CGPoint(x: pt.x + iconsOffset.x, y: pt.y + iconsOffset.y), size: icon.size)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    public override func drawExtras(context: CGContext) {
        drawCircles(context: context)
        drawIsoCurveLabels(context: context)
    }
    
    private func drawCircles(context: CGContext) {
        // if you require actual input data to be shown in contour chart
        if let dataProvider = dataProvider,
           let data = dataProvider.contourData {
            
            let phaseY = animator.phaseY
            
            var pt = CGPoint()
            var rect = CGRect()
            
            
            for i in data.indices {
                if let dataSet = data[i] as? ContourChartDataSetProtocol {
                    
                    // Skip Circles and Accessibility if not enabled,
                    // reduces CPU significantly if not needed
                    if !dataSet.isVisible || !dataSet.isDrawCirclesEnabled || dataSet.entryCount == 0 {
                        continue
                    }
                    
                    if !dataSet.functionPlot {
                        
                        let trans = dataProvider.getTransformer(forAxis: .left)
                        let valueToPixelMatrix = trans.valueToPixelMatrix
                        
                        context.saveGState()
                        
                        let circleRadius = dataSet.circleRadius
                        let circleDiameter = circleRadius * 2.0
                        let circleHoleRadius = dataSet.circleHoleRadius
                        let circleHoleDiameter = circleHoleRadius * 2.0
                        
                        let drawCircleHole = dataSet.isDrawCircleHoleEnabled && circleHoleRadius < circleRadius &&  circleHoleRadius > 0.0
                        let drawTransparentCircleHole = drawCircleHole && (dataSet.circleHoleColor == nil || dataSet.circleHoleColor == NSUIColor.clear)
                        
                        for j in 0..<dataSet.entryCount  {
                            if let entry = dataSet.entryForIndex(j) {
                                
                                pt.x = CGFloat(entry.x)
                                pt.y = CGFloat(entry.y * phaseY)
                                pt = pt.applying(valueToPixelMatrix)
                                
                                // make sure the circles don't do shitty things outside bounds
                                if viewPortHandler.isInBounds(point: pt) {
                                    
                                    
                                    context.setFillColor((dataSet.getCircleColor(atIndex: j) ?? .black).cgColor)
                                    
                                    rect.origin.x = pt.x - circleRadius
                                    rect.origin.y = pt.y - circleRadius
                                    rect.size.width = circleDiameter
                                    rect.size.height = circleDiameter
                                    
                                    if drawTransparentCircleHole {
                                        // Begin path for circle with hole
                                        context.beginPath()
                                        context.addEllipse(in: rect)
                                        
                                        // Cut hole in path
                                        rect.origin.x = pt.x - circleHoleRadius
                                        rect.origin.y = pt.y - circleHoleRadius
                                        rect.size.width = circleHoleDiameter
                                        rect.size.height = circleHoleDiameter
                                        context.addEllipse(in: rect)
                                        
                                        // Fill in-between
                                        context.fillPath(using: .evenOdd)
                                    }
                                    else {
                                        context.fillEllipse(in: rect)
                                        
                                        if drawCircleHole {
                                            context.setFillColor((dataSet.circleHoleColor ?? .white).cgColor)
                                            
                                            // The hole rect
                                            rect.origin.x = pt.x - circleHoleRadius
                                            rect.origin.y = pt.y - circleHoleRadius
                                            rect.size.width = circleHoleDiameter
                                            rect.size.height = circleHoleDiameter
                                            
                                            context.fillEllipse(in: rect)
                                        }
                                    }
                                }
                            }
                        }
                        context.restoreGState()
                    }
                    
                }
            }
            
        }
    }
    
    private func drawIsoCurveLabels(context: CGContext) {
        if let dataProvider = dataProvider,
           let contourData = dataProvider.contourData {
            
            let phaseY = animator.phaseY
            var pt = CGPoint()
            
            for i in contourData.indices {
                if let dataSet = contourData[i] as? ContourChartDataSetProtocol,
                   dataSet.isVisible && dataSet.isDrawIsoCurvesLabelsEnabled,
                   let _isoCurvesLabelsPositions = dataSet.isoCurvesLabelsPositions,
                   let _isoCurvesLabelsRotations = dataSet.isoCurvesLabelsRotations,
                   let _isoCurvesValues = dataSet.isoCurvesValues {
                    
                    let valueFont = dataSet.valueFont
                    let formatter = dataSet.isoCurvesLabelFormatter
                    
                    let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
                    let valueToPixelMatrix = trans.valueToPixelMatrix
                    
                    let lineHeight = valueFont.lineHeight
                    
                    for j in 0..<_isoCurvesLabelsPositions.count  {
                        if !_isoCurvesLabelsPositions[j].isEmpty,
                           let text = formatter.string(from: NSNumber(value: _isoCurvesValues[j])) {
                            for k in 0..<_isoCurvesLabelsPositions[j].count {
                                
                                pt.x = _isoCurvesLabelsPositions[j][k].x
                                pt.y = _isoCurvesLabelsPositions[j][k].y * phaseY
                                pt = pt.applying(valueToPixelMatrix)
                                
                                if viewPortHandler.isInBoundsLeft(pt.x) && viewPortHandler.isInBoundsRight(pt.x) && viewPortHandler.isInBoundsY(pt.y) {
                                    context.drawText(text, at: CGPoint(x: pt.x, y: pt.y - lineHeight), align: .center, angleRadians: _isoCurvesLabelsRotations[j][k], attributes: [.font: valueFont, .foregroundColor: dataSet.isoCurvesLabelTextColor])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    public override func drawHighlighted(context: CGContext, indices: [Highlight]) {
        if let dataProvider = dataProvider,
           let contourData = dataProvider.contourData {
            
            context.saveGState()
            
            for high in indices {
                guard
                    let set = contourData[high.dataSetIndex] as? ContourChartDataSetProtocol,
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
    }
    
    //  MARK: - Drawing
    
    private func drawFillBetweenClosedIsoCurves(_ context: CGContext, dataSet: ContourChartDataSetProtocol, usedExtraLineStripLists: [Bool], boundary: Boundary) -> Void {
        let phaseY = animator.phaseY
            
        var theFill: Any?
        // look for all closed strips ie not touching boundary
        var collectedPlanes: [Int] = []
        var startPoint: CGPoint = .zero
        
        // go through all the planes
        for i in 0..<dataSet.isoCurvesIndices.count {
            let actualPlane = dataSet.isoCurvesIndices[i]
            //                    if ( !(actualPlane == 1 || actualPlane == 2 || actualPlane == 3) ) continue;
            collectedPlanes.append(actualPlane)
            // search for all the closed isocurves for this plane and store in closedStrips
            let closedStrips = searchPlaneClosedIsoCurves(context: context, dataSet: dataSet, plane: actualPlane, useExtraLineStripList: usedExtraLineStripLists[actualPlane])
            if !closedStrips.isEmpty {
                // go through the isocurves in each plane
                for j in 0..<closedStrips.count {
                    collectedPlanes[0] = actualPlane
                    if let refDataLinePath = createClosedDataLinePath(dataSet: dataSet, strip: closedStrips, index: j, startPoint: &startPoint),
                       !refDataLinePath.isEmpty {
                        if !dataSet.extrapolateToLimits && !dataSet.functionPlot && !refDataLinePath.currentPoint.equalTo(startPoint) {
                            refDataLinePath.addLine(to:  CGPoint(x: startPoint.x, y: startPoint.y * phaseY) )
                        }
                        var foundDataLinePaths: [CGMutablePath] = []
                        var foundPlanes: [Int] = []
                        // now find any paths that are within this contour
                        // check if any of other closedStrips for this plane are inside refDataLinePath
                        for k in 0..<closedStrips.count {
                            if k == j {
                                continue
                            }
                            
                            if refDataLinePath.contains(startPoint, using: .evenOdd) {
                                if let innerRefDataLinePath = createClosedDataLinePath(dataSet: dataSet, strip: closedStrips, index: k, startPoint: &startPoint),
                                   !innerRefDataLinePath.isEmpty {
                                    foundDataLinePaths.append(innerRefDataLinePath)
                                    foundPlanes.append(closedStrips[k].plane)
#if os(OSX)
                                    let bezierPath4 = NSBezierPath(cgPath: refDataLinePath)
                                    bezierPath4.append(NSBezierPath(cgPath: innerRefDataLinePath))
#else
                                    let bezierPath4 = UIBezierPath(cgPath: refDataLinePath)
                                    bezierPath4.append(UIBezierPath(cgPath: innerRefDataLinePath))
#endif
                                }
                            }
                        }
                        context.saveGState()
                        
                        var plane = i
                        var noFoundDataLinePaths = findClosedDataLinePaths(&foundDataLinePaths, foundClosedPlanes: &foundPlanes, outerCGPath: refDataLinePath, context: context, dataSet: dataSet, plane: &plane, boundary: boundary, ascendingOrder: true, useExtraLineStripList: closedStrips[j].extra, fromCurrentPlane: false, checkPointOnPath: false)
                        //                if ( noFoundDataLinePaths == 0 ) {
                        noFoundDataLinePaths = findClosedDataLinePaths(&foundDataLinePaths, foundClosedPlanes: &foundPlanes, outerCGPath: refDataLinePath, context: context, dataSet: dataSet, plane: &plane, boundary: boundary, ascendingOrder: false, useExtraLineStripList: closedStrips[j].extra, fromCurrentPlane: false, checkPointOnPath: false)
                        //                }
                        // just check if we've missed a path inside another, if so get rid of smaller path
                        var k = 0
                        while k < noFoundDataLinePaths {
#if DEBUG
#if os(OSX)
                            let bezierPath9 = NSBezierPath(cgPath: foundDataLinePaths[k])
#else
                            let bezierPath9 = UIBezierPath(cgPath: foundDataLinePaths[k])
#endif
                            print(bezierPath9.currentPoint)
#endif
                            var l = 0
                            while l < noFoundDataLinePaths {
                                if l != k && foundDataLinePaths[k].contains(foundDataLinePaths[l].centre, using: .evenOdd) {
                                    foundDataLinePaths.remove(at: l)
                                    foundPlanes.remove(at: l)
                                    noFoundDataLinePaths -= 1
                                    if k > 0 {
                                        k -= 1
                                    }
                                }
                                l += 1
                            }
                            k += 1
                        }
                        for l in 0..<noFoundDataLinePaths {
                            collectedPlanes.append(foundPlanes[l])// [[self.isoCurvesIndices objectAtIndex:plane > self.isoCurvesIndices.count - 1 ? self.isoCurvesIndices.count - 1 : plane] unsignedIntegerValue];
                        }
                        
                        if !refDataLinePath.isEmpty {
                            context.addPath(refDataLinePath)
#if DEBUG
#if os(OSX)
                            let bezierPath = NSBezierPath(cgPath: refDataLinePath)
#else
                            let bezierPath = UIBezierPath(cgPath: refDataLinePath)
#endif
                            print(bezierPath.currentPoint)
#endif
                            for k in 0..<noFoundDataLinePaths {
                                if !dataSet.extrapolateToLimits && !dataSet.functionPlot {
                                    foundDataLinePaths[k].closeSubpath()
                                }
#if DEBUG
#if os(OSX)
                                let bezierPath1 = NSBezierPath(cgPath: foundDataLinePaths[k])
                                bezierPath.append(bezierPath1)
#else
                                let bezierPath1 = UIBezierPath(cgPath: foundDataLinePaths[k])
                                bezierPath.append(bezierPath1)
#endif
#endif
                                context.addPath(foundDataLinePaths[k])
                            }
                        }
                        foundDataLinePaths.removeAll()
                        foundPlanes.removeAll()
                        
                        if collectedPlanes.count == 1 {
#if DEBUG
#if os(OSX)
                            let bezierPath = NSBezierPath(cgPath: refDataLinePath)
#else
                            let bezierPath = UIBezierPath(cgPath: refDataLinePath)
#endif
                            print(bezierPath.currentPoint)
#endif
                            //                    theFill = [self findFillFromBoundingPlanes:collectedPlanes noCollectedPlanes:countCollectedPlanes];
                            theFill = calculateFill(refDataLinePath, combinedPath: nil, collectedPlanes: collectedPlanes, dataSet: dataSet)
                        }
                        else {
                            // rid duplicates collectedPlanes
                            collectedPlanes.removeDuplicates()
                            theFill = findFillFromBoundingPlanes(collectedPlanes, dataSet: dataSet)
                            //                        theFill = [self calculateFill:outerCheckValueCGPath combinedPath:innerCheckValueCGPath collectedPlanes:collectedPlanes];
                        }
                        
                        if theFill is ColorFill,
                           let _theFill = theFill as? ColorFill {
                            _theFill.fillPath(context: context, rect: .zero)
                        }
                        else if theFill is ImageFill,
                            let _theFill = theFill as? ImageFill {
                            _theFill.fillPath(context: context, rect: .zero)
                        }
#if DEBUG
                        if let imgRef = context.makeImage() {
#if os(OSX)
                            let img = NSImage(cgImage: imgRef, size: .zero)
                            let flippedImage = NSImage(size: img.size, flipped: true, drawingHandler: { dstRect in
                                img.draw(in: dstRect)
                                return true
                            })
#else
                            let image = UIImage(cgImage: imgRef)
                            let size = image.size
                            UIGraphicsBeginImageContext(CGSize(width: size.width, height: size.height))
                            UIImage(cgImage: imgRef, scale: 1.0, orientation: .downMirrored).draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                            let flippedImage = UIGraphicsGetImageFromCurrentImageContext()
                            print(flippedImage?.size ?? CGSize())
                            UIGraphicsEndImageContext()
#endif
                        }
#endif
                        context.restoreGState()
                    }
                }
            }
            collectedPlanes.removeAll()
        }
    }
                       
    private func drawFillBetweenBorderIsoCurves(_ context: CGContext, dataSet: ContourChartDataSetProtocol, borderStrips: [Strip], borderIndices: inout [BorderIndex], outerBoundaryLimitsCGPaths: [CGMutablePath]?, usedExtraLineStripLists: [Bool], boundary: Boundary) -> Void {
        if let dataProvider = dataProvider,
            let contours = dataSet.contours {
            
            let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
            let phaseY = animator.phaseY
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            let cornerPoints: [CGPoint] = [ CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge),
                                            CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge),
                                            CGPoint(x: boundary.rightEdge, y: boundary.topEdge),
                                            CGPoint(x: boundary.leftEdge, y: boundary.topEdge) ]
            let centre: CGPoint = CGPoint(x: (boundary.leftEdge + boundary.rightEdge) / 2.0, y: (boundary.bottomEdge + boundary.topEdge) / 2.0)
            var cornerAngles: [CGFloat] = [ atan2(boundary.leftEdge - centre.x, boundary.bottomEdge - centre.y),
                                            atan2(boundary.rightEdge - centre.x, boundary.bottomEdge - centre.y),
                                            atan2(boundary.rightEdge - centre.x, boundary.topEdge - centre.y),
                                            atan2(boundary.leftEdge - centre.x, boundary.topEdge - centre.y) ]
            let offset = -cornerAngles[0]
            cornerAngles[0] = 2.0 * .pi
            cornerAngles[1] += offset
            cornerAngles[2] += offset
            cornerAngles[3] += offset
            
            var corner: Int = 0, start: Int = 0
            if !borderIndices[0].point.equalTo(cornerPoints[0]) {
                var element = BorderIndex()
                element.point = cornerPoints[corner]
                borderIndices.insert(element, at: 0)
                corner += 1
                start = 1
            }
            
            var i: Int = start, j: Int = start + 1
            var thetaI: CGFloat , thetaJ: CGFloat
            while ( i < borderIndices.count - 1 ) {
                if j == borderIndices.count {
                    j = 0
                }
                if corner == 4 {
                    break
                }
                thetaI = atan2(borderIndices[i].point.x - centre.x, borderIndices[i].point.y - centre.y) + offset
                if thetaI < 0  {
                    thetaI = cornerAngles[0] + thetaI
                }
                thetaJ = atan2(borderIndices[j].point.x - centre.x, borderIndices[j].point.y - centre.y) + offset
                if thetaJ < 0 {
                    thetaJ = cornerAngles[0] + thetaJ;
                }
                if thetaI > cornerAngles[corner] && thetaJ < cornerAngles[corner] {
                    var element = BorderIndex()
                    element.point = cornerPoints[corner]
                    borderIndices.insert(element, at: j)
                    corner += 1
                    continue
                }
                else if borderIndices[i].point.equalTo(cornerPoints[corner])  {
                    corner += 1
                    continue
                }
                else if ( thetaI < cornerAngles[corner] && thetaJ < cornerAngles[corner] ) {
                    var element = BorderIndex()
                    element.point = cornerPoints[corner]
                    borderIndices.insert(element, at: i)
                    corner += 1
                    continue
                }
                i += 1
                j += 1
            }
            
            // if extra contours involved for a functionPlot, sort the borderIndices array correctly
            var usedExtraLineStripList = false
            for i in 0..<contours.getNoIsoCurves() {
                usedExtraLineStripList = usedExtraLineStripList || usedExtraLineStripLists[i]
            }
            if usedExtraLineStripList {
                borderIndices = borderIndices.sortBorderIndicesWithExtraContours()
                borderIndices = borderIndices.authenticateNextToDuplicatesBorderIndices()
            }
            
            // since border intersection point go around the boundary line anti-clockwise staring in bottom left we need to shift the
            // borderIndices to the right to make sure we see all the complex regions
            // shift borderIndices such that if first and last are the same contour, move first to last
            // till array is split across a complex region
            var theFill: Any?
            var centroids: [Centroid] = []
            var collectedPlanes: [Int] = []
            var startPoint: CGPoint = .zero, endPoint: CGPoint = .zero
            var reverse: Bool = false
            var containsACorner: Bool, consecutiveEdge: Bool
            var borderIndex: Int = 0, initialBorderIndex: Int = 0, nextBorderIndex: Int = NSNotFound
            while ( borderIndex < borderIndices.count ) {
                containsACorner = false
                consecutiveEdge = false
                
                while borderIndices[borderIndex].borderdirection == .none {
                    borderIndex += 1
                    if borderIndex >= borderIndices.count {
                        break // safety break
                    }
                }
                initialBorderIndex = borderIndex
                var dataLinePath: CGMutablePath = CGMutablePath()
                if borderIndex - 1 != NSNotFound && borderIndices[borderIndex - 1].borderdirection == .none && !borderIndices[borderIndex - 1].used {
//                    dataLinePath.move(to: CGPoint(x: (borderIndices[borderIndex - 1].point.x - dataSet.originOfContext.x) * dataSet.scaleOfContext, y:(borderIndices[borderIndex - 1].point.y - dataSet.originOfContext.y) * dataSet.scaleOfContext), transform: transform)
                    dataLinePath.move(to: CGPoint(x: borderIndices[borderIndex - 1].point.x, y: borderIndices[borderIndex - 1].point.y * phaseY))
                    initialBorderIndex = borderIndex - 1
                    borderIndices[borderIndex - 1].used = true
                    containsACorner = true
                }
                else {
//                    dataLinePath.move(to: CGPoint(x: (borderIndices[borderIndex].point.x - dataSet.originOfContext.x) * dataSet.scaleOfContext, y:(borderIndices[borderIndex].point.y - dataSet.originOfContext.y) * dataSet.scaleOfContext), transform: transform)
                    dataLinePath.move(to:CGPoint(x: borderIndices[borderIndex].point.x, y: borderIndices[borderIndex].point.y * phaseY))
                }
#if DEBUG
#if os(OSX)
                let bezierPath = NSBezierPath(cgPath: dataLinePath)
#else
                let bezierPath = UIBezierPath(cgPath: dataLinePath)
                print(bezierPath.bounds)
#endif
#endif
                while ( true ) {
                    let stripIndex = borderIndices[borderIndex].index
                    borderIndices[borderIndex].used = true
                    collectedPlanes.append(borderStrips[stripIndex].plane)
                    let positionsForBorderStripIndex = borderIndices.searchBorderIndicesForBorderStripIndex(borderIndices[borderIndex].index)
                    
                    var workingPath: CGMutablePath?
                    if borderStrips[stripIndex].plane == NSNotFound,
                       let _outerBoundaryLimitsCGPath = outerBoundaryLimitsCGPaths?[borderStrips[stripIndex].index] { // is a discontinuity border already have CGPath
                        if borderStrips[stripIndex].reverse {
#if os(OSX)
                            var discontinuityBezierPath = NSBezierPath(cgPath: _outerBoundaryLimitsCGPath)
                            discontinuityBezierPath = discontinuityBezierPath.reversed
                            workingPath = discontinuityBezierPath.cgPath.mutableCopy() ?? nil
#else
                            var discontinuityBezierPath = UIBezierPath(cgPath: _outerBoundaryLimitsCGPath)
                            discontinuityBezierPath = discontinuityBezierPath.reversing()
                            workingPath = discontinuityBezierPath.cgPath.mutableCopy() ?? nil
#endif
                        }
                        else {
                            workingPath = _outerBoundaryLimitsCGPath.mutableCopy()
                        }
//                        startPoint = CGPoint(x: (borderStrips[stripIndex].startPoint.x - dataSet.originOfContext.x) * dataSet.scaleOfContext, y:  (borderStrips[stripIndex].startPoint.y - dataSet.originOfContext.y) * dataSet.scaleOfContext)
//                        endPoint = CGPoint(x: (borderStrips[stripIndex].endPoint.x - dataSet.originOfContext.x) * dataSet.scaleOfContext, y: (borderStrips[stripIndex].endPoint.y - dataSet.originOfContext.y) * dataSet.scaleOfContext)
                        startPoint = CGPoint(x: borderStrips[stripIndex].startPoint.x, y: borderStrips[stripIndex].startPoint.y * phaseY)
                        endPoint = CGPoint(x: borderStrips[stripIndex].endPoint.x, y: borderStrips[stripIndex].endPoint.y * phaseY)
                    }
                    else {
                        if let strip = borderStrips[stripIndex].stripList?[borderStrips[stripIndex].index] {
                            reverse = false
                            if borderIndices[borderIndex].end {
                                reverse = true
                            }
                            workingPath = createDataLinePath(fromStrip: strip, dataSet: dataSet, startPoint: &startPoint, endPoint: &endPoint, reverseOrder: ((reverse ^^ borderStrips[stripIndex].reverse) ? true : false), closed: false, extraStripList: borderStrips[stripIndex].stripList == contours.getExtraIsoCurvesList(atIsoCurve: borderStrips[stripIndex].plane))
                        }
                    }
                    dataLinePath.addLine(to: startPoint)
                    if let _workingPath = workingPath {
                        dataLinePath.addPath(_workingPath)
#if DEBUG
#if os(OSX)
                        bezierPath.line(to: startPoint)
                        let bezierPath1 = NSBezierPath(cgPath: _workingPath)
                        bezierPath.append(bezierPath1)
#else
                        bezierPath.addLine(to: startPoint)
                        let bezierPath1 = UIBezierPath(cgPath: _workingPath)
                        bezierPath.append(bezierPath1)
#endif
#endif
                    }
                    borderIndex = borderIndex == positionsForBorderStripIndex[0] ? positionsForBorderStripIndex[1] : positionsForBorderStripIndex[0]
                    borderIndices[borderIndex].used = true
                    
                    var pointOnBorder = CGPoint(x: borderIndices[initialBorderIndex].point.x, y: borderIndices[initialBorderIndex].point.y * phaseY)
//                    var pointOnBorder = CGPoint(x: (borderIndices[initialBorderIndex].point.x - dataSet.originOfContext.x) * dataSet.scaleOfContext, y: (borderIndices[initialBorderIndex].point.y - dataSet.originOfContext.y) * dataSet.scaleOfContext);
                    if endPoint.equalTo(pointOnBorder){
                        dataLinePath.addLine(to: pointOnBorder)
                        if borderIndices[initialBorderIndex].index == borderIndices[borderIndex].index {
                            consecutiveEdge = true
                        }
                        break
                    }
                    
                    borderIndex += 1
                    if borderIndex == borderIndices.count {
                        borderIndex = 0
                    }
                    pointOnBorder = CGPoint(x: borderIndices[borderIndex].point.x, y: borderIndices[borderIndex].point.y * phaseY)
//                    pointOnBorder = CGPoint(x: (borderIndices[borderIndex].point.x - dataSet.originOfContext.x) * dataSet.scaleOfContext, y: (borderIndices[borderIndex].point.y - dataSet.originOfContext.y) * dataSet.scaleOfContext)
                    if borderIndex == initialBorderIndex || endPoint.equalTo(pointOnBorder) {
                        dataLinePath.addLine(to: pointOnBorder)
//                        dataLinePath.addLine(to: CGPoint(x: (borderIndices[borderIndex].point.x - dataSet.originOfContext.x) * dataSet.scaleOfContext, y: (borderIndices[borderIndex].point.y - dataSet.originOfContext.y) * dataSet.scaleOfContext))
                        if borderIndices[initialBorderIndex].index == borderIndices[borderIndex].index {
                            consecutiveEdge = true
                        }
                        break
                    }
                    
                    if endPoint.equalTo(pointOnBorder) {
                        if nextBorderIndex != NSNotFound {
                            borderIndex = nextBorderIndex
                        }
                        else {
                            borderIndex += 1
                            if borderIndex == borderIndices.count {
                                borderIndex = 0
                            }
                            if endPoint.equalTo(pointOnBorder) {
                                borderIndex = initialBorderIndex
                            }
                        }
                    }
                    
                    if borderIndex == initialBorderIndex && borderIndices[borderIndex].borderdirection == .none  {
                        dataLinePath.addLine(to: CGPoint(x: borderIndices[borderIndex].point.x, y: borderIndices[borderIndex].point.y * phaseY))
//                        dataLinePath.addLine(to: CGPoint(x: (borderIndices[borderIndex].point.x - dataSet.originOfContext.x) * dataSet.scaleOfContext, y: (borderIndices[borderIndex].point.y - dataSet.originOfContext.y) * dataSet.scaleOfContext))
                        break
                    }
                    
                    while( borderIndices[borderIndex].borderdirection == .none ) {
                        dataLinePath.addLine(to: CGPoint(x: borderIndices[borderIndex].point.x, y: borderIndices[borderIndex].point.y * phaseY))
//                        dataLinePath.addLine(to: CGPoint(x: (borderIndices[borderIndex].point.x - dataSet.originOfContext.x) * dataSet.scaleOfContext, y: (borderIndices[borderIndex].point.y - dataSet.originOfContext.y) * dataSet.scaleOfContext), transform: transform)
                        borderIndex += 1
                        if borderIndex == borderIndices.count {
                            borderIndex = 0
                        }
                        if borderIndex == initialBorderIndex {
                            break // safety break
                        }
                    }
                    
                    if borderIndex == initialBorderIndex  {
                        dataLinePath.addLine(to: CGPoint(x: borderIndices[borderIndex].point.x, y: borderIndices[borderIndex].point.y * phaseY))
//                        dataLinePath.addLine(to: CGPoint(x: (borderIndices[borderIndex].point.x - dataSet.originOfContext.x) * dataSet.scaleOfContext, y: (borderIndices[borderIndex].point.y - dataSet.originOfContext.y) * dataSet.scaleOfContext), transform: transform)
                        break
                    }
                }
                if collectedPlanes.count == 0 || (collectedPlanes.count == 1 && !(containsACorner || consecutiveEdge))  {
                    collectedPlanes.removeAll()
                    borderIndex = initialBorderIndex + 1
                    continue
                }
                
                dataLinePath = dataLinePath.stripCGPathOfExtraMoveTos() ?? dataLinePath
                
#if DEBUG
#if os(OSX)
                let bezierPath2 = NSBezierPath(cgPath: dataLinePath)
#else
                let bezierPath2 = UIBezierPath(cgPath: dataLinePath )
#endif
#endif
                centroids = centroids.sort()
                let centroid = Centroid(noVertices: dataLinePath.noVertices, centre: dataLinePath.centre, boundingBox: dataLinePath.boundingBox)
                if let index = centroids.search(centroid),
                   centroids[index].boundingBox.toleranceCGRectEqualToRect(centroid.boundingBox) {
                    collectedPlanes.removeAll()
                }
                else {
                    centroids.append(centroid)
                    context.saveGState()
                    context.addPath(dataLinePath)
                    
                    var closedDataLinePaths: [CGMutablePath] = []
                    var closedPlanes: [Int] = []
                    let noFoundClosedDataLinePaths = findClosedDataLinePaths(&closedDataLinePaths, foundClosedPlanes: &closedPlanes, outerCGPath: dataLinePath, context:context, dataSet: dataSet, boundary: boundary, useExtraLineStripList: true, checkPointOnPath: false)
                    
                    var areaOfDataLinePath: CGFloat = 0
                    if noFoundClosedDataLinePaths > 0 {
                        areaOfDataLinePath = abs(dataLinePath.area)
                        for l in 0..<noFoundClosedDataLinePaths {
                            if dataLinePath.contains(closedDataLinePaths[l].currentPoint) {
                                context.addPath(closedDataLinePaths[l])
#if DEBUG
#if os(OSX)
                                let bezierPath6 = NSBezierPath(cgPath: closedDataLinePaths[l])
                                bezierPath2.append(bezierPath6)
#else
                                let bezierPath6 = UIBezierPath(cgPath: closedDataLinePaths[l])
                                bezierPath2.append(bezierPath6)
#endif
#endif
                                // if area of closed contour is tiny compare to main contour don't use it for fill colour
                                if abs(closedDataLinePaths[l].area) > 0.1 * areaOfDataLinePath {
                                    collectedPlanes.append(l)
                                }
                            }
                        }
                    }
                    closedPlanes.removeAll()
                    closedDataLinePaths.removeAll()
                    collectedPlanes = collectedPlanes.unique() // rid duplicates collectedPlanes
                    
                    // Fill colours will be made from combining or not the elevation levels of contours surrunding a fill region
                    // the elevation levels colours are stored in the isoCurvesLineStyles array.
                    // actualPlane is the real plane index in the isoCurvesIndices array
                    if collectedPlanes.count == 1 {
                        theFill = calculateFill(dataLinePath, combinedPath: nil, collectedPlanes: collectedPlanes, dataSet: dataSet)
                    }
                    else {
                        //                theFill = [self calculateFill:dataLinePath combinedPath:bezierPath.CGPath collectedPlanes:collectedPlanes];
                        theFill = findFillFromBoundingPlanes(collectedPlanes, dataSet: dataSet)
                    }
                    
                    collectedPlanes.removeAll()
                    
                    //            if ( outerBoundaryLimitsCGPaths != NULL ) {
                    //#if DEBUG
                    //    #if os(OSX)
                    //                NSBezierPath * bezierPath3 = [NSBezierPath bezierPathWithCGPath:dataLinePath];
                    //    #else
                    //                UIBezierPath * bezierPath3 = [UIBezierPath bezierPathWithCGPath:dataLinePath];
                    //    #endif
                    //#endif
                    //                for( NSUInteger k = 0; k < noOuterBoundaryLimitsCGPaths; k++ ) {
                    //                    if ( !CGPathIsEmpty(outerBoundaryLimitsCGPaths[k]) ) {
                    //#if DEBUG
                    //    #if os(OSX)
                    //                            [bezierPath3 appendBezierPath:[NSBezierPath bezierPathWithCGPath:outerBoundaryLimitsCGPaths[k]]];
                    //    #else
                    //                             [bezierPath3 appendPath:[UIBezierPath bezierPathWithCGPath:outerBoundaryLimitsCGPaths[k]]];
                    //    #endif
                    //#endif
                    //                        CGPoint last = CGPathGetCurrentPoint(outerBoundaryLimitsCGPaths[k]);
                    //                        if ( CGPathContainsPoint(dataLinePath, &transform, last, YES) || CGPathIntersectsPathWithOther(outerBoundaryLimitsCGPaths[k], dataLinePath) ) {
                    //                            CGContextAddPath(context, outerBoundaryLimitsCGPaths[k]);
                    //                            theFill = nil;
                    //                        }
                    //                    }
                    //                }
                    //            }
                    
                    if theFill is ColorFill,
                       let _theFill = theFill as? ColorFill {
                        _theFill.fillPath(context: context, rect: .zero)
                    }
                    else if theFill is ImageFill,
                        let _theFill = theFill as? ImageFill {
                        _theFill.fillPath(context: context, rect: .zero)
                    }
#if DEBUG
                    if let imgRef = context.makeImage() {
#if os(OSX)
                        let img = NSImage(cgImage: imgRef, size: .zero)
                        let flippedImage = NSImage(size: img.size, flipped: true, drawingHandler: { dstrect in
                            img.draw(in: dstrect)
                            return true
                        })
                        print(flippedImage.size)
#else
                        let image = UIImage(cgImage: imgRef)
                        let size = image.size
                        UIGraphicsBeginImageContext(CGSize(width: size.width, height: size.height))
                        UIImage(cgImage: imgRef, scale: 1.0, orientation: .downMirrored).draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                        if let flippedImage = UIGraphicsGetImageFromCurrentImageContext() {
                            print(flippedImage.size)
                        }
                        UIGraphicsEndImageContext()
#endif
                    }
#endif
                    context.restoreGState()
                }
                borderIndex = initialBorderIndex
                while ( borderIndices[borderIndex].borderdirection == .none ) {
                    borderIndex += 1
                    if borderIndex >= borderIndices.count {
                        break // safety break
                    }
                }
                
                if borderIndices[borderIndex].point.equalTo(borderIndices[borderIndex + 1 == borderIndices.count ? 0 : borderIndex + 1].point) {
                    let positionsForBorderStripIndex = borderIndices.searchBorderIndicesForBorderStripIndex(borderIndices[borderIndex + 1 == borderIndices.count ? 0 : borderIndex + 1].index)
                    nextBorderIndex = (borderIndex + 1) == positionsForBorderStripIndex[0] ? positionsForBorderStripIndex[1] : positionsForBorderStripIndex[0]
                    if nextBorderIndex == borderIndices.count {
                        nextBorderIndex = 0
                    }
                    borderIndex += 2
                }
                else {
                    if nextBorderIndex == NSNotFound {
                        borderIndex += 1
                    }
                    nextBorderIndex = NSNotFound
                }
            }
            centroids.removeAll()
        }
    }

    
    private func addCorners(toDataLinePath dataLineBorderPath: inout CGMutablePath, startBorderdirection: ContourBorderDimensionDirection, endBorderdirection: ContourBorderDimensionDirection, boundary: Boundary, mirror: Bool) -> Void {
        let cornerRectPoints: [CGPoint] =  [ CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge), CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge), CGPoint(x: boundary.rightEdge, y: boundary.topEdge), CGPoint(x: boundary.leftEdge, y: boundary.topEdge) ]
        let transform: CGAffineTransform = .identity
        switch startBorderdirection  {
            case .xForward:
                if endBorderdirection == .yForward {
                    dataLineBorderPath.addLine(to: cornerRectPoints[1], transform:  transform)
                }
                else if endBorderdirection == .yBackward {
                    dataLineBorderPath.addLine(to: cornerRectPoints[0], transform:  transform)
                }
                else if endBorderdirection == .xBackward {
                    if mirror {
                        dataLineBorderPath.addLine(to: cornerRectPoints[1], transform:  transform)
                        dataLineBorderPath.addLine(to: cornerRectPoints[2], transform:  transform)
                    }
                    else {
                        dataLineBorderPath.addLine(to: cornerRectPoints[0], transform:  transform)
                        dataLineBorderPath.addLine(to: cornerRectPoints[1], transform:  transform)
                    }
                }
                
            case .yForward:
                if endBorderdirection == .xBackward {
                    dataLineBorderPath.addLine(to: cornerRectPoints[2], transform:  transform)
                }
                else if endBorderdirection == .xForward {
                    dataLineBorderPath.addLine(to: cornerRectPoints[1], transform:  transform)
                }
                else if endBorderdirection == .yBackward {
                    if mirror {
                        dataLineBorderPath.addLine(to: cornerRectPoints[2], transform:  transform)
                        dataLineBorderPath.addLine(to: cornerRectPoints[3], transform:  transform)
                    }
                    else {
                        dataLineBorderPath.addLine(to: cornerRectPoints[1], transform:  transform)
                        dataLineBorderPath.addLine(to: cornerRectPoints[2], transform:  transform)
                    }
                }
                    
            case .xBackward:
                if endBorderdirection == .yBackward {
                    dataLineBorderPath.addLine(to: cornerRectPoints[3], transform:  transform)
                }
                else if endBorderdirection == .yForward {
                    dataLineBorderPath.addLine(to: cornerRectPoints[2], transform:  transform)
                }
                else if endBorderdirection == .xForward {
                    if ( mirror ) {
                        dataLineBorderPath.addLine(to: cornerRectPoints[0], transform:  transform)
                        dataLineBorderPath.addLine(to: cornerRectPoints[1], transform:  transform)
                    }
                    else {
                        dataLineBorderPath.addLine(to: cornerRectPoints[3], transform:  transform)
                        dataLineBorderPath.addLine(to: cornerRectPoints[0], transform:  transform)
                    }
                }
                    
            case .yBackward:
                if endBorderdirection == .xForward {
                    dataLineBorderPath.addLine(to: cornerRectPoints[0], transform:  transform)
                }
                else if endBorderdirection == .xBackward {
                    dataLineBorderPath.addLine(to: cornerRectPoints[3], transform:  transform)
                }
                else if endBorderdirection == .yForward {
                    if ( mirror ) {
                        dataLineBorderPath.addLine(to: cornerRectPoints[1], transform:  transform)
                        dataLineBorderPath.addLine(to: cornerRectPoints[2], transform:  transform)
                    }
                    else {
                        dataLineBorderPath.addLine(to: cornerRectPoints[0], transform:  transform)
                        dataLineBorderPath.addLine(to: cornerRectPoints[1], transform:  transform)
                    }
                }
                    
            case .none:
                break
        }
    }
               
    
    // MARK: - Searches & Tests
    
    private func calculateFill(_ refDataLinePath: CGPath, combinedPath: CGPath?, collectedPlanes: [Int], dataSet: ContourChartDataSetProtocol) -> Any? {
        var theFill: Any?
        if let dataProvider = self.dataProvider,
            let _fieldBlock = dataSet.fieldBlock,
           let _isoCurvesValues = dataSet.isoCurvesValues {
            
            let trans = dataProvider.getTransformer(forAxis: .left)
            let pixelToValueMatrix = trans.pixelToValueMatrix
#if DEBUG
#if os(OSX)
            let bezierPath = NSBezierPath(cgPath: refDataLinePath)
#else
            let bezierPath = UIBezierPath(cgPath: refDataLinePath)
#endif
#endif
            var ptInside: CGPoint
            if let _combinedPath = combinedPath,
               !_combinedPath.isEmpty {
                ptInside = refDataLinePath.pointBetweenOuterInnerCGPaths(_combinedPath)
#if DEBUG
#if os(OSX)
                bezierPath.append(NSBezierPath(cgPath: _combinedPath))
#else
                bezierPath.append(UIBezierPath(cgPath: _combinedPath))
#endif
#endif
            }
            else {
                ptInside = refDataLinePath.pointBetweenOuterInnerCGPaths(refDataLinePath)
            }
            ptInside = ptInside.applying(pixelToValueMatrix)
            
            let averageX = ptInside.x
            let averageY = ptInside.y
            let fieldValue = _fieldBlock(Double(averageX), Double(averageY))
            //    int value = (int)(fieldValue * 100);
            //    fieldValue = (double)value / 100;
            if fieldValue.isNaN {
                return EmptyFill()
            }
            
            let filling = ContourFill()
            
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var strongAlpha = false
            if collectedPlanes.count == 1 {
                strongAlpha = true
                var fillIndex1: Int, fillIndex2: Int = NSNotFound
                if fieldValue < _isoCurvesValues[0] {
                    fillIndex1 = 0
                    filling.first = _isoCurvesValues[fillIndex1]
                }
                else if fieldValue > _isoCurvesValues[_isoCurvesValues.count - 1]  {
                    fillIndex1 = _isoCurvesValues.count - 1;
                    filling.second = _isoCurvesValues[_isoCurvesValues.count - 1]
                }
                else {
                    fillIndex1 = 0
                    for i in 1..<_isoCurvesValues.count {
                        if fieldValue > _isoCurvesValues[i - 1] && fieldValue <= _isoCurvesValues[i] {
                            fillIndex1 = i
                            break
                        }
                    }
                    filling.first = _isoCurvesValues[fillIndex1]
                }
                if let _isoCurvesFills = dataSet.isoCurvesColourFills {
                    theFill = _isoCurvesFills[fillIndex1]
                }
                else if let _isoCurvesFills = dataSet.isoCurvesImageFills {
                    theFill = _isoCurvesFills[fillIndex1]
                }
                else  {
                    var colour: NSUIColor = .clear
                    if fillIndex2 == NSNotFound {
                        let _colour = dataSet.isoCurvesLineColours?[fillIndex1] ?? NSUIColor()
                        _colour.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                        if strongAlpha {
                            colour = _colour.withAlphaComponent(a1 * 0.75)
                        }
                        else {
                            colour = _colour.withAlphaComponent(a1 * 0.5)
                        }
                    }
                    //            else {
                    //                CPTLineStyle *lineStyle1 = [self.isoCurvesLineStyles objectAtIndex: fillIndex1];
                    //                CPTLineStyle *lineStyle2 = [self.isoCurvesLineStyles objectAtIndex: fillIndex2];
                    //                UIColor *colour1 = [[lineStyle1 lineColor] uiColor];
                    //                UIColor *colour2 = [[lineStyle2 lineColor] uiColor];
                    //                CGFloat r2, g2, b2, a2;
                    //                [colour1 getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
                    //                [colour2 getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
                    //                CGFloat red     = (r2 + r1) / 2;
                    //                CGFloat green   = (g2 + g1) / 2;
                    //                CGFloat blue    = (b2 + b1) / 2;
                    //                CGFloat alpha   = (a2 + a1) / 4;
                    //                colour = [CPTColor colorWithComponentRed:red green:green blue:blue alpha:alpha];
                    //            }
                    theFill = ColorFill(color: colour)
                }
                filling.fill = theFill
            }
            else if fieldValue < _isoCurvesValues[0] {
                if let _isoCurvesFills = dataSet.isoCurvesColourFills {
                    theFill = _isoCurvesFills[0]
                }
                else if let _isoCurvesFills = dataSet.isoCurvesImageFills {
                    theFill = _isoCurvesFills[0]
                }
                else {
                    var colour = dataSet.isoCurvesLineColours?[0] ?? NSUIColor()
                    colour.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                    colour = colour.withAlphaComponent(a1 * 0.75)
                    theFill = ColorFill(color: colour)
                }
                filling.fill = theFill
                filling.first = _isoCurvesValues[0]
            }
            else if fieldValue > _isoCurvesValues[_isoCurvesValues.count - 1] {
                if let _isoCurvesFills = dataSet.isoCurvesColourFills{
                    theFill = _isoCurvesFills[_isoCurvesFills.count - 1]
                }
                else if let _isoCurvesFills = dataSet.isoCurvesImageFills {
                    theFill = _isoCurvesFills[_isoCurvesFills.count - 1]
                }
                else {
                    var colour = dataSet.isoCurvesLineColours?.last ?? NSUIColor()
                    colour.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                    colour = colour.withAlphaComponent(a1 * 0.75)
                    theFill = ColorFill(color: colour)
                }
                filling.fill = theFill
                filling.second = _isoCurvesValues[_isoCurvesValues.count - 1]
            }
            else {
                var fillIndex: Int = 0
                for i in 1..<_isoCurvesValues.count {
                    if  fieldValue > _isoCurvesValues[i - 1] && fieldValue <= _isoCurvesValues[i] {
                        fillIndex = i
                        break
                    }
                }
                if let _isoCurvesFills = dataSet.isoCurvesColourFills {
                    theFill = _isoCurvesFills[fillIndex]
                }
                else if let _isoCurvesFills = dataSet.isoCurvesImageFills {
                    theFill = _isoCurvesFills[fillIndex]
                }
                else {
                    let colour1 = dataSet.isoCurvesLineColours?[fillIndex - 1] ?? NSUIColor()
                    let colour2 = dataSet.isoCurvesLineColours?[fillIndex] ?? NSUIColor()
                    
                    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
                    colour1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                    colour2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
                    //            CGFloat alpha2 = MIN( 1.0, MAX( 0.0, a2 ) );
                    //            CGFloat beta = 1.0 - alpha2;
                    //            CGFloat red     = r1 * beta + r2 * alpha2;
                    //            CGFloat green   = g1 * beta + g2 * alpha2;
                    //            CGFloat blue    = b1 * beta + b2 * alpha2;
                    //            CGFloat alpha   = a1 * beta + a2 * alpha2;
                    //            CGFloat alpha1 = MIN( 1.0, MAX( 0.0, a1 ) );
                    //            CGFloat beta = 1.0 - alpha1;
                    //            CGFloat red     = r2 * beta + r1 * alpha1;
                    //            CGFloat green   = g2 * beta + g1 * alpha1;
                    //            CGFloat blue    = b2 * beta + b1 * alpha1;
                    //            CGFloat alpha   = a2 * beta + a1 * alpha1;
                    
                    let red     = (r2 + r1) / 2
                    let green   = (g2 + g1) / 2
                    let blue    = (b2 + b1) / 2
                    let alpha   = (a2 + a1) / 4
                    let colour = NSUIColor(red: red, green: green, blue: blue, alpha: alpha)
                    theFill = ColorFill(color: colour)
                }
                filling.fill = theFill
                filling.first = _isoCurvesValues[fillIndex - 1]
                filling.second = _isoCurvesValues[fillIndex]
            }
            appendFillingIfNotUsedPreviously(filling, dataSet: dataSet)
        }
        return theFill
    }
    
    private func findFillFromBoundingPlanes(_ collectedPlanes: [Int], dataSet: ContourChartDataSetProtocol) -> Any? {

        var theFill: Any?
        if let _isoCurvesValues = dataSet.isoCurvesValues {
            let filling = ContourFill()
            
            var fillIndex1: Int = collectedPlanes[0], fillIndex2: Int = NSNotFound
            if fillIndex1 == 0 && _isoCurvesValues[0] == 10.0 * _isoCurvesValues[1] {
                let colour = NSUIColor.clear
                return ColorFill(color: colour)
            }
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var noCollectedPlanes = collectedPlanes.count
            if noCollectedPlanes > 1 && fillIndex1 == NSNotFound  {
                fillIndex1 = collectedPlanes[1]
                noCollectedPlanes = 1
            }
            else if noCollectedPlanes > 1 && collectedPlanes[1] == NSNotFound {
                fillIndex1 = collectedPlanes[0]
                noCollectedPlanes = 1
            }
            
            if noCollectedPlanes == 1 {
                if let _isoCurvesFills = dataSet.isoCurvesColourFills {
                    theFill = _isoCurvesFills[fillIndex1]
                }
                else if let _isoCurvesFills = dataSet.isoCurvesImageFills {
                    theFill = _isoCurvesFills[fillIndex1]
                }
                else {
                    var colour = dataSet.isoCurvesLineColours?.last ?? NSUIColor()
                    colour.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                    colour = colour.withAlphaComponent(a1 * 0.75)
                    theFill = ColorFill(color: colour)
                }
                filling.fill = theFill
                filling.first = _isoCurvesValues[0]
            }
            else {
                fillIndex2 = collectedPlanes[1]
                if let _isoCurvesFills = dataSet.isoCurvesColourFills {
                    theFill = _isoCurvesFills[fillIndex1]
                }
                else if let _isoCurvesFills = dataSet.isoCurvesImageFills {
                    theFill = _isoCurvesFills[fillIndex1]
                }
                else {
                    let colour1 = dataSet.isoCurvesLineColours?[fillIndex2 - 1] ?? NSUIColor()
                    let colour2 = dataSet.isoCurvesLineColours?[fillIndex2] ?? NSUIColor()
                    
                    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
                    colour1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                    colour2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
                    
                    let red     = (r2 + r1) / 2
                    let green   = (g2 + g1) / 2
                    let blue    = (b2 + b1) / 2
                    let alpha   = (a2 + a1) / 4
                    let colour = NSUIColor(red: red, green: green, blue: blue, alpha: alpha)
                    theFill = ColorFill(color: colour)
                }
                
                filling.fill = theFill
                filling.first = _isoCurvesValues[fillIndex1]
                filling.second = _isoCurvesValues[fillIndex2]
            }
            appendFillingIfNotUsedPreviously(filling, dataSet: dataSet)
        }
        
        return theFill
    }
    
    private func appendFillingIfNotUsedPreviously(_ filling: ContourFill, dataSet: ContourChartDataSetProtocol) {
        
        if let _isoCurvesFillings = dataSet.isoCurvesFillings {
            if filling.fill is ColorFill,
               let fill = filling.fill as? ColorFill {
                if let components: [CGFloat] = fill.color.components {
                    let noComponents = fill.color.numberOfComponents
                    if _isoCurvesFillings.firstIndex(where: { testFilling in
                        
                        if let testFill = testFilling.fill as? ColorFill,
                           let componentsObj: [CGFloat] = testFill.color.components {
                            let noComponentsObj = testFill.color.numberOfComponents
                            if noComponents == 2 && noComponentsObj == 2 {
                                return componentsObj[0] == components[0] && componentsObj[1] == components[1] && ((testFilling.first ==  filling.first && testFilling.second == filling.second) || (testFilling.first == filling.second && testFilling.second == filling.first))
                            }
                            else if noComponents == 2 && noComponentsObj == 4 {
                                return componentsObj[0] == components[0] && componentsObj[1] == components[0] && componentsObj[2] == components[0] && componentsObj[3] == components[1] && ((testFilling.first == filling.first && testFilling.second  == filling.second) || (testFilling.first == filling.second && testFilling.second ==  filling.first))
                            }
                            else if noComponents == 4 && noComponentsObj == 2 {
                                return componentsObj[0] == components[0] && componentsObj[0] == components[1] && componentsObj[0] == components[2] && componentsObj[1] == components[3] && ((testFilling.first == filling.first && testFilling.second == filling.second) || (testFilling.first == filling.second && testFilling.second == filling.first))
                            }
                            else {
                                return componentsObj[0] == components[0] && componentsObj[1] == components[1] && componentsObj[2] == components[2] && componentsObj[3] == components[3] && ((testFilling.first == filling.first && testFilling.second == filling.second) || (testFilling.first == filling.second && testFilling.second == filling.first))
                            }
                        }
                        else {
                            return false
                        }
                    }) == NSNotFound {
                        dataSet.isoCurvesFillings?.append(filling)
                    }
                }
            }
            else if filling.fill is ImageFill {
                
            }
        }
    }

    private func findFillIndex(_ actualPlane: Int, dataSet: ContourChartDataSetProtocol) -> Int {
        var index = NSNotFound
        if let _index = dataSet.isoCurvesIndices.firstIndex(where: { $0 == actualPlane }) {
            index = _index
        }
        return index
    }

    private func findIsoCurveIndicesIndex(_ actualPlane: Int, dataSet: ContourChartDataSetProtocol) -> Int {
        var index = NSNotFound
        if let _index = dataSet.isoCurvesIndices.firstIndex(where: { $0 == actualPlane }) {
            index = _index
        }
        return index
    }

    private func findNextBorderStrip(from borderStrips:[Strip], direction: ContourBorderDimensionDirection, point: CGPoint, startIndex: Int, boundary: Boundary) -> Int {
        var  prevPoint: CGPoint, nextPoint: CGPoint
        var i: Int = startIndex
        for _ in 0..<borderStrips.count {
            if borderStrips[i].endBorderdirection == direction || borderStrips[i].startBorderdirection == direction {
                prevPoint = borderStrips[i].endPoint
                nextPoint = borderStrips[i + 1 > borderStrips.count - 1 ? 0 : i + 1].startPoint
                if ( direction == .xForward && point.y == boundary.bottomEdge && point.x >= prevPoint.x && point.x <= nextPoint.x && nextPoint.y == boundary.bottomEdge ) {
                    break
                }
                else if( direction == .yForward && point.x == boundary.rightEdge && point.y >= prevPoint.y && point.y <= nextPoint.y && nextPoint.x == boundary.rightEdge ) {
                    break
                }
                else if ( direction == .xBackward && point.y == boundary.topEdge && point.x <= prevPoint.x && point.x >= nextPoint.x && nextPoint.y == boundary.topEdge ) {
                    break
                }
                else if ( direction == .yBackward && point.x == boundary.leftEdge && point.y <= prevPoint.y && point.y >= nextPoint.y && nextPoint.x == boundary.leftEdge ) {
                    break
                }
            }
            i += 1
            if i > borderStrips.count {
                i = 0
            }
        }
        if i >= borderStrips.count {
            return NSNotFound
        }
        return i
    }
    
    private func collectStripsForBorders(context: CGContext, dataSet: ContourChartDataSetProtocol, usedExtraLineStripLists: inout [Bool] , boundary: Boundary) -> [[Strip]] {
        /* since contours are grouped by their isocurve value within a defined rectangle, one needs to search for the inner
         contour for the current contour in order to enable filling.
         Start in bottom left hand corner and move around perimeter of rectangle till getting back to bottm left */
        var edgeStrips: [[Strip]] = Array(repeating: [], count: 4)
        // will have to iterate through descending / ascending iso curves to see if any curves inside outer curve, as inner curve may not have an iso curve inside outer
        // move along bottom edge, then up right edge, back along top edge and finally back down left edge to start
        // looking of boundary intersection point in each isoCurve plane group of points and storing the index for later
        //CGPoint previousEndPoint = CGPointMake(-0.0, -0.0);
        for iPlane in 0..<dataSet.isoCurvesIndices.count {
            // actualPlane is the real plane index in the isoCurvesIndices array
            let actualPlane = dataSet.isoCurvesIndices[iPlane]
            usedExtraLineStripLists[actualPlane] = false
            if dataSet.functionPlot {
                if checkForIntersectingContoursAndCreateNewBorderContours(context: context, dataSet: dataSet, plane: actualPlane) > 0 /*|| [self checkForMirroredContoursAndCreateNewBorderContours:context contours:contours plane:actualPlane] > 0*/ {
                    let _edgeStrips = searchPlaneBorderIsoCurves(context: context, dataSet: dataSet, plane: actualPlane, useExtraLineStripList: true, boundary: boundary)
                    for i in 0..<4 {
                        edgeStrips[i].append(contentsOf: _edgeStrips[i])
                    }
                    usedExtraLineStripLists[actualPlane] = true
                }
                else { // if no extra LineStripList detected
                    let _edgeStrips = searchPlaneBorderIsoCurves(context: context, dataSet: dataSet, plane: actualPlane, useExtraLineStripList: false, boundary: boundary)
                    for i in 0..<4 {
                        edgeStrips[i].append(contentsOf: _edgeStrips[i])
                    }
                }
            }
            else {
                let _edgeStrips = searchPlaneBorderIsoCurves(context: context, dataSet: dataSet, plane: actualPlane, useExtraLineStripList: false, boundary: boundary)
                for i in 0..<4 {
                    edgeStrips[i].append(contentsOf: _edgeStrips[i])
                }
            }
        }
        return edgeStrips
    }

    private func collectBorderDiscontinuityStrips(discontinuityStrips: [Strip], boundary: Boundary) -> [[Strip]] {
    
        var borderStrips: [[Strip]] =  Array(repeating: [], count: 4)
    
        for i in 0..<discontinuityStrips.count {
        // check that end and start positions are not the same, then if they are on the boundary
        var strip = discontinuityStrips[i]
        if !strip.startPoint.equalTo(strip.endPoint) {
            // from indexs get physical point in plot space
            // depending on the start edge of contour update the borderStrip.startBorderdirection
            var foundBorder: Bool = false
            var tempPoint: CGPoint = .zero
            for border in ContourBorderDimensionDirection.allCases {
                switch(border) {
                    case .xForward:
                    if (strip.startPoint.y == boundary.bottomEdge || (strip.startPoint.y == boundary.topEdge && strip.endPoint.y == boundary.bottomEdge)) && strip.startPoint.x > boundary.leftEdge && strip.startPoint.x <= boundary.rightEdge {
                        if strip.endBorderdirection == .xForward {
                                if strip.endPoint.x < strip.startPoint.x {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                            borderStrips[0].append(strip)
                            }
                        else if ( strip.endBorderdirection == .yForward || strip.endBorderdirection == .xBackward ) {
                                if ( strip.endPoint.y == boundary.bottomEdge ) {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                            borderStrips[0].append(strip)
                            }
                        else if strip.startBorderdirection == .yBackward {//make it YBackward edge border
                                tempPoint = strip.startPoint
                                strip.startPoint = strip.endPoint
                                strip.endPoint = tempPoint
                                strip.startBorderdirection = .yBackward
                                strip.endBorderdirection = .xForward
                                strip.reverse = true
                                borderStrips[3].append(strip)
                            }
                            foundBorder = true
                        }
                    
                case .yForward:
                        if (strip.startPoint.x == boundary.rightEdge || (strip.startPoint.x == boundary.leftEdge && strip.endPoint.x == boundary.rightEdge)) && strip.startPoint.y > boundary.bottomEdge && strip.startPoint.y <= boundary.topEdge {
                            if strip.endBorderdirection == .yForward {
                                if strip.endPoint.y < strip.startPoint.y {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                                borderStrips[1].append(strip)
                            }
                            else if strip.endBorderdirection == .xBackward || strip.endBorderdirection == .yBackward {
                                if strip.endPoint.x == boundary.rightEdge {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                                borderStrips[1].append(strip)
                            }
                            else {
                                tempPoint = strip.startPoint
                                strip.startPoint = strip.endPoint
                                strip.endPoint = tempPoint
                                strip.startBorderdirection = .xForward
                                strip.endBorderdirection = .yForward
                                strip.reverse = true
                                borderStrips[0].append(strip)
                            }
                            foundBorder = true
                        }
                case .xBackward:
                        if strip.startPoint.y == boundary.topEdge && strip.startPoint.x < boundary.rightEdge && strip.startPoint.x >= boundary.leftEdge {
                            if strip.endBorderdirection == .xBackward {
                                if strip.endPoint.x > strip.startPoint.x {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                                borderStrips[2].append(strip)
                            }
                            else if strip.endBorderdirection == .yBackward {
                                if strip.endPoint.y == boundary.topEdge {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                                borderStrips[2].append(strip)
                            }
                            else if strip.endBorderdirection == .xForward {
                                if strip.endPoint.y == boundary.bottomEdge {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                                strip.startBorderdirection = .xForward
                                strip.endBorderdirection = .xBackward
                                borderStrips[0].append(strip)
                            }
                            else if strip.endBorderdirection == .yForward {
                                if strip.endPoint.x == boundary.rightEdge {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                                strip.startBorderdirection = .yForward
                                strip.endBorderdirection = .xBackward
                                borderStrips[1].append(strip)
                            }
                            foundBorder = true
                        }
                
                case .yBackward:
                        if strip.startPoint.x == boundary.leftEdge && strip.startPoint.y < boundary.topEdge && strip.startPoint.y >= boundary.bottomEdge {
                            if strip.endBorderdirection == .yBackward  {
                                if strip.endPoint.y > strip.startPoint.y {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                                borderStrips[3].append(strip)
                            }
                            else if strip.endBorderdirection == .xForward {
                                if strip.endPoint.x == boundary.leftEdge {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                                borderStrips[3].append(strip)
                            }
                            else if strip.endBorderdirection == .yForward {
                                if strip.endPoint.x == boundary.rightEdge {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                                strip.startBorderdirection = .yForward
                                strip.endBorderdirection = .xBackward
                                borderStrips[1].append(strip)
                            }
                            else if strip.endBorderdirection == .xBackward {
                                if strip.startPoint.x == boundary.leftEdge {
                                    tempPoint = strip.startPoint
                                    strip.startPoint = strip.endPoint
                                    strip.endPoint = tempPoint
                                    strip.reverse = true
                                }
                                strip.startBorderdirection = .xBackward
                                strip.endBorderdirection = .yBackward
                                borderStrips[2].append(strip)
                            }
                            foundBorder = true
                        }
                    case .none:
                        break
                    
                }
                if foundBorder {
                    break
                }
            }
        }
    }
    
        return borderStrips
    }


    private func joinBorderStripsToCreateClosedStrips(_ borderStrips: inout [Strip], borderIndices: inout [BorderIndex], usedExtraLineStripLists: inout [Bool], context: CGContext, dataSet: ContourChartDataSetProtocol, boundary: Boundary) -> Void {
        if let contours = dataSet.contours {
            var borderIndex: Int = 0
            for plane in 0..<dataSet.isoCurvesIndices.count {
                let actualPlane = dataSet.isoCurvesIndices[plane]
                let indices: [Int] = borderStrips.searchForStripIndicesForPlane(plane: actualPlane)
                if indices.count > 0 {
                    var planeStrips: [Strip] = Array(repeating: Strip(), count: indices.count)
                    var planeBorderIndices: [BorderIndex] = Array(repeating: BorderIndex(), count: 2 * indices.count)
                    var vertices: [CGPoint] = Array(repeating: .zero, count: 2 * indices.count)
                    
                    for i in 0..<indices.count {
                        borderStrips[indices[i]].usedInExtra = true
                        planeStrips[i] = borderStrips[indices[i]]
                        var element1 = BorderIndex()
                        element1.point = borderStrips[indices[i]].startPoint
                        element1.index = indices[i]
                        planeBorderIndices[i * 2] = element1
                        var element2 = BorderIndex()
                        element2.point =  borderStrips[indices[i]].endPoint
                        element2.index = indices[i]
                        planeBorderIndices[i * 2 + 1] = element2
                        vertices[i * 2] = borderStrips[indices[i]].startPoint
                        vertices[i * 2 + 1] = borderStrips[indices[i]].endPoint
                    }
                    let centre = vertices.findCentroidOfShape()
                    for i in 0..<indices.count * 2 {
                        planeBorderIndices[i].angle = atan2(vertices[i].x - centre.x, vertices[i].y - centre.y)
                    }
                    planeBorderIndices = planeBorderIndices.sortBorderIndicesByAngle()
                    
                    if planeBorderIndices[0].index != planeBorderIndices[1].index { // start on BorderIndex with the same BorderStrip
                        planeBorderIndices.append(planeBorderIndices[0])
                        planeBorderIndices.remove(at: 0)
                    }
                    
                    var combinedLineStrip: LineStrip = []
                    borderIndex = 0
                    while ( borderIndex < planeBorderIndices.count ) {
                        let index = planeBorderIndices[borderIndex].index
                        if let strip = borderStrips[index].stripList?[borderStrips[index].index] {
                            var reverse = false
                            if !borderStrips[index].startPoint.equalTo(planeBorderIndices[borderIndex].point) {
                                reverse = true
                            }
                            if (borderStrips[index].reverse && !reverse) || (!borderStrips[index].reverse && reverse) {
                                for i in stride(from: strip.count - 1, through: 0, by: -1) {
                                    combinedLineStrip.append(strip[i])
                                }
                            }
                            else {
                                for i in 0..<strip.count {
                                    combinedLineStrip.append(strip[i])
                                }
                            }
                        }
                        borderIndex += 2
                    }
                    combinedLineStrip.append(combinedLineStrip[0])
                    
                    if combinedLineStrip.count > 0 {
                        usedExtraLineStripLists[actualPlane] = true
                        if var reOrganisedLineStripList = contours.getExtraIsoCurvesList(atIsoCurve: actualPlane) {
                            let _ = contours.addLineStripToLineStripList(&reOrganisedLineStripList, lineStrip: combinedLineStrip, isoCurve: actualPlane)
                        }
                    }
                }
            }
        }
    }

    
    // finds next valid inner closed contour in an outer closed contour and passes back the plane and no of contours found
    private func findClosedDataLinePaths(_ foundClosedDataLinePaths: inout [CGMutablePath], foundClosedPlanes: inout [Int], outerCGPath: inout CGMutablePath, innerCGPaths: inout [CGMutablePath], context: CGContext, dataSet: ContourChartDataSetProtocol, plane: inout Int, boundary: Boundary, ascendingOrder: Bool) -> Int {
        var counter: Int = foundClosedDataLinePaths.count
        var foundPlane = plane
        // now check for closed contours within  the ref contour and added border contours
        if (ascendingOrder && plane + 1 < dataSet.isoCurvesIndices.count) || (!ascendingOrder && plane - 1 > -1 ) {
    //        if ( !CGPathIsEmpty(*outerCGPath) && ![self isCGPathClockwise:*outerCGPath] ) {
    //            [self reverseCGPath:outerCGPath];
    //        }
    //        if ( innerCGPaths != NULL ) {
    //            for( NSUInteger i = 0; i < noInnerCGPaths; i++ ) {
    //                if ( !CGPathIsEmpty(*(*innerCGPaths + i)) && ![self isCGPathClockwise:*(*innerCGPaths + i)] ) {
    //                    [self reverseCGPath:(*innerCGPaths + i)];
    //                }
    //            }
    //        }
    //        CGMutablePathRef joinedCGPath;
            var joinedCGPaths: [CGMutablePath] = []
            if innerCGPaths.count > 0 {
                var usedIndices: [Int] = []
                let _ = createCGPathOfJoinedCGPathsPlanesWithACommonEdge(outerPath: &outerCGPath, innerPaths: &innerCGPaths, boundary: boundary, joinedCGPaths: &joinedCGPaths, usedIndices: &usedIndices)
                
    //            joinedCGPath = CGPathCreateMutable();
    //            if ( [self createCGPathOfJoinedCGPathsPlanesWithACommonEdge:*outerCGPath innerPaths:*innerCGPaths noInnerPaths:noInnerCGPaths boundary.leftEdge:leftEdge boundary.bottomEdge:bottomEdge boundary.rightEdge:rightEdge boundary.topEdge:topEdge joinedCGPaths:&joinedCGPaths usedIndices:&usedIndices noUsedIndices:&noUsedIndices] ) {
    ////                CGMutablePathRef *splitCGPaths = (CGMutablePathRef*)calloc(1, sizeof(CGMutablePathRef));
    ////                NSUInteger noSplits = [self splitSelfIntersectingCGPath:joinedCGPath SeparateCGPaths:&splitCGPaths boundary.leftEdge:leftEdge boundary.bottomEdge:bottomEdge boundary.rightEdge:rightEdge boundary.topEdge:topEdge];
    ////                NSLog(@"%ld", noSplits);
    ////                free(splitCGPaths);
    //            }
            }
            else {
                joinedCGPaths.append(outerCGPath)
            }
            var startPoint: CGPoint = .zero
            let transform: CGAffineTransform = .identity
    //        currentPlane = ascendingOrder ? *plane + 1 : *plane - 1;
            let currentPlane = plane
            var workingStrips: [Strip] = []
    //        while ( TRUE ) {
            if checkForClosedIsoCurvesInsideOuterIsoCurve(context: context, dataSet: dataSet, plane: currentPlane, strips: &workingStrips, ascendingOrder: ascendingOrder, useExtraLineStripList:false) {
                    var include = true, foundCGPath = false
                    for i in 0..<workingStrips.count {
                        if var foundDataLinePath = createClosedDataLinePath(dataSet: dataSet, strip: workingStrips, index: i, startPoint: &startPoint) {
                            if !foundDataLinePath.isCGPathClockwise {
                                foundDataLinePath = foundDataLinePath.reverse()
                            }
                            include = true
                            foundCGPath = false
                            if !innerCGPaths.isEmpty {
                                for j in 0..<joinedCGPaths.count {
                                    if joinedCGPaths[j].contains(startPoint, using: .evenOdd, transform: transform) {
                                        foundCGPath = true
                                        break
                                    }
                                }
                            }
                            else {
                                if joinedCGPaths[0].contains(startPoint, using: .evenOdd, transform: transform) {
                                    foundCGPath = true
                                }
                            }
                            //                    if ( **innerCGPaths != NULL && !CGPathIsEmpty(joinedCGPath) ) {
                            //                        if ( CGPathContainsPoint(joinedCGPath, &transform, startPoint, YES) ) {
                            //                            foundCGPath = YES;
                            //                        }
                            ////                        for ( NSUInteger j = 0; j < noInnerCGPaths; j++ ) {
                            ////                            lastPoint = CGPathGetCurrentPoint(*(*innerCGPaths + j));
                            ////                            NSLog(@"%f %f", lastPoint.x, lastPoint.y);
                            ////                            if( CGPathContainsPoint(*outerCGPath, &transform, startPoint, YES) && CGPathContainsPoint(*outerCGPath, &transform, lastPoint, YES) && !CGPathContainsPoint(*(*innerCGPaths + j), &transform, startPoint, YES) ) {
                            ////                                foundCGPath = YES;
                            ////                                break;
                            ////                            }
                            ////                        }
                            //                    }
                            //                    else {
                            //                        if( CGPathContainsPoint(*outerCGPath, &transform, startPoint, YES) ) {
                            //                            foundCGPath = YES;
                            //                        }
                            //                    }
                            if foundCGPath {
                                for j in 0..<counter {
                                    include = !foundClosedDataLinePaths[j].contains(startPoint, using: .evenOdd, transform: transform)
                                    if !include {
                                        break
                                    }
                                }
                            }
                            if include && foundCGPath {
                                foundPlane = workingStrips[i].plane;
                                foundClosedDataLinePaths.append(foundDataLinePath)
                                foundClosedPlanes.append(workingStrips[i].plane)
                                counter += 1
                            }
                        }
                    }
                    workingStrips.removeAll()
                }
    //            if( (ascendingOrder && currentPlane + 1 > [dataSetisoCurvesIndices count] - 1) || (!ascendingOrder && (NSInteger)currentPlane - 1 < 0) ) {
    //                break;
    //            }
    //            currentPlane = ascendingOrder ? currentPlane + 1 : currentPlane - 1;
    //        }
    //        if ( **innerCGPaths != NULL ) {
    //            CGPathRelease(joinedCGPath);
    //        }
            
            plane = foundPlane
        }
        return counter
    }
      
    private func findClosedDataLinePaths(_ foundClosedDataLinePaths: inout [CGMutablePath], foundClosedPlanes: inout [Int], outerCGPath: CGMutablePath, context: CGContext, dataSet: ContourChartDataSetProtocol, plane: inout Int, boundary: Boundary, ascendingOrder: Bool, useExtraLineStripList: Bool, fromCurrentPlane: Bool, checkPointOnPath: Bool) -> Int {
        var  counter = foundClosedDataLinePaths.count
        var currentPlane: Int
        // now check for closed contours within  the ref contour and added border contours
        if (ascendingOrder && plane + 1 < dataSet.isoCurvesIndices.count) || (!ascendingOrder && plane - 1 > -1) {
            if fromCurrentPlane {
                currentPlane = plane
            }
            else {
                currentPlane = ascendingOrder ? plane + 1 : plane - 1
            }
            let  areaOfOuterCGPath = abs(outerCGPath.area)
            var workingStrips: [Strip] = []
            var startPoint: CGPoint = .zero
            //        while ( TRUE ) {
            if checkForClosedIsoCurvesInsideOuterIsoCurve(context: context, dataSet: dataSet, plane: currentPlane, strips: &workingStrips, ascendingOrder: ascendingOrder, useExtraLineStripList: useExtraLineStripList) {
                var include = true, foundCGPath = false
                for i in 0..<workingStrips.count {
                    include = true
                    foundCGPath = false
                    if let foundDataLinePath = createClosedDataLinePath(dataSet: dataSet, strip: workingStrips, index: i, startPoint: &startPoint) {
                        let centreOfPath = foundDataLinePath.centre
                        let areaOfFoundDataLinePath = abs(foundDataLinePath.area)
                        if outerCGPath.contains(centreOfPath, using: .evenOdd) && areaOfFoundDataLinePath < areaOfOuterCGPath {
                            foundCGPath = true
#if DEBUG
#if os(OSX)
                            let bezierPath = NSBezierPath(cgPath: outerCGPath)
                            bezierPath.append(NSBezierPath(cgPath: foundDataLinePath))
#else
                            let bezierPath = UIBezierPath(cgPath: outerCGPath)
                            bezierPath.append(UIBezierPath(cgPath: foundDataLinePath))
#endif
#endif
                            if outerCGPath.isEqualToPath(foundDataLinePath) || (checkPointOnPath && outerCGPath.checkCGPathHasCGPoint(workingStrips[i].startPoint)) {
                                foundCGPath = false
                            }
                            else {
                                for j in 0..<counter {
                                    include =  !foundClosedDataLinePaths[j].contains(startPoint, using: .evenOdd)
                                    if !include {
                                        break
                                    }
                                }
                            }
                        }
                        if include && foundCGPath {
#if DEBUG
#if os(OSX)
                            let bezierPath = NSBezierPath(cgPath: foundDataLinePath)
#else
                            let bezierPath = UIBezierPath(cgPath: foundDataLinePath)
#endif
                            print(bezierPath.bounds)
#endif
                            foundClosedDataLinePaths.append(foundDataLinePath)
                            foundClosedPlanes.append(workingStrips[i].plane)
                            counter += 1
                        }
                    }
                }
                workingStrips.removeAll()
            }
        }
        return foundClosedPlanes.count
    }

    private func findClosedDataLinePaths(_ foundClosedDataLinePaths: inout [CGMutablePath], foundClosedPlanes: inout [Int], outerCGPath: CGMutablePath, context: CGContext, dataSet: ContourChartDataSetProtocol, boundary: Boundary, useExtraLineStripList: Bool, checkPointOnPath: Bool) -> Int {
        
        var counter: Int = 0
        var currentPlane: Int
        var startPoint: CGPoint = .zero
        // now check for closed contours within  the ref contour and added border contours
        for i in 0..<dataSet.isoCurvesIndices.count {
            currentPlane = dataSet.isoCurvesIndices[i]
            let workingStrips = searchPlaneClosedIsoCurves(context: context, dataSet: dataSet, plane: currentPlane, useExtraLineStripList: useExtraLineStripList)
            if workingStrips.count > 0 {
                var include = true, foundCGPath = false
                for j in 0..<workingStrips.count {
                    var foundDataLinePath: CGMutablePath?
                    include = true
                    foundCGPath = false
                    if outerCGPath.contains(workingStrips[j].startPoint, using: .evenOdd) {
                        foundCGPath = true
                        if let _foundDataLinePath = createClosedDataLinePath(dataSet: dataSet, strip: workingStrips, index: j, startPoint:&startPoint) {
                            foundDataLinePath = _foundDataLinePath
                            
                            
#if os(OSX)
                            let bezierPath = NSBezierPath(cgPath: _foundDataLinePath)
                            print(bezierPath.currentPoint)
                            if NSBezierPath(cgPath: outerCGPath).isEqual(NSBezierPath(cgPath: _foundDataLinePath)) || (checkPointOnPath && outerCGPath.checkCGPathHasCGPoint(workingStrips[j].startPoint)) {
                                foundCGPath = false
                            }
                            else {
                                for k in 0..<counter {
                                    include = !foundClosedDataLinePaths[k].contains(startPoint, using: .evenOdd)
                                    if !include {
                                        break
                                    }
                                }
                            }
#else
                            let  bezierPath = UIBezierPath(cgPath: _foundDataLinePath)
                            print(bezierPath.currentPoint)
                            if UIBezierPath(cgPath: outerCGPath).isEqual(UIBezierPath(cgPath: _foundDataLinePath)) || (checkPointOnPath && outerCGPath.checkCGPathHasCGPoint(workingStrips[j].startPoint)) {
                                foundCGPath = false
                            }
                            else {
                                for k in 0..<counter {
                                    include = !foundClosedDataLinePaths[k].contains(startPoint, using: .evenOdd)
                                    if !include {
                                        break
                                    }
                                }
                            }
#endif
                        }
                    }
                    
                    if include && foundCGPath,
                     let _foundDataLinePath = foundDataLinePath {
#if DEBUG
        #if os(OSX)
                        let bezierPath = NSBezierPath(cgPath: _foundDataLinePath)
        #else
                        let bezierPath = UIBezierPath(cgPath: _foundDataLinePath)
        #endif
                        print(bezierPath.currentPoint)
#endif
                        foundClosedDataLinePaths.append(_foundDataLinePath)
                        foundClosedPlanes.append(workingStrips[j].plane)
                        counter += 1
                    }
                }
            }
        }

        return counter
    }

    private func shiftUpInnerDataLinePaths(_ dataLinePaths: inout [CGMutablePath], index: Int) -> Void {
    // move all datalinePaths below index up and free the last datalinePath
        if index < dataLinePaths.count {
            dataLinePaths.remove(at: index)
        }
    }
    
    private func searchPlaneClosedIsoCurves(context: CGContext, dataSet: ContourChartDataSetProtocol, plane: Int, useExtraLineStripList: Bool) -> [Strip] {
        var closedStrips: [Strip] = []
        if let contours = dataSet.contours {
            
            var stripList: LineStripList
            if useExtraLineStripList,
               let _stripList = contours.getExtraIsoCurvesList(atIsoCurve: plane),
               _stripList.count > 0 {
                stripList = _stripList
            }
            else if let _stripList = contours.getStripList(forIsoCurve: plane) {
                stripList = _stripList
            }
            else {
                return closedStrips
            }
            if let dataProvider = dataProvider {
                
                let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
                let valueToPixelMatrix = trans.valueToPixelMatrix
                
                var index: Int = 0
                for pos in 0..<stripList.count {
                    let strip = stripList[pos]
                    if strip.count > 0 {
                        let indexStart = strip[0]
                        let indexEnd = strip[strip.count - 1]
                        if !(contours.isNodeOnBoundary(indexStart) && contours.isNodeOnBoundary(indexEnd)) || (!dataSet.extrapolateToLimits && !dataSet.functionPlot) {
//                            let startX = (contours.getX(at: indexStart) - dataSet.xRange.minLimit) * dataSet.scaleX
//                            let startY = (contours.getY(at: indexStart) - dataSet.yRange.minLimit) * dataSet.scaleY
//                            let endX = (contours.getX(at: indexEnd) - dataSet.xRange.minLimit) * dataSet.scaleX
//                            let endY = (contours.getY(at: indexEnd) - dataSet.yRange.minLimit) * dataSet.scaleY
                            var startPoint = CGPoint(x: contours.getX(at: indexStart), y: contours.getY(at: indexStart)).applying(valueToPixelMatrix)
                            var endPoint = CGPoint(x: contours.getX(at: indexEnd), y: contours.getY(at: indexEnd)).applying(valueToPixelMatrix)
                            
//                            var startPoint = CGPoint(x: startX, y: startY)
//                            var endPoint = CGPoint(x: endX, y: endY)
                            if dataSet.alignsPointsToPixels {
                                var convertPoints: [CGPoint] = [ startPoint, endPoint ]
                                convertPointsIfPixelAligned(context, points: &convertPoints, dataSet: dataSet, plane: plane)
                                startPoint = convertPoints[0]
                                endPoint = convertPoints[1]
                            }
                            
                            let scaleX = (valueToPixelMatrix.a/abs(valueToPixelMatrix.a)) * sqrt(pow(valueToPixelMatrix.a, 2) + pow(valueToPixelMatrix.c, 2))
                            let scaleY = -(valueToPixelMatrix.d/abs(valueToPixelMatrix.d)) * sqrt(pow(valueToPixelMatrix.b, 2) + pow(valueToPixelMatrix.d, 2))
                            
                            var closedStrip = Strip()
                            closedStrip.stripList = stripList
                            closedStrip.startPoint = startPoint
                            closedStrip.endPoint = endPoint
                            closedStrip.startBorderdirection = .none
                            closedStrip.endBorderdirection = .none
                            closedStrip.reverse = false
                            if indexStart == indexEnd {
                                closedStrip.index = index
                                closedStrip.plane = plane
                                closedStrip.usedInExtra = false
                                closedStrip.extra = false
                                closedStrips.append(closedStrip)
                            }
                            else if sqrt(pow(startPoint.x - endPoint.x, 2.0) + pow(startPoint.y - endPoint.y, 2.0)) < 10.0 * sqrt(pow(contours.deltaX * scaleX, 2.0) + pow(contours.deltaY * scaleY, 2.0)) || (!dataSet.extrapolateToLimits && !dataSet.functionPlot) {  // if contours are not extrapolated to a rectangle
                                closedStrip.endPoint = closedStrip.startPoint
                                closedStrip.index = index
                                closedStrip.plane = plane
                                closedStrip.usedInExtra = false
                                closedStrip.extra = false
                                closedStrips.append(closedStrip)
                            }
                        }
                    }
                    index += 1
                }
            }
        }
        return closedStrips
    }
    
    private func convertPointsIfPixelAligned(_ context: CGContext, points: inout [CGPoint], dataSet: ContourChartDataSetProtocol, plane: Int) {
        if dataSet.alignsPointsToPixels {
            alignViewPointsToUserSpace(&points, withContext: context, lineWidth: dataSet.isoCurvesLineWidth)
        }
    }
    
    private func alignViewPointsToUserSpace(_ viewPoints: inout [CGPoint], withContext context: CGContext, lineWidth: CGFloat) -> Void {
        // Align to device pixels if there is a data line.
        // Otherwise, align to view space, so fills are sharp at edges.
        let _ = DispatchQueue.global(qos: .userInitiated)
        if lineWidth > 0.0  {
            DispatchQueue.concurrentPerform(iterations: viewPoints.count, execute: { i in
                Utilities.alignPointToUserSpace(context, point: &viewPoints[i])
            })
        }
        else {
            DispatchQueue.concurrentPerform(iterations: viewPoints.count, execute: { i in
                Utilities.alignIntegralPointToUserSpace(context, point: &viewPoints[i])
            })
        }
    }
        
    private func searchPlaneBorderIsoCurves(context: CGContext, dataSet: ContourChartDataSetProtocol, plane: Int, useExtraLineStripList: Bool, boundary: Boundary) -> [[Strip]] {
        var borderStrips: [[Strip]] = []
        if let contours = dataSet.contours {
            var stripList: LineStripList
            if useExtraLineStripList,
               let _stripList = contours.getExtraIsoCurvesList(atIsoCurve: plane),
               _stripList.count > 0 {
                stripList = _stripList
            }
            else if let _stripList = contours.getStripList(forIsoCurve: plane) {
                stripList = _stripList
            }
            else {
                return borderStrips
            }
            
            borderStrips = Array(repeating: [], count: 4)
            borderStrips[0] = []
            borderStrips[1] = []
            borderStrips[2] = []
            borderStrips[3] = []
            if let dataProvider = dataProvider {
                
                let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
                let valueToPixelMatrix = trans.valueToPixelMatrix
                
                for pos in 0..<stripList.count {
                    let strip = stripList[pos]
                    if strip.count > 0 {
                        let indexStart = strip[0]
                        let indexEnd = strip[strip.count - 1]
                        // check that end and start indexs are not the same, then if they are on the boundary
                        if indexStart != indexEnd && contours.isNodeOnBoundary(indexStart) && contours.isNodeOnBoundary(indexEnd) {
                            
                            // from indexs get physical point in plot space
//                            let startX = (contours.getX(at: indexStart) - dataSet.xRange.minLimit) * dataSet.scaleX
//                            let startY = (contours.getY(at: indexStart) - dataSet.yRange.minLimit) * dataSet.scaleY
//                            let endX = (contours.getX(at: indexEnd) - dataSet.xRange.minLimit) * dataSet.scaleX
//                            let endY = (contours.getY(at: indexEnd) - dataSet.yRange.minLimit) * dataSet.scaleY
                            
                            var startPoint = CGPoint(x: contours.getX(at: indexStart), y: contours.getY(at: indexStart)).applying(valueToPixelMatrix)
                            var endPoint = CGPoint(x: contours.getX(at: indexEnd), y: contours.getY(at: indexEnd)).applying(valueToPixelMatrix)
                            
//                            var startPoint = CGPoint(x: startX, y: startY)
//                            var endPoint = CGPoint(x: endX, y: endY)
                            if dataSet.alignsPointsToPixels {
                                var convertPoints: [CGPoint] = [ startPoint, endPoint ]
                                convertPointsIfPixelAligned(context, points: &convertPoints, dataSet: dataSet, plane: plane)
                                startPoint = convertPoints[0]
                                endPoint = convertPoints[1]
                            }
                            
                            // depending on the start edge of contour update the borderStrip.startBorderdirection
                            var foundBorder = false
                            for border in ContourBorderDimensionDirection.allCases {
                                switch border {
                                case .xForward:
                                    if (startPoint.y == boundary.bottomEdge || (startPoint.y == boundary.topEdge && endPoint.y == boundary.bottomEdge)) && startPoint.x > boundary.leftEdge && startPoint.x <= boundary.rightEdge {
                                        var borderStrip = Strip()
                                        borderStrip.stripList = stripList
                                        borderStrip.usedInExtra = false
                                        borderStrip.extra = useExtraLineStripList
                                        borderStrip.index = pos
                                        borderStrip.plane = plane
                                        borderStrip.reverse = false
                                        borderStrip.startBorderdirection = border
                                        borderStrip.endBorderdirection = findPointBorderDirection(endPoint.y == boundary.bottomEdge ? startPoint : endPoint, boundary:boundary)
                                        borderStrip.startPoint = startPoint
                                        borderStrip.endPoint = endPoint
                                        if borderStrip.endBorderdirection == .xForward {
                                            if endPoint.x < startPoint.x {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrips[0].append(borderStrip)
                                        }
                                        else if borderStrip.endBorderdirection == .yForward || borderStrip.endBorderdirection == .xBackward {
                                            if endPoint.y == boundary.bottomEdge {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrips[0].append(borderStrip)
                                        }
                                        else {  // if startBorderdirection == .yBackward make it YBackward edge border
                                            borderStrip.startPoint = endPoint
                                            borderStrip.endPoint = startPoint
                                            borderStrip.startBorderdirection = .yBackward
                                            borderStrip.endBorderdirection = .xForward
                                            borderStrip.reverse = true
                                            borderStrips[3].append(borderStrip)
                                        }
                                        foundBorder = true
                                    }
                                    
                                case .yForward:
                                    if (startPoint.x == boundary.rightEdge || (startPoint.x == boundary.leftEdge && endPoint.x == boundary.rightEdge)) && startPoint.y > boundary.bottomEdge && startPoint.y <= boundary.topEdge {
                                        var borderStrip = Strip()
                                        borderStrip.stripList = stripList
                                        borderStrip.usedInExtra = false
                                        borderStrip.extra = useExtraLineStripList
                                        borderStrip.index = pos
                                        borderStrip.plane = plane
                                        borderStrip.reverse = false
                                        borderStrip.startBorderdirection = border
                                        borderStrip.endBorderdirection = findPointBorderDirection(endPoint.x == boundary.rightEdge ? startPoint : endPoint, boundary: boundary)
                                        borderStrip.startPoint = startPoint
                                        borderStrip.endPoint = endPoint
                                        if borderStrip.endBorderdirection == .yForward {
                                            if endPoint.y < startPoint.y {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrips[1].append(borderStrip)
                                        }
                                        else if borderStrip.endBorderdirection == .xBackward || borderStrip.endBorderdirection == .yBackward  {
                                            if endPoint.x == boundary.rightEdge {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrips[1].append(borderStrip)
                                        }
                                        else {
                                            borderStrip.startPoint = endPoint
                                            borderStrip.endPoint = startPoint
                                            borderStrip.startBorderdirection = .xForward
                                            borderStrip.endBorderdirection = .yForward
                                            borderStrip.reverse = true
                                            borderStrips[0].append(borderStrip)
                                        }
                                        foundBorder = true
                                    }
                                    
                                case .xBackward:
                                    if  startPoint.y == boundary.topEdge && startPoint.x < boundary.rightEdge && startPoint.x >= boundary.leftEdge {
                                        var borderStrip = Strip()
                                        borderStrip.stripList = stripList
                                        borderStrip.usedInExtra = false
                                        borderStrip.extra = useExtraLineStripList
                                        borderStrip.index = pos
                                        borderStrip.plane = plane
                                        borderStrip.startPoint = startPoint
                                        borderStrip.endPoint = endPoint
                                        borderStrip.startBorderdirection = border
                                        borderStrip.endBorderdirection = findPointBorderDirection(startPoint.y == boundary.topEdge ? endPoint : startPoint, boundary: boundary)
                                        borderStrip.reverse = false
                                        if borderStrip.endBorderdirection == .xBackward {
                                            if endPoint.x > startPoint.x {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrips[2].append(borderStrip)
                                        }
                                        else if borderStrip.endBorderdirection == .yBackward {
                                            if endPoint.y == boundary.topEdge {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrips[2].append(borderStrip)
                                        }
                                        else if borderStrip.endBorderdirection == .xForward {
                                            if endPoint.y == boundary.bottomEdge {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrip.startBorderdirection = .xForward
                                            borderStrip.endBorderdirection = .xBackward
                                            borderStrips[0].append(borderStrip)
                                        }
                                        else {//} if ( borderStrip.endBorderdirection == .yForward ) {
                                            if endPoint.x == boundary.rightEdge {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrip.startBorderdirection = .yForward
                                            borderStrip.endBorderdirection = .xBackward
                                            borderStrips[1].append(borderStrip)
                                        }
                                        foundBorder = true
                                    }
                                    
                                case .yBackward:
                                    if startPoint.x == boundary.leftEdge && startPoint.y < boundary.topEdge && startPoint.y >= boundary.bottomEdge {
                                        var borderStrip = Strip()
                                        borderStrip.stripList = stripList
                                        borderStrip.usedInExtra = false
                                        borderStrip.extra = useExtraLineStripList
                                        borderStrip.index = pos
                                        borderStrip.plane = plane
                                        borderStrip.reverse = false
                                        borderStrip.startBorderdirection = border
                                        borderStrip.endBorderdirection = findPointBorderDirection(startPoint.x == boundary.leftEdge ? endPoint : startPoint, boundary: boundary)
                                        borderStrip.startPoint = startPoint
                                        borderStrip.endPoint = endPoint
                                        if borderStrip.endBorderdirection == .yBackward {
                                            if endPoint.y > startPoint.y {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrips[3].append(borderStrip)
                                        }
                                        else if borderStrip.endBorderdirection == .xForward {
                                            if endPoint.x == boundary.leftEdge {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrips[3].append(borderStrip)
                                        }
                                        else if borderStrip.endBorderdirection == .yForward {
                                            if endPoint.x == boundary.rightEdge {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrip.startBorderdirection = .yForward
                                            borderStrip.endBorderdirection = .xBackward
                                            borderStrips[1].append(borderStrip)
                                        }
                                        else { //if ( borderStrip.endBorderdirection == .xBackward ) {
                                            if startPoint.x == boundary.leftEdge {
                                                borderStrip.startPoint = endPoint
                                                borderStrip.endPoint = startPoint
                                                borderStrip.reverse = true
                                            }
                                            borderStrip.startBorderdirection = .xBackward
                                            borderStrip.endBorderdirection = .yBackward
                                            borderStrips[2].append(borderStrip)
                                        }
                                        foundBorder = true
                                    }
                                    
                                case .none:
                                    break
                                }
                                if foundBorder {
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        return borderStrips
    }
    
    private func findPointBorderDirection(_ point: CGPoint, boundary: Boundary) -> ContourBorderDimensionDirection {
        var borderdirection: ContourBorderDimensionDirection
        if point.y == boundary.bottomEdge && point.x >= boundary.leftEdge && point.x <= boundary.rightEdge  {
            borderdirection = .xForward
        }
        else if point.x == boundary.rightEdge && point.y >= boundary.bottomEdge && point.y <= boundary.topEdge {
            borderdirection = .yForward
        }
        else if point.y == boundary.topEdge && point.x >= boundary.leftEdge && point.x <= boundary.rightEdge {
            borderdirection = .xBackward
        }
        else if point.x == boundary.leftEdge && point.y >= boundary.bottomEdge && point.y <= boundary.topEdge {
            borderdirection = .yBackward
        }
        else {
            borderdirection = .none
        }
        return borderdirection
    }
    
    private func checkForClosedIsoCurvesInsideOuterIsoCurve(context: CGContext, dataSet: ContourChartDataSetProtocol, plane: Int, strips: inout [Strip], ascendingOrder: Bool, useExtraLineStripList: Bool) -> Bool {
        var _plane = plane
        if (ascendingOrder && _plane < dataSet.isoCurvesIndices.count) || (!ascendingOrder && _plane >= 0) {
            while (ascendingOrder ? _plane < dataSet.isoCurvesIndices.count : _plane >= 0) {
                // look for all closed strips ie not touching boundary
                let _strips = searchPlaneClosedIsoCurves(context: context, dataSet: dataSet, plane: dataSet.isoCurvesIndices[_plane], useExtraLineStripList: useExtraLineStripList)
                if !_strips.isEmpty {
                    strips.append(contentsOf: _strips)
                }
                _plane = ascendingOrder ? _plane + 1 : _plane - 1
            }
        }
        return strips.count > 0
    }
    
    private func checkForIntersectingContoursAndCreateNewBorderContours(context: CGContext, dataSet: ContourChartDataSetProtocol, plane: Int) -> Int {
        var noReorganisedLineStrips: Int = 0
        if let dataProvider = self.dataProvider,
           let contours = dataSet.contours,
           let stripList = contours.getStripList(forIsoCurve: plane) {
            
            let trans = dataProvider.getTransformer(forAxis: .left)
            let valueToPixelMatrix = trans.valueToPixelMatrix
                
            var intersections: [Intersection] = []
            var borderIntersections: [Intersection] = []
            
            let diffSecondaryToPrimaryColumns: Int = contours.noColumnsSecondary / contours.noColumnsFirst
            let diffSecondaryToPrimaryRows: Int = contours.noRowsSecondary / contours.noRowsFirst
            let tolerance = max(diffSecondaryToPrimaryColumns, diffSecondaryToPrimaryRows) / 4
            
            // now list the strip intersections
            for pos0 in 0..<stripList.count {
                let strip0 = stripList[pos0]
                var startPoint: CGPoint = .zero, endPoint: CGPoint = .zero
#if DEBUG
#if os(OSX)
                let bezierPath = NSBezierPath()
#else
                
                let bezierPath = UIBezierPath()
#endif
#endif
                if let workingPath = createDataLinePath(fromStrip: strip0, dataSet: dataSet, startPoint: &startPoint, endPoint: &endPoint, reverseOrder: false, closed: false, extraStripList: false) {
#if DEBUG
#if os(OSX)
                    let bezierPath0 = NSBezierPath(cgPath: workingPath)
                    bezierPath.append(bezierPath0)
#else
                    
                    let bezierPath0 = UIBezierPath(cgPath: workingPath)
                    bezierPath.append(bezierPath0)
#endif
#endif
                }

                if strip0.count > 0 {
                    let indexStart0 = strip0[0]
                    let indexEnd0 = strip0[strip0.count - 1]
                    if indexStart0 != indexEnd0 {  // if the start index and end index are the same then contour is closed
                        for pos1 in pos0+1..<stripList.count {
                            let strip1 = stripList[pos1]
                            if let workingPath = createDataLinePath(fromStrip: strip1, dataSet: dataSet, startPoint: &startPoint, endPoint: &endPoint, reverseOrder: false, closed: false, extraStripList: false) {
#if DEBUG
#if os(OSX)
                                let bezierPath1 = NSBezierPath(cgPath: workingPath)
                                bezierPath.append(bezierPath1)
#else
                                let bezierPath1 = UIBezierPath(cgPath: workingPath)
                                bezierPath.append(bezierPath1)
#endif
#endif
                            }
                            if strip1.count > 0 {
                                let indexStart1 = strip1[0]
                                let indexEnd1 = strip1[strip1.count - 1]
                                if indexStart1 != indexEnd1 {
                                    contours.intersectionsWithAnotherList(strip0, other: strip1, tolerance: tolerance)
                                    if let indices = contours.getIntersectionIndicesList(),
                                       indices.count > 0 {
                                        for pos in 0..<indices.count {
                                            let indexes: IntersectionIndices  = indices[pos]
                                            let point = CGPoint(x: contours.getX(at: indexes.index), y: contours.getY(at: indexes.index)).applying(valueToPixelMatrix)
                                            intersections.insertIntersection(index: indexes.index, jndex: indexes.jndex, strip0: strip0, strip1: strip1, point: point, useStrips: true)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            intersections.sortIntersectionsByPointIncreasingXCoordinate()
            intersections.removeDuplicates(withinTolerance: 5)
            
            if intersections.count > 0 {
                // now list the border intersections
                for pos0 in 0..<stripList.count {
                    let strip0 = stripList[pos0]
                    if strip0.count > 0  {
                        let indexStart0 = strip0[0]
                        let indexEnd0 = strip0[strip0.count - 1]
                        if indexStart0 != indexEnd0 {  // if the start index and end index are the same then contour is closed
                            let pointStart = CGPoint(x: contours.getX(at: indexStart0), y: contours.getY(at: indexStart0)).applying(valueToPixelMatrix)
                            borderIntersections.insertIntersection(index: indexStart0, jndex: indexStart0, strip0: strip0, strip1: nil, point: pointStart, useStrips: false)
                            let pointEnd = CGPoint(x: contours.getX(at: indexEnd0), y: contours.getY(at: indexEnd0)).applying(valueToPixelMatrix)
                            borderIntersections.insertIntersection(index: indexEnd0, jndex: indexEnd0, strip0: strip0, strip1: nil, point: pointEnd, useStrips: false)
                        }
                    }
                }
                borderIntersections.sortIntersectionsByPointIncreasingXCoordinate()
                // make sure we haven't picked up any border intersections
                intersections.removeSimilarIntersections(borderIntersections)
                
                
                var borderCorners: [CGPoint] = Array(repeating: .zero, count: 4)
                // corners could be contour border Intersections so check on insertCorner
                var indexCorner: Int = contours.getIndex(x: contours.getLimits()[0], y: contours.getLimits()[2])
                var _point = CGPoint(x: contours.getLimits()[0], y: contours.getLimits()[2]).applying(valueToPixelMatrix)
                var index: Int = borderIntersections.insertCorner(_point, index: indexCorner)
                if index != NSNotFound {
                    borderCorners[0] = borderIntersections[index].point
                }
                indexCorner = contours.getIndex(x: contours.getLimits()[1], y: contours.getLimits()[2])
                _point = CGPoint(x: contours.getLimits()[1], y: contours.getLimits()[2]).applying(valueToPixelMatrix)
                index = borderIntersections.insertCorner(_point, index: indexCorner)
                if index != NSNotFound {
                    borderCorners[1] = borderIntersections[index].point
                }
                indexCorner = contours.getIndex(x: contours.getLimits()[1], y: contours.getLimits()[3])
                _point = CGPoint(x: contours.getLimits()[1], y: contours.getLimits()[3]).applying(valueToPixelMatrix)
                index = borderIntersections.insertCorner(_point, index: indexCorner)
                if index != NSNotFound {
                    borderCorners[2] = borderIntersections[index].point
                }
                indexCorner = contours.getIndex(x: contours.getLimits()[0], y: contours.getLimits()[3])
                _point = CGPoint(x: contours.getLimits()[0], y: contours.getLimits()[3]).applying(valueToPixelMatrix)
                index = borderIntersections.insertCorner(_point, index: indexCorner)
                if index != NSNotFound {
                    borderCorners[3] = borderIntersections[index].point
                }
                
                for i in 0..<intersections.count {
                    intersections[i].intersectionIndex = i
                }
                borderIntersections.sortIntersectionsByPointIncreasingXCoordinate()
                
                for i in 0..<borderIntersections.count {
                    borderIntersections[i].intersectionIndex = i + intersections.count
                }
                noReorganisedLineStrips = reorganiseIntersectingContours(&intersections, borderIntersections: &borderIntersections, context: context, dataSet: dataSet, plane: plane, borderCorners: borderCorners)
            }
            intersections.removeAll()
            borderIntersections.removeAll()
        }
        return noReorganisedLineStrips
    }

    private func checkForMirroredContoursAndCreateNewBorderContours(dataSet: ContourChartDataSetProtocol, plane: Int) -> Int {
        
        var noReorganisedLineStrips: Int = 0
        if let contours = dataSet.contours,
           let stripList = contours.getExtraIsoCurvesList(atIsoCurve: plane) {
        
            var _strip1: LineStrip
            var index: [Int] = Array(repeating: NSNotFound, count: 4)
            var x: [CGFloat] = Array(repeating: -0.0, count: 4)
            var y: [CGFloat] = Array(repeating: -0.0, count: 4)
            
            // now list the strip intersections
            for pos0 in 0..<stripList.count-1 {
                let strip0 = stripList[pos0]
                let strip1 = stripList[pos0 + 1]
                if strip0.count > 1 && strip1.count > 1 && strip0.count == strip1.count {
                    index[0] = strip0[0]
                    x[0] = CGFloat(contours.getX(at: index[0]))
                    y[0] = CGFloat(contours.getY(at: index[0]))
                    index[1] = strip0[strip0.count - 1]
                    x[1] = CGFloat(contours.getX(at: index[1]))
                    y[1] = CGFloat(contours.getY(at: index[1]))
                    if x[0] == x[1] || y[0] == y[1] {
                        continue
                    }
                    index[2] = strip1[0]
                    x[2] = CGFloat(contours.getX(at: index[2]))
                    y[2] = CGFloat(contours.getY(at: index[2]))
                    index[3] = strip1[strip1.count - 1]
                    x[3] = CGFloat(contours.getX(at: index[3]))
                    y[3] = CGFloat(contours.getY(at: index[3]))
                    if x[2] == x[3] || y[2] == y[3] || (x[0] == x[2] && x[1] == x[3]) || (y[0] == y[2] && y[1] == y[3]) {
                        continue
                    }
                    var pts0: [CGPoint] = Array(repeating: .zero, count: strip0.count)
                    var pts1: [CGPoint] = Array(repeating: .zero, count: strip1.count)
                    
                    _strip1 = strip1.clone()
                    _strip1.reverse()
                    
                    var skip: Bool
                    let ptr1: [LineStrip] = [ strip1, _strip1 ]
                    var count: Int = 0
                    for j in 0..<2 {
                        count = 0
                        skip = false
                        for pos2 in 0..<strip0.count {
                            index[0] = strip0[pos2]
                            x[0] = CGFloat(contours.getX(at: index[0]))
                            y[0] = CGFloat(contours.getY(at: index[0]))
                            index[1] = ptr1[j][pos2]
                            x[1] = CGFloat(contours.getX(at: index[1]))
                            y[1] = CGFloat(contours.getY(at: index[1]))
                            if (x[0] + x[1]) / 2 != 0.0 && (y[0] + y[1]) / 2 != 0.0 {
                                skip = true
                                break
                            }
                            pts0[pos2] = CGPoint(x: x[0], y: y[0])
                            pts1[pos2] = CGPoint(x: x[1], y: y[1])
                            count += 1
                        }
                        if !skip && count == strip0.count {
                            var newStrip0: LineStrip = []
                            newStrip0.reserveCapacity(strip0.count)
                            var newStrip1: LineStrip = []
                            newStrip1.reserveCapacity(strip0.count)
                            let line: [CGPoint] = [ CGPoint(x: (dataSet.limits[0] + dataSet.limits[1]) / 2.0, y: dataSet.limits[2]), CGPoint(x: (dataSet.limits[0] + dataSet.limits[1]) / 2.0, y: dataSet.limits[3]) ]
                            for pos2 in 0..<strip0.count {
                                pts0[pos2] = pts0[pos2].mirrorPointAboutALine(line)
                                pts1[pos2] = pts1[pos2].mirrorPointAboutALine(line)
                                index[0] = contours.getIndex(x: pts0[pos2].x, y: pts0[pos2].y)
                                newStrip0.append(index[0])
                                index[1] = contours.getIndex(x: pts1[pos2].x, y: pts1[pos2].y)
                                newStrip1.append(index[1])
                            }
                            // clear any Strips in contours->extraIsoCurvesLists at isoCurve
                            if var extraList = contours.getExtraIsoCurvesList(atIsoCurve: plane) {
                                if extraList.count > 0 {
                                    extraList.removeAll()
                                }
                                var newPStrip0: LineStrip = strip0.clone()
                                extraList.append(newPStrip0)
                                extraList.append(newStrip0)
                                
                                var newPStrip1: LineStrip = strip1.clone()
                                extraList.append(newPStrip1)
                                extraList.append(newStrip1)
                                
                                newPStrip0.removeAll()
                                newPStrip1.removeAll()
                            }
                            
                            noReorganisedLineStrips = 4
                        }
                    }
                }
                                                                                                                                        }
        }
       
        return noReorganisedLineStrips
    }
    
    
    private func reorganiseIntersectingContours(_ intersections: inout [Intersection], borderIntersections: inout [Intersection], context: CGContext, dataSet:ContourChartDataSetProtocol, plane: Int, borderCorners: [CGPoint]) -> Int {
        
        if let contours = dataSet.contours {
            
            intersections.sortIntersectionsByPointIncreasingXCoordinate()
        
            // clear any Strips in contours->extraIsoCurvesLists at isoCurve
            var extraList: LineStripList
            if let _extraList = contours.getExtraIsoCurvesList(atIsoCurve: plane) {
                extraList = _extraList
            }
            else {
                extraList = []
            }
            if !extraList.isEmpty {
                extraList.removeAll()
            }
            
            //    // now let's get the surrounding intersection points of these internal intersection points
            //    _CPTHull *Hull = [[_CPTHull alloc] init];
            //    [Hull quickConvexHullOnIntersections:pIntersections];
            //
            //    NSUInteger index;
            //    Intersections outerIntersections;
            //    initIntersections(&outerIntersections, [Hull hullpoints]->used);
            //    for( NSUInteger i = 0; i < (NSUInteger)[Hull hullpoints]->used; i++) {
            //        if ( (index = searchForIndexIntersection(pIntersections, [Hull hullpoints][i].index)) != NSNotFound ) {
            //            appendIntersections(&outerIntersections, pIntersections[index]);
            //        }
            //    }
            //    Hull = nil;
            
            //    sortIntersectionsByOrderAntiClockwiseFromBottomLeftCorner(pBorderIntersections, borderCorners, 0.01);
            
            // internal Intersection Indices will be from 0-maxInternal#-1, border from maxInternal# to ??
            var allIntersections: [Intersection] = []
            allIntersections.reserveCapacity(intersections.count + borderIntersections.count)
            
            allIntersections.append(contentsOf: intersections)
            allIntersections.append(contentsOf: borderIntersections)
            
            var interSectionIndices: LineStrip = []
            interSectionIndices.reserveCapacity(intersections.count)
            var alternativeInterSectionIndices: LineStrip = []
            alternativeInterSectionIndices.reserveCapacity(intersections.count)
            
            interSectionIndices.append(contentsOf: intersections.map( { $0.index } ))
            alternativeInterSectionIndices.append(contentsOf: intersections.map( { $0.jndex } ))
            
            // unweighted bidirectional BFS
            let graph = ContourGraph(noNodes: intersections.count + borderIntersections.count)
            var j: Int = 1
            for i in 0..<borderIntersections.count {
                if j == borderIntersections.count {
                    j = 0
                }
                if let strip0 = borderIntersections[i].strip0 {
                    for l in j+1..<borderIntersections.count {
                        if contours.checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip(strip0, index:  borderIntersections[i].index, jndex: borderIntersections[l].index, indicesList: interSectionIndices, jndicesList: alternativeInterSectionIndices) {
                            graph.addEdge(from: i + intersections.count, to: l + intersections.count)
                        }
                    }
                }
                // Inner intersections have contour index Index & Jndex, they may not be the same as 2 contour lines may have intersected
                // with a tolerance
                for k in 0..<intersections.count {
                    if contours.checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip(intersections[k].strip0, index: intersections[k].index, jndex: intersections[i].index, indicesList: interSectionIndices, jndicesList: alternativeInterSectionIndices) || contours.checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip(intersections[k].strip1, index: intersections[k].index, jndex: intersections[i].index, indicesList: interSectionIndices, jndicesList: alternativeInterSectionIndices) || contours.checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip(intersections[k].strip0, index: intersections[k].jndex, jndex: intersections[i].index, indicesList: interSectionIndices, jndicesList: alternativeInterSectionIndices) || contours.checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip(intersections[k].strip1, index: intersections[k].jndex, jndex: intersections[i].index, indicesList: interSectionIndices, jndicesList: alternativeInterSectionIndices) {
                        graph.addEdge(from: i + intersections.count, to: k)
                    }
                }
                j += 1
            }
            
            for i in 0..<intersections.count {
                for k in i+1..<intersections.count {
                    if contours.checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip(intersections[i].strip0, index: intersections[i].index, jndex: intersections[k].index, indicesList: interSectionIndices, jndicesList: alternativeInterSectionIndices) || contours.checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip(intersections[i].strip1, index: intersections[i].index, jndex: intersections[k].index, indicesList: interSectionIndices, jndicesList: alternativeInterSectionIndices) {
                        graph.addEdge(from: i, to: k)
                    }
                }
            }
            
            // start a first border intersection in btm left corner, then iterate around the edges back to start
            // find each shape, some shapes will be repeats so eliminate them from the list.
            borderIntersections.sortIntersectionsByOrderAntiClockwiseFromBottomLeftCorner(corners: borderCorners, tolerance: 5)
            
            if borderIntersections.count > 0 {
                var paths: LineStripList = []
                paths.reserveCapacity(8)
                
                var pathFound = true
                var start: Int = 0
                if borderIntersections[0].isCorner { // which it probably always will be
                    start = 1
                }
                j = start + 1
                for i in start..<borderIntersections.count {
                    if j == borderIntersections.count {
                        j = 0
                    }
                    pathFound = true
                    if graph.biDirSearch(fromSource: borderIntersections[i].intersectionIndex, toTarget: borderIntersections[j].intersectionIndex, paths: &paths) == NSNotFound {
                        //                NSLog(@"Path don't exist between %ld and %ld\n", pBorderIntersections[i].intersectionIndex, pBorderIntersections[j].intersectionIndex);
                        pathFound = false
                        //            if !(borderIntersections[i].isCorner || borderIntersections[j].isCorner) {
                        var k: Int = j + 1, count: Int = 0
                        if k == borderIntersections.count {
                            k = 0
                        }
                        while  count < borderIntersections.count {
                            pathFound = true
                            if graph.biDirSearch(fromSource: borderIntersections[i].intersectionIndex, toTarget: borderIntersections[k].intersectionIndex, paths: &paths) == NSNotFound {
                                //                        NSLog(@"Path don't exist between %ld and %ld\n", pBorderIntersections[i].intersectionIndex, pBorderIntersections[k].intersectionIndex);
                                pathFound = false
                                k += 1
                                count += 1
                                if k == borderIntersections.count {
                                    k = 0
                                }
                            }
                            else {
                                break
                            }
                        }
                    }
                    if !pathFound {
                        var k: Int = j
                        if borderIntersections[j].isCorner {
                            k += 1
                        }
                        if borderIntersections[i].strip0 == borderIntersections[k].strip0 {
                            var path: LineStrip = []
                            path.reserveCapacity(2)
                            
                            if borderIntersections[i].index < borderIntersections[k].index {
                                path.append(borderIntersections[k].intersectionIndex)
                                path.append(borderIntersections[i].intersectionIndex)
                            }
                            else {
                                path.append(borderIntersections[i].intersectionIndex)
                                path.append(borderIntersections[k].intersectionIndex)
                            }
                            paths.append(path)
                        }
                    }
                    j += 1
                }
                
                // now do the inner nodes
                if intersections.count > 1 {
                    var temp: [Intersection] = []
                    temp.reserveCapacity(intersections.count)
                    
                    for i in 0..<intersections.count {
                        temp = intersections.clone()
                        temp.remove(at: i)
                        intersections[i].closestKIntersections(&temp)
                        
                        for j in 0..<2 {
                            
                            if let k = intersections.firstIndex(where: { $0.intersectionIndex == temp[j].intersectionIndex }) {
                                if graph.biDirSearch(fromSource: i, toTarget: k, paths: &paths) == NSNotFound {
                                    print("Path don't exist between %ld and %ld\n", intersections[i].intersectionIndex, temp[j].intersectionIndex)
                                }
                                else {
                                    if paths[paths.count - 1].count != 4 {
                                        paths.remove(at: paths.count - 1)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // initialise variable
                var vertices: [CGPoint] = []
                var vertex: CGPoint
                var centroids: [Centroid] = []
                centroids.reserveCapacity(8)
                var status: ContourPolygonStatus
                var intersections: [Intersection] = []
                intersections.reserveCapacity(8)
                var grad0: CGFloat, grad1: CGFloat
                var breakOut = false
                
                for i in 0..<paths.count {
                    var k: Int = 0
                    breakOut = false
                    for j in 0..<paths[i].count {
                        if k > 0 && k < paths[i].count - 1 { // check if 3 nodes on a straight line and rid if so
                            grad0 = (allIntersections[paths[i][j]].point.y - allIntersections[paths[i][j-1]].point.y) / (allIntersections[paths[i][j]].point.x - allIntersections[paths[i][j-1]].point.x)
                            grad1 = (allIntersections[paths[i][j+1]].point.y - allIntersections[paths[i][j]].point.y) / (allIntersections[paths[i][j+1]].point.x - allIntersections[paths[i][j]].point.x)
                            if abs(grad0 - grad1) < 0.001 {
                                breakOut = true
                                break
                            }
                        }
                        intersections.append(allIntersections[paths[i][j]])
                        vertex = allIntersections[paths[i][j]].point
                        vertices.append(vertex)
                        k += 1
                    }
                    if breakOut {
                        print("Status: can't create shape as 3 nodes in a line, but will use original LineStrip")
                        var m: Int = 1
                        for l in 0..<paths[i].count{
                            if m == paths[i].count {
                                m = 0
                            }
                            if let strip00 = allIntersections[paths[i][l]].strip0,
                               let strip01 = allIntersections[paths[i][m]].strip0,
                               strip00 == strip01 {
                                let element = strip00.clone()
                                extraList.append(element)
                                break
                            }
                            else if let strip10 = allIntersections[paths[i][l]].strip1,
                                    let strip11 = allIntersections[paths[i][m]].strip1,
                                    strip10 == strip11 {
                                let element = strip10.clone()
                                extraList.append(element)
                                break
                            }
                            m += 1
                        }
                    }
                    else {
                        status = createPolygonFromIntersections(intersections, vertices: vertices, centroids: &centroids, plane: plane, contours: contours)
                        print("Status: %s", status.description)
                    }
                    
                    vertices.removeAll()
                    intersections.removeAll()
                    paths[i].removeAll()
                }
                paths.removeAll()
                
                // Weighted search using Dijkstra algorithm
                //    NSUInteger noVertices = (NSUInteger)(outerIntersections.used + pBorderIntersections->used);
                //    CGFloat** adjMatrix = (CGFloat**)calloc((size_t)noVertices, sizeof(CGFloat*));
                //    for( NSUInteger i = 0; i < noVertices; i++ ) {
                //        adjMatrix[i] = (CGFloat*)calloc((size_t)noVertices, sizeof(CGFloat));
                //        for( NSUInteger j = 0; j < noVertices; j++ ) {
                //            adjMatrix[i][j] = 0.0;
                //        }
                //    }
                //
                //    for( NSUInteger i = 0, j = 1, k = (NSUInteger)pBorderIntersections->used - 1; i < (NSUInteger)pBorderIntersections->used-1; i++, j++, k++) {
                //        if ( j == (NSUInteger)pBorderIntersections->used ) {
                //            j = 0;
                //        }
                //        if ( k == (NSUInteger)pBorderIntersections->used ) {
                //            k = 0;
                //        }
                //        adjMatrix[i+outerIntersections.used][j+outerIntersections.used] = sqrt(pow(pBorderIntersections[i].point.x - pBorderIntersections[j].point.x, 2.0) + pow(pBorderIntersections[i].point.y - pBorderIntersections[j].point.y , 2.0));
                //
                //        if( pBorderIntersections[i].pStrip0 != NULL )  {
                //            for ( NSUInteger l = 0; l < pBorderIntersections->used; l++ ) {
                //                if ( l != i && [contours checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip:pBorderIntersections[i].pStrip0 Index:pBorderIntersections[i].index Jndex:pBorderIntersections[l].index IndicesList:&interSectionIndices] ) {
                //                    adjMatrix[k+outerIntersections.used][i+outerIntersections.used] = sqrt(pow(pBorderIntersections[i].point.x - pBorderIntersections[l].point.x, 2.0) + pow(pBorderIntersections[i].point.y - pBorderIntersections[l].point.y , 2.0));
                //                    adjMatrix[i+outerIntersections.used][k+outerIntersections.used] = adjMatrix[k+outerIntersections.used][i+outerIntersections.used];
                //                }
                //            }
                //        }
                //
                //        for ( NSUInteger l = 0; l < outerIntersections.used; l++ ) {
                //            if( [contours checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip:outerIntersections[l].pStrip0 Index:pBorderIntersections[i].index Jndex:outerIntersections[l].index IndicesList:&interSectionIndices] || [contours checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip:outerIntersections[l].pStrip1 Index:pBorderIntersections[i].index Jndex:outerIntersections[l].index IndicesList:&interSectionIndices] ) {
                ////                CGFloat P12 = sqrt(pow(pBorderIntersections[k].point.x - pBorderIntersections[i].point.x, 2.0) + pow(pBorderIntersections[k].point.y - pBorderIntersections[i].point.y, 2.0));
                ////                CGFloat P13 = sqrt(pow(pBorderIntersections[k].point.x - outerIntersections[l].point.x, 2.0) + pow(pBorderIntersections[k].point.y - outerIntersections[l].point.y, 2.0));
                ////                CGFloat P23 = sqrt(pow(pBorderIntersections[i].point.x - outerIntersections[l].point.x, 2.0) + pow(pBorderIntersections[i].point.y - outerIntersections[l].point.y, 2.0));
                ////                CGFloat subtendedAngle = acos((P12 * P12 + P13 * P13 + P23 * P23) / 2 / P12 / P13);
                ////                if ( subtendedAngle <= M_PI_2 ) {
                //                    adjMatrix[i+outerIntersections.used][l] = sqrt(pow(pBorderIntersections[i].point.x - outerIntersections[l].point.x, 2.0) + pow(pBorderIntersections[i].point.y - outerIntersections[l].point.y , 2.0));
                ////                }
                //            }
                //        }
                //    }
                //    for ( NSUInteger l = 0; l < outerIntersections.used; l++ ) {
                //        for( NSUInteger m = 0; m < outerIntersections.used; m++ ) {
                //            if ( m != l && ([contours checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip:outerIntersections[l].pStrip0 Index:outerIntersections[l].index Jndex:outerIntersections[m].index IndicesList:&interSectionIndices] || [contours checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip:outerIntersections[l].pStrip1 Index:outerIntersections[l].index Jndex:outerIntersections[m].index IndicesList:&interSectionIndices]) ) {
                //                adjMatrix[l][m] = sqrt(pow(outerIntersections[l].point.x - outerIntersections[m].point.x, 2.0) + pow( outerIntersections[l].point.y - outerIntersections[m].point.y , 2.0));
                //                adjMatrix[m][l] = adjMatrix[l][m];
                //            }
                //        }
                //    }
                //    [self DijkstraWithAdjacency:adjMatrix noVertices:(NSUInteger)(outerIntersections.used + pBorderIntersections->used) startNode:10];
                //
                //    for( NSUInteger i = 0; i < noVertices; i++ ) {
                //        free(adjMatrix[i]);
                //    }
                //    free(adjMatrix);
                
                // now iterated through the border intersection in anticlockwise direction (contour to border meeting points and corners)
                // start at the bottom left corner as the first vertex and see if there is a direct contour line to any of the outer inside
                // intersections establish through the convex hull method. If not, add next border intersection in anticlockwise direction to
                // the vertices array, check whether this vertex has direct contour line to any of the outer inside intersections, iterating
                // through till one is found
                return extraList.count
            }
            else {
                return 0
            }
        }
        else {
            return 0
        }
    }


    private func createPolygonFromIntersections(_ intersections: [Intersection], vertices: [CGPoint], centroids: inout [Centroid], plane: Int, contours: Contours) -> ContourPolygonStatus {
        
        centroids.sort(by: { centroid0, centroid1 in
            if abs(centroid0.centre.x - centroid1.centre.x) < 0.5 {
                return abs(centroid0.centre.y - centroid1.centre.y) < 0.5
            }
            else {
                return false
            }
        })
        var centroid: Centroid = Centroid()
        centroid.centre = vertices.findCentroidOfShape()
        centroid.noVertices = vertices.count
        if let _ = centroids.first(where: { _centroid in
            if abs(centroid.centre.x - _centroid.centre.x) < 0.5 {
                return abs(centroid.centre.y - _centroid.centre.y) < 0.5
            }
            else {
                return false
            }
        }) {
            return .alreadyExists
        }
        else {
            createNPointShapeFromIntersections(intersections: intersections, noVertices: vertices.count, plane: plane, contours: contours)
            centroids.append(centroid)
            
            return .created
        }
    }
    
    private func createNPointShapeFromIntersections(intersections: [Intersection], noVertices: Int, plane: Int, contours: Contours) -> Void {
        // use the contours extraLineStripList to created new shapes
        if var reOrganisedLineStripList = contours.getExtraIsoCurvesList(atIsoCurve: plane) {
            
            var stripList0: LineStripList = []
            stripList0.reserveCapacity(8)
            var stripList1: LineStripList = []
            stripList1.reserveCapacity(8)
            var indexes: [Int] = Array(repeating: NSNotFound, count: noVertices)
            var jndexes: [Int] = Array(repeating: NSNotFound, count: noVertices)
            var count: Int = 0
            var deltaX: CGFloat, deltaY: CGFloat
            var onBoundary1: Bool, onBoundary2: Bool, anyOnBoundary1: Bool = false, anyOnBoundary2: Bool = false
            var m: Int = 0, n: Int = 1
            while m < noVertices  {
                if n == noVertices {
                    n = 0
                }
                if !intersections[m].isCorner {
                    // now we have established a shape get rid of boundary nodes unless start/end of new contour Strip
                    onBoundary1 = contours.isNodeOnBoundary(intersections[m].index)
                    onBoundary2 = contours.isNodeOnBoundary(intersections[n].index)
                    anyOnBoundary1 = anyOnBoundary1 || onBoundary1
                    anyOnBoundary2 = anyOnBoundary2 || onBoundary2
                    deltaX = abs(intersections[m].point.x - intersections[n].point.x)
                    deltaY = abs(intersections[m].point.y - intersections[n].point.y)
                    if let strip0 = intersections[m].strip0 {
                        stripList0.append(strip0)
                    }
                    
                    if let strip1 = intersections[m].strip1 {
                        stripList1.append(strip1)
                    }
                    
                    indexes[count] = intersections[m].index
                    jndexes[count] = intersections[m].jndex
                    count += 1
                    if (deltaX == 0.0 || deltaY == 0.0) && onBoundary1 && onBoundary2 && count > 1 {
                        if contours.createNPointShapeFromIntersectionPtToLineStripList(&reOrganisedLineStripList, striplist0: stripList0, striplist1: stripList1, indexs: indexes, jndexs: jndexes, NPoints: count, isoCurve: plane) {
                            count = 0
                        }
                    }
                }
                m += 1
                n += 1
            }
            
            if count > 1 {
                if  !(anyOnBoundary1 || anyOnBoundary2) {
                    indexes.append(intersections[0].index)
                    jndexes.append(intersections[0].jndex)
                    count += 1
                }
                let _ = contours.createNPointShapeFromIntersectionPtToLineStripList(&reOrganisedLineStripList, striplist0: stripList0, striplist1: stripList1, indexs: indexes, jndexs: jndexes, NPoints: count, isoCurve: plane)
            }
            stripList0.removeAll()
            stripList1.removeAll()
        }
    }

    
    // MARK: - Discontinuities

    private func pathsDiscontinuityRegions(context: CGContext, dataSet: inout ContourChartDataSetProtocol, discontinuityStrips: inout [Strip], boundary: Boundary) -> [CGMutablePath] {
        var noClusters: Int = 0
        var boundaryLimitsDataLinePaths: [CGMutablePath] = []
        
        if let dataProvider = self.dataProvider,
           let contours = dataSet.contours {
            
            let trans = dataProvider.getTransformer(forAxis: .left)
            let phaseY = animator.phaseY
            let valueToPixelMatrix = trans.valueToPixelMatrix
            //#if DEBUG
            //    CPTPlotSymbol *symbol = [[CPTPlotSymbol alloc] init];
            //    symbol.fill               = [CPTFill fillWithColor:[CPTColor darkGrayColor]];
            //    symbol.size               = CGSizeMake(2.0, 2.0);
            //#endif
            
            let _discontinuities: Discontinuities = contours.getDiscontinuities()
            if _discontinuities.count > 0 {
                let discontinuousCount = _discontinuities.count
                dataSet.hasDiscontinuity = true
                var discontinuousPoints: [CGPoint] = Array(repeating: .zero, count: _discontinuities.count)
                for i in 0..<_discontinuities.count {
                    discontinuousPoints[i] = CGPoint(x: contours.getX(at: _discontinuities[i]), y: contours.getY(at: _discontinuities[i])).applying(valueToPixelMatrix)
                }
                // MARK: - Clustering
                // Use  the Gaussian Mixed Model GMMCluster
                var samples: [[GMMPoint]] = Array(repeating: [], count: discontinuousCount)
                var element: GMMPoint = GMMPoint()
                for i in 0..<discontinuousCount {
                    element.x = discontinuousPoints[i].x;
                    element.y = discontinuousPoints[i].y;
                    samples[0].append(element)
                }
                let gmmCluster = GMMCluster(usingGMMPointsWithNoClasses: 1, vector_dimension: 2, samples: samples)
                gmmCluster.init_num_of_subclasses = 19
                gmmCluster.cluster()
                
                if let signatureSet = gmmCluster.signatureSet {
                    print(String(format: "No classes: %d", signatureSet.nclasses))
                    
                    // use ConcaveHull method to get outer points of area of discontinuity
                    // find the boundary of drawnViewPoints
                    // CGFLOAT_MAX is convex, 20.0 default, 1 thin shape
                    let hull = Hull(concavity: 5)
                    
                    var countAllSubclasses: Int = 0
                    for i in 0..<signatureSet.nclasses {
                        let classSignature = signatureSet.classSig[i]
                        print(String(format: "Class: %ld No SubClasses: %ld", i, classSignature.nsubclasses))
                        countAllSubclasses += classSignature.nsubclasses
                    }
                    
                    var clustersOuterPoints: [[CGPoint]] = Array(repeating: [], count: countAllSubclasses)
                    //        NSMutableArray<NSString*> *clustersOuterName = [NSMutableArray new];
                    //        CGAffineTransform transform = CGAffineTransformIdentity;
                    //#if DEBUG
                    //        CGAffineTransform transformEllipse;
                    //        double **eigenVectors = (double**)calloc(2, sizeof(double*));
                    //        eigenVectors[0] = (double*)calloc(2, sizeof(double));
                    //        eigenVectors[1] = (double*)calloc(2, sizeof(double));
                    //        double eigenValues[2] = { 0, 0 };
                    //        NSUInteger largest_eigenvec_index;
                    //    #if os(OSX)
                    //        NSFont *font = [NSFont systemFontOfSize:30];
                    //    #else
                    //        UIFont *font = [UIFont systemFontOfSize:30];
                    //    #endif
                    //#endif
                    
                    var clusterCount = 0;//, symbolType = 0
                    for i in 0..<signatureSet.nclasses {
                        let classSignature: ClassSig = signatureSet.classSig[i]
                        for j in 0..<classSignature.nsubclasses {
                            var discontinuities: [CGPoint] = Array(repeating: .zero, count: discontinuousCount)
                            //#if DEBUG
                            //                symbolType++;
                            //                if( symbolType >= CPTPlotSymbolTypeCustom ) {
                            //                    symbolType = 0;
                            //                }
                            //                symbol.symbolType = (CPTPlotSymbolType)symbolType;
                            ////                symbol.symbolType = (CPTPlotSymbolType)(i * (NSUInteger)signatureSet.nclasses + j + 1);
                            ////                SubSig *subSig = &classSignature.subSig[j];
                            //#endif
                            var m: Int = 0, nearestSubclassIndex: Int = 0
                            var nearestMeanToPointDistance: CGFloat , meanToPointDistance: CGFloat
                            for k in 0..<discontinuousCount {
                                nearestMeanToPointDistance = CGFloat.greatestFiniteMagnitude
                                for l in 0..<classSignature.nsubclasses {
                                    let _subSig: SubSig = classSignature.subSig[l]
                                    meanToPointDistance = sqrt(pow(_subSig.means[0] - discontinuousPoints[k].x, 2.0) + pow(_subSig.means[1] - discontinuousPoints[k].y, 2.0))
                                    if meanToPointDistance < nearestMeanToPointDistance {
                                        nearestSubclassIndex = l
                                        nearestMeanToPointDistance = meanToPointDistance
                                    }
                                }
                                if nearestSubclassIndex == j {
                                    discontinuities[m] = discontinuousPoints[k]
                                    //#if DEBUG
                                    //                        CGPoint symbolPoint = CGPoint(x: discontinuities[m].x - dataSet.originOfContext.x, discontinuities[m].y - dataSet.originOfContext.y);
                                    //                        [symbol renderAsVectorInContext:context atPoint:symbolPoint scale:(CGFloat)1.0];
                                    //#endif
                                    m += 1
                                }
                            }
                            
                            clustersOuterPoints[clusterCount] = hull.hull(cgPoints: discontinuities)
                            //#if DEBUG
                            //                    CGPoint symbolPoint = CGPoint(x: clustersOuterPoints[clusterCount][k].x - dataSet.originOfContext.x, clustersOuterPoints[clusterCount][k].y - dataSet.originOfContext.y);
                            //                    [symbol renderAsVectorInContext:context atPoint:symbolPoint scale:(CGFloat)1.0];
                            //#endif
                            
                            // add first to end for controlpoints if need to fit curve
                            clustersOuterPoints[clusterCount].append(clustersOuterPoints[clusterCount][0])
                            discontinuities.removeAll()
                            //                [clustersOuterName addObject: [NSString stringWithFormat:@"%ld", clusterCount]];
                            
                            //                CGPoint centre = centroidCGPoints(clustersOuterPoints[clusterCount], clustersOuterNoPoints[clusterCount]);
                            //                CGPoint symbolPoint = CGPoint(x: centre.x - dataSet.originOfContext.x, centre.y - dataSet.originOfContext.y);
                            //                [symbol renderAsVectorInContext:context atPoint:symbolPoint scale:(CGFloat)1.0];
                            //
                            //                NSAttributedString *string = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%ld", clusterCount] attributes:@{ NSFontAttributeName: font }];
                            //                [string drawAtPoint:CGPoint(x: symbolPoint.x - string.size.width / 2, symbolPoint.y - string.size.height / 2)];
                            clusterCount += 1
                        }
                    }
                    
                    samples[0].removeAll()
                    discontinuousPoints.removeAll()
                    
                    let diffSecondaryToPrimaryColumns: Int = contours.noColumnsSecondary / contours.noColumnsFirst
                    let diffSecondaryToPrimaryRows: Int = contours.noRowsSecondary / contours.noRowsFirst
                    let weldDistMultiplier: Double = sqrt(pow(Double(diffSecondaryToPrimaryColumns), 2) + pow(Double(diffSecondaryToPrimaryRows), 2))
                    let scaleX = (valueToPixelMatrix.a/abs(valueToPixelMatrix.a)) * sqrt(pow(valueToPixelMatrix.a, 2) + pow(valueToPixelMatrix.c, 2))
                    let scaleY = -(valueToPixelMatrix.d/abs(valueToPixelMatrix.d)) * sqrt(pow(valueToPixelMatrix.b, 2) + pow(valueToPixelMatrix.d, 2))
                    let weldDist: Double = weldDistMultiplier * (pow(contours.deltaX * scaleX, 2.0) + pow(contours.deltaY * scaleY, 2.0))
                    
                    noClusters = countAllSubclasses
                    for _ in 0..<4 {
                        for i in 0..<noClusters {
                            let tree: KDTree = KDTree(values: clustersOuterPoints[i])
                            for var j in i+1..<noClusters {
                                /* search for neighbours */
                                var foundOne = false
                                for k in 0..<clustersOuterPoints[j].count {
                                    if let _ = tree.nearest(to: clustersOuterPoints[j][k]) {
                                        foundOne = true
                                        break
                                    }
                                }
                                if foundOne {
                                    // if meets adjacent criteria merge 2 to grow i cluster and get rid of this cluster
                                    clustersOuterPoints[i].append(contentsOf: clustersOuterPoints[j])
                                    clustersOuterPoints[j].removeAll()
                                    clustersOuterPoints[i] = hull.hull(cgPoints: clustersOuterPoints[i])
                                    clustersOuterPoints[i].append(clustersOuterPoints[i][0])
                                    clustersOuterPoints.remove(at: j)
                                    
                                    noClusters -= 1
                                    j -= 1
                                    break
                                }
                                if ( noClusters < 3 ) {
                                    break;
                                }
                            }
                            if noClusters < 3 {
                                break
                            }
                        }
                        if noClusters < 3 {
                            break
                        }
                    }
                    
                    for i in 0..<noClusters {
                        //#if DEBUG
                        //            symbolType++;
                        //            if( symbolType >= CPTPlotSymbolTypeCustom ) {
                        //                symbolType = 0;
                        //            }
                        //            symbol.symbolType = (CPTPlotSymbolType)symbolType;
                        //
                        //            for ( NSUInteger k = 0; k < clustersOuterNoPoints[i]; k++ ) {
                        //
                        //                    CGPoint symbolPoint = CGPoint(x: clustersOuterPoints[i][k].x - dataSet.originOfContext.x, clustersOuterPoints[i][k].y - dataSet.originOfContext.y);
                        //                    [symbol renderAsVectorInContext:context atPoint:symbolPoint scale:(CGFloat)1.0];
                        //
                        //            }
                        //            CGPoint centre = centroidCGPoints(clustersOuterPoints[i], clustersOuterNoPoints[i]);
                        //            CGPoint symbolPoint = CGPoint(x: centre.x - dataSet.originOfContext.x, centre.y - dataSet.originOfContext.y);
                        //            [symbol renderAsVectorInContext:context atPoint:symbolPoint scale:(CGFloat)1.0];
                        //
                        //            NSAttributedString *string = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%ld%ld", i, i] attributes:@{ NSFontAttributeName: font }];
                        //            [string drawAtPoint:CGPoint(x: symbolPoint.x - string.size.width / 2, symbolPoint.y - string.size.height / 2)];
                        //#endif
                        // now let's try to get a better discontinuity trace for this region
                        // CPTContourPlot uses an initial user defined grid ie 256 * 256
                        // this resolution may not be good enough to present a neat discontinuity line,
                        // we need to trace this with closer resolution
                        //            [dataSet traceDiscontinuityLine:clustersOuterPoints[i] noPoints:clustersOuterNoPoints[i] contours:contours];
                        
                        // redo concavity on larger value
                        hull.concavity = 20
                        clustersOuterPoints[i] = hull.hull(cgPoints: clustersOuterPoints[i])
                        
                        if dataSet.alignsPointsToPixels && clustersOuterPoints[i].count > 0 {
                            alignViewPointsToUserSpace(&clustersOuterPoints[i], withContext: context, lineWidth: dataSet.isoCurvesLineWidth)
                        }
                    }
                    
                    var bezierPoints: [CGPoint] = [ .zero, .zero, .zero, .zero ]
                    if discontinuityStrips.count > 0 {
                        discontinuityStrips.removeAll()
                    }
                    boundaryLimitsDataLinePaths.removeAll()
                    for i in 0..<noClusters {
                        var strip: Strip = Strip()
                        // create heap memory for next boundaryLimitsDataLinePath
                        // and create the respective paths for boundaries
                        
                        let boundaryLimitsDataLinePath = CGMutablePath()
                        
                        var k: Int = 0
                        for j in 0..<clustersOuterPoints[i].count {
                            if clustersOuterPoints[i][j].x == boundary.leftEdge || clustersOuterPoints[i][j].x == boundary.rightEdge || clustersOuterPoints[i][j].y == boundary.bottomEdge || clustersOuterPoints[i][j].y == boundary.topEdge {
                                if j > 0 {
                                    clustersOuterPoints[i].append(clustersOuterPoints[i][j])
                                }
                                k = j
                                break
                            }
                        }
                        while ( (clustersOuterPoints[i][k].x == boundary.leftEdge && clustersOuterPoints[i][k+1].x == boundary.leftEdge) || (clustersOuterPoints[i][k].x == boundary.rightEdge && clustersOuterPoints[i][k+1].x == boundary.rightEdge) || (clustersOuterPoints[i][k].y == boundary.bottomEdge && clustersOuterPoints[i][k+1].y == boundary.bottomEdge) || (clustersOuterPoints[i][k].y == boundary.topEdge && clustersOuterPoints[i][k+1].y == boundary.topEdge) ) {
                            k += 1
                            if k == clustersOuterPoints[i].count {
                                break
                            }
                        }
                        boundaryLimitsDataLinePath.move(to: CGPoint(x: clustersOuterPoints[i][k].x, y: clustersOuterPoints[i][k].y * phaseY))
                        strip.startBorderdirection = findPointBorderDirection(clustersOuterPoints[i][k], boundary: boundary)
                        strip.startPoint = clustersOuterPoints[i][k]
                        
                        var n: Int = 0
                        for j in k+1..<clustersOuterPoints[i].count {
                            // if a straight line parallel x or y axis
                            if (clustersOuterPoints[i][j].x == boundary.leftEdge && clustersOuterPoints[i][j-1].x == boundary.leftEdge) || (clustersOuterPoints[i][j].x == boundary.rightEdge && clustersOuterPoints[i][j-1].x == boundary.rightEdge) || (clustersOuterPoints[i][j].y == boundary.bottomEdge && clustersOuterPoints[i][j-1].y == boundary.bottomEdge) || (clustersOuterPoints[i][j].y == boundary.topEdge && clustersOuterPoints[i][j-1].y == boundary.topEdge) {
                                if n == 0 {
                                    n = j - 1
                                }
                            }
                            else if j < clustersOuterPoints[i].count - 1 && ((clustersOuterPoints[i][j-1].x == boundary.leftEdge && clustersOuterPoints[i][j+1].x == boundary.leftEdge) || (clustersOuterPoints[i][j-1].x == boundary.rightEdge && clustersOuterPoints[i][j+1].x == boundary.rightEdge) || (clustersOuterPoints[i][j-1].y == boundary.bottomEdge && clustersOuterPoints[i][j+1].y == boundary.bottomEdge) || (clustersOuterPoints[i][j-1].y == boundary.topEdge && clustersOuterPoints[i][j+1].y == boundary.topEdge)) {
                                boundaryLimitsDataLinePath.addLine(to: CGPoint(x: clustersOuterPoints[i][j-1].x, y: clustersOuterPoints[i][j-1].y * phaseY))
                            }
                            else if (clustersOuterPoints[i][j].x - clustersOuterPoints[i][j-1].x == 0) || (clustersOuterPoints[i][j].y - clustersOuterPoints[i][j-1].y == 0) || j == clustersOuterPoints[i].count - 1 {
                                boundaryLimitsDataLinePath.addLine(to: CGPoint(x: clustersOuterPoints[i][j].x, y: clustersOuterPoints[i][j].y * phaseY))
                            }
                            else { // fit a curve instead
                                let bezierIndexRange = j < 2 ? 0..<3 : 0..<4
                                var jj = j < 2 ? j - 1 : j - 2
                                for l in bezierIndexRange {
                                    bezierPoints[l] = clustersOuterPoints[i][jj]
                                    jj += 1
                                }
                                
                                let cubicPath: CGMutablePath?
                                switch dataSet.cubicInterpolation {
                                    case .normal:
                                        cubicPath = cubicBezierPath(forViewPoints: bezierPoints, dataSet: dataSet)
                                        
                                    case .catmullRomUniform:
                                        cubicPath = catmullRomPath(forViewPoints: bezierPoints, dataSet: dataSet, alpha: 0.0)
                                        
                                    case .catmullRomCentripetal:
                                        cubicPath = catmullRomPath(forViewPoints: bezierPoints, dataSet: dataSet, alpha: 0.5)
                                        
                                    case .catmullCustomAlpha:
                                        cubicPath = catmullRomPath(forViewPoints: bezierPoints, dataSet: dataSet, alpha: dataSet.catmullCustomAlpha)
                                        
                                    case .catmullRomChordal:
                                        cubicPath = catmullRomPath(forViewPoints: bezierPoints, dataSet: dataSet, alpha: 1.0)
                                        
                                    case .hermite:
                                        cubicPath = hermitePath(forViewPoints: bezierPoints, dataSet: dataSet)
                                    
                                }
                                if let _cubicPath = cubicPath {
                                    boundaryLimitsDataLinePath.addPath(_cubicPath)
                                }
                            }
                            
                        }
                        if n == 0 {
                            n = clustersOuterPoints[i].count - 1
                        }
                        boundaryLimitsDataLinePath.addLine(to: CGPoint(x: clustersOuterPoints[i][n].x, y: clustersOuterPoints[i][n].y * phaseY))
                        
                        boundaryLimitsDataLinePaths.append(boundaryLimitsDataLinePath)
#if DEBUG
#if os(OSX)
                        //NSBezierPath __unused *bezierPath = [NSBezierPath bezierPathWithCGPath:*boundaryLimitsDataLinePath];
#else
                        let bezierPath = UIBezierPath(cgPath: boundaryLimitsDataLinePath)
#endif
                        
#endif
                        strip.endBorderdirection = findPointBorderDirection(clustersOuterPoints[i][n], boundary: boundary)
                        strip.endPoint = clustersOuterPoints[i][n]
                        strip.stripList = nil
                        strip.index = i
                        strip.plane = NSNotFound
                        strip.reverse = strip.isReverse
                        discontinuityStrips.append(strip)
                        
                        //#if DEBUG
                        //                // to show the ellipse of uncertainty and the boundary path
                        //                CGContextSaveGState(context);
                        //                CGContextBeginPath(context);
                        //                CGContextAddPath(context, *(*boundaryLimitsDataLinePaths + i * (NSUInteger)signatureSet.nclasses + j));
                        //                CGContextClosePath(context);
                        //
                        //                CGFloat components[4] = { 1, (CGFloat)(i * (NSUInteger)signatureSet.nclasses + j) / (CGFloat)noBoundaryLimitsDataLinePaths, 0.0, 1 };
                        //                CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
                        //                CGColorRef color = CGColorCreate(colorspace, components);
                        //                CGContextSetStrokeColorWithColor(context, color);
                        //                CGContextSetLineWidth(context, 4.0);
                        //                CGContextStrokePath(context);
                        //                CGColorRelease(color);
                        //                CGColorSpaceRelease(colorspace);
                        
                        //                eigenValuesAndEigenVectorsOfCoVariance(subSig, eigenValues, eigenVectors, 2);
                        //                // Get the largest eigenvalue
                        //                if ( eigenValues[0] > eigenValues[1] ) {
                        //                    largest_eigenvec_index = 0;
                        //                }
                        //                else {
                        //                    largest_eigenvec_index = 1;
                        //                }
                        //                // Calculate the angle between the x-axis and the largest eigenvector
                        //                // This angle is between -pi and pi.
                        //                // Let's shift it such that the angle is between 0 and 2pi
                        //                CGFloat angle;
                        //                if ( (angle = atan2((CGFloat)eigenVectors[largest_eigenvec_index][1], (CGFloat)eigenVectors[largest_eigenvec_index][0])) < 0.0 ) {
                        //                    angle+= 2.0 * M_PI;
                        //                }
                        //
                        //                // Get the 99%/95% confidence interval error ellipse
                        //                CGFloat chisquare_val = 3.0;//2.4477;
                        //                CGFloat pearson = (CGFloat)subSig.R[0][1] / sqrt((CGFloat)subSig.R[0][0] * (CGFloat)subSig.R[1] [1]);
                        //                CGFloat ell_radius_x = sqrt(1.0 + pearson) * (CGFloat)sqrt(subSig.R[0][0]) * chisquare_val;
                        //                CGFloat ell_radius_y = sqrt(1.0 - pearson) * (CGFloat)sqrt(subSig.R[1][1]) * chisquare_val;
                        //                CGMutablePathRef ellipsePath = CGPathCreateMutable();
                        //                transformEllipse = CGAffineTransformIdentity;
                        //                transformEllipse = CGAffineTransformRotate(transformEllipse, angle);
                        //                transformEllipse = CGAffineTransformTranslate(transformEllipse, subSig.means[0], subSig.means[1]);
                        //
                        //
                        //                CGPathAddEllipseInRect(ellipsePath, &transformEllipse, CGRectMake( /*subSig.means[0]*/ - ell_radius_x / 2.0,  /*subSig.means[1]*/ - ell_radius_y / 2.0, ell_radius_x, ell_radius_y));
                        //                CGContextSaveGState(context);
                        //                CGContextBeginPath(context);
                        //                CGContextAddPath(context, ellipsePath);
                        //                CGContextClosePath(context);
                        //                CGPathRelease(ellipsePath);
                        //
                        //                CGFloat components1[4] = { 1, (CGFloat)(i * (NSUInteger)signatureSet.nclasses + j) / (CGFloat)noBoundaryLimitsDataLinePaths, 1, 1 };
                        //                CGColorSpaceRef colorspace1 = CGColorSpaceCreateDeviceRGB();
                        //                CGColorRef color1 = CGColorCreate(colorspace1, components1);
                        //                CGContextSetStrokeColorWithColor(context, color1);
                        //                CGContextSetLineWidth(context, 4.0);
                        //                CGFloat lengths[4] = { (CGFloat)1.0, (CGFloat)3.0, (CGFloat)4.0, (CGFloat)2.0 } ;
                        //                CGContextSetLineDash(context, 0.0, lengths, 4.0);
                        //                CGContextStrokePath(context);
                        //                CGColorRelease(color1);
                        //                CGColorSpaceRelease(colorspace1);
                        //                          Do your stuff here
                        //                CGImageRef imgRef = CGBitmapContextCreateImage(context);
                        //#if os(OSX)
                        //                NSImage* img = [[NSImage alloc] initWithCGImage:imgRef size: NSZeroSize];
                        //
                        //                NSImage* __unused flippedImage = [NSImage imageWithSize:img.size flipped:YES drawingHandler:^BOOL(NSRect dstRect) {
                        //                    [img drawInRect:dstRect];
                        //                    return true
                        //                }];
                        //#else
                        //                UIImage* img = [UIImage imageWithCGImage:imgRef];
                        //                CGSize size = img.size;
                        //                UIGraphicsBeginImageContext(CGSizeMake(size.height, size.width));
                        //                [[UIImage imageWithCGImage:imgRef scale:1.0 orientation:UIImageOrientationDownMirrored] drawInRect:CGRectMake(0,0,size.height ,size.width)];
                        //                UIImage* __unused flippedImage = UIGraphicsGetImageFromCurrentImageContext();
                        //                UIGraphicsEndImageContext();
                        //#endif
                        //                CGImageRelease(imgRef);
                        //                CGContextRestoreGState(context);
                        //#endif
                    }
                    //#if DEBUG
                    //        free(eigenVectors[0]);
                    //        free(eigenVectors[1]);
                    //        free(eigenVectors);
                    //#endif
                    for i in 0..<noClusters {
                        clustersOuterPoints[i].removeAll()
                    }
                    clustersOuterPoints.removeAll()
                }
            }
        }
        
        return boundaryLimitsDataLinePaths
    }
    // resolution of the firstgrid of contour algorithm may produce a poor curve, so let's improve this by iteration of each concave
    // hull point of the initial formation of this region
    private func traceDiscontinuityLine(regionPoints: inout [CGPoint], dataSet: ContourChartDataSetProtocol) -> Void {
        
        if let dataProvider = self.dataProvider,
           let contours = dataSet.contours,
           let _fieldBlock = dataSet.fieldBlock {
            
            let trans = dataProvider.getTransformer(forAxis: .left)
            let valueToPixelMatrix = trans.valueToPixelMatrix
            let pixelToValueMatrix = trans.pixelToValueMatrix
            
            let minX: CGFloat = regionPoints.map( { $0.x } ).min()!
            let minY: CGFloat = regionPoints.map( { $0.y } ).min()!
            let maxX: CGFloat = regionPoints.map( { $0.x } ).max()!
            let maxY: CGFloat = regionPoints.map( { $0.y } ).max()!
            
            let resolutionX = contours.deltaX
            let resolutionY = contours.deltaY
            let resolutionFirstGridX = resolutionX * Double(contours.noColumnsSecondary) / Double(contours.noColumnsFirst)
            let resolutionFirstGridY = resolutionY * Double(contours.noRowsSecondary) / Double(contours.noRowsFirst)
            var deltaX: CGFloat, deltaY: CGFloat, distance: CGFloat
            var x2: Double, y2: Double, xMiddle: Double = 0.0, yMiddle: Double = 0.0, functionValueMiddle: Double
            var centroid: CGPoint = regionPoints.findCentroidOfShape(), point1: CGPoint
            var x1: Double = Double(centroid.x)
            var y1: Double = Double(centroid.y)
            centroid = CGPoint(x: x1, y: y1).applying(pixelToValueMatrix)
            for i in 0..<regionPoints.count-1 {
                deltaX = regionPoints[i + 1].x - regionPoints[i].x
                deltaY = regionPoints[i + 1].y - regionPoints[i].y
                x1 = Double(regionPoints[i].x)
                y1 = Double(regionPoints[i].y)
                point1 = CGPoint(x: x1, y: y1).applying(pixelToValueMatrix)
                x1 = point1.x
                y1 = point1.y
                distance = sqrt(pow(x1 - centroid.x, 2.0) + pow(y1 - centroid.y, 2.0))
                if abs(deltaX) > 0 || regionPoints[i].y == minY || regionPoints[i].y == maxY {
                    y2 = y1
                    x2 = x1
                    if sqrt(pow(x2 - centroid.x, 2.0) + pow(y2 + resolutionFirstGridY - centroid.y, 2.0)) > distance {
                        y2 += resolutionFirstGridY * 2.0
                    }
                    else {
                        y2 -= resolutionFirstGridY * 2.0
                    }
                    if y2 >= contours.getLimits()[2] && y2 <= contours.getLimits()[3] {
                        while( abs(y1 - y2) >= resolutionY ) {
                            yMiddle = (y1 + y2) / 2.0
                            functionValueMiddle = _fieldBlock(x1, yMiddle)
                            if functionValueMiddle.isNaN {
                                y1 = yMiddle
                            }
                            else {
                                y2 = yMiddle
                            }
                        }
                        let point1 = CGPoint(x: 0, y: yMiddle).applying(valueToPixelMatrix)
                        regionPoints[i] = CGPoint(x: regionPoints[i].x, y: point1.y)
                    }
                }
                x1 = Double(regionPoints[i].x)
                y1 = Double(regionPoints[i].y)
                point1 = CGPoint(x: x1, y: y1).applying(pixelToValueMatrix)
                distance = sqrt(pow(x1 - centroid.x, 2.0) + pow(y1 - centroid.y, 2.0))
                if abs(deltaY) > 0 || regionPoints[i].x == minX || regionPoints[i].x == maxX {
                    x2 = x1
                    y2 = y1
                    if sqrt(pow(x2 + resolutionFirstGridX - centroid.x, 2.0) + pow(y2 - centroid.y, 2.0)) > distance {
                        x2 += resolutionFirstGridX * 2.0
                    }
                    else {
                        x2 -= resolutionFirstGridX * 2.0
                    }
                    if x2 >= contours.getLimits()[0] && x2 <= contours.getLimits()[1] {
                        while abs(x1 - x2) >= resolutionX {
                            xMiddle = (x1 + x2) / 2.0
                            functionValueMiddle = _fieldBlock(xMiddle, y1)
                            if functionValueMiddle.isNaN {
                                x1 = xMiddle
                            }
                            else {
                                x2 = xMiddle
                            }
                        }
                        let point1 = CGPoint(x: xMiddle, y: 0).applying(valueToPixelMatrix)
                        regionPoints[i] = CGPoint(x: point1.x, y: regionPoints[i].y)
                    }
                }
            }
        }
    }

    
    // MARK: - Create CGPaths from contour indices

    private func createClosedDataLinePath(dataSet: ContourChartDataSetProtocol, strip closedStrip: [Strip], index: Int, startPoint: inout CGPoint) -> CGMutablePath? {
        var dataLineClosedPath: CGMutablePath?
        if let contours = dataSet.contours,
           closedStrip.count > 0 {
            let pos = closedStrip[index].index
            if let strip = closedStrip[index].stripList?[pos],
               strip.count > 0 {
                var _startPoint: CGPoint = .zero, _endPoint: CGPoint = .zero
                dataLineClosedPath = createDataLinePath(fromStrip: strip, dataSet: dataSet, startPoint: &_startPoint, endPoint: &_endPoint, reverseOrder:false, closed: true, extraStripList: closedStrip[index].stripList == contours.getExtraIsoCurvesList(atIsoCurve: closedStrip[index].plane))
                if !_startPoint.equalTo(_endPoint) {
                    dataLineClosedPath?.addLine(to: _startPoint)
                }
                startPoint = _startPoint
            }
        }
        return dataLineClosedPath
    }

    private func includeCornerIfRequired(usingStartEdge startEdge: ContourBorderDimensionDirection, endEdge: ContourBorderDimensionDirection, cornerPoints: inout [CGPoint], startPoint: CGPoint, endPoint: CGPoint, boundary: Boundary, useAllCorners: Bool) -> Int {   // every thing is anti-clockwise
        var noCorners: Int = 0

        if startEdge == endEdge && !useAllCorners {
            return noCorners
        }

        cornerPoints[0] = CGPoint(x: -0.0, y: -0.0)
        cornerPoints[1] = CGPoint(x: -0.0, y: -0.0)
        cornerPoints[2] = CGPoint(x: -0.0, y: -0.0)
        cornerPoints[3] = CGPoint(x: -0.0, y: -0.0)
        switch (startEdge) {
            case .xForward:   // bottom edge
                switch endEdge {
                    case .xForward:
                        if useAllCorners  {
                            cornerPoints[0] = CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge)
                            cornerPoints[1] = CGPoint(x: boundary.rightEdge, y: boundary.topEdge)
                            cornerPoints[2] = CGPoint(x: boundary.leftEdge, y: boundary.topEdge)
                            cornerPoints[3] = CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge)
                            noCorners = 4
                        }
                        
                    case .yForward:
                        cornerPoints[0] = CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge)
                        noCorners = 1
                        
                    case .xBackward:
                        cornerPoints[0] = CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge)
                        cornerPoints[1] = CGPoint(x: boundary.rightEdge, y: boundary.topEdge)
                        noCorners = 2
                        
                    case .yBackward:
                        cornerPoints[0] = CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge)
                        cornerPoints[1] = CGPoint(x: boundary.rightEdge, y: boundary.topEdge)
                        cornerPoints[2] = CGPoint(x: boundary.leftEdge, y: boundary.topEdge)
                        noCorners = 3
                    
                    case .none:
                        break
                }
                
            case .yForward:   // right edge
                switch endEdge {
                    case .xForward:
                        cornerPoints[0] = CGPoint(x: boundary.rightEdge, y: boundary.topEdge)
                        cornerPoints[1] = CGPoint(x: boundary.leftEdge, y: boundary.topEdge)
                        cornerPoints[2] = CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge)
                        noCorners = 3
                        
                    case .yForward:
                        if( useAllCorners ) {
                            cornerPoints[0] = CGPoint(x: boundary.rightEdge, y: boundary.topEdge)
                            cornerPoints[1] = CGPoint(x: boundary.leftEdge, y: boundary.topEdge)
                            cornerPoints[2] = CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge)
                            cornerPoints[3] = CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge)
                            noCorners = 4
                        }
                       
                    case .xBackward:
                        cornerPoints[0] = CGPoint(x: boundary.rightEdge, y: boundary.topEdge)
                        noCorners = 1
                        
                    case .yBackward:
                        cornerPoints[0] = CGPoint(x: boundary.rightEdge, y: boundary.topEdge)
                        cornerPoints[1] = CGPoint(x: boundary.leftEdge, y: boundary.topEdge)
                        noCorners = 2
                    
                    case .none:
                        break
                }
                
            case .xBackward:   // top edge
                switch endEdge {
                        case .xForward:
                        cornerPoints[0] = CGPoint(x: boundary.leftEdge, y: boundary.topEdge)
                        cornerPoints[1] = CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge)
                        noCorners = 2
                        
                    case .yForward:
                        cornerPoints[0] = CGPoint(x: boundary.leftEdge, y: boundary.topEdge)
                        cornerPoints[1] = CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge)
                        cornerPoints[2] = CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge)
                        noCorners = 3
                       
                    case .xBackward:
                        if( useAllCorners ) {
                            cornerPoints[0] = CGPoint(x: boundary.leftEdge, y: boundary.topEdge)
                            cornerPoints[1] = CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge)
                            cornerPoints[2] = CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge)
                            cornerPoints[3] = CGPoint(x: boundary.rightEdge, y: boundary.topEdge)
                            noCorners = 4
                        }
                        
                    case .yBackward:
                        cornerPoints[0] = CGPoint(x: boundary.leftEdge, y: boundary.topEdge)
                        noCorners = 1
                        
                    case .none:
                        break
                }
                
            case .yBackward:   // left edge
                switch endEdge {
                    case .xForward:
                        cornerPoints[0] = CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge)
                        noCorners = 1
                        
                    case .yForward:
                        cornerPoints[0] = CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge)
                        cornerPoints[1] = CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge)
                        noCorners = 2
                        
                    case .xBackward:
                        cornerPoints[0] = CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge)
                        cornerPoints[1] = CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge)
                        cornerPoints[2] = CGPoint(x: boundary.rightEdge, y: boundary.topEdge)
                        noCorners = 3
                        
                    case .yBackward:
                        if( useAllCorners ) {
                            cornerPoints[0] = CGPoint(x: boundary.leftEdge, y: boundary.bottomEdge)
                            cornerPoints[1] = CGPoint(x: boundary.rightEdge, y: boundary.bottomEdge)
                            cornerPoints[2] = CGPoint(x: boundary.rightEdge, y: boundary.topEdge)
                            cornerPoints[3] = CGPoint(x: boundary.leftEdge, y: boundary.topEdge)
                            noCorners = 4
                        }
                    case .none:
                        break
                }
            case .none:
                    break
        }

        return noCorners
    }
    
    
    private func createCGPathOfJoinedCGPathsPlanesWithACommonEdge(outerPath: inout CGMutablePath, innerPaths: inout [CGMutablePath], boundary: Boundary, joinedCGPaths: inout [CGMutablePath], usedIndices: inout [Int]) -> Int {
        
        let transform:  CGAffineTransform = .identity
        var innerPathsIndices: [Int] = []
       
        if outerPath.isCGPathClockwise {
            outerPath = outerPath.reverse()
        }
        var lastPoint: CGPoint = .zero
        for i in 0..<innerPaths.count {
            if innerPaths[i].isCGPathClockwise {
                innerPaths[i] = innerPaths[i].reverse()
            }
            lastPoint = innerPaths[i].currentPoint
            if outerPath.contains(lastPoint, using: .evenOdd, transform: transform) {
                innerPathsIndices.append(i)
            }
        }
        if innerPathsIndices.count > 0 {
            for ii in 0..<innerPathsIndices.count {
                usedIndices.append(innerPathsIndices[ii])
            }
            
            let outerPoints: [CGPoint] = outerPath.points
            var outerBoundaryPoints: [CGPathBoundaryPoint] = filterCGPointsBoundaryPoints(points: outerPoints, boundary: boundary)
            var innerPoints: [CGPoint]
            var innerBoundariesPoints: [[CGPathBoundaryPoint]] = Array(repeating: [], count: innerPathsIndices.count)
            
            var counterInnerBoundariesPoints: [Int] = Array(repeating: NSNotFound, count: innerPathsIndices.count)
            var startPositionInnerBoundariesPoints: [Int] = Array(repeating: NSNotFound, count: innerPathsIndices.count)
            var lastPositionInnerBoundariesPoints: [Int] = Array(repeating: NSNotFound, count: innerPathsIndices.count)
            var comparisonPoints: [CGPoint] = Array(repeating: .zero, count: innerPathsIndices.count)
            
            // need to see whether the first or last of innerPaths is next to the end of the outerPath
            // thus allowing correct order to include in overlapPath
            for ii in 0..<innerPathsIndices.count {
                innerPoints = innerPaths[innerPathsIndices[ii]].points
                innerBoundariesPoints[ii] = filterCGPointsBoundaryPoints(points: innerPoints, boundary: boundary)
                counterInnerBoundariesPoints[ii] = 0
                comparisonPoints[ii] = innerBoundariesPoints[ii][0].point
                startPositionInnerBoundariesPoints[ii] = innerBoundariesPoints[ii].count - 1
                lastPositionInnerBoundariesPoints[ii] = 0
                innerBoundariesPoints[ii][startPositionInnerBoundariesPoints[ii]].used = true
                
            }
            
            var missPoint = false, closeOut = false
            var point: CGPoint, prevPoint: CGPoint, comparisonPoint: CGPoint, nextComparisonPoint: CGPoint, innerPoint: CGPoint = .zero
            var i: Int = 0, startPosition: Int = outerBoundaryPoints.count - 1, counterCGPath: Int = 0
            outerBoundaryPoints[startPosition].used = true
            while !outerBoundaryPoints[i].used {
                counterCGPath = 0
                var joinedCGPath = CGMutablePath()
                closeOut = false
                point = outerBoundaryPoints[startPosition].point
                while i < outerBoundaryPoints.count - 1 && !outerBoundaryPoints[i].used {
                    prevPoint = point
                    point = outerBoundaryPoints[i].point
                    for j in 0..<innerPathsIndices.count {
                        if counterInnerBoundariesPoints[j] == innerBoundariesPoints[j].count - 1 {
                            counterInnerBoundariesPoints[j] = lastPositionInnerBoundariesPoints[j]
                            if counterInnerBoundariesPoints[j] == 0 {
                                startPositionInnerBoundariesPoints[j] = innerBoundariesPoints[j].count - 1
                            }
                            else {
                                startPositionInnerBoundariesPoints[j] = counterInnerBoundariesPoints[j] - 1
                            }
                            comparisonPoints[j] = innerBoundariesPoints[j][counterInnerBoundariesPoints[j]].point
                        }
                        while counterInnerBoundariesPoints[j] < innerBoundariesPoints[j].count - 1 && !innerBoundariesPoints[j][counterInnerBoundariesPoints[j]].used {
                            comparisonPoint = comparisonPoints[j]
                            if (point.y == boundary.bottomEdge && prevPoint.y == boundary.bottomEdge && comparisonPoint.y == boundary.bottomEdge &&  comparisonPoint.x >= prevPoint.x && comparisonPoint.x <= point.x) || (point.y == boundary.topEdge && prevPoint.y == boundary.topEdge && comparisonPoint.y == boundary.topEdge && comparisonPoint.x <= prevPoint.x && comparisonPoint.x >= point.x) || (point.x == boundary.leftEdge && prevPoint.x == boundary.leftEdge && comparisonPoint.x == boundary.leftEdge && comparisonPoint.y >= prevPoint.y && comparisonPoint.y <= point.y) || (point.x == boundary.rightEdge && prevPoint.x == boundary.rightEdge && comparisonPoint.x == boundary.rightEdge && comparisonPoint.y >= prevPoint.y && comparisonPoint.y <= point.y)  {
                                if point.equalTo(comparisonPoint) {
                                    missPoint = true
                                    outerBoundaryPoints[i].used = true
                                }
                                else {
                                    missPoint = false
                                    if counterInnerBoundariesPoints[j] + 1 < innerBoundariesPoints[j].count - 1 {
                                        nextComparisonPoint = innerBoundariesPoints[j][counterInnerBoundariesPoints[j] + 1].point
                                        if ((point.y == boundary.bottomEdge && prevPoint.y == boundary.bottomEdge && nextComparisonPoint.y == boundary.bottomEdge &&  nextComparisonPoint.x >= prevPoint.x && nextComparisonPoint.x <= point.x) || (point.y == boundary.topEdge && prevPoint.y == boundary.topEdge && nextComparisonPoint.y == boundary.topEdge && nextComparisonPoint.x <= prevPoint.x && nextComparisonPoint.x >= point.x) || (point.x == boundary.leftEdge && prevPoint.x == boundary.leftEdge && nextComparisonPoint.x == boundary.leftEdge && nextComparisonPoint.y >= prevPoint.y && nextComparisonPoint.y <= point.y) || (point.x == boundary.rightEdge && prevPoint.x == boundary.rightEdge && nextComparisonPoint.x == boundary.rightEdge && nextComparisonPoint.y >= prevPoint.y && nextComparisonPoint.y <= point.y)) && counterCGPath == 0 {
                                            closeOut = true
                                            prevPoint = comparisonPoint
                                            counterInnerBoundariesPoints[j] = counterInnerBoundariesPoints[j] + 1
                                            if startPositionInnerBoundariesPoints[j] == innerBoundariesPoints[j].count - 1  {
                                                startPositionInnerBoundariesPoints[j] = 0
                                            }
                                            else {
                                                startPositionInnerBoundariesPoints[j] = startPositionInnerBoundariesPoints[j] + 1
                                            }
                                            comparisonPoints[j] = innerBoundariesPoints[j][counterInnerBoundariesPoints[j]].point
                                        }
                                        else if ((point.y == boundary.bottomEdge && comparisonPoint.y == boundary.bottomEdge && nextComparisonPoint.y == boundary.bottomEdge && point.x >= comparisonPoint.x && point.x <= nextComparisonPoint.x) || (point.y == boundary.topEdge && comparisonPoint.y == boundary.topEdge && nextComparisonPoint.y == boundary.topEdge && point.x <= comparisonPoint.x && point.x >= nextComparisonPoint.x) || (point.x == boundary.leftEdge && comparisonPoint.x == boundary.leftEdge && nextComparisonPoint.x == boundary.leftEdge && point.y >= comparisonPoint.y && point.y <= nextComparisonPoint.y) || (point.x == boundary.rightEdge && comparisonPoint.x == boundary.rightEdge && nextComparisonPoint.x == boundary.rightEdge && point.y >= comparisonPoint.y && point.y <= nextComparisonPoint.y)) && counterCGPath == 0 {
                                            prevPoint = nextComparisonPoint
                                            counterInnerBoundariesPoints[j] = counterInnerBoundariesPoints[j] + 1
                                            if startPositionInnerBoundariesPoints[j] == innerBoundariesPoints[j].count - 1 {
                                                startPositionInnerBoundariesPoints[j] = 0
                                            }
                                            else {
                                                startPositionInnerBoundariesPoints[j] = startPositionInnerBoundariesPoints[j] + 1
                                            }
                                            comparisonPoints[j] = innerBoundariesPoints[j][counterInnerBoundariesPoints[j]].point;
                                        }
                                    }
                                    if counterCGPath == 0 {
                                        joinedCGPath.move(to: prevPoint, transform: transform)
                                    }
                                    else {
                                        joinedCGPath.addLine(to: prevPoint, transform: transform)
                                    }
                                    lastPoint = prevPoint
                                    innerPoints = innerPaths[innerPathsIndices[j]].points
                                    
                                    for k in stride(from: innerBoundariesPoints[j][counterInnerBoundariesPoints[j]].position, to: innerBoundariesPoints[j][startPositionInnerBoundariesPoints[j]].position, by: -1) {
                                        joinedCGPath.addLine(to: innerPoints[k], transform: transform)
                                        counterCGPath += 1
                                    }
                                    if closeOut {
                                        if !joinedCGPath.isEmpty {
                                            joinedCGPaths.append(joinedCGPath)
                                        }
                                        
                                        joinedCGPath = CGMutablePath()
                                        
                                        innerBoundariesPoints[j][startPositionInnerBoundariesPoints[j]].used = true
                                        counterCGPath = 0
                                        closeOut = false
                                    }
                                    else {
                                        var pt: CGPoint = outerBoundaryPoints[i == 0 ? outerBoundaryPoints.count - 1 : i - 1].point, prevPt: CGPoint
                                        for k in i..<outerBoundaryPoints.count {
                                            prevPt = pt
                                            pt = outerBoundaryPoints[k].point
                                            if (pt.y == boundary.bottomEdge && prevPt.y == boundary.bottomEdge && innerPoint.y == boundary.bottomEdge && innerPoint.x >= prevPt.x && innerPoint.x <= pt.x) || (pt.y == boundary.topEdge && prevPt.y == boundary.topEdge && innerPoint.y == boundary.topEdge && innerPoint.x <= prevPt.x && innerPoint.x >= pt.x) || (pt.x == boundary.leftEdge && prevPt.x == boundary.leftEdge && innerPoint.x == boundary.leftEdge && innerPoint.y <= prevPt.y && innerPoint.y >= pt.y) || (pt.x == boundary.rightEdge && prevPt.x == boundary.rightEdge && innerPoint.x == boundary.rightEdge && innerPoint.y >= prevPt.y && innerPoint.y <= pt.y) {
                                                startPosition = k
                                                i = k + 1
                                                prevPoint = outerBoundaryPoints[startPosition].point
                                                point = outerBoundaryPoints[i].point
                                                break
                                            }
                                        }
                                    }
                                }
                                innerBoundariesPoints[j][counterInnerBoundariesPoints[j]].used = true
                                lastPositionInnerBoundariesPoints[j] = counterInnerBoundariesPoints[j] + 1
                            }
                            counterInnerBoundariesPoints[j] = counterInnerBoundariesPoints[j] + 1;
                            if startPositionInnerBoundariesPoints[j] == innerBoundariesPoints[j].count - 1 {
                                startPositionInnerBoundariesPoints[j] = 0
                            }
                            else {
                                startPositionInnerBoundariesPoints[j] = startPositionInnerBoundariesPoints[j] + 1
                            }
                            comparisonPoints[j] = innerBoundariesPoints[j][counterInnerBoundariesPoints[j]].point;
                            if counterInnerBoundariesPoints[j] > innerBoundariesPoints[j].count - 1 {
//                                innerPoints.removeAll()
                                break
                            }
                        }
                    }
                    if !missPoint {
                        outerBoundaryPoints[startPosition].used = true
                        outerBoundaryPoints[i].used = true
                        var start: Int
                        if counterCGPath == 0 {
                            joinedCGPath.move(to: prevPoint, transform: transform)
                            start = outerBoundaryPoints[startPosition].position + 1
                        }
                        else {
                            start = outerBoundaryPoints[startPosition].position
                        }
                        for k in start...outerBoundaryPoints[i].position {
                            joinedCGPath.addLine(to: outerPoints[k], transform: transform)
                            counterCGPath += 1
                        }
                    }
                    startPosition = i
                    i += 1
                }
                if missPoint {
                    joinedCGPath.addLine(to: lastPoint, transform: transform)
                }
                else {
                    joinedCGPath.addLine(to: outerPoints[outerBoundaryPoints[i].position], transform: transform)
                }
                if !joinedCGPath.isEmpty {
                    joinedCGPaths.append(joinedCGPath)
                }
                
                i = 0 // now find first outerBoundaryPoints that hasn't been used
                while true {
                    if !outerBoundaryPoints[i].used {
                        startPosition = i - 1
                        break
                    }
                    i += 1
                    if i > outerBoundaryPoints.count - 1 {
                        break
                    }
                }
                if i > outerBoundaryPoints.count - 1 {
                    break
                }
            }
            
            for ii in 0..<innerPathsIndices.count {
                innerBoundariesPoints[ii].removeAll()
            }
        }
        
        return joinedCGPaths.count
    }
    
    private func filterCGPointsBoundaryPoints(points: [CGPoint], boundary: Boundary) -> [CGPathBoundaryPoint] {
        var boundaryPoints: [CGPathBoundaryPoint] = []
        
        var i: Int = 0
        for point in points {
            if point.x == boundary.leftEdge || point.x == boundary.rightEdge || point.y == boundary.bottomEdge || point.y == boundary.topEdge {
                var boundaryPoint = CGPathBoundaryPoint()
                boundaryPoint.point = point
                boundaryPoint.position = i
                boundaryPoint.used = false
                boundaryPoint.direction = .none
                if point.y == boundary.bottomEdge {
                    boundaryPoint.direction = .xForward
                }
                if point.x == boundary.rightEdge {
                    boundaryPoint.direction = .yForward
                }
                if point.y == boundary.topEdge {
                    boundaryPoint.direction = .xBackward
                }
                if( point.x == boundary.leftEdge ) {
                    boundaryPoint.direction = .yBackward
                }
                boundaryPoints.append(boundaryPoint)
            }
            i += 1
        }
        
        var edgeBorderPoints: [[CGPathBoundaryPoint]] = Array(repeating: [], count: 4)
        
        var unique: [Bool] = Array(repeating: false, count: 4)
        let edge: [CGFloat] = [ boundary.bottomEdge, boundary.rightEdge, boundary.topEdge, boundary.leftEdge ]
        let sortFunctions: [([CGPathBoundaryPoint]) -> [CGPathBoundaryPoint]] = [ sortCGPathBoundaryPointsByBottomEdge, sortCGPathBoundaryPointsByRightEdge, sortCGPathBoundaryPointsByTopEdge, sortCGPathBoundaryPointsByLeftEdge ]
        
        let callbackPlotEdge: ( CGPathBoundaryPoint, ContourBorderDimensionDirection, CGFloat) -> Bool = { item, direction, edge in
            var test: Bool
            switch(direction) {
                case .xForward, .xBackward:
                    test = item.point.y == edge
                    
                case .yForward, .yBackward:
                    test = item.point.x == edge
                    
                case .none:
                    test = false
                    
            }
            return test
        }
        
        for i in 0..<4 {
            edgeBorderPoints[i] = boundaryPoints.filterCGPathBoundaryPoints(predicate: callbackPlotEdge, direction: ContourBorderDimensionDirection(rawValue: i)!, edge: edge[i])
            unique[i] = edgeBorderPoints[i].count > 1
            if unique[i] {
                edgeBorderPoints[i] = sortFunctions[i](edgeBorderPoints[i])
            }
        }
        boundaryPoints.removeAll()
        for i in 0..<4 {
            if unique[i] {
                for j in 0..<edgeBorderPoints[i].count {
                    boundaryPoints.append(edgeBorderPoints[i][j])
                }
            }
            edgeBorderPoints[i].removeAll()
        }
        if boundaryPoints.count > 1  {
            if boundaryPoints[0].position == 0 {
                let firstPoint = boundaryPoints[0]
                boundaryPoints.remove(at: 0)
                boundaryPoints.append(firstPoint)
            }
            let lastPoint = boundaryPoints[boundaryPoints.count - 1]
            boundaryPoints.remove(at: boundaryPoints.count - 1)
            boundaryPoints.removeDuplicates()
            boundaryPoints.append(lastPoint)
        }
        
        return boundaryPoints
    }
    
    private func sortCGPathBoundaryPointsByBottomEdge(_ points: [CGPathBoundaryPoint]) -> [CGPathBoundaryPoint] {
        return points.sortCGPathBoundaryPointsByBottomEdge()
    }
    
    private func sortCGPathBoundaryPointsByRightEdge(_ points: [CGPathBoundaryPoint]) -> [CGPathBoundaryPoint]{
        return points.sortCGPathBoundaryPointsByRightEdge()
    }
    
    private func sortCGPathBoundaryPointsByTopEdge(_ points: [CGPathBoundaryPoint]) -> [CGPathBoundaryPoint] {
        return points.sortCGPathBoundaryPointsByTopEdge()
    }
    
    private func sortCGPathBoundaryPointsByLeftEdge(_ points: [CGPathBoundaryPoint]) -> [CGPathBoundaryPoint] {
        return points.sortCGPathBoundaryPointsByLeftEdge()
    }
    
    // MARK: - Create CGPath

    func createDataLinePath(fromStrip strip: LineStrip, dataSet: ContourChartDataSetProtocol, startPoint: inout CGPoint, endPoint: inout CGPoint, reverseOrder reverse: Bool, closed: Bool, extraStripList: Bool) -> CGMutablePath? {
        var dataLinePath: CGMutablePath?
        if let dataProvider = self.dataProvider,
           let contours = dataSet.contours,
           strip.count > 0  {
            
            let trans = dataProvider.getTransformer(forAxis: .left)
            let valueToPixelMatrix = trans.valueToPixelMatrix
          
            var stripContours: [CGPoint] = []
            // check there are only 2 boundary touches, else get rid of outer ones and use inner, else messes up code for
            // splitSelfIntersectingCGPath when a multi-contour path touches itself
            var boundaryPositions: [Int]?
            if closed {
                boundaryPositions = [ 0, strip.count - 1]
            }
            else {
                boundaryPositions = contours.searchExtraLineStripOfTwoBoundaryPoints(strip)
            }
            if let _boundaryPositions = boundaryPositions,
               _boundaryPositions[0] != NSNotFound && _boundaryPositions[1] != NSNotFound {
                for pos in _boundaryPositions[0]..<_boundaryPositions[1]+1 {
                    // retreiving index
                    let index = strip[pos];
                    // drawing
//                    let x = contours.getX(at:index)
//                    let y = contours.getY(at:index)
                    let point = CGPoint(x: contours.getX(at:index), y: contours.getY(at:index))
//                    let point = CGPoint(x: ((x - dataSet.xRange.minLimit) * dataSet.scaleX - dataSet.originOfContext.x) * dataSet.scaleOfContext, y: ((y - dataSet.yRange.minLimit) * dataSet.scaleY - dataSet.originOfContext.y) * dataSet.scaleOfContext);
                    stripContours.append(point)
                }
            }
            boundaryPositions?.removeAll()
            
            if stripContours.count > 0 {
                if reverse {
                    stripContours.reverse()
                }
                dataLinePath = newDataLinePath(forViewPoints: stripContours, dataSet: dataSet, useExtraStripList: extraStripList)
                startPoint = stripContours[0].applying(valueToPixelMatrix)
                endPoint = stripContours[stripContours.count - 1].applying(valueToPixelMatrix)
            }
            stripContours.removeAll()
        }
        return dataLinePath
    }
        
    private func newDataLinePath(forViewPoints viewPoints:[CGPoint], dataSet: ContourChartDataSetProtocol, useExtraStripList: Bool) -> CGMutablePath {
        
        if dataSet.interpolationMode == .cubic {
            return newCurvedDataLinePath(forViewPoints: viewPoints, dataSet: dataSet)
        }
        
        let dataLinePath: CGMutablePath = CGMutablePath()
        
        if let dataProvider = self.dataProvider {
            
            let trans = dataProvider.getTransformer(forAxis: .left)
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            let scaleX = (valueToPixelMatrix.a/abs(valueToPixelMatrix.a)) * sqrt(pow(valueToPixelMatrix.a, 2) + pow(valueToPixelMatrix.c, 2))
            let scaleY = -(valueToPixelMatrix.d/abs(valueToPixelMatrix.d)) * sqrt(pow(valueToPixelMatrix.b, 2) + pow(valueToPixelMatrix.d, 2))
            let deltaXLimit: CGFloat = dataSet.maxWidthPixels / scaleX * 2.0
            let deltaYLimit: CGFloat = dataSet.maxHeightPixels / scaleY * 2.0
//            var deltaXLimit: CGFloat, deltaYLimit: CGFloat
//            if let _ = dataSet.fieldBlock {
////                deltaXLimit = dataSet.maxWidthPixels / dataSet.scaleX * 2.0
////                deltaYLimit = dataSet.maxHeightPixels / dataSet.scaleY * 2.0
//
//                deltaXLimit = dataSet.maxWidthPixels / scaleX * 2.0
//                deltaYLimit = dataSet.maxHeightPixels / scaleY * 2.0
//            }
//            else {
//                deltaXLimit = dataSet.maxWidthPixels / 25.0
//                deltaYLimit = dataSet.maxWidthPixels / 33.0
//            }
            
            var lastPoint: CGPoint = viewPoints[0]
            dataLinePath.move(to: lastPoint, transform: valueToPixelMatrix)
            for viewPoint in viewPoints {
                if viewPoint.equalTo(lastPoint) {
                    
                }
                else if (abs(lastPoint.x - viewPoint.x) > deltaXLimit || abs(lastPoint.y - viewPoint.y) > deltaYLimit) && !useExtraStripList {
                    dataLinePath.move(to: viewPoint, transform: valueToPixelMatrix)
                }
                else {
                    dataLinePath.addLine(to: viewPoint, transform: valueToPixelMatrix)
                }
                lastPoint = viewPoint
            }
        }

        return dataLinePath
    }
    
    private func newCurvedDataLinePath(forViewPoints viewPoints: [CGPoint], dataSet: ContourChartDataSetProtocol) -> CGMutablePath {
        var dataLinePath: CGMutablePath = CGMutablePath()
        var lastPointSkipped = true
    
        var lastDrawnPointIndex = viewPoints.count

        if lastDrawnPointIndex > 0 {
            switch dataSet.cubicInterpolation {
                case .normal:
                    dataLinePath = cubicBezierPath(forViewPoints: viewPoints, dataSet: dataSet)
                    
                case .catmullRomUniform:
                    dataLinePath = catmullRomPath(forViewPoints: viewPoints, dataSet: dataSet, alpha: 0.0)
                    
                case .catmullRomCentripetal:
                    dataLinePath = catmullRomPath(forViewPoints: viewPoints, dataSet: dataSet, alpha: 0.5)
                    
                case .catmullCustomAlpha:
                    dataLinePath = catmullRomPath(forViewPoints: viewPoints, dataSet: dataSet, alpha: dataSet.catmullCustomAlpha)
                    
                case .catmullRomChordal:
                    dataLinePath = catmullRomPath(forViewPoints: viewPoints, dataSet: dataSet, alpha: 1.0)
                    
                case .hermite:
                    dataLinePath = hermitePath(forViewPoints: viewPoints, dataSet: dataSet)
            }
        }
        return dataLinePath
    }

    // Compute the control points using the algorithm described at http://www.particleincell.com/blog/2012/bezier-splines/
    // cp1, cp2, and viewPoints should point to arrays of points with at least NSMaxRange(indexRange) elements each.
    private func cubicBezierPath(forViewPoints viewPoints: [CGPoint], dataSet: ContourChartDataSetProtocol) -> CGMutablePath {
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        if let dataProvider = self.dataProvider {

            let trans = dataProvider.getTransformer(forAxis: .left)
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            if viewPoints.count > 2 {
                let n = viewPoints.count - 1

                // rhs vector
                var a: [CGPoint] = Array(repeating: .zero, count: n)
                var b: [CGPoint] = Array(repeating: .zero, count: n)
                var c: [CGPoint] = Array(repeating: .zero, count: n)
                var r: [CGPoint] = Array(repeating: .zero, count: n)
                var cp1: [CGPoint] = Array(repeating: .zero, count: n+1)
                var cp2: [CGPoint] = Array(repeating: .zero, count: n+1)
                // Take an extra point from the left, and an extra from the right.
                // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
                // So in the starting `prev` and `cur`, go -2, -1
                
                var curCGPoint: CGPoint = .zero, prevCGPoint: CGPoint = .zero, nextCGPoint: CGPoint = .zero
                var nextIndex: Int = -1
                
                for j in 0..<n {
//                    prevPrevCGPoint = prevCGPoint
                    prevCGPoint = curCGPoint
                    if nextIndex == j {
                        curCGPoint = nextCGPoint
                    }
                    else {
                        curCGPoint = viewPoints[j]
                    }
                        
                    nextIndex = j + 1 < viewPoints.count ? j + 1 : j
                    nextCGPoint = viewPoints[nextIndex]
                    if j == 0 {
                        // left most segment
                        a[j] = .zero
                        b[j] = CGPoint(x: 2.0, y: 2.0)
                        c[j] = CGPoint(x: 1.0, y: 1.0)
                        r[j] = CGPoint(x: curCGPoint.x + 2.0 * nextCGPoint.x, y: curCGPoint.y + 2.0 * nextCGPoint.y)
                    }
                    else if j == n - 1 {
                        // right segment
                        a[j] = CGPoint(x: 2.0, y: 2.0)
                        b[j] = CGPoint(x: 7.0, y: 7.0)
                        c[j] = .zero
                        r[j] = CGPoint(x: 8.0 * curCGPoint.x + nextCGPoint.x, y: 8.0 * curCGPoint.y + nextCGPoint.y)
                    }
                    else {
                        a[j] = CGPoint(x: 1.0, y: 1.0)
                        b[j] = CGPoint(x: 4.0, y: 4.0)
                        c[j] = CGPoint(x: 1.0, y: 1.0)
                        r[j] = CGPoint(x: 4.0 * curCGPoint.x + 2.0 * nextCGPoint.x, y: 4.0 * curCGPoint.y + 2.0 * nextCGPoint.y)
                    }
                }
                    
                // solve Ax=b with the Thomas algorithm (from Wikipedia)
                var m : CGPoint
                for j in 1..<n {
                    m = CGPoint(x: a[j].x / b[j - 1].x, y: a[j].y / b[j - 1].y)
                    b[j] = CGPoint(x: b[j].x - m.x * c[j - 1].x, y: b[j].y - m.y * c[j - 1].y)
                    r[j] = CGPoint(x: r[j].x - m.x * r[j - 1].x, y: r[j].y - m.y * r[j - 1].y)
                }
                cp1[n] = CGPoint(x: r[n - 1].x / b[n - 1].x, y: r[n - 1].y / b[n - 1].y)
                for j in stride(from: n - 2, to: 1, by: -1) {
                    cp1[j + 1] = CGPoint(x: (r[j].x - c[j].x * cp1[j + 2].x) / b[j].x, y: (r[j].y - c[j].y * cp1[j + 2].y) / b[j].y)
                }
                cp1[1] = CGPoint(x: (r[0].x - c[0].x * cp1[2].x) / b[0].x, y: (r[0].y - c[0].y * cp1[2].y) / b[0].y)
                    
                // we have cp1, now compute cp2
                    
                for j in 1..<n-1 {
                    curCGPoint = viewPoints[j]
                    cp2[j] = CGPoint(x: 2.0 * curCGPoint.x - cp1[j + 1].x, y: 2.0 * curCGPoint.y - cp1[j + 1].y)
                }
                curCGPoint = viewPoints[n-1]
                cp2[n-1] = CGPoint(x: 0.5 * (curCGPoint.x + cp1[n-1].x), y: 0.5 * (curCGPoint.y + cp1[n-1].y))
                    
                // let the spline start
                cubicPath.move(to: curCGPoint, transform: valueToPixelMatrix)
                for j in 1..<n+1 {
                    curCGPoint = viewPoints[j]
                    cubicPath.addCurve(to: curCGPoint, control1: cp1[j], control2: cp2[j], transform: valueToPixelMatrix)
                }
            }
            else {
                let curCGPoint = viewPoints[0]
                let nextCGPoint = viewPoints[1]
                cubicPath.move(to: curCGPoint, transform: valueToPixelMatrix)
                cubicPath.addCurve(to: nextCGPoint, control1: curCGPoint, control2: nextCGPoint, transform: valueToPixelMatrix)
            }

        }
        return cubicPath
    }
    
    // Compute the control points using a catmull-rom spline.
    //  points A pointer to the array which should hold the first control points.
    // points2 A pointer to the array which should hold the second control points.
    // alpha The alpha value used for the catmull-rom interpolation.
    // viewPoints A pointer to the array which holds all view points for which the interpolation should be calculated.
    private func catmullRomPath(forViewPoints viewPoints: [CGPoint], dataSet: ContourChartDataSetProtocol, alpha: CGFloat) -> CGMutablePath {
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        if let dataProvider = self.dataProvider {
            
            let trans = dataProvider.getTransformer(forAxis: .left)
            
            let phaseY = animator.phaseY
            
            
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            if viewPoints.count >= 2 {
                
                let epsilon: CGFloat = CGFloat(1.0e-5) // the minimum point distance. below that no interpolation happens.
                
                // Take an extra point from the left, and an extra from the right.
                // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
                // So in the starting `prev` and `cur`, go -2, -1
                
                var p2 = viewPoints[0]
                var nextIndex: Int = -1
                var p0: CGPoint, p1: CGPoint = .zero, p3: CGPoint = .zero
                    
                // let the spline start
                cubicPath.move(to: CGPoint(x: p2.x, y: p2.y * CGFloat(phaseY)), transform: valueToPixelMatrix)
                
                for j in 1..<viewPoints.count {
                    p0 = p1
                    p1 = p2
                    if nextIndex == j {
                        p2 = p3
                    }
                    else {
                        p2 = viewPoints[j]
                    }
                    nextIndex = j + 1 < viewPoints.count ? j + 1 : j
                    p3 = viewPoints[nextIndex]
                        
                    // distance between the points
                    let d1: CGFloat = hypot(p1.x - p0.x, p1.y - p0.y);
                    let d2: CGFloat = hypot(p2.x - p1.x, p2.y - p1.y);
                    let d3: CGFloat = hypot(p3.x - p2.x, p3.y - p2.y);
                    // constants
                    let d1_a: CGFloat  = pow(d1, alpha)           // d1^alpha
                    let d2_a: CGFloat  = pow(d2, alpha)           // d2^alpha
                    let d3_a: CGFloat  = pow(d3, alpha)           // d3^alpha
                    let d1_2a: CGFloat = pow( d1_a, CGFloat(2.0) ) // d1^alpha^2 = d1^2*alpha
                    let d2_2a: CGFloat = pow( d2_a, CGFloat(2.0) ) // d2^alpha^2 = d2^2*alpha
                    let d3_2a: CGFloat = pow( d3_a, CGFloat(2.0) ) // d3^alpha^2 = d3^2*alpha

                    // calculate the control points
                    // see : http://www.cemyuksel.com/research/catmullrom_param/catmullrom.pdf under point 3.
                    var cp1: CGPoint, cp2: CGPoint // the calculated view points;
                    if abs(d1) <= epsilon  {
                        cp1 = p1
                    }
                    else {
                        let divisor: CGFloat = CGFloat(3.0) * d1_a * (d1_a + d2_a)
                        cp1 = CGPoint(x: (p2.x * d1_2a - p0.x * d2_2a + (2 * d1_2a + 3 * d1_a * d2_a + d2_2a) * p1.x) / divisor, y: (p2.y * d1_2a - p0.y * d2_2a + (2 * d1_2a + 3 * d1_a * d2_a + d2_2a) * p1.y) / divisor )
                    }

                    if abs(d3) <= epsilon {
                        cp2 = p2
                    }
                    else {
                        let divisor: CGFloat = CGFloat(3.0) * d3_a * (d3_a + d2_a)
                        cp2 = CGPoint(x: (d3_2a * p1.x - d2_2a * p3.x + (2 * d3_2a + 3 * d3_a * d2_a + d2_2a) * p2.x) / divisor, y: (d3_2a * p1.y - d2_2a * p3.y + (2 * d3_2a + 3 * d3_a * d2_a + d2_2a) * p2.y) / divisor )
                    }

                    cubicPath.addCurve( to: CGPoint(x: p2.x, y: p2.y * CGFloat(phaseY)),
                                control1: CGPoint(x: cp1.x, y: cp1.y * CGFloat(phaseY)),
                                control2: CGPoint(x: cp2.x, y: cp2.y * CGFloat(phaseY)), transform: valueToPixelMatrix)
                    }
                }
            }
        return cubicPath
    }

    /** @brief Compute the control points using a hermite cubic spline.
     *
     *  If the view points are monotonically increasing or decreasing in both @par{x} and @par{y},
     *  the smoothed curve will be also.
     *
     *  @param points A pointer to the array which should hold the first control points.
     *  @param points2 A pointer to the array which should hold the second control points.
     *  @param viewPoints A pointer to the array which holds all view points for which the interpolation should be calculated.
     *  @param indexRange The range in which the interpolation should occur.
     *  @warning The @par{indexRange} must be valid for all passed arrays otherwise this method crashes.
     **/
    private func hermitePath(forViewPoints viewPoints: [CGPoint], dataSet: ContourChartDataSetProtocol) -> CGMutablePath {
        // See https://en.wikipedia.org/wiki/Cubic_Hermite_spline and https://en.m.wikipedia.org/wiki/Monotone_cubic_interpolation for a discussion of algorithms used.
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        if let dataProvider = self.dataProvider {
            
            let trans = dataProvider.getTransformer(forAxis: .left)
            
            let phaseY = animator.phaseY
            
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            if viewPoints.count >= 2 {
                
                // Take an extra point from the left, and an extra from the right.
                // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
                // So in the starting `prev` and `cur`, go -2, -1
                
                let firstIndex = 1
                var p2 = viewPoints[0]
                var nextIndex: Int = -1
                var p1: CGPoint = .zero, p3: CGPoint = .zero
                    
                // let the spline start
                cubicPath.move(to: p2, transform: valueToPixelMatrix)
            
                let monotonic = monotonicViewPoints(viewPoints, dataSet: dataSet)
                    
                for j in 1..<viewPoints.count {
                    p1 = p2
                    if nextIndex == j {
                        p2 = p3
                    }
                    else {
                        p2 = viewPoints[j]
                    }
                    
                    nextIndex = j + 1 < viewPoints.count ? j + 1 : j
                    p3 = viewPoints[nextIndex]
                    var m = CGVector(dx: 0, dy: 0)
                    if j == firstIndex {
                        let p2 = p3
                        m.dx = p2.x - p1.x
                        m.dy = p2.y - p1.y
                    }
                    else if j == viewPoints.count {
                        let p0 = p1
                        m.dx = p1.x - p0.x
                        m.dy = p1.y - p0.y
                    }
                    else { // index > startIndex && index < numberOfPoints
                        let p0 = p1
                        let p2 = p3
                        m.dx = p2.x - p0.x
                        m.dy = p2.y - p0.y

                        if monotonic {
                            if m.dx > 0 {
                                m.dx = min(p2.x - p1.x, p1.x - p0.x)
                            }
                            else if m.dx < 0 {
                                m.dx = max(p2.x - p1.x, p1.x - p0.x)
                            }

                            if m.dy > 0 {
                                m.dy = min(p2.y - p1.y, p1.y - p0.y)
                            }
                            else if m.dy < 0 {
                                m.dy = max(p2.y - p1.y, p1.y - p0.y)
                            }
                        }
                    }

                    // get control points
                    m.dx /= CGFloat(6.0)
                    m.dy /= CGFloat(6.0)

                    let cp1 = CGPoint(x: p1.x + m.dx, y: p1.y + m.dy)
                    let cp2 = CGPoint(x: p1.x - m.dx, y: p1.y - m.dy)

                    cubicPath.addCurve( to: CGPoint(x: p2.x, y: p2.y * CGFloat(phaseY)),
                                control1: CGPoint(x: cp1.x, y: cp1.y * CGFloat(phaseY)),
                                control2: CGPoint(x: cp2.x, y: cp2.y * CGFloat(phaseY)), transform: valueToPixelMatrix)
                }
            }
        }
        
        return cubicPath
    }
    
    /** @brief Determine whether the plot points form a monotonic series.
     *  @param viewPoints A pointer to the array which holds all view points for which the interpolation should be calculated.
     *  @param indexRange The range in which the interpolation should occur.
     *  @return Returns @YES if the viewpoints are monotonically increasing or decreasing in both @par{x} and @par{y}.
     *  @warning The @par{indexRange} must be valid for all passed arrays otherwise this method crashes.
     **/
    private func monotonicViewPoints(_ viewPoints: [CGPoint], dataSet: ContourChartDataSetProtocol) -> Bool {
        
        if viewPoints.count < 2 {
            return true
        }
        
        
        var foundTrendX = false
        var foundTrendY = false
        var isIncreasingX = false
        var isIncreasingY = false
        
        let startIndex = 0
        let lastIndex  = viewPoints.count - 2
        
        for index in startIndex...lastIndex {
            let p1 = viewPoints[index]
            let p2 = viewPoints[index + 1]
                
            if !foundTrendX {
                if p2.x > p1.x {
                    isIncreasingX = true
                    foundTrendX   = true
                }
                else if p2.x < p1.x {
                    foundTrendX = true
                }
            }
            
            if foundTrendX {
                if isIncreasingX {
                    if p2.x < p1.x {
                        return false
                    }
                }
                else {
                    if p2.x > p1.x {
                        return false
                    }
                }
            }
            
            if !foundTrendY {
                if p2.y > p1.y {
                    isIncreasingY = true
                    foundTrendY   = true
                }
                else if p2.y < p1.y {
                    foundTrendY = true
                }
            }
            
            if foundTrendY {
                if isIncreasingY {
                    if p2.y < p1.y {
                        return false
                    }
                }
                else {
                    if p2.y > p1.y {
                        return false
                    }
                }
            }
        }
        
        return true
    }

    
    // MARK: - YBounds 
    
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
        
        public init(chart: ContourChartDataProvider, dataSet: ContourChartDataSetProtocol, animator: Animator?){
            self.set(chart: chart, dataSet: dataSet, animator: animator)
        }
        
        /// Calculates the minimum and maximum x values as well as the range between them.
        public func set(chart: ContourChartDataProvider, dataSet: ContourChartDataSetProtocol, animator: Animator?) {
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
