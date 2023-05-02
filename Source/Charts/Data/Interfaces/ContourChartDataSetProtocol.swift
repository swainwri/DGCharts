//
//  ContourChartDataSetProtocol.swift
//  Charts
//
//  Created by Steve Wainwright on 15/04/2023.
//

import Foundation
import CoreGraphics


@objc
public protocol ContourChartDataSetProtocol: LineScatterCandleRadarChartDataSetProtocol {

    // MARK: - Data functions and accessors
    
    func getFirstLastIndexInEntries(forEntryX e: ChartDataEntry) -> [Int]? 
    
    var identifier: String? { get set }
    
    var contours: Contours? { get set }
    
    var maxFxy: Double { get }
    
    var interpolationMode: ContourChartDataSet.Mode  { get set }
    var cubicInterpolation: ContourChartDataSet.CubicInterpolation  { get set }
    var catmullCustomAlpha: Double { get set }
    var extrapolateToLimits: Bool { get set }
    var functionPlot: Bool { get set }
    var hidden: Bool { get set }
    var alignsPointsToPixels: Bool { get set }
    var fieldBlock: ((Double, Double) -> Double)? { get set } // block to F(x,y) function
    var limits: [CGFloat] { get set }
    var minFunctionValue: CGFloat { get set }
    var maxFunctionValue: CGFloat { get set }
    
    var fillIsoCurves: Bool { get set }
    var hasDiscontinuity: Bool { get set }
    
    var noIsoCurves: Int { get set }
    var noColumnsFirst: Int { get set }
    var noRowsFirst: Int { get set }
    var noColumnsSecondary: Int { get set }
    var noRowsSecondary: Int { get set }
    
    var easyOnTheEye: Bool { get set }
    
    var xRange: Range { get set }
    var yRange: Range { get set }
    var originOfContext: CGPoint { get set }
    var scaleOfContext: CGFloat { get set }
    var initialXRange: Range { get set }
    var initialYRange: Range { get set }
    var previousLimits: [CGFloat] { get set }
    var previousFillIsoCurves: Bool { get set }
    
    var noActualIsoCurves: Int { get set }
    
    var maxWidthPixels: CGFloat { get set }
    var maxHeightPixels: CGFloat { get set }
    var scaleX: CGFloat { get set }
    var scaleY: CGFloat { get set }
    var greatestContourBox: CGRect { get set }
    var extraWidth: CGFloat { get set }
    var extraHeight: CGFloat { get set }
    
    var needsIsoCurvesUpdate: Bool { get set }
    var firstRendition: Bool { get set }
    var needsIsoCurvesRelabel: Bool { get set }
    
    var isoCurvesIndices: [Int] { get set }
    
#if os(OSX)
    var macOSImage: NSImage? { get set }
#endif
    
    var imageFilePath: String { get }
                                
    
    // MARK: - Styling functions and accessors
    
    var isoCurvesLabelFont: NSUIFont { get set }
    var isoCurvesLabelTextColor: NSUIColor { get set }
    var isoCurvesLabelFormatter: NumberFormatter { get set }
    
    var isoCurvesLineColour: NSUIColor { get set }
    var isoCurvesLineWidth: CGFloat { get set }
    var isoCurvesLineDashPhase: CGFloat { get set }
    var isoCurvesLineDashLengths: [CGFloat]? { get set }
    
    var isoCurvesLineColours: [NSUIColor]? { get set }
    var isIsoCurveFillsUsingColour: Bool { get set }
    var isoCurvesColourFills: [ColorFill]? { get set }
    var isoCurvesImageFills: [ImageFill]? { get set }
    var isoCurvesFillings: [ContourFill]? { get set }
    var isoCurvesValues: [Double]? { get set }
    var isoCurvesNoStrips: [Int]? { get set }
    var isoCurvesLabelsPositions: [[CGPoint]]? { get set }
    var isoCurvesLabelsRotations: [[CGFloat]]? { get set }
    
    var isDrawIsoCurvesLabelsEnabled: Bool { get }
    var drawIsoCurvesLabelsEnabled: Bool { get set }
    
    /// Custom formatter that is used instead of the auto-formatter if set
    var pointFormatter: PointFormatter { get set }
    
    /// The radius of the drawn circles.
    var circleRadius: CGFloat { get set }
    
    /// The hole radius of the drawn circles.
    var circleHoleRadius: CGFloat { get set }
    
    var circleColors: [NSUIColor] { get set }
    
    /// - Returns: The color at the given index of the DataSet's circle-color array.
    /// Performs a IndexOutOfBounds check by modulus.
    func getCircleColor(atIndex: Int) -> NSUIColor?
    
    /// Sets the one and ONLY color that should be used for this DataSet.
    /// Internally, this recreates the colors array and adds the specified color.
    func setCircleColor(_ color: NSUIColor)
    
    /// Resets the circle-colors array and creates a new one
    func resetCircleColors(_ index: Int)
    
    /// If true, drawing circles is enabled
    var drawCirclesEnabled: Bool { get set }
    
    /// `true` if drawing circles for this DataSet is enabled, `false` ifnot
    var isDrawCirclesEnabled: Bool { get }
    
    /// The color of the inner circle (the circle-hole).
    var circleHoleColor: NSUIColor? { get set }
    
    /// `true` if drawing circles for this DataSet is enabled, `false` ifnot
    var drawCircleHoleEnabled: Bool { get set }
    
    /// `true` if drawing the circle-holes is enabled, `false` ifnot.
    var isDrawCircleHoleEnabled: Bool { get }
    
    /// - Returns: The size the contour shape will have
    var contourShapeSize: CGFloat { get }
    
    /// - Returns: The radius of the hole in the shape (applies to Square, Circle and Triangle)
    /// Set this to <= 0 to remove holes.
    /// **default**: 0.0
    var contourShapeHoleRadius: CGFloat { get }
    
    /// - Returns: Color for the hole in the shape. Setting to `nil` will behave as transparent.
    /// **default**: nil
    var contourShapeHoleColor: NSUIColor? { get }
    
    /// - Returns: The ShapeRenderer responsible for rendering this DataSet.
    var shapeRenderer: ShapeRenderer? { get }
}
