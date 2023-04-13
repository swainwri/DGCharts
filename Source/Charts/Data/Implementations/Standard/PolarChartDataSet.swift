//
//  PolarChartDataSet.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics


public class PolarChartDataSet: RadarChartDataSet, PolarChartDataSetProtocol {
    
    @objc(PolarChartMode)
    public enum Mode: Int {
        case linear
        case stepped
        case cubic
    }
    
    /**
     *  @brief Enumration of polar plot curved interpolation style options
     **/
    @objc(PolarChartCurvedInterpolationOption)
    public enum CurvedInterpolationOption: Int {
        case normal              ///< Standard Curved Interpolation (Bezier Curve)
        case catmullRomUniform   ///< Catmull-Rom Spline Interpolation with alpha = @num{0.0}.
        case catmullRomCentripetal ///< Catmull-Rom Spline Interpolation with alpha = @num{0.5}.
        case catmullRomChordal    ///< Catmull-Rom Spline Interpolation with alpha = @num{1.0}.
        case catmullCustomAlpha  ///< Catmull-Rom Spline Interpolation with a custom alpha value.
        case hermite       ///< Hermite Cubic Spline Interpolation
    }

    /**
     *  @brief Enumeration of polar plot histogram style options
     **/
    @objc(PolarChartHistogramOption)
    public enum HistogramOption: Int {
        case normal   ///< Standard histogram.
        case skipFirst ///< Skip the first step of the histogram.
        case skipSecond///< Skip the second step of the histogram.
       // case optionCount///< The number of histogram options available.
    }

    
    private func initialize() {
        self.valueFont = NSUIFont.systemFont(ofSize: 13.0)
    }
    
    public required init() {
        super.init()
        initialize()
    }
    
    public required init(entries: [ChartDataEntry], label: String) {
        super.init(entries: entries, label: label)
        initialize()
    }
    
    // MARK: - Data functions and accessors
    
    /// The minimum radial-value this DataSet holds
    public var radialMin: Double {
        get {
            return self.yMin
        }
    }
    
    /// The maximum radial-value this DataSet holds
    public var radialMax: Double {
        get {
            return self.yMax
        }
    }
    
    /// The minimum theta-value this DataSet holds
    public var thetaMin: Double {
        get {
            return self.xMin
        }
    }
    
    /// The maximum theta-value this DataSet holds
    public var thetaMax: Double {
        get {
            return self.xMax
        }
    }
    
    /// Calculates the min and max radial-values from the Entry closest to the given fromTheta to the Entry closest to the given toThetavalue.
    /// This is only needed for the autoScaleMinMax feature.
    public func calcMinMaxRadial(fromTheta: Double, toTheta: Double) {
        calcMinMaxY(fromX: fromTheta, toX: toTheta)
    }
    
    /// - Parameters:
    ///   - thetaValue: the theta-value
    ///   - closestToRadial: If there are multiple radial-values for the specified theta-value,
    ///   - rounding: determine whether to round up/down/closest if there is no Entry matching the provided theta-value
    /// - Returns: The first Entry object found at the given x-value with binary search.
    /// If the no Entry at the specified theta-value is found, this method returns the Entry at the closest x-value according to the rounding.
    /// nil if no Entry object at that theta-value.
    public func entryForThetaValue(_ thetaValue: Double, closestToRadial radialValue: Double, rounding: ChartDataSetRounding) -> PolarChartDataEntry? {
        return self.entryForXValue(thetaValue, closestToY:radialValue, rounding: rounding) as? PolarChartDataEntry
    }
    
    /// - Parameters:
    ///   - thetaValue: the theta-value
    ///   - closestToRadial: If there are multiple radial-values for the specified theta-value,
    /// - Returns: The first Entry object found at the given theta-value with binary search.
    /// If the no Entry at the specified theta-value is found, this method returns the Entry at the closest theta-value.
    /// nil if no Entry object at that theta-value.
    public func entryForThetaValue(_ thetaValue: Double, closestToRadial radialValue: Double) -> PolarChartDataEntry? {
        return self.entryForXValue(thetaValue, closestToY:radialValue) as? PolarChartDataEntry
    }
    
    /// - Returns: All Entry objects found at the given theta-value with binary search.
    /// An empty array if no Entry object at that theta-value.
    public func entriesForThetaValue(_ thetaValue: Double) -> [PolarChartDataEntry] {
        return self.entriesForXValue(thetaValue) as? [PolarChartDataEntry] ?? []
    }
    
    /// - Parameters:
    ///   - thetaValue: theta-value of the entry to search for
    ///   - closestToRadial: If there are multiple radial-values for the specified x-value,
    ///   - rounding: Rounding method if exact value was not found
    /// - Returns: The array-index of the specified entry.
    /// If the no Entry at the specified theta-value is found, this method returns the index of the Entry at the closest theta-value according to the rounding.
    public func entryIndex(theta thetaValue: Double, closestToRadial radialValue: Double, rounding: ChartDataSetRounding) -> Int {
        return self.entryIndex(x: thetaValue, closestToY: radialValue, rounding: rounding)
    }
    
    // MARK: - Styling functions and accessors
    
    ///
    /// **default**: Linear
    public var polarMode: PolarChartDataSet.Mode = .linear
    public var mode: LineChartDataSet.Mode = .linear
    /// The drawing option for this cubic line dataset
    ///
    /// **default**: normal bezier curve
    public var polarCurvedInterpolation: PolarChartDataSet.CurvedInterpolationOption = .normal
    
    private var _polarCatmullCustomAlpha: Double = 0
    /// The drawing alpha option for this catmullCustomAlpha cubic line
    /// between 0 and 1
    /// 
    /// **default**:  0
    ///
    public var polarCatmullCustomAlpha: Double {
        get {
            return _polarCatmullCustomAlpha
        }
        set {
            if newValue >= 0 && newValue <= 1 {
                _polarCatmullCustomAlpha = newValue
            }
        }
    }
    
    /// The drawing option for this stepped line dataset
    ///
    /// **default**: normal bezier curve
    public var polarHistogram: PolarChartDataSet.HistogramOption = .normal
    
    private var _cubicIntensity = CGFloat(0.2)
    
    /// Intensity for cubic lines (min = 0.05, max = 1)
    ///
    /// **default**: 0.2
    public var cubicIntensity: CGFloat {
        get {
            return _cubicIntensity
        }
        set {
            _cubicIntensity = newValue.clamped(to: 0.05...1)
        }
    }
    
    public var isDrawLineWithGradientEnabled = false

    public var gradientPositions: [CGFloat]?
    
    /// The radius of the drawn circles.
    public var circleRadius = CGFloat(8.0)
    
    /// The hole radius of the drawn circles
    public var circleHoleRadius = CGFloat(4.0)
    
    public var circleColors = [NSUIColor]()
    
    /// - Returns: The color at the given index of the DataSet's circle-color array.
    /// Performs a IndexOutOfBounds check by modulus.
    public func getCircleColor(atIndex index: Int) -> NSUIColor?
    {
        let size = circleColors.count
        let index = index % size
        if index >= size
        {
            return nil
        }
        return circleColors[index]
    }
    
    /// Sets the one and ONLY color that should be used for this DataSet.
    /// Internally, this recreates the colors array and adds the specified color.
    public func setCircleColor(_ color: NSUIColor)
    {
        circleColors.removeAll(keepingCapacity: false)
        circleColors.append(color)
    }
    
    public func setCircleColors(_ colors: NSUIColor...)
    {
        circleColors.removeAll(keepingCapacity: false)
        circleColors.append(contentsOf: colors)
    }
    
    /// Resets the circle-colors array and creates a new one
    public func resetCircleColors(_ index: Int)
    {
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
    
    /// This is how much (in pixels) into the dash pattern are we starting from.
    public var lineDashPhase = CGFloat(0.0)
    
    /// This is the actual dash pattern.
    /// I.e. [2, 3] will paint [--   --   ]
    /// [1, 3, 4, 2] will paint [-   ----  -   ----  ]
    public var lineDashLengths: [CGFloat]?
    
    /// Line cap type, default is CGLineCap.Butt
    public var lineCapType = CGLineCap.butt
    
    /// Custom formatter that is used instead of the auto-formatter if set
    public lazy var pointFormatter: PointFormatter = DefaultPointFormatter()
    
    /// formatter for customizing the position of the fill-line
    private var _polarFillFormatter: PolarFillFormatter = DefaultPolarFillFormatter()
    
    /// Sets a custom PolarFillFormatterProtocol to the chart that handles the position of the filled-line for each DataSet. Set this to null to use the default logic.
    public var polarFillFormatter: PolarFillFormatter? {
        get {
            return _polarFillFormatter
        }
        set {
            _polarFillFormatter = newValue ?? DefaultPolarFillFormatter()
        }
    }
    
    public var fillFormatter: FillFormatter? {
        get {
            return nil
        }
        set {
            
        }
    }
    
    /// since this is a polar plot on may want the first point joing the last poin
    public var polarClosePath: Bool = false
    
}
