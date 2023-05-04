//
//  ContourChartDataSet.swift
//  Charts
//
//  Created by Steve Wainwright on 15/04/2023.
//

import Foundation
import CoreGraphics

public typealias ContourChartDataSetFieldBlock = ((Double, Double) -> Double)

public class ContourChartDataSet: LineRadarChartDataSet, ContourChartDataSetProtocol, ContourChartViewDelegate {
    
    @objc public weak var delegate: ContourChartViewDelegate?
    
    /**
     *  @brief Enumeration of Contour plot interpolation algorithms
    **/
    @objc(ContourChartMode)
    public enum Mode: Int {
        case linear
        case cubic
    }

    /**
     *  @brief Enumeration of Contour plot cubic interpolation style options
     **/
    @objc(ContourChartCubicInterpolation)
    public enum CubicInterpolation: Int, CaseIterable {
        case normal                ///< Standard Curved Interpolation (Bezier Curve)
        case catmullRomUniform    ///< Catmull-Rom Spline Interpolation with alpha = @num{0.0}.
        case catmullRomCentripetal ///< Catmull-Rom Spline Interpolation with alpha = @num{0.5}.
        case catmullRomChordal   ///< Catmull-Rom Spline Interpolation with alpha = @num{1.0}.
        case catmullCustomAlpha   ///< Catmull-Rom Spline Interpolation with a custom alpha value.
        case hermite           ///< Hermite Cubic Spline Interpolation
        
        public var description: String {
            get {
                switch self {
                    case .normal:
                        return "Bezier"
                    case .catmullRomUniform:
                        return "Catmull Rom Uniform"
                    case .catmullRomCentripetal:
                        return "Catmull Rom Centripetal"
                    case .catmullRomChordal:
                        return "Catmull Rom Chordal"
                    case .catmullCustomAlpha:
                        return "Catmull Rom Chordal Alpha"
                    case .hermite:
                        return "Hermite"
                }
            }
        }
        
        public static var count: Int {
            return Int(CubicInterpolation.hermite.rawValue + 1)
        }
    }
    
    @objc public override convenience init(entries: [ChartDataEntry], label: String) {
        
        self.init()
        
        // default color
        colors.append(NSUIColor.blue)
        // default color
        circleColors.append(NSUIColor.darkGray)
        valueColors.append(.labelOrBlack)
        
        self.label = label
        
        self.replaceEntries(entries)
    }
    
    // MARK: - Data functions and accessors
    
    /// identifier other than a chart title
    public var identifier: String?
    
    /** @property BOOL usesEvenOddClipRule
     *  @brief If @YES, the even-odd rule is used to draw the arrow, otherwise the non-zero winding number rule is used.
     *  @see <a href="http://developer.apple.com/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_paths/dq_paths.html#//apple_ref/doc/uid/TP30001066-CH211-TPXREF106">Filling a Path</a> in the Quartz 2D Programming Guide.
     **/
    public var usesEvenOddClipRule: Bool = true
    
    public var contours: Contours?
    
    public var maxFxy: Double {
        get {
            if let _entries = entries as? [FieldChartDataEntry] {
                return _entries.map( { $0.magnitude } ).reduce(-Double.infinity,  { Swift.max($0, $1) })
            }
            else {
                return .infinity
            }
        }
    }
    
    public var interpolationMode: Mode = .linear
    public var cubicInterpolation: CubicInterpolation = .normal
    
    /// the catmullRom custom Alpha value
    ///
    /// **default**: 0.25
    private var _catmullCustomAlpha: Double = 0.25

    /// the catmullRom custom Alpha value 0 to 1,
    /// **default**: 0.25, max 1.00, min 0.0
    public var catmullCustomAlpha: Double {
        get {
            return _catmullCustomAlpha
        }
        set {
            _catmullCustomAlpha = newValue.clamped(to: 0...1.0)
        }
    }
    
    public var extrapolateToLimits: Bool = true
    public var functionPlot: Bool = true
    public var hidden: Bool = false
    public var alignsPointsToPixels: Bool = false
    public var fieldBlock: ContourChartDataSetFieldBlock? // block to F(x,y) function
    
    private var _limits: [CGFloat] = [ -1, 1, -1, 1 ]
    
    public var limits: [CGFloat] {
        get { return _limits }
        set {
            _limits = newValue
            self.xRange = Range(from: Double(_limits[0]), to: Double(_limits[1]))
            self.yRange = Range(from: Double(_limits[2]), to: Double(_limits[3]))
        }
    }
    
    public var minFunctionValue: CGFloat = 0
    public var maxFunctionValue: CGFloat = 1
    
    public var fillIsoCurves: Bool = false
    public var hasDiscontinuity: Bool = false
    
    public var noIsoCurves: Int = 9
    public var noColumnsFirst: Int = 64
    public var noRowsFirst: Int = 64
    public var noColumnsSecondary: Int = 1024
    public var noRowsSecondary: Int = 1024
    
    public var easyOnTheEye: Bool = false
    
    public var xRange: Range = Range(from: -1, to: 1)
    public var yRange: Range = Range(from: -1, to: 1)
    public var originOfContext: CGPoint = .zero
    public var scaleOfContext: CGFloat = 1.0
    public var initialXRange: Range = Range(from: -1, to: 1)
    public var initialYRange: Range = Range(from: -1, to: 1)
    
    public var previousLimits: [CGFloat] = []
    public var previousFillIsoCurves: Bool = false
    
    public var noActualIsoCurves: Int = 9
    
    public var maxWidthPixels: CGFloat = 0
    public var maxHeightPixels: CGFloat = 0
    public var scaleX: CGFloat = 1
    public var scaleY: CGFloat = 1
    public var greatestContourBox: CGRect = .zero
    public var extraWidth: CGFloat = 0
    public var extraHeight: CGFloat = 0
    
    public var needsIsoCurvesUpdate: Bool = false
    public var firstRendition: Bool = true
    public var needsIsoCurvesRelabel: Bool = false
    
    public var isoCurvesIndices: [Int] = []
    
    public weak var renderer: ContourChartRenderer?
    
#if os(OSX)
    public var macOSImage: NSImage?
#endif
    
    public var imageFilePath = String(format: "%@layer.png", NSTemporaryDirectory())
    private var filePath = String(format: "%@contours.bin", NSTemporaryDirectory())
    
    @objc(ContourShape)
    public enum Shape: Int {
        case square
        case circle
        case triangle
        case cross
        case x
        case chevronUp
        case chevronDown
    }
    
    /// The size the scatter shape will have
    public var contourShapeSize = CGFloat(10.0)
    
    /// The radius of the hole in the shape (applies to Square, Circle and Triangle)
    /// **default**: 0.0
    public var contourShapeHoleRadius: CGFloat = 0.0
    
    /// Color for the hole in the shape. Setting to `nil` will behave as transparent.
    /// **default**: nil
    public var contourShapeHoleColor: NSUIColor? = nil
    
    /// Sets the ContourrShape this DataSet should be drawn with.
    /// This will search for an available ShapeRenderer and set this renderer for the DataSet
    @objc public func setContourShape(_ shape: Shape) {
        self.shapeRenderer = ContourChartDataSet.renderer(forShape: shape)
    }
    
    /// The IShapeRenderer responsible for rendering this DataSet.
    /// This can also be used to set a custom IShapeRenderer aside from the default ones.
    /// **default**: `SquareShapeRenderer`
    public var shapeRenderer: ShapeRenderer? = SquareShapeRenderer()
    
    @objc public class func renderer(forShape shape: Shape) -> ShapeRenderer {
        switch shape {
            case .square: return SquareShapeRenderer()
            case .circle: return CircleShapeRenderer()
            case .triangle: return TriangleShapeRenderer()
            case .cross: return CrossShapeRenderer()
            case .x: return XShapeRenderer()
            case .chevronUp: return ChevronUpShapeRenderer()
            case .chevronDown: return ChevronDownShapeRenderer()
        }
    }
    
    
// MARK: - Contouring
    
    /// Used to replace all entries of a data set while retaining styling properties.
    /// This is a separate method from a setter on `entries` to encourage usage
    /// of `Collection` conformances.
    ///
    /// - Parameter entries: new entries to replace existing entries in the dataset
    @objc
    public override func replaceEntries(_ entries: [ChartDataEntry]) {
        
        if var _entries = entries as? [FieldChartDataEntry] {
            // need to sort the Field in to x columns of y rows, in order to redeem YBounds on each x column
            _entries.sort(by: {  $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x } )
            super.replaceEntries(_entries)
        }
        else {
            super.replaceEntries(entries)
        }
        
        notifyDataSetChanged()
    }
    
    public func calculateContourLines(plotAreaSize: CGSize) -> Void {
        if self.fieldBlock == nil {
            self.fieldBlock = { x, y in
                let functionValue: Double = sin(x) * sin(y)
                return functionValue
            }
        }
        
        var _limits: [Double] = Array(repeating: 0, count: 4)
        if !self.extrapolateToLimits && !self.functionPlot {
            _limits[0] = self.limits[0]
            _limits[1] = self.limits[1]
            _limits[2] = self.limits[2]
            _limits[3] = self.limits[3]
        }
        else {
            if self.xRange.length > self.yRange.length {
                if self.limits[0] == -.greatestFiniteMagnitude && self.limits[1] == .greatestFiniteMagnitude {
                    _limits[0] = self.xRange.start
                    _limits[1] = self.xRange.end
                    _limits[2] = self.yRange.midPoint - self.xRange.length / 2.0
                    _limits[3] = self.yRange.midPoint + self.xRange.length / 2.0
                }
                else {
                    _limits[0] = self.xRange.minLimit > self.limits[0] ? self.xRange.minLimit : self.limits[0]
                    _limits[1] = self.xRange.maxLimit < self.limits[1] ? self.xRange.maxLimit : self.limits[1]
                    _limits[2] = self.yRange.minLimit > self.limits[2] ? self.yRange.minLimit : self.limits[2]
                    _limits[3] = self.yRange.maxLimit < self.limits[3] ? self.yRange.maxLimit : self.limits[3]
                }
            }
            else {
                if self.limits[2] == -.greatestFiniteMagnitude && self.limits[3] == -.greatestFiniteMagnitude {
                    _limits[2] = self.yRange.start
                    _limits[3] = self.yRange.end
                    _limits[0] = self.xRange.midPoint - self.yRange.length / 2.0
                    _limits[1] = self.xRange.midPoint + self.yRange.length / 2.0
                }
                else {
                    _limits[2] = self.yRange.minLimit > self.limits[2] ? self.yRange.minLimit : self.limits[2]
                    _limits[3] = self.yRange.maxLimit < self.limits[3] ? self.yRange.maxLimit : self.limits[3]
                    _limits[0] = self.xRange.minLimit > self.limits[0] ? self.xRange.minLimit : self.limits[0]
                    _limits[1] = self.xRange.maxLimit < self.limits[1] ? self.xRange.maxLimit : self.limits[1]
                }
            }
        }
        self.maxWidthPixels = plotAreaSize.width
        self.maxHeightPixels = plotAreaSize.height
        self.scaleX = self.maxWidthPixels / CGFloat(self.xRange.length)
        self.scaleY = self.maxHeightPixels / CGFloat(self.yRange.length)
        
        var previousGreatestContourBox: CGRect = CGRect(x: (_limits[0] - self.xRange.minLimit) * self.scaleX, y: (_limits[2] - self.yRange.minLimit) * self.scaleY, width: (_limits[1] - _limits[0]) * self.scaleX, height: (_limits[3] - _limits[2]) * self.scaleY)
        
        var limitPoints: [CGPoint] = [ CGPoint(x: previousGreatestContourBox.origin.x, y: previousGreatestContourBox.origin.y),
                                       CGPoint(x: previousGreatestContourBox.origin.x + previousGreatestContourBox.size.width, y: previousGreatestContourBox.origin.y  + previousGreatestContourBox.size.height) ]
    
        
        var workingNoColumnsFirst = self.noColumnsFirst
        var workingNoRowsFirst = self.noRowsFirst
        var workingNoColumnsSecondary = self.noColumnsSecondary
        var workingNoRowsSecondary = self.noRowsSecondary
        
        if abs(self.xRange.length - self.initialXRange.length) > 0.001 || abs(self.yRange.length - self.initialYRange.length) > 0.001 || self.previousFillIsoCurves != self.fillIsoCurves || self.firstRendition {
            self.needsIsoCurvesUpdate = true
        }
        
        if !self.extrapolateToLimits && !self.functionPlot {
            let constantColumns: Int = Int(ceil((_limits[1] - _limits[0]) / self.xRange.length))
            workingNoColumnsFirst = constantColumns * self.noColumnsFirst
            workingNoColumnsSecondary = constantColumns * self.noColumnsSecondary
            let constantRows: Int = Int(ceil((_limits[3] - _limits[2]) / self.yRange.length))
            workingNoRowsFirst = constantRows * self.noRowsFirst
            workingNoRowsSecondary = constantRows * self.noRowsSecondary
        }
        else {
            if self.xRange.start > self.limits[0] || self.xRange.end < self.limits[1] {
                let constant = Int((self.limits[1] - self.limits[0]) / (_limits[1] - _limits[0]))
                workingNoColumnsFirst = constant * self.noColumnsFirst
                workingNoColumnsSecondary = constant * self.noColumnsSecondary
            }
            if self.yRange.start > self.limits[2] || self.yRange.end < self.limits[3] {
                let constant = Int((self.limits[3] - self.limits[2]) / (_limits[3] - _limits[2]))
                workingNoRowsFirst = constant * self.noRowsFirst
                workingNoRowsSecondary = constant * self.noRowsSecondary
            }
        }
        
        // get extra drawing size if symbols/lines on border
        self.extraWidth = self.lineWidth
        self.extraHeight = self.lineWidth
        
        self.extraWidth =  Swift.max(self.contourShapeSize, self.extraWidth)
        self.extraHeight = Swift.max(self.contourShapeSize , self.extraHeight)
    
        
        // here we are going to generate contour planes based on max/min FunctionValue
            // then go through each plane and plot the points, lets try to make steps easy on the eye
        var _adjustedMinFunctionValue: Double = 0, _adjustedMaxFunctionValue: Double = 0, adjustedStep: Double = 0
        if self.easyOnTheEye && !Utilities.easyOnTheEyeScaling(fMin: self.minFunctionValue, fMax: self.maxFunctionValue, N: self.noIsoCurves, valueMin: &_adjustedMinFunctionValue, valueMax: &_adjustedMaxFunctionValue, step: &adjustedStep) {
        }
        else {
            _adjustedMinFunctionValue = CGFloat(lrint(floor(self.minFunctionValue)))
            _adjustedMaxFunctionValue = CGFloat(lrint(ceil(self.maxFunctionValue)))
            adjustedStep = (self.maxFunctionValue - self.minFunctionValue) / Double(self.noIsoCurves - 1)
        }
        self.noActualIsoCurves = self.noIsoCurves
        
        var planesValues: [Double] = Array(repeating: 0, count: Int(self.noActualIsoCurves))
        for iPlane in 0..<Int(self.noActualIsoCurves) {
            planesValues[iPlane] = _adjustedMinFunctionValue + Double(iPlane) * adjustedStep
        }
        if planesValues[Int(self.noActualIsoCurves) - 1] < _adjustedMaxFunctionValue {
            planesValues[Int(self.noActualIsoCurves) - 1] = _adjustedMaxFunctionValue
        }
        _limits[0] = self.limits[0]
        _limits[1] = self.limits[1]
        _limits[2] = self.limits[2]
        _limits[3] = self.limits[3]
        contours = Contours(noIsoCurves: self.noActualIsoCurves, isoCurveValues: planesValues, limits: _limits)
        if let _fieldBlock = self.fieldBlock {
            contours?.fieldBlock = _fieldBlock
        }
            
        // for contour analysis of data nor extrapolated to limits, will have to pass through a number of times
        // especially using Kriging Surface Interpolation to make sure the whole field is covered
        // function contour will only run through once
        var repeatContoursCalculation: Int = 3
        while ( repeatContoursCalculation > 0 ) {
            contours?.setFirstGridDimensionColumns(cols: workingNoColumnsFirst, rows: workingNoRowsFirst)
            contours?.setSecondaryGridDimensionColumns(cols: workingNoColumnsSecondary, rows: workingNoRowsSecondary)
            contours?.initialiseMemory()
            if !self.firstRendition && self.fillIsoCurves != self.previousFillIsoCurves && (contours?.readPlanesFromDisk(filePath) ?? false) {
                self.greatestContourBox = .zero
            }
            else {
                self.firstRendition = false
                contours?.generateAndCompactStrips()
                let _ = contours?.writePlanesToDisk(filePath)
            }
            
            if self.isoCurvesIndices.count > 0 {
                self.isoCurvesIndices.removeAll()
            }
            if let isoCurvesLists = contours?.getIsoCurvesLists() {
                for i in 0..<isoCurvesLists.count {
                    contours?.dumpPlane(i)
                    if let stripList = contours?.getStripList(forIsoCurve: i),
                       stripList.count > 0 {
                        self.isoCurvesIndices.append(i)
                        
                        var stripEndsOnBoundary = false
                        if !self.extrapolateToLimits && !self.functionPlot {
                            var _startPoint: CGPoint = .zero, _endPoint: CGPoint = .zero
                            var plane: Int = self.isoCurvesIndices[0]
                            if let stripList = contours?.getStripList(forIsoCurve: plane) {
                                let strip = stripList[0]
                                if let _renderer = self.renderer,
                                   let dataLineClosedPath = _renderer.createDataLinePath(fromStrip: strip, dataSet: self, startPoint: &_startPoint, endPoint: &_endPoint, reverseOrder: false, closed: true, extraStripList: false) {
                                    if !_startPoint.equalTo(_endPoint) {
                                        dataLineClosedPath.addLine(to: _startPoint)
                                    }
                                    self.greatestContourBox = dataLineClosedPath.boundingBoxOfPath
                                }
                                
                                for iPlane in 0..<self.isoCurvesIndices.count {
                                    plane = self.isoCurvesIndices[iPlane]
                                    if let stripList = contours?.getStripList(forIsoCurve: plane) {
                                        for pos in 0..<stripList.count {
                                            let strip = stripList[pos]
                                            if let _contours = contours,
                                               strip.count > 0 {
                                                stripEndsOnBoundary = stripEndsOnBoundary || (_contours.isNodeOnBoundary(strip[0]) || _contours.isNodeOnBoundary(strip[strip.count - 1]))
                                                if let renderer = self.renderer,
                                                   let dataLineClosedPath = renderer.createDataLinePath(fromStrip: strip, dataSet: self, startPoint: &_startPoint, endPoint: &_endPoint, reverseOrder: false, closed:true, extraStripList: false) {
                                                    if !_startPoint.equalTo(_endPoint) {
                                                        dataLineClosedPath.addLine(to: _startPoint)
                                                    }
                                                    self.greatestContourBox = self.greatestContourBox.union(dataLineClosedPath.boundingBoxOfPath)
#if DEBUG
    #if os(OSX)
                                                    let bezierPath1 = NSBezierPath(cgPath: dataLineClosedPath)
    #else
                                                    let bezierPath1 = UIBezierPath(cgPath: dataLineClosedPath)
    #endif
                                                    print(bezierPath1.bounds)
#endif
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        print(String(format: "greatestContourBox: %f %f %f %f", self.greatestContourBox.origin.x, self.greatestContourBox.origin.y, self.greatestContourBox.size.width, self.greatestContourBox.size.height))
                        print(String(format: "previousGreatestContourBox: %f %f %f %f", previousGreatestContourBox.origin.x, previousGreatestContourBox.origin.y, previousGreatestContourBox.size.width, previousGreatestContourBox.size.height))
                        
                        if !self.extrapolateToLimits && !self.functionPlot && !self.greatestContourBox.equalTo(.zero) && (self.greatestContourBox.equalTo(previousGreatestContourBox) || stripEndsOnBoundary)  {
                            previousGreatestContourBox = self.greatestContourBox
                            repeatContoursCalculation -= 1
                            if repeatContoursCalculation <= 0 {
                                break
                            }
                            _limits[0] = (self.greatestContourBox.origin.x - self.greatestContourBox.size.width) / self.scaleX + self.xRange.minLimit
                            _limits[1] = (self.greatestContourBox.origin.x + self.greatestContourBox.size.width * 2.0) / self.scaleX + self.xRange.minLimit
                            _limits[2] = (self.greatestContourBox.origin.y - self.greatestContourBox.size.height) / self.scaleY + self.yRange.minLimit
                            _limits[3] = (self.greatestContourBox.origin.y + self.greatestContourBox.size.height * 2.0) / self.scaleY + self.yRange.minLimit
                            if ceil((_limits[1] - _limits[0]) / (previousLimits[1] - previousLimits[0])) >= 2 || ceil((_limits[3] - _limits[2]) / (previousLimits[3] - previousLimits[2])) >= 2  {
                                //                            limit0 = _limits[0];
                                //                            limit1 = _limits[1];
                                //                            limit2 = _limits[2];
                                //                            limit3 = _limits[3];
                                //                        self.noColumnsFirst *= 2;
                                //                        self.noRowsFirst *= 2;
                                self.noColumnsSecondary *= 2
                                self.noRowsSecondary *= 2
                            }
                            contours?.setLimits(_limits)
                        }
                        else {
                            repeatContoursCalculation = 0
                        }
                    }
                }
            }
        }
        
        
        if let _contours = self.contours {
    
            self.needsIsoCurvesRelabel = true
            self.isoCurvesValues = []
            
            for value in _contours.getContourPlanes() {
                self.isoCurvesValues?.append(value)
            }
            self.noActualIsoCurves = _contours.getContourPlanes().count
            self.isoCurvesNoStrips = []
            self.isoCurvesLabelsPositions = []
            self.isoCurvesLabelsRotations = []
            self.isoCurvesLineColours = []
            
            for plane in 0..<self.noActualIsoCurves {
                if let stripList = _contours.getStripList(forIsoCurve: plane),
                    !stripList.isEmpty {
                    self.isoCurvesNoStrips?.append(stripList.count)
                    // position one set of contour labels
                    var positionsPerStrip: [CGPoint] = []
                    positionsPerStrip.reserveCapacity(stripList.count)
                    var rotationsPerStrip: [CGFloat] = []
                    rotationsPerStrip.reserveCapacity(stripList.count)
                    self.isoCurvesNoStrips?.append(stripList.count)
                    for pos in 0..<stripList.count {
                        let strip = stripList[pos]
                        if strip.count > 5 {
                            var pos2 = (strip.count - 1) / 8; // * pos / pStripList->used;
                            if pos2 >= strip.count {
                                pos2 = strip.count - 1
                            }
                            var index = strip[pos2] // retreiving index
                            let x = _contours.getX(at: index)
                            let y = _contours.getY(at: index)
                            let point = CGPoint(x: x, y: y)
                            // try to rotate label to parallel contour
                            if pos2 + 2 > strip.count - 1 {
                                index = strip[strip.count - 1]
                            }
                            else {
                                index = strip[pos2 + 2]
                            }
                            var rotation = atan2(y - _contours.getY(at: index), x - _contours.getY(at: index))
                            if rotation > .pi / 2.0 {
                                rotation -= .pi
                            }
                            else if rotation < -.pi / 2.0 {
                                rotation += .pi
                            }
                            positionsPerStrip.append(point)
                            rotationsPerStrip.append(rotation)
                        }
                    }
                    if positionsPerStrip.count > 0 {
                        self.isoCurvesLabelsPositions?.append(positionsPerStrip)
                        self.isoCurvesLabelsRotations?.append(rotationsPerStrip)
                    }
                    else {
                        self.isoCurvesLabelsPositions?.append([])
                        self.isoCurvesLabelsRotations?.append([])
                    }
                }
                else {
                    self.isoCurvesNoStrips?.append(0)
                    self.isoCurvesLabelsPositions?.append([])
                    self.isoCurvesLabelsRotations?.append([])
                }
                self.isoCurvesLineColours?.append(NSUIColor(red: CGFloat(plane) / CGFloat(_contours.noPlanes), green: 1 - CGFloat(plane) / CGFloat(_contours.noPlanes), blue: 0.0, alpha: 1))
            }
        }
    }
    
    private func averageFillColour(betweenIndex index0: Int, and index1: Int) -> NSUIColor? {
        
        var avg: NSUIColor? = .clear
        let colorspace = CGColorSpaceCreateDeviceRGB()
        if var color1 = self.isoCurvesLineColours?[index0].cgColor,
           var color2 = self.isoCurvesLineColours?[index1].cgColor {
            var components1: [CGFloat]?, components2: [CGFloat]?
            if let _components1 = color1.components {
                if color1.numberOfComponents < 4 {
                    color1 = CGColor(colorSpace: colorspace, components: _components1)!
                }
                else {
                    components1 = _components1
                }
            }
            if let _components2 = color2.components {
                if color2.numberOfComponents < 4 {
                    color2 = CGColor(colorSpace: colorspace, components: _components2)!
                }
                else {
                    components2 = _components2
                }
            }
            
            
            if let model1 = color1.colorSpace?.model,
               let model2 = color2.colorSpace?.model,
               model1 != .rgb || model2 != .rgb {
                print("no rgb colorspace")
                avg = NSUIColor(cgColor: color1)
            }
            else if let _components1 = components1,
                let _components2 = components2 {
                avg = NSUIColor(red: (_components1[0] + _components2[0]) / 2.0, green: (_components1[1] + _components2[1]) / 2.0, blue: (_components1[2] + _components2[2]) / 2.0, alpha: (_components1[3] + _components2[3]) / 2.0)
            }
        }
        return avg
    }
    
    // MARK: - Delegates
    
    public func setupCustomisedColoursEtc() {
        if let _delegate = self.delegate,
           let _isoCurvesValues = self.isoCurvesValues {
            // get customised isocurve colours
            if _delegate.responds(to: #selector(ContourChartViewDelegate.chartIsoCurvesLineColours(dataSet:lineColours:))) {
                var colours: [NSUIColor] = Array(repeating: .clear, count: _isoCurvesValues.count)
                do {
                    let unsafePtr = UnsafeMutablePointer<NSUIColor>.allocate(capacity: _isoCurvesValues.count)
                    unsafePtr.initialize(repeating: .clear, count: _isoCurvesValues.count)
                    defer {
                        unsafePtr.deinitialize(count: _isoCurvesValues.count)
                        unsafePtr.deallocate()
                    }
                    _delegate.chartIsoCurvesLineColours?(dataSet: self, lineColours: unsafePtr)
                    
                    let bufferPointer = UnsafeBufferPointer(start: unsafePtr, count: _isoCurvesValues.count)
                    for (index, value) in bufferPointer.enumerated() {
                        colours[index] = value
                    }
                }
                self.isoCurvesLineColours = colours
            }
            else if _delegate.responds(to: #selector(ContourChartViewDelegate.chartIsoCurvesLineColour(at:dataSet:lineColour:))) {
                self.isoCurvesLineColours = []
                for plane in 0..<_isoCurvesValues.count {
                    var colour: NSUIColor = .clear
                    _delegate.chartIsoCurvesLineColour?(at: plane, dataSet: self, lineColour: &colour)
                    self.isoCurvesLineColours?.append(colour)
                }
            }
            
            // get customised isocurve fills
            if self.isIsoCurveFillsUsingColour {
                if _delegate.responds(to: #selector(ContourChartViewDelegate.chartIsoCurvesColourFills(dataSet:fills:))) {
                    var fills: [ColorFill] = Array(repeating: ColorFill(color: .clear), count: _isoCurvesValues.count)
                    let unsafePtr = UnsafeMutablePointer<ColorFill>.allocate(capacity: _isoCurvesValues.count)
                    unsafePtr.initialize(repeating: ColorFill(color: .clear), count: _isoCurvesValues.count)
                    do {
                        defer {
                            unsafePtr.deinitialize(count: _isoCurvesValues.count)
                            unsafePtr.deallocate()
                        }
                        _delegate.chartIsoCurvesColourFills?(dataSet: self, fills: unsafePtr)
                        
                        let bufferPointer = UnsafeBufferPointer(start: unsafePtr, count: _isoCurvesValues.count)
                        for (index, value) in bufferPointer.enumerated() {
                            fills[index] = value
                        }
                    }
                    self.isoCurvesColourFills = fills
                }
                else if _delegate.responds(to: #selector(ContourChartViewDelegate.chartIsoCurvesColourFill(at:dataSet:fill:))) {
                    self.isoCurvesColourFills = []
                    for plane in 0..<_isoCurvesValues.count {
                        var fill: ColorFill = ColorFill(color: .clear)
                        _delegate.chartIsoCurvesColourFill?(at: plane, dataSet: self, fill: &fill)
                        self.isoCurvesColourFills?.append(fill)
                    }
                }
                else {
                    self.isoCurvesColourFills = []
                    for plane in 0..<self.noActualIsoCurves-1 {
                        if var averageColour = averageFillColour(betweenIndex: plane, and: plane + 1) {
                            averageColour = averageColour.withAlphaComponent(0.4)
                            let colourFill = ColorFill(color: averageColour)
                            self.isoCurvesColourFills?.append(colourFill)
                        }
                    }
                    let colourFill = ColorFill(color: self.isoCurvesLineColours?[self.noActualIsoCurves-1].withAlphaComponent(0.4) ?? .clear)
                    
                    self.isoCurvesColourFills?.append(colourFill)
                }
            }
            else {
                if _delegate.responds(to: #selector(ContourChartViewDelegate.chartIsoCurvesImageFills(dataSet:fills:))) {
                    var fills = Array(repeating: ImageFill(image: NSUIImage()), count: _isoCurvesValues.count)
                    let unsafePtr = UnsafeMutablePointer<ImageFill>.allocate(capacity: _isoCurvesValues.count)
                    unsafePtr.initialize(repeating: ImageFill(image: NSUIImage()), count: _isoCurvesValues.count)
                    do {
                        defer {
                            unsafePtr.deinitialize(count: _isoCurvesValues.count)
                            unsafePtr.deallocate()
                        }
                        _delegate.chartIsoCurvesImageFills?(dataSet: self, fills: unsafePtr)
                        
                        let bufferPointer = UnsafeBufferPointer(start: unsafePtr, count: _isoCurvesValues.count)
                        for (index, value) in bufferPointer.enumerated() {
                            fills[index] = value
                        }
                    }
                    self.isoCurvesImageFills = fills
                }
                else if _delegate.responds(to: #selector(ContourChartViewDelegate.chartIsoCurvesImageFill(at:dataSet:fill:))) {
                    self.isoCurvesImageFills = []
                    for plane in 0..<_isoCurvesValues.count {
                        var fill: ImageFill = ImageFill(image: NSUIImage())
                        _delegate.chartIsoCurvesImageFill?(at: plane, dataSet: self, fill: &fill)
                        self.isoCurvesImageFills?.append(fill)
                    }
                }
            }
        }
        else {
            
        }
    }
    
    // MARK: - Styling functions and accessors
    
    @objc public var isoCurvesLabelFont: NSUIFont = .systemFont(ofSize: 10.0)
    @objc public var isoCurvesLabelTextColor: NSUIColor = .labelOrBlack
    @objc public var isoCurvesLabelFormatter: NumberFormatter = NumberFormatter()
    
    @objc public var isoCurvesLineColour: NSUIColor = .gray
    @objc public var isoCurvesLineWidth: CGFloat = 0.5
    @objc public var isoCurvesLineDashPhase: CGFloat = 0.0
    @objc public var isoCurvesLineDashLengths: [CGFloat]?
    
    public var isoCurvesLineColours: [NSUIColor]?
    public var isIsoCurveFillsUsingColour: Bool = true
    public var isoCurvesColourFills: [ColorFill]?
    public var isoCurvesImageFills: [ImageFill]?
    public var isoCurvesFillings: [ContourFill]?
    public var isoCurvesValues: [Double]?
    public var isoCurvesNoStrips: [Int]?
    public var isoCurvesLabelsPositions: [[CGPoint]]?
    public var isoCurvesLabelsRotations: [[CGFloat]]?
    
    public var isDrawIsoCurvesLabelsEnabled: Bool {
        get { return drawIsoCurvesLabelsEnabled }
    }
    
    public var drawIsoCurvesLabelsEnabled: Bool = false
    
    /// Custom formatter that is used instead of the auto-formatter if set
    public lazy var pointFormatter: PointFormatter = DefaultPointFormatter()
    
    /// The radius of the drawn circles.
    public var circleRadius = CGFloat(8.0)
    
    /// The hole radius of the drawn circles
    public var circleHoleRadius = CGFloat(4.0)
    
    public var circleColors = [NSUIColor]()
    
    /// - Returns: The color at the given index of the DataSet's circle-color array.
    /// Performs a IndexOutOfBounds check by modulus.
    public func getCircleColor(atIndex index: Int) -> NSUIColor? {
        let size = circleColors.count
        let index = index % size
        if index >= size {
            return nil
        }
        return circleColors[index]
    }
    
    /// Sets the one and ONLY color that should be used for this DataSet.
    /// Internally, this recreates the colors array and adds the specified color.
    public func setCircleColor(_ color: NSUIColor) {
        circleColors.removeAll(keepingCapacity: false)
        circleColors.append(color)
    }
    
    public func setCircleColors(_ colors: NSUIColor...) {
        circleColors.removeAll(keepingCapacity: false)
        circleColors.append(contentsOf: colors)
    }
    
    /// Resets the circle-colors array and creates a new one
    public func resetCircleColors(_ index: Int) {
        circleColors.removeAll(keepingCapacity: false)
    }
    
    /// If true, drawing circles is enabled
    public var drawCirclesEnabled = true
    
    /// `true` if drawing circles for this DataSet is enabled, `false` ifnot
    public var isDrawCirclesEnabled: Bool { return drawCirclesEnabled }
    
    /// The color of the inner circle (the circle-hole).
    public var circleHoleColor: NSUIColor? = NSUIColor.white
    
    /// `true` if drawing circles for this DataSet is enabled, `false` ifnot
    public var drawCircleHoleEnabled = true
    
    /// `true` if drawing the circle-holes is enabled, `false` ifnot.
    public var isDrawCircleHoleEnabled: Bool { return drawCircleHoleEnabled }
    
    
    public func getFirstLastIndexInEntries(forEntryX e: ChartDataEntry) -> [Int]? {
        if let _entries = entries as? [FieldChartDataEntry],
           let first = _entries.firstIndex(where: { $0.x == e.x }),
           let last = _entries.firstIndex(where: { $0.x > e.x }) {
            return [ first, last ]
        }
        else {
            return nil
        }
    }
    
    public func sortEntries() {
        if var _entries = entries as? [FieldChartDataEntry] {
            _entries.sort(by: {  $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x } )
            self.replaceEntries(_entries)
        }
    }
    
    
    // MARK: NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! ContourChartDataSet
        copy.identifier = identifier
        copy.isoCurvesLabelFont = isoCurvesLabelFont
        copy.isoCurvesLabelTextColor = isoCurvesLabelTextColor
        copy.isoCurvesLabelFormatter = isoCurvesLabelFormatter
        copy.isoCurvesLineColour = isoCurvesLineColour
        copy.isoCurvesLineWidth = isoCurvesLineWidth
        copy.isoCurvesLineDashPhase = isoCurvesLineDashPhase
        copy.isoCurvesLineDashLengths = isoCurvesLineDashLengths
        copy.isoCurvesLineColours = isoCurvesLineColours
        copy.isIsoCurveFillsUsingColour = isIsoCurveFillsUsingColour
        copy.isoCurvesColourFills = isoCurvesColourFills
        copy.isoCurvesImageFills = isoCurvesImageFills
        copy.isoCurvesFillings = isoCurvesFillings
        copy.isoCurvesValues = isoCurvesValues
        copy.isoCurvesNoStrips = isoCurvesNoStrips
        copy.isoCurvesLabelsPositions = isoCurvesLabelsPositions
        copy.isoCurvesLabelsRotations = isoCurvesLabelsRotations
        copy.drawIsoCurvesLabelsEnabled = drawIsoCurvesLabelsEnabled
        copy.pointFormatter = pointFormatter
        copy.contourShapeSize = contourShapeSize
        copy.contourShapeHoleRadius = contourShapeHoleRadius
        copy.contourShapeHoleColor = contourShapeHoleColor
        copy.shapeRenderer = shapeRenderer
        
        return copy
    }
}

extension Range {
    
    public var location: Double {
        get {
            return self.from
        }
    }
    public var length: Double {
        get {
            return abs(self.to - self.from)
        }
    }
    
    public var midPoint: Double {
        get {
            return (self.to - self.from) / 2.0
        }
    }
    
    public var start: Double {
        get {
            return self.from
        }
    }
    
    public var end: Double {
        get {
            return self.to
        }
    }
    
    public var minLimit: Double {
        get {
            return self.from
        }
    }
    
    public var maxLimit: Double {
        get {
            return self.to
        }
    }
    
}
