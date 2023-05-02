//
//  PolarChartDataSetProtocol.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics

@objc
public protocol PolarChartDataSetProtocol: RadarChartDataSetProtocol {
    
    // MARK: - Data functions and accessors
    
    
    /// Calculates the min and max radial-values from the Entry closest to the given fromRadial to the Entry closest to the given toRadial value.
    /// This is only needed for the autoScaleMinMax feature.
    func calcMinMaxRadial(fromTheta: Double, toTheta: Double)
    
    /// The minimum radial-value this DataSet holds
    var radialMin: Double { get }
    
    /// The maximum radial-value this DataSet holds
    var radialMax: Double { get }
    
    /// The minimum theta-value this DataSet holds
    var thetaMin: Double { get }
    
    /// The maximum theta-value this DataSet holds
    var thetaMax: Double { get }
    
    /// - Parameters:
    ///   - thetaValue: the theta-value
    ///   - closestToRadial: If there are multiple radial-values for the specified theta-value,
    ///   - rounding: determine whether to round up/down/closest if there is no Entry matching the provided theta-value
    /// - Returns: The first Entry object found at the given x-value with binary search.
    /// If the no Entry at the specified theta-value is found, this method returns the Entry at the closest x-value according to the rounding.
    /// nil if no Entry object at that theta-value.
    func entryForThetaValue(_ thetaValue: Double, closestToRadial radialValue: Double, rounding: ChartDataSetRounding) -> PolarChartDataEntry?
    
    /// - Parameters:
    ///   - thetaValue: the theta-value
    ///   - closestToRadial: If there are multiple radial-values for the specified theta-value,
    /// - Returns: The first Entry object found at the given theta-value with binary search.
    /// If the no Entry at the specified theta-value is found, this method returns the Entry at the closest theta-value.
    /// nil if no Entry object at that theta-value.
    func entryForThetaValue(_ thetaValue: Double, closestToRadial radialValue: Double) -> PolarChartDataEntry?
    
    /// - Returns: All Entry objects found at the given theta-value with binary search.
    /// An empty array if no Entry object at that theta-value.
    func entriesForThetaValue(_ thetaValue: Double) -> [PolarChartDataEntry]
    
    /// - Parameters:
    ///   - thetaValue: theta-value of the entry to search for
    ///   - closestToRadial: If there are multiple radial-values for the specified x-value,
    ///   - rounding: Rounding method if exact value was not found
    /// - Returns: The array-index of the specified entry.
    /// If the no Entry at the specified theta-value is found, this method returns the index of the Entry at the closest theta-value according to the rounding.
    func entryIndex(theta thetaValue: Double, closestToRadial radialValue: Double, rounding: ChartDataSetRounding) -> Int
    
    // MARK: - Styling functions and accessors
    
    
    /// The drawing mode for this line dataset
    ///
    /// **default**: Linear
    var polarMode: PolarChartDataSet.Mode { get set }
    
    /// The drawing option for this cubic line dataset
    ///
    /// **default**: normal bezier curve
    /// 
    var polarCurvedInterpolation: PolarChartDataSet.CubicInterpolation { get set }
    
    /// The drawing alpha option for this catmullCustomAlpha cubic line
    ///
    /// **default**:  0
    ///
    var polarCatmullCustomAlpha: Double { get set }
    
    /// The drawing option for this stepped line dataset
    ///
    /// **default**: normal bezier curve
    var polarHistogram: PolarChartDataSet.HistogramOption { get set }
    
    /// Intensity for cubic lines (min = 0.05, max = 1)
    ///
    /// **default**: 0.2
    var cubicIntensity: CGFloat { get set }
    
    /// Custom formatter that is used instead of the auto-formatter if set
    var pointFormatter: PointFormatter { get set }
    
    /// Sets a custom FillFormatterProtocol to the chart that handles the position of the filled-line for each DataSet. Set this to null to use the default logic.
    var polarFillFormatter: PolarFillFormatter? { get set }
    
    /// since this is a polar plot on may want the first point joing the last poin
    var polarClosePath: Bool { get set }
    
    /// If true, gradient lines are drawn instead of solid
    var isDrawLineWithGradientEnabled: Bool { get set }

    /// The points where gradient should change color
    var gradientPositions: [CGFloat]? { get set }

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
    
    /// This is how much (in pixels) into the dash pattern are we starting from.
    var lineDashPhase: CGFloat { get }
    
    /// This is the actual dash pattern.
    /// I.e. [2, 3] will paint [--   --   ]
    /// [1, 3, 4, 2] will paint [-   ----  -   ----  ]
    var lineDashLengths: [CGFloat]? { get set }
    
    /// Line cap type, default is CGLineCap.Butt
    var lineCapType: CGLineCap { get set }
    
    /// Sets a custom FillFormatterProtocol to the chart that handles the position of the filled-line for each DataSet. Set this to null to use the default logic.
    var fillFormatter: FillFormatter? { get set }
}
