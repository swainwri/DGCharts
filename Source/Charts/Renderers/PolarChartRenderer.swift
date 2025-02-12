//
//  PolarChartRenderer.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics


@objc(ChartPolarChartRenderer)
class PolarChartRenderer: LineRadarRenderer {
    
    // NOTE: Unlike the other renderers, LineChartRenderer populates accessibleChartElements in drawCircles due to the nature of its drawing options.
    /// A nested array of elements ordered logically (i.e not in visual/drawing order) for use with VoiceOver.
    private lazy var accessibilityOrderedElements: [[NSUIAccessibilityElement]] = accessibilityCreateEmptyOrderedElements()

    private lazy var accessibilityPointLabels: [String] = {
        guard let chart = chart else { return [] }
        guard let formatter = chart.xAxis.valueFormatter else { return [] }

        let maxEntryCount = chart.polarData?.maxEntryCountSet?.entryCount ?? 0
        return stride(from: 0, to: maxEntryCount, by: 1).map {
            formatter.stringForValue(Double($0), axis: chart.xAxis)
        }
    }()
    
    private var _thetaBounds = ThetaBounds() // Reusable XBounds object

    @objc public weak var chart: PolarChartView?
    
    @objc open weak var dataProvider: PolarChartDataProvider?
    
    @objc public init(dataProvider: PolarChartDataProvider, chart: PolarChartView, animator: Animator, viewPortHandler: ViewPortHandler) {
        
        self.chart = chart
        self.dataProvider = dataProvider
        
        super .init(animator: animator, viewPortHandler: viewPortHandler)
    }
    
    /// Calculates and returns the x-bounds for the given DataSet in terms of index in their values array.
    /// This includes minimum and maximum visible x, as well as range.
    private func thetaBounds(chart: PolarChartDataProvider, dataSet: PolarChartDataSetProtocol, animator: Animator?) -> ThetaBounds {
        return ThetaBounds(chart: chart, dataSet: dataSet, animator: animator)
    }
    
    /// Checks if the provided entry object is in bounds for drawing considering the current animation phase.
    private func isInBounds(entry e: PolarChartDataEntry, dataSet: PolarChartDataSetProtocol) -> Bool {
        
        if let chart = self.chart {
            if chart.majorAxis.gridLinesToChartRectEdges {
                let centre = chart.centerOffsets
                let point = centre.moving(distance: e.radial * chart.factor, atAngle: e.theta, radians: chart.radialAxis.radialAngleMode == .radians)
                return chart.contentRect.contains(point)
            }
            else {
                return e.radial < chart.majorAxis.axisMaximum
            }
        }
        else {
            return false
        }
    
    }
    
    public override func drawData(context: CGContext) {
        if let data = dataProvider?.polarData {
            
            let sets = data.dataSets as? [PolarChartDataSet]
            assert(sets != nil, "Datasets for PolarChartRenderer must conform to IPolarChartDataSet")
            
            let drawDataSet = { self.drawDataSet(context: context, dataSet: $0) }
            sets!.lazy.filter(\.isVisible).forEach(drawDataSet)
        }
    }
    
    @objc public func drawDataSet(context: CGContext, dataSet: PolarChartDataSetProtocol) {
        if dataSet.entryCount < 1 {
            return
        }
        
        context.saveGState()
        
        context.setLineWidth(dataSet.lineWidth)
        if let _lineDashLengths = dataSet.lineDashLengths {
            context.setLineDash(phase: dataSet.lineDashPhase, lengths: _lineDashLengths)
        }
        else {
            context.setLineDash(phase: 0.0, lengths: [])
        }
        context.setLineCap(dataSet.lineCapType)
        
        // if drawing cubic lines is enabled
        switch dataSet.polarMode {
            case .linear, .stepped, .histogram:
                drawLinear(context: context, dataSet: dataSet)
        
            case .cubic:
                switch dataSet.polarCurvedInterpolation {
                    case .normal:
                        drawCubicBezier(context: context, dataSet: dataSet)
                    case .catmullRomUniform:
                        drawCatmullRom(context: context, dataSet: dataSet , alpha: 0)
                    case .catmullRomCentripetal:
                        drawCatmullRom(context: context, dataSet: dataSet , alpha: 0.5)
                    case .catmullRomChordal:
                        drawCatmullRom(context: context, dataSet: dataSet , alpha: 1)
                    case .catmullCustomAlpha:
                        drawCatmullRom(context: context, dataSet: dataSet , alpha: dataSet.polarCatmullCustomAlpha)
                    case .hermite:
                        drawHermite(context: context, dataSet:dataSet)
                    
                }
        }
        
        context.restoreGState()
    }

    private func drawLine(context: CGContext, spline: CGMutablePath, drawingColor: NSUIColor) {
        context.beginPath()
        context.addPath(spline)
        context.setStrokeColor(drawingColor.cgColor)
        context.strokePath()
    }
    
    @objc public func drawCubicBezier1(context: CGContext, dataSet: PolarChartDataSetProtocol) {
        if let dataProvider = dataProvider {

            let trans = dataProvider.getTransformer(forAxis: .major)

            let phase = animator.phaseY
            let centre: CGPoint = .zero

            _thetaBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)

            // get the color that is specified for this position from the DataSet
            let drawingColor = dataSet.colors.first ?? NSUIColor.black
            let intensity = dataSet.cubicIntensity

            // the path for the cubic-spline
            let cubicPath = CGMutablePath()
            let valueToPixelMatrix = trans.valueToPixelMatrix

            if _thetaBounds.range >= 1 {
                
                var cp1: CGPoint = .zero, cp2: CGPoint = .zero
                // Take an extra point from the left, and an extra from the right.
                // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
                // So in the starting `prev` and `cur`, go -2, -1

                let firstIndex = _thetaBounds.min + 1
                if var cur = dataSet.entryForIndex(max(firstIndex - 1, 0)) as? PolarChartDataEntry {
                    var nextIndex: Int = -1
                    var prevPrev: PolarChartDataEntry = PolarChartDataEntry()
                    var prev: PolarChartDataEntry = PolarChartDataEntry()
                    var next: PolarChartDataEntry = cur

//                    var prevPrevCGPoint: CGPoint
                    var prevCGPoint: CGPoint = .zero
                    if let _prev = dataSet.entryForIndex(max(firstIndex - 2, 0))  as? PolarChartDataEntry {
                        prev = _prev
                        prevCGPoint = centre.moving(distance: prev.radial * phase, atAngle: prev.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                    }
                    var curCGPoint: CGPoint = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)

//                    var nextCGPoint: CGPoint = curCGPoint
                    // let the spline start
                    cubicPath.move(to: curCGPoint)

                    for j in _thetaBounds.dropFirst() { // same as firstIndex
                        prevPrev = prev
                        prev = cur
                        
                        //                        prevPrevCGPoint = prevCGPoint
                        prevCGPoint = curCGPoint
                        if nextIndex == j {
                            cur = next
                        }
                        else {
                            if let _cur = dataSet.entryForIndex(j) as? PolarChartDataEntry {
                                cur = _cur
                            }
                            else {
                                break
                            }
                        }
                        curCGPoint = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                        nextIndex = j + 1 < dataSet.entryCount ? j + 1 : j
                        if let _next = dataSet.entryForIndex(nextIndex) as? PolarChartDataEntry {
                            next = _next
                            //                            let nextCGPoint = centre.moving(distance: next.radial * phase, atAngle: next.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                            
                            cp1 = centre.moving(distance: prev.radial + cur.radial - prevPrev.radial * intensity, atAngle: prev.theta + cur.theta - prevPrev.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                            cp2 = centre.moving(distance: cur.radial - next.radial + prev.radial, atAngle:  cur.theta - next.theta + prev.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                            
                            cubicPath.addCurve( to: curCGPoint, control1: cp1, control2: cp2)
                        }
                        else {
                            break
                        }
                    }
                }
            }

            context.saveGState()
            defer { context.restoreGState() }

            if dataSet.isDrawFilledEnabled {
                // Copy this path because we make changes to it
                if let fillPath = cubicPath.mutableCopy() {
                    drawCubicFill(context: context, dataSet: dataSet, spline: fillPath, matrix: valueToPixelMatrix, bounds: _thetaBounds)
                }
            }

            if dataSet.isDrawLineWithGradientEnabled {
                drawGradientLine(context: context, dataSet: dataSet, spline: cubicPath, matrix: valueToPixelMatrix)
            }
            else {
                drawLine(context: context, spline: cubicPath, drawingColor: drawingColor)
            }
        }
    }
    
    // Compute the control points using the algorithm described at http://www.particleincell.com/blog/2012/bezier-splines/
    // cp1, cp2, and viewPoints should point to arrays of points with at least NSMaxRange(indexRange) elements each.
    @objc public func drawCubicBezier(context: CGContext, dataSet: PolarChartDataSetProtocol) {
        if let dataProvider = dataProvider {

            let trans = dataProvider.getTransformer(forAxis: .major)

            let phase = animator.phaseY
            let centre: CGPoint = .zero

            // get the color that is specified for this position from the DataSet
            let drawingColor = dataSet.colors.first ?? NSUIColor.black

            // the path for the cubic-spline
            let cubicPath = CGMutablePath()
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            _thetaBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
            
            var _dataSet: PolarChartDataSet
            if dataSet.polarClosePath,
            let __dataSet = dataSet as? PolarChartDataSet {
                _dataSet = __dataSet.copy() as! PolarChartDataSet
                if let e = dataSet.entryForIndex(0) {
                    _dataSet.append(e)
                    _thetaBounds.max += 1
                    _thetaBounds.range += 1
                }
                if let e = dataSet.entryForIndex(1) {
                    _dataSet.append(e)
                    _thetaBounds.max += 1
                    _thetaBounds.range += 1
                }
            }
            else {
                if let __dataSet = (dataSet as? PolarChartDataSet) {
                    _dataSet = __dataSet
                }
                else {
                    _dataSet = dataSet as! PolarChartDataSet
                }
            }
            
            

            if _thetaBounds.range > 2 {
                let n = _thetaBounds.max - 1

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
                
                
                let firstIndex = _thetaBounds.min + 1
                if var cur = _dataSet.entryForIndex(max(firstIndex - 1, 0)) as? PolarChartDataEntry {
                    var nextIndex: Int = -1
                    var prevPrev: PolarChartDataEntry = PolarChartDataEntry()
                    var prev: PolarChartDataEntry = PolarChartDataEntry()
                    var next: PolarChartDataEntry = cur
                    
                    var prevPrevCGPoint: CGPoint
                    var prevCGPoint: CGPoint = .zero
                    if let _prev = _dataSet.entryForIndex(max(firstIndex - 2, 0)) as? PolarChartDataEntry {
                        prev = _prev
                        prevCGPoint = centre.moving(distance: prev.radial * phase, atAngle: prev.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                    }
                    var curCGPoint: CGPoint = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                    
                    for j in 0..<n { // same as firstIndex
                        prevPrev = prev
                        prev = cur
                        
                        prevPrevCGPoint = prevCGPoint
                        prevCGPoint = curCGPoint
                        if nextIndex == j {
                            cur = next
                        }
                        else {
                            if let _cur = dataSet.entryForIndex(j + _thetaBounds.min) as? PolarChartDataEntry {
                                cur = _cur
                            }
                            else {
                                break
                            }
                        }
                        curCGPoint = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                        nextIndex = j + 1 < dataSet.entryCount ? j + 1 : j
                        if let _next = _dataSet.entryForIndex(nextIndex + _thetaBounds.min) as? PolarChartDataEntry {
                            next = _next
                            let nextCGPoint = centre.moving(distance: next.radial * phase, atAngle: next.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                            
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
                        else {
                            break
                        }
                    }
                    // solve Ax=b with the Thomas algorithm (from Wikipedia)
                    var m : CGPoint
                    for j in 1..<n {
                        m = CGPoint(x: a[j].x / b[j - 1].x, y: a[j].y / b[j - 1].y)
                        b[j] = CGPoint(x: b[j].x - m.x * c[j - 1].x, y: b[j].y - m.y * c[j - 1].y)
                        r[j] = CGPoint(x: r[j].x - m.x * r[j - 1].x, y: r[j].y - m.y * r[j - 1].y)
                    }
                    cp1[_thetaBounds.min + n] = CGPoint(x: r[n - 1].x / b[n - 1].x, y: r[n - 1].y / b[n - 1].y)
                    for j in stride(from: n - 2, to: 0, by: -1) {
                        cp1[_thetaBounds.min + j + 1] = CGPoint(x: (r[j].x - c[j].x * cp1[_thetaBounds.min + j + 2].x) / b[j].x, y: (r[j].y - c[j].y * cp1[_thetaBounds.min + j + 2].y) / b[j].y)
                    }
                    cp1[_thetaBounds.min + 1] = CGPoint(x: (r[0].x - c[0].x * cp1[_thetaBounds.min + 2].x) / b[0].x, y: (r[0].y - c[0].y * cp1[_thetaBounds.min + 2].y) / b[0].y)
                    
                    // we have cp1, now compute cp2
                    
                    for j in _thetaBounds.min+1..<n-1 {
                        cur = _dataSet.entryForIndex(j) as! PolarChartDataEntry
                        curCGPoint = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                        cp2[j] = CGPoint(x: 2.0 * curCGPoint.x - cp1[j + 1].x, y: 2.0 * curCGPoint.y - cp1[j + 1].y)
                    }
                    cur = dataSet.entryForIndex(n-1) as! PolarChartDataEntry
                    curCGPoint = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                    cp2[n-1] = CGPoint(x: 0.5 * (curCGPoint.x + cp1[n-1].x), y: 0.5 * (curCGPoint.y + cp1[n-1].y))
                    
                    // let the spline start
                    if var cur = _dataSet.entryForIndex(max(firstIndex - 1, 0)) as? PolarChartDataEntry {
                        curCGPoint = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                        cubicPath.move(to: curCGPoint)
                        
                        for j in 1..<n/*-1*/ {
                            cur = _dataSet.entryForIndex(j) as! PolarChartDataEntry
                            curCGPoint = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                            cubicPath.addCurve(to: curCGPoint.applying(valueToPixelMatrix), control1: cp1[j].applying(valueToPixelMatrix), control2: cp2[j].applying(valueToPixelMatrix))
                        }
                    }
                }
            }
            else {
                if let cur = dataSet.entryForIndex(0) as? PolarChartDataEntry,
                   let next = dataSet.entryForIndex(1)  as? PolarChartDataEntry {
                    let curCGPoint = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                    let nextCGPoint = centre.moving(distance: next.radial * phase, atAngle: next.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                    cubicPath.move(to: curCGPoint)
                    cubicPath.addCurve(to: nextCGPoint, control1: curCGPoint, control2: nextCGPoint)
                }
            }

            context.saveGState()
            defer { context.restoreGState() }

            if dataSet.isDrawFilledEnabled {
                // Copy this path because we make changes to it
                if let fillPath = cubicPath.mutableCopy() {
                    drawCubicFill(context: context, dataSet: dataSet, spline: fillPath, matrix: valueToPixelMatrix, bounds: _thetaBounds)
                }
            }

            if dataSet.isDrawLineWithGradientEnabled {
                drawGradientLine(context: context, dataSet: dataSet, spline: cubicPath, matrix: valueToPixelMatrix)
            }
            else {
                drawLine(context: context, spline: cubicPath, drawingColor: drawingColor)
            }
        }
    }
    
    // Compute the control points using a catmull-rom spline.
    //  points A pointer to the array which should hold the first control points.
    // points2 A pointer to the array which should hold the second control points.
    // alpha The alpha value used for the catmull-rom interpolation.
    // viewPoints A pointer to the array which holds all view points for which the interpolation should be calculated.
    public func drawCatmullRom(context: CGContext, dataSet: PolarChartDataSetProtocol, alpha: CGFloat) {
        if let dataProvider = dataProvider {
            
            let trans = dataProvider.getTransformer(forAxis: .major)
            
            let phaseY = animator.phaseY
            let centre: CGPoint = .zero
            
            _thetaBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
            
            var _dataSet: PolarChartDataSet
            if dataSet.polarClosePath,
            let __dataSet = dataSet as? PolarChartDataSet {
                _dataSet = __dataSet.copy() as! PolarChartDataSet
                if let e = dataSet.entryForIndex(0) {
                    _dataSet.append(e)
                    _thetaBounds.max += 1
                    _thetaBounds.range += 1
                }
                if let e = dataSet.entryForIndex(1) {
                    _dataSet.append(e)
                    _thetaBounds.max += 1
                    _thetaBounds.range += 1
                }
            }
            else {
                if let __dataSet = (dataSet as? PolarChartDataSet) {
                    _dataSet = __dataSet
                }
                else {
                    _dataSet = dataSet as! PolarChartDataSet
                }
            }
            
            
            
            // get the color that is specified for this position from the DataSet
            let drawingColor = _dataSet.colors.first ?? NSUIColor.black
            
            // the path for the cubic-spline
            let cubicPath = CGMutablePath()
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            if _thetaBounds.range >= 2 {
                
                let epsilon: CGFloat = CGFloat(1.0e-5) // the minimum point distance. below that no interpolation happens.
                
                // Take an extra point from the left, and an extra from the right.
                // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
                // So in the starting `prev` and `cur`, go -2, -1
                
                let firstIndex = _thetaBounds.min + 1
                if var cur = _dataSet.entryForIndex(max(firstIndex - 1, 0)) as? PolarChartDataEntry {
                    var nextIndex: Int = -1

                    var prev: PolarChartDataEntry
                    var next: PolarChartDataEntry = cur
                    
                    var p0: CGPoint
                    var p1: CGPoint = .zero
                    if let _prev = _dataSet.entryForIndex(max(firstIndex - 2, 0))  as? PolarChartDataEntry {
                        prev = _prev
                        p1 = centre.moving(distance: prev.radial * phaseY, atAngle: prev.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                    }
                    var p2: CGPoint = centre.moving(distance: cur.radial * phaseY, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                    // let the spline start
                    cubicPath.move(to: p2)
                    
                    for j in _thetaBounds.dropFirst() { // same as firstIndex
                        prev = cur
                        p0 = p1
                        p1 = p2
                        if nextIndex == j {
                            cur = next
                        }
                        else {
                            if let _cur = _dataSet.entryForIndex(j) as? PolarChartDataEntry {
                                cur = _cur
                            }
                            else {
                                break
                            }
                        }
                        p2 = centre.moving(distance: cur.radial * phaseY, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                        nextIndex = j + 1 < _dataSet.entryCount ? j + 1 : j
                        if let _next = _dataSet.entryForIndex(nextIndex) as? PolarChartDataEntry {
                            next = _next
                            let p3 = centre.moving(distance: next.radial * phaseY, atAngle: next.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
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

                            cubicPath.addCurve( to: p2, control1: cp1, control2: cp2)
                        }
                        else {
                            break
                        }
                    }
                }
            }
            
            context.saveGState()
            defer { context.restoreGState() }
            
            if dataSet.isDrawFilledEnabled {
                // Copy this path because we make changes to it
                if let fillPath = cubicPath.mutableCopy() {
                    drawCubicFill(context: context, dataSet: dataSet, spline: fillPath, matrix: valueToPixelMatrix, bounds: _thetaBounds)
                }
            }
            
            if dataSet.isDrawLineWithGradientEnabled {
                drawGradientLine(context: context, dataSet: dataSet, spline: cubicPath, matrix: valueToPixelMatrix)
            }
            else {
                drawLine(context: context, spline: cubicPath, drawingColor: drawingColor)
            }
        }
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
    public func drawHermite(context: CGContext, dataSet: PolarChartDataSetProtocol) {
        // See https://en.wikipedia.org/wiki/Cubic_Hermite_spline and https://en.m.wikipedia.org/wiki/Monotone_cubic_interpolation for a discussion of algorithms used.
        if let dataProvider = dataProvider {
            
            let trans = dataProvider.getTransformer(forAxis: .major)
            
            let phase = animator.phaseY
            let centre: CGPoint = .zero
            
            _thetaBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
            
            var _dataSet: PolarChartDataSet
            if dataSet.polarClosePath,
            let __dataSet = dataSet as? PolarChartDataSet {
                _dataSet = __dataSet.copy() as! PolarChartDataSet
                if let e = dataSet.entryForIndex(0) {
                    _dataSet.append(e)
                    _thetaBounds.max += 1
                    _thetaBounds.range += 1
                }
                if let e = dataSet.entryForIndex(1) {
                    _dataSet.append(e)
                    _thetaBounds.max += 1
                    _thetaBounds.range += 1
                }
            }
            else {
                if let __dataSet = (dataSet as? PolarChartDataSet) {
                    _dataSet = __dataSet
                }
                else {
                    _dataSet = dataSet as! PolarChartDataSet
                }
            }
            
            
            
            // get the color that is specified for this position from the DataSet
            let drawingColor = _dataSet.colors.first ?? NSUIColor.black
            
            // the path for the cubic-spline
            let cubicPath = CGMutablePath()
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            if _thetaBounds.range >= 2 {
                
                // Take an extra point from the left, and an extra from the right.
                // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
                // So in the starting `prev` and `cur`, go -2, -1
                
                let firstIndex = _thetaBounds.min + 1
                if var cur = _dataSet.entryForIndex(max(firstIndex - 1, 0)) as? PolarChartDataEntry {
                    var nextIndex: Int = -1

                    var prev: PolarChartDataEntry
                    var next: PolarChartDataEntry = cur
                    
                    var p1: CGPoint
                    if let _prev = _dataSet.entryForIndex(max(firstIndex - 2, 0))  as? PolarChartDataEntry {
                        prev = _prev
                        p1 = centre.moving(distance: prev.radial * phase, atAngle: prev.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                    }
                    var p2: CGPoint = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                    // let the spline start
                    cubicPath.move(to: p2)
                    
                    let monotonic = monotonicViewPoints(dataSet)
                    
                    for j in _thetaBounds.dropFirst() { // same as firstIndex
                        prev = cur
                        p1 = p2
                        if nextIndex == j {
                            cur = next
                        }
                        else {
                            if let _cur = _dataSet.entryForIndex(j) as? PolarChartDataEntry {
                                cur = _cur
                            }
                            else {
                                break
                            }
                        }
                        p2 = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                        nextIndex = j + 1 < dataSet.entryCount ? j + 1 : j
                        if let _next = _dataSet.entryForIndex(nextIndex) as? PolarChartDataEntry {
                            next = _next
                            let p3 = centre.moving(distance: next.radial * phase, atAngle: next.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                            var m = CGVector(dx: 0, dy: 0)
                            if j == firstIndex {
                                let p2 = p3
                                m.dx = p2.x - p1.x
                                m.dy = p2.y - p1.y
                            }
                            else if j == _thetaBounds.max {
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

                            let rhsControlPoint = CGPoint(x: p1.x + m.dx, y: p1.y + m.dy)
                            let lhsControlPoint = CGPoint(x: p1.x - m.dx, y: p1.y - m.dy)

                            cubicPath.addCurve( to: p2, control1: lhsControlPoint, control2: rhsControlPoint)
                        }
                        else {
                            break
                        }
                    }
                }
            }
            
            context.saveGState()
            defer { context.restoreGState() }
            
            if dataSet.isDrawFilledEnabled {
                // Copy this path because we make changes to it
                if let fillPath = cubicPath.mutableCopy() {
                    drawCubicFill(context: context, dataSet: dataSet, spline: fillPath, matrix: valueToPixelMatrix, bounds: _thetaBounds)
                }
            }
            
            if dataSet.isDrawLineWithGradientEnabled {
                drawGradientLine(context: context, dataSet: dataSet, spline: cubicPath, matrix: valueToPixelMatrix)
            }
            else {
                drawLine(context: context, spline: cubicPath, drawingColor: drawingColor)
            }
        }
        
    }
    
    /** @brief Determine whether the plot points form a monotonic series.
     *  @param viewPoints A pointer to the array which holds all view points for which the interpolation should be calculated.
     *  @param indexRange The range in which the interpolation should occur.
     *  @return Returns @YES if the viewpoints are monotonically increasing or decreasing in both @par{x} and @par{y}.
     *  @warning The @par{indexRange} must be valid for all passed arrays otherwise this method crashes.
     **/
    private func monotonicViewPoints(_ dataSet: PolarChartDataSetProtocol) -> Bool {
        
        if _thetaBounds.range < 2 {
            return true
        }
        
        if let dataProvider = dataProvider {
            
            
            let phase = animator.phaseY
            let centre: CGPoint = .zero
            
            _thetaBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
            
            var foundTrendTheta = false
            var foundTrendRadial = false
            var isIncreasingTheta = false
            var isIncreasingRadial = false
            
            let startIndex = _thetaBounds.min;
            let lastIndex  = _thetaBounds.max - 2
            
            for index in startIndex...lastIndex {
                if let cur = dataSet.entryForIndex(index) as? PolarChartDataEntry,
                let next = dataSet.entryForIndex(index + 1) as? PolarChartDataEntry {
                    let p1 = centre.moving(distance: cur.radial * phase, atAngle: cur.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                    let p2 = centre.moving(distance: next.radial * phase, atAngle: next.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                    
                    if !foundTrendTheta {
                        if p2.x > p1.x {
                            isIncreasingTheta = true
                            foundTrendTheta   = true
                        }
                        else if p2.x < p1.x {
                            foundTrendTheta = true
                        }
                    }
                    
                    if foundTrendTheta {
                        if isIncreasingTheta {
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
                    
                    if !foundTrendRadial {
                        if p2.y > p1.y {
                            isIncreasingRadial = true
                            foundTrendRadial   = true
                        }
                        else if p2.y < p1.y {
                            foundTrendRadial = true
                        }
                    }
                    
                    if foundTrendRadial {
                        if isIncreasingRadial {
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
                else {
                    break
                }
            }
        }
        return true
    }
    
    public func drawCubicFill(context: CGContext, dataSet: PolarChartDataSetProtocol, spline: CGMutablePath, matrix: CGAffineTransform, bounds: ThetaBounds) {
        if let dataProvider = dataProvider,
           bounds.range > 0 {
            let centre: CGPoint = self.chart?.centerOffsets ?? .zero
            if let dataEntry1 = dataSet.entryForIndex(bounds.min + bounds.range) as? PolarChartDataEntry,
               let dataEntry2 = dataSet.entryForIndex(bounds.min)  as? PolarChartDataEntry {
                let fillMinRadius = dataSet.polarFillFormatter?.getFillLineRadius(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0
                
                let pt1 = centre.moving(distance: fillMinRadius, atAngle: dataEntry1.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(matrix)
                let pt2 = centre.moving(distance: fillMinRadius, atAngle: dataEntry2.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(matrix)
                
                spline.addLine(to: pt1)
                spline.addLine(to: pt2)
                spline.closeSubpath()
                
                if let fill = dataSet.fill {
                    drawFilledPath(context: context, path: spline, fill: fill, fillAlpha: dataSet.fillAlpha)
                }
                else {
                    drawFilledPath(context: context, path: spline, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
                }
            }
        }
    }
    
    private var _lineSegments = [CGPoint](repeating: CGPoint(), count: 2)
    
    @objc public func drawLinear(context: CGContext, dataSet: PolarChartDataSetProtocol) {
        
        if dataSet.polarMode == .cubic { // Cubic curves handled separately
            return
        }
        
        if let dataProvider = dataProvider {
            
            let trans = dataProvider.getTransformer(forAxis: .major)
            
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            let entryCount = dataSet.entryCount
            let isDrawSteppedEnabled = dataSet.polarMode == .stepped
            let pointsPerEntryPair = isDrawSteppedEnabled ? 4 : 2
            
            let phase = animator.phaseY
            let centre: CGPoint = .zero
            
            _thetaBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
            
            // if drawing filled is enabled
            if dataSet.isDrawFilledEnabled && entryCount > 0 {
                drawLinearFill(context: context, dataSet: dataSet, trans: trans, bounds: _thetaBounds)
            }
            
            context.saveGState()
            defer { context.restoreGState() }
            
            // more than 1 color
            if dataSet.colors.count > 1, !dataSet.isDrawLineWithGradientEnabled {
                if _lineSegments.count != pointsPerEntryPair {
                    // Allocate once in correct size
                    _lineSegments = [CGPoint](repeating: CGPoint(), count: pointsPerEntryPair)
                }
                
                for j in _thetaBounds.dropLast() {
                    if let e  = dataSet.entryForIndex(j) as? PolarChartDataEntry {
                        
                        var point = centre.moving(distance: e.radial * phase, atAngle: e.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                        
                        _lineSegments[0].x = point.x
                        _lineSegments[0].y = point.y
                        
                        if j < _thetaBounds.max {
                            if let eNext = dataSet.entryForIndex(j + 1) as? PolarChartDataEntry {
                                
                                point = centre.moving(distance: eNext.radial * phase, atAngle: eNext.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                                
                                if isDrawSteppedEnabled {
                                    _lineSegments[1] = CGPoint(x: point.x, y: _lineSegments[0].y)
                                    _lineSegments[2] = _lineSegments[1]
                                    _lineSegments[3] = point
                                }
                                else {
                                    _lineSegments[1] = point
                                }
                            }
                        }
                        else {
                            _lineSegments[1] = _lineSegments[0]
                        }
                        
                        _lineSegments = _lineSegments.map { $0.applying(valueToPixelMatrix) }
                        
                        if !viewPortHandler.isInBounds(point: _lineSegments[0]) {
                            break
                        }
                        
                        // Determine the start and end coordinates of the line, and make sure they differ.
                        // & make sure the lines don't do shitty things outside bounds
                        if let firstCoordinate = _lineSegments.first,
                           let lastCoordinate = _lineSegments.last,
                           firstCoordinate != lastCoordinate,
                           viewPortHandler.isInBounds(point: firstCoordinate) && viewPortHandler.isInBounds(point: lastCoordinate) {
                            // get the color that is set for this line-segment
                            context.setStrokeColor(dataSet.color(atIndex: j).cgColor)
                            context.strokeLineSegments(between: _lineSegments)
                        }
                    }
                }
            }
            else  { // only one color per dataset
                if let _ = dataSet.entryForIndex(_thetaBounds.min) {
                    
//                    var firstPoint: CGPoint = .zero
                    var lastPointSkipped = true
                    var lastPoint: CGPoint = .zero
                    
                    let path = CGMutablePath()
                    
                    for i in _thetaBounds.min..<_thetaBounds.range + _thetaBounds.min {
                        if let e1 = dataSet.entryForIndex(i == 0 ? 0 : (i - 1)) as? PolarChartDataEntry {
                            
                            let point = centre.moving(distance: e1.radial * phase, atAngle: e1.theta, radians: chart?.radialAxis.radialAngleMode == .radians).applying(valueToPixelMatrix)
                            
                            if lastPointSkipped {
                                path.move(to: point)
                                lastPointSkipped = false
//                                firstPoint = point
                            }
                            else {
                                switch dataSet.polarMode {
                                    case .linear:
                                        path.addLine(to: point)
                                    case .stepped:
                                        path.addLine(to: CGPoint(x: point.x, y: lastPoint.y))
                                        path.addLine(to: point)
                                    case .histogram:
                                        let x = (lastPoint.x + point.x) / 2
                                        if dataSet.polarHistogram != .skipFirst {
                                            path.addLine(to: CGPoint(x: x, y: lastPoint.y))
                                        }
                                        if dataSet.polarHistogram != .skipSecond {
                                            path.addLine(to: CGPoint(x: x, y: point.y))
                                        }
                                        path.addLine(to: point)
                                    case .cubic:
                                        break
                                }
                                
                                
                                
                            }
                            lastPoint = point
                        }
                    }
                    if dataSet.polarClosePath,
                       let e2 = dataSet.entryForIndex(0 ) as? PolarChartDataEntry {
                        let endPoint = centre.moving(distance: e2.radial * phase, atAngle: e2.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                        path.addLine(to: endPoint)
                    }
                    
                    if !lastPointSkipped {
                        if dataSet.isDrawLineWithGradientEnabled {
                            drawGradientLine(context: context, dataSet: dataSet, spline: path, matrix: valueToPixelMatrix)
                        }
                        else {
                            context.beginPath()
                            context.addPath(path)
                            context.setStrokeColor(dataSet.color(atIndex: 0).cgColor)
                            context.strokePath()
                        }
                    }
                }
            }
        }
    }
    
    public func drawLinearFill(context: CGContext, dataSet: PolarChartDataSetProtocol, trans: Transformer, bounds: ThetaBounds) {
        if let dataProvider = dataProvider {
            
            var fillMinRadius: CGFloat = 0
            if let _fillMinRadius = dataSet.polarFillFormatter?.getFillLineRadius(dataSet: dataSet, dataProvider: dataProvider) {
                fillMinRadius = _fillMinRadius
            }
            let filled = generateFilledPath(dataSet: dataSet, fillMinRadius: fillMinRadius, bounds: bounds, matrix: trans.valueToPixelMatrix)
            
            if let fill = dataSet.fill {
                drawFilledPath(context: context, path: filled, fill: fill, fillAlpha: dataSet.fillAlpha)
            }
            else {
                drawFilledPath(context: context, path: filled, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
            }
        }
    }
    
    /// Generates the path that is used for filled drawing.
    private func generateFilledPath(dataSet: PolarChartDataSetProtocol, fillMinRadius: CGFloat, bounds: ThetaBounds, matrix: CGAffineTransform) -> CGPath {
        
        let phase = animator.phaseY
        let isDrawSteppedEnabled = dataSet.polarMode == .stepped
        let matrix = matrix
        let centre: CGPoint = self.chart?.centerOffsets ?? .zero
        
        let filled = CGMutablePath()
        
        if let e = dataSet.entryForIndex(bounds.min) as? PolarChartDataEntry {
            filled.move(to: centre.moving(distance: fillMinRadius * phase, atAngle: e.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians), transform: matrix)
            filled.addLine(to: centre.moving(distance: e.radial * phase, atAngle: e.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians), transform: matrix)
        }
        
        // create a new path
        for x in bounds.min+1..<bounds.range + bounds.min {
            if let e = dataSet.entryForIndex(x)  as? PolarChartDataEntry {
                let pointE = centre.moving(distance: e.radial * phase, atAngle: e.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                if isDrawSteppedEnabled {
                    if let ePrev = dataSet.entryForIndex(x - 1) as? PolarChartDataEntry{
                        let pointEPrev =  centre.moving(distance: ePrev.radial * phase, atAngle: e.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                        filled.addLine(to: CGPoint(x: pointE.x, y: pointEPrev.y), transform: matrix)
                    }
                }
                filled.addLine(to: pointE, transform: matrix)
            }
        }
        
        // close up
        if let e = dataSet.entryForIndex(bounds.range + bounds.min) as? PolarChartDataEntry {
            filled.addLine(to: centre.moving(distance: fillMinRadius * phase, atAngle: e.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians), transform: matrix)
        }
        filled.closeSubpath()
        
        return filled
    }
    
    public override func drawValues(context: CGContext) {
        if let dataProvider = dataProvider,
           let data = dataProvider.polarData,
           isDrawingValuesAllowed(dataProvider: dataProvider) {
            
            let phase = animator.phaseY
            let centre: CGPoint = .zero
            
            for i in data.indices {
                if let dataSet = data[i] as? PolarChartDataSetProtocol,
                   shouldDrawValues(forDataSet: dataSet) {
                    
                    let valueFont = dataSet.valueFont
                    let formatter = dataSet.pointFormatter
                    let angleRadians = dataSet.valueLabelAngle.DEG2RAD
                    let trans = dataProvider.getTransformer(forAxis: .major)
                    let valueToPixelMatrix = trans.valueToPixelMatrix
                    let iconsOffset = dataSet.iconsOffset
                    // make sure the values do not interfer with the circles
                    var valOffset = Int(dataSet.circleRadius * 1.75)
                    
                    if !dataSet.isDrawCirclesEnabled {
                        valOffset = valOffset / 2
                    }
                    _thetaBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
                    
                    for j in 0..<_thetaBounds.max {
                        if let e = dataSet.entryForIndex(j) as? PolarChartDataEntry {
            
                            let pt = centre.moving(distance: e.radial * phase, atAngle: e.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians).applying(valueToPixelMatrix)
                            if viewPortHandler.isInBounds(point: pt) {
                                if dataSet.isDrawValuesEnabled {
                                    let text = formatter.stringForPoint(entry: e, dataSetIndex: i, viewPortHandler: viewPortHandler)
                                    let size: CGSize = text.size(withAttributes: [.font: valueFont])
                                    context.drawText(text, at: CGPoint(x: pt.x + CGFloat((Double(valOffset) + size.width / 2) * cos(e.theta)), y: pt.y - CGFloat((Double(valOffset) + size.height / 2) * sin(e.theta)) - valueFont.lineHeight), align: .center, angleRadians: angleRadians, attributes: [.font: valueFont, .foregroundColor: dataSet.valueTextColorAt(j)])
                                }
                                
                                if let icon = e.icon,
                                   dataSet.isDrawIconsEnabled {
                                    context.drawImage(icon, atCenter: CGPoint(x: pt.x + iconsOffset.x, y: pt.y + iconsOffset.y), size: icon.size)
                                }
                            }
                        }
                        else {
                            break
                        }
                    }
                }
            }
        }
    }
    
    public override func drawExtras(context: CGContext) {
        drawCircles(context: context)
    }
    
    private func drawCircles(context: CGContext) {
        if let dataProvider = dataProvider,
           let data = dataProvider.polarData {
            
            let phase = animator.phaseY
            
            var pt = CGPoint()
            var rect = CGRect()
            let centre: CGPoint = .zero
            
            // If we redraw the data, remove and repopulate accessible elements to update label values and frames
            accessibleChartElements.removeAll()
            accessibilityOrderedElements = accessibilityCreateEmptyOrderedElements()
            
            // Make the chart header the first element in the accessible elements array
            if let chart = dataProvider as? PolarChartView {
                let element = createAccessibleHeader(usingChart: chart, andData: data, withDefaultDescription: "Polar Chart")
                accessibleChartElements.append(element)
            }
            
            context.saveGState()
            
            for i in data.indices {
                if let dataSet = data[i] as? PolarChartDataSetProtocol {
                    
                    // Skip Circles and Accessibility if not enabled,
                    // reduces CPU significantly if not needed
                    if !dataSet.isVisible || !dataSet.isDrawCirclesEnabled || dataSet.entryCount == 0 {
                        continue
                    }
                    
                    let trans = dataProvider.getTransformer(forAxis: .none)
                    let valueToPixelMatrix = trans.valueToPixelMatrix
                    
                    _thetaBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
                    
                    let circleRadius = dataSet.circleRadius
                    let circleDiameter = circleRadius * 2.0
                    let circleHoleRadius = dataSet.circleHoleRadius
                    let circleHoleDiameter = circleHoleRadius * 2.0
                    
                    let drawCircleHole = dataSet.isDrawCircleHoleEnabled && circleHoleRadius < circleRadius &&  circleHoleRadius > 0.0
                    let drawTransparentCircleHole = drawCircleHole && (dataSet.circleHoleColor == nil || dataSet.circleHoleColor == NSUIColor.clear)
                    
                    for j in _thetaBounds {
                        if let e = dataSet.entryForIndex(j) as? PolarChartDataEntry {
                            
                            pt = centre.moving(distance: e.radial * phase, atAngle: e.theta).applying(valueToPixelMatrix)
                            
                            // make sure the circles don't do shitty things outside bounds
                            if !viewPortHandler.isInBounds(point: pt) {
                                continue
                            }
                            
                            // Accessibility element geometry
                            let scaleFactor: CGFloat = 3
                            let accessibilityRect = CGRect(x: pt.x - (scaleFactor * circleRadius), y: pt.y - (scaleFactor * circleRadius), width: scaleFactor * circleDiameter, height: scaleFactor * circleDiameter)
                            // Create and append the corresponding accessibility element to accessibilityOrderedElements
                            if let chart = dataProvider as? PolarChartView {
                                let element = createAccessibleElement(withIndex: j, container: chart, dataSet: dataSet, dataSetIndex: i) { element in
                                    element.accessibilityFrame = accessibilityRect
                                }
                                
                                accessibilityOrderedElements[i].append(element)
                            }
                            
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
                        else {
                            break
                        }
                    }
                }
            }
            
            context.restoreGState()
            
            // Merge nested ordered arrays into the single accessibleChartElements.
            accessibleChartElements.append(contentsOf: accessibilityOrderedElements.flatMap { $0 } )
            accessibilityPostLayoutChangedNotification()
        }
    }
    
    public override func drawHighlighted(context: CGContext, indices: [Highlight]) {
        if let dataProvider = dataProvider,
           let data = dataProvider.polarData {
    
            let chartRadialMax = dataProvider.chartRadialMax
            
            let phase = animator.phaseY
            let centre: CGPoint = .zero
            
            context.saveGState()
            
            for high in indices {
                if let set = data[high.dataSetIndex] as? PolarChartDataSetProtocol,
                   set.isHighlightEnabled {
                    
                    if let e = set.entryForThetaValue(high.x, closestToRadial: high.y),
                       isInBounds(entry: e, dataSet: set) {
                        
                        context.setStrokeColor(set.highlightColor.cgColor)
                        context.setLineWidth(set.highlightLineWidth)
                        if let _highlightLineDashLengths = set.highlightLineDashLengths {
                            context.setLineDash(phase: set.highlightLineDashPhase, lengths: _highlightLineDashLengths)
                        }
                        else {
                            context.setLineDash(phase: 0.0, lengths: [])
                        }
                        
                        let point = centre.moving(distance: e.radial * phase, atAngle: e.theta, radians: chart?.radialAxis.radialAngleMode ?? .radians == .radians)
                        
                        if point.x > chartRadialMax || point.y > chartRadialMax {
                            continue
                        }
                        
                        let trans = dataProvider.getTransformer(forAxis: .major)
                        
                        let pt = trans.pixelForValues(x: point.x, y: point.y)
                        
                        high.setDraw(pt: pt)
                        
                        // draw the lines
                        drawHighlightLines(context: context, point: pt, set: set)
                    }
                }
            }
            
            context.restoreGState()
        }
    }

    func drawGradientLine(context: CGContext, dataSet: PolarChartDataSetProtocol, spline: CGPath, matrix: CGAffineTransform) {
        if let gradientPositions = dataSet.gradientPositions {
            // `insetBy` is applied since bounding box
            // doesn't take into account line width
            // so that peaks are trimmed since
            // gradient start and gradient end calculated wrong
            let boundingBox = spline.boundingBox
                .insetBy(dx: -dataSet.lineWidth / 2, dy: -dataSet.lineWidth / 2)

            if !boundingBox.isNull, !boundingBox.isInfinite, !boundingBox.isEmpty  {
                
                let gradientStart = CGPoint(x: 0, y: boundingBox.minY)
                let gradientEnd = CGPoint(x: 0, y: boundingBox.maxY)
                let gradientColorComponents: [CGFloat] = dataSet.colors.reversed().reduce(into: []) { (components, color) in
                        if let (r, g, b, a) = color.nsuirgba  {
                            components += [r, g, b, a]
                        }
                    }
                let gradientLocations: [CGFloat] = gradientPositions.reversed().map { (position) in
                        let location = CGPoint(x: boundingBox.minX, y: position).applying(matrix)
                        let normalizedLocation = (location.y - boundingBox.minY) / (boundingBox.maxY - boundingBox.minY)
                        return normalizedLocation.clamped(to: 0...1)
                    }
                
                let baseColorSpace = CGColorSpaceCreateDeviceRGB()
                if let gradient = CGGradient(colorSpace: baseColorSpace, colorComponents: gradientColorComponents, locations: gradientLocations, count: gradientLocations.count) {
                    
                    context.saveGState()
                    defer { context.restoreGState() }
                    
                    context.beginPath()
                    context.addPath(spline)
                    context.replacePathWithStrokedPath()
                    context.clip()
                    context.drawLinearGradient(gradient, start: gradientStart, end: gradientEnd, options: [])
                }
            }
        }
        else {
            assertionFailure("Must set `gradientPositions if `dataSet.isDrawLineWithGradientEnabled` is true")
            return
        }
        
    }
    
    public func getTransformer() -> Transformer {
        return Transformer(viewPortHandler: self.viewPortHandler)
    }
    
    private func createAccessibleElement(withDescription description: String, container: PolarChartView, dataSet: PolarChartDataSetProtocol, modifier: (NSUIAccessibilityElement) -> ()) -> NSUIAccessibilityElement {

        let element = NSUIAccessibilityElement(accessibilityContainer: container)
        element.accessibilityLabel = description

        // The modifier allows changing of traits and frame depending on highlight, rotation, etc
        modifier(element)

        return element
    }
    
    
    public func isDrawingValuesAllowed(dataProvider: PolarChartDataProvider?) -> Bool {
        if let data = dataProvider?.polarData {
            return data.entryCount <= dataProvider?.maxVisibleCount ?? 0
        }
        else {
            return false
        }
        
    }
    
    /// Creates a nested array of empty subarrays each of which will be populated with NSUIAccessibilityElements.
    /// This is marked internal to support HorizontalBarChartRenderer as well.
    private func accessibilityCreateEmptyOrderedElements() -> [[NSUIAccessibilityElement]] {
        if let chart = dataProvider as? PolarChartView  {
        
            let dataSetCount = chart.polarData?.dataSetCount ?? 0
        
            return Array(repeating: [NSUIAccessibilityElement](), count: dataSetCount)
        }
        else {
            return []
        }
    }

    /// Creates an NSUIAccessibleElement representing the smallest meaningful bar of the chart
    /// i.e. in case of a stacked chart, this returns each stack, not the combined bar.
    /// Note that it is marked internal to support subclass modification in the HorizontalBarChart.
    private func createAccessibleElement(withIndex idx: Int, container: PolarChartView, dataSet: PolarChartDataSetProtocol, dataSetIndex: Int, modifier: (NSUIAccessibilityElement) -> ()) -> NSUIAccessibilityElement {
        let element = NSUIAccessibilityElement(accessibilityContainer: container)
        
        if let e = dataSet.entryForIndex(idx),
           let dataProvider = dataProvider {
        
            let elementPointText = dataSet.pointFormatter.stringForPoint(entry: e, dataSetIndex: dataSetIndex, viewPortHandler: viewPortHandler)
            
            let dataSetCount = dataProvider.polarData?.dataSetCount ?? -1
            let doesContainMultipleDataSets = dataSetCount > 1
            
            element.accessibilityLabel = "\(doesContainMultipleDataSets ? (dataSet.label ?? "")  + ", " : "") : \(elementPointText)"
            
            modifier(element)
        }
        return element
    }
    
    /// Class representing the bounds of the current viewport in terms of indices in the values array of a DataSet.
    public class ThetaBounds {
        /// minimum visible entry index
        public var min: Int = 0

        /// maximum visible entry index
        public var max: Int = 0

        /// range of visible entry indices
        public var range: Int = 0

        public init() {
            
        }
        
        public init(chart: PolarChartDataProvider, dataSet: PolarChartDataSetProtocol, animator: Animator?) {
            self.set(chart: chart, dataSet: dataSet, animator: animator)
        }
        
        /// Calculates the minimum and maximum x values as well as the range between them.
        public func set(chart: PolarChartDataProvider, dataSet: PolarChartDataSetProtocol, animator: Animator?) {
             
            let phaseX = Swift.max(0.0, Swift.max/*min*/(1.0, animator?.phaseX ?? 1.0))
//            let phaseY = Swift.max(0.0, Swift.min(1.0, animator?.phaseY ?? 1.0))
            
            let low = chart.lowestVisibleTheta
            let high = chart.highestVisibleTheta
            
            if let entryFrom = dataSet.entryForThetaValue(low, closestToRadial: .nan, rounding: .down),
               let entryTo = dataSet.entryForThetaValue(high, closestToRadial: .nan, rounding: .up) {
                self.min = dataSet.entryIndex(entry: entryFrom)
                self.max = dataSet.entryIndex(entry: entryTo)
                range = Int(Double(self.max - self.min) * phaseX)
            }
            else {
                self.min = 0
                self.max = 0
                range = 0
            }
            
        }
    }
}

extension PolarChartRenderer.ThetaBounds: RangeExpression {
    public func relative<C>(to collection: C) -> Swift.Range<Int> where C : Collection, Bound == C.Index {
        return Swift.Range<Int>(min...min + range)
    }

    public func contains(_ element: Int) -> Bool {
        return (min...min + range).contains(element)
    }
}

extension PolarChartRenderer.ThetaBounds: Sequence {
    public struct Iterator: IteratorProtocol {
        private var iterator: IndexingIterator<ClosedRange<Int>>
        
        fileprivate init(min: Int, max: Int) {
            self.iterator = (min...max).makeIterator()
        }
        
        public mutating func next() -> Int? {
            return self.iterator.next()
        }
    }
    
    func makeIterator() -> Iterator {
        return Iterator(min: self.min, max: self.min + self.range)
    }
}

extension PolarChartRenderer.ThetaBounds: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "min:\(self.min), max:\(self.max), range:\(self.range)"
    }
}

