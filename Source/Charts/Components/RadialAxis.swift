//
//  RadialAxis.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics


@objc(ChartRadialAxis)
public class RadialAxis: AxisBase {
    @objc(RadialAxisLabelPosition)
    public enum LabelPosition: Int {
        case top
        case bottom
        case left
        case right
        case centre
    }
    
    @objc(RadialAxisPolarRadialAngleMode)
    public enum PolarRadialAngleMode: Int {
        case radians
        case degrees
    }
    
    ///  Enum that specifies the axis a DataSet should be plotted against, either major or minor.
    @objc public enum PolarAxisDependency: Int {
        case none
        case major
        case minor
    }
    
    public override init() {
        super.init()
        
        self.xOffset = 0.0
        self.yOffset = 0.0
    }
    
    /// width of the x-axis labels in pixels - this is automatically calculated by the `computeSize()` methods in the renderers
    @objc public var labelWidth = CGFloat(1.0)
    
    /// height of the x-axis labels in pixels - this is automatically calculated by the `computeSize()` methods in the renderers
    @objc public var labelHeight = CGFloat(1.0)
    
    /// width of the (rotated) x-axis labels in pixels - this is automatically calculated by the `computeSize()` methods in the renderers
    @objc public var labelRotatedWidth = CGFloat(1.0)
    
    /// height of the (rotated) x-axis labels in pixels - this is automatically calculated by the `computeSize()` methods in the renderers
    @objc public var labelRotatedHeight = CGFloat(1.0)
    
    /// This is the angle for drawing the X axis labels (in degrees)
    @objc public var labelRotationAngle = CGFloat(0.0)
    
    /// if set to true, the chart will avoid that the first and last label entry in the chart "clip" off the edge of the chart
    @objc public var avoidFirstLastClippingEnabled = false
    
    /// the position of the radial-labels relative to the chart
    @objc public var labelPosition = LabelPosition.centre
    
    /// the labelRadius as a portion of outerCircleRadius of the radial-labels relative to the chart centre
    @objc public var labelPositionRadiusRatio = CGFloat(0.75)
    
    /// if set to true, word wrapping the labels will be enabled.
    /// word wrapping is done using `(value width * labelRotatedWidth)`
    ///
    /// - Note: currently supports all charts except pie/radar/horizontal-bar*
    @objc public var wordWrapEnabled = false
    
    /// `true` if word wrapping the labels is enabled
    @objc public var isWordWrapEnabled: Bool { return wordWrapEnabled }
    
    /// the width for wrapping the labels, as percentage out of one value width.
    /// used only when isWordWrapEnabled = true.
    ///
    /// **default**: 1.0
    @objc public var wordWrapWidthPercent: CGFloat = 1.0
    
    /// the angle increment in radians for intervals around the circle fo
    ///
    /// **default**: 15 degrees
    private var _webInterval: Double = Double.pi / 8
    
    /// outer circle gridline of the major-axis
    @objc public var outerCircleRadius = CGFloat(0.0)
    
    /// draw spoke gridlines of the radial-axis to fill chart.rect
    @objc public var gridLinesToChartRectEdges = false
    
    /// the side this axis object represents
    private var _axisDependency = PolarAxisDependency.major
    
    @objc public init(position: PolarAxisDependency) {
        super.init()
        
        _axisDependency = position
        
        self.yOffset = 0.0
    }
    
    @objc open var axisDependency: PolarAxisDependency {
        get {
            return _axisDependency
        }
        set {
            _axisDependency = newValue
        }
    }
    
    /// the number of entries the legend contains
    @objc public override var entryCount: Int {
        get {
            return entries.count
        }
        set {
            entries.removeAll()
            let deltaAngle = (self.axisMaximum - self.axisMinimum) / Double(newValue)
            for i in 0..<newValue+1 {
                entries.append(self.axisMinimum + Double(i) * deltaAngle)
            }
            self._webInterval = deltaAngle
        }
    }
    
    @objc public var webInterval: Double {
        get {
            return _webInterval
        }
        set {
            _webInterval = newValue
            self.entryCount = Int((self.axisMaximum - self.axisMinimum) / (self.radialAngleMode == .radians ? 2 * Double.pi : Double(360.0)))
        }
    }
    
    @objc public var radialAngleMode: PolarRadialAngleMode = .radians
    
    @objc public var reversed: Bool = false
    
    @objc public var isAvoidFirstLastClippingEnabled: Bool {
        return avoidFirstLastClippingEnabled
    }
}
