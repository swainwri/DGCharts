//
//  PiNumberFormatter.swift
//  PlotterSwift
//
//  Created by Steve Wainwright on 10/09/2017.
//  Copyright © 2017 Whichtoolface.com. All rights reserved.
//

import Foundation
import DGCharts

func gcd(_ a_: Double, _ b_: Double) -> Double {
    var c: Double
    var a = round(a_)
    var b = b_
    while a != 0.0 {
        c = a
        a = round(fmod(b, a))
        b = c
    }
    return b
}


/** @brief A number formatter that converts numbers to multiples of π.
 **/
/// @}
public class PiNumberFormatter : NumberFormatter, ValueFormatter, AxisValueFormatter {
    // MARK: -
    // MARK: Formatting
    /// @name Formatting
    /// @{
    /**
     *  @brief Converts a number into multiples of π. Use the @link NSNumberFormatter::multiplier multiplier @endlink to control the maximum fraction denominator.
     *  @param coordinateValue The numeric value.
     *  @return The formatted string.
     **/
    fileprivate func format(value: Double) -> String {
        var string: String

        let _value = value / .pi
        var factor: Double = round(self.multiplier!.doubleValue)
        if factor == 0.0 {
            factor = 1.0
        }
        let numerator: Double = round(_value * factor)
        let denominator: Double = factor
        let fraction: Double = numerator / denominator
        let divisor: Double = abs(gcd(numerator, denominator))
        if fraction == 0.0 {
            string = "0"
        }
        else if abs(fraction) == 1.0 {
            string = "\(fraction.sign.rawValue == FloatingPointSign.minus.rawValue ? "-" : "")π"
        }
        else if abs(numerator) == 1.0 {
            string = "\(numerator.sign.rawValue == FloatingPointSign.minus.rawValue ? "-" : "")π/\(Int(denominator))"
        }
        else if abs(numerator / divisor) == 1.0 {
            string = "\(numerator.sign.rawValue == FloatingPointSign.minus.rawValue ? "-" : "")π/\(Int(denominator / divisor))"
        }
        else if round(fraction) == fraction {
            string = "\(Int(fraction)) π"
        }
        else if divisor != denominator {
            string = "\(Int(numerator / divisor)) π/\(Int(denominator / divisor))"
        }
        else {
            string = "\(Int(numerator)) π/\(Int(denominator))"
        }
        
        return string
    }
    
    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return format(value: value)
    }
    
    public func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        return format(value: value)
    }
}

