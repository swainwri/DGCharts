//
//  MinorAxis.swift
//  
//
//  Created by Steve Wainwright on 02/04/2023.
//

import Foundation
import CoreGraphics

@objc(ChartMinorAxis)
public class MinorAxis: AxisBase {
    
    @objc(MinorAxisLabelPosition)
    public enum LabelPosition: Int {
        case left
        case right
        case bothSided
        case leftInside
        case rightInside
    }
    
    /// width of the minor-axis labels in pixels - this is automatically calculated by the `computeSize()` methods in the renderers
    @objc open var labelWidth = CGFloat(1.0)
    
    /// height of the minor-axis labels in pixels - this is automatically calculated by the `computeSize()` methods in the renderers
    @objc open var labelHeight = CGFloat(1.0)
    
    /// width of the (rotated) minor-axis labels in pixels - this is automatically calculated by the `computeSize()` methods in the renderers
    @objc open var labelRotatedWidth = CGFloat(1.0)
    
    /// height of the (rotated) minor-axis labels in pixels - this is automatically calculated by the `computeSize()` methods in the renderers
    @objc open var labelRotatedHeight = CGFloat(1.0)
    
    /// This is the angle for drawing the minor axis labels (in degrees)
    @objc open var labelRotationAngle = CGFloat(0.0)

    /// if set to true, the chart will avoid that the first and last label entry in the chart "clip" off the edge of the chart
    @objc open var avoidFirstLastClippingEnabled = false
    
    /// axis space from the largest value to the top in percent of the total axis range
    @objc open var spaceTop = CGFloat(0.1)

    /// axis space from the smallest value to the bottom in percent of the total axis range
    @objc open var spaceBottom = CGFloat(0.1)
    
    /// the position of the minor-labels relative to the chart
    @objc open var labelPosition = LabelPosition.left
    
    /// if set to true, word wrapping the labels will be enabled.
    /// word wrapping is done using `(value width * labelRotatedWidth)`
    ///
    /// - Note: currently supports all charts except pie/radar/horizontal-bar*
    @objc open var wordWrapEnabled = false
    
    /// `true` if word wrapping the labels is enabled
    @objc open var isWordWrapEnabled: Bool { return wordWrapEnabled }
    
    /// the width for wrapping the labels, as percentage out of one value width.
    /// used only when isWordWrapEnabled = true.
    ///
    /// **default**: 1.0
    @objc open var wordWrapWidthPercent: CGFloat = 1.0
   
    /// draw circle gridlines of the radial-axis to fill chart.rect
    @objc public var gridLinesToChartRectEdges = false
    
    /// flag that indicates if the axis is inverted or not
    @objc open var inverted = false
    
    @objc open var isInverted: Bool { return inverted }
    
    /// the minimum width that the axis should take
    ///
    /// **default**: 0.0
    @objc open var minWidth = CGFloat(0)
    
    /// the maximum width that the axis can take.
    /// use Infinity for disabling the maximum.
    ///
    /// **default**: CGFloat.infinity
    @objc open var maxWidth = CGFloat(CGFloat.infinity)
    
    public override init() {
        super.init()
        
        self.yOffset = 4.0
    }
    
    @objc open func requiredSize() -> CGSize {
        let label = getLongestLabel() as NSString
        var size = label.size(withAttributes: [.font: labelFont])
        size.width += xOffset * 2.0
        size.height += yOffset * 2.0
        size.width = max(minWidth, min(size.width, maxWidth > 0.0 ? maxWidth : size.width))
        return size
    }
    
    @objc open func getRequiredHeightSpace() -> CGFloat {
        return requiredSize().height
    }
    
//    /// `true` if this axis needs horizontal offset, `false` ifno offset is needed.
//    @objc open var needsOffset: Bool {
//        if isEnabled && isDrawLabelsEnabled && labelPosition == .outsideChart {
//            return true
//        }
//        else {
//            return false
//        }
//    }
    
    public override func calculate(min dataMin: Double, max dataMax: Double) {
        // if custom, use value as is, else use data value
        var min = _customAxisMin ? _axisMinimum : dataMin
        var max = _customAxisMax ? _axisMaximum : dataMax
        
        // Make sure max is greater than min
        // Discussion: https://github.com/danielgindi/Charts/pull/3650#discussion_r221409991
        if min > max {
            switch(_customAxisMax, _customAxisMin)
            {
            case(true, true):
                (min, max) = (max, min)
            case(true, false):
                min = max < 0 ? max * 1.5 : max * 0.5
            case(false, true):
                max = min < 0 ? min * 0.5 : min * 1.5
            case(false, false):
                break
            }
        }
        
        // temporary range (before calculations)
        let range = abs(max - min)
        
        // in case all values are equal
        if range == 0.0 {
            max = max + 1.0
            min = min - 1.0
        }
        
        // bottom-space only effects non-custom min
        if !_customAxisMin {
            let bottomSpace = range * Double(spaceBottom)
            _axisMinimum = (min - bottomSpace)
        }
        
        // top-space only effects non-custom max
        if !_customAxisMax {
            let topSpace = range * Double(spaceTop)
            _axisMaximum = (max + topSpace)
        }
        
        // calc actual range
        axisRange = abs(_axisMaximum - _axisMinimum)
    }
}
