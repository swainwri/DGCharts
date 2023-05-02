//
//  Utilities.swift
//  SwiftCharts_Contouring
//
//  Created by Steve Wainwright on 26/03/2023.
//

import Foundation
import CoreGraphics

enum ScaleType {
    case linear, category, log, logmodulus
}

@objc(ChartUtilities)
public class Utilities: NSObject {
    
    // MARK - Log Modulus

    /** @brief Computes the log modulus of the given value.
     *  @param  value The value.
     *  @return       The log modulus of the given value.
     *  @see          <a href="https://blogs.sas.com/content/iml/2014/07/14/log-transformation-of-pos-neg.html">A log transformation of positive and negative values</a> for more information about the log-modulus transformation.
     **/
    class func LogModulus(_ value: Double) -> Double {
        if value != 0.0  {
            let sign =  value.sign == .minus ? -1.0 : +1.0

            return sign * log10(fabs(value) + 1.0)
        }
        else {
            return 0.0
        }
    }

    /** @brief Computes the inverse log modulus of the given value.
     *  @param  value The value.
     *  @return       The inverse log modulus of the given value.
     **/
    class func InverseLogModulus(_ value: Double) -> Double {
        if ( value != 0.0 ) {
            let sign = value.sign == .minus ? -1.0 : +1.0

            return sign * (pow(10.0, fabs(value)) - 1.0)
        }
        else {
            return 0.0
        }
    }
    
    // MARK - Easy On the Eye Scaling

    public class func easyOnTheEyeScaling(fMin: Double, fMax: Double, N: Int, valueMin: inout Double, valueMax: inout Double, step : inout Double) -> Bool {
        var iFault = false
        // C
        // C     ALGORITHM AS 96  APPL. STATIST. (1976) VOL.25, NO.1
        // C
        // C     Given extreme values FMin, FMax, and the need for a scale with N
        // C     marks, calculates value for the lowest scale mark (ValueMin) and
        // C     step length (Step) and highest scale mark (ValueMax).
        // C
        // C     Units for step lengths
        // C
        //double UNIT[11] = { 1.0, 1.2, 1.6, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0 };
        let UNIT: [Double] = [ 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0 ]
        //     Local variables
        
        let TOL: Double = 5.0E-6
        let BIAS: Double = 1.0E-4
        
        var FMAX = fMax
        var FMIN = fMin
        
        //     Test for valid parameter values
        if FMAX < FMIN || N <= 1 {
            iFault = true
        }
        else {
            let RN = N - 1
            var X = fabs(FMAX)
            if X == 0.0 {
                X = 1.0
            }
            if (FMAX - FMIN) / X <= TOL {
                if FMAX < 0.0 {
                    FMAX = 0.0
                }
                else if FMAX == 0.0 {
                    FMAX = 1.0
                }
                else {
                    FMIN = 0.0
                }
            }
            step = (FMAX - FMIN) / Double(RN)
            var S = step
            //     Find power of 10
            while(S < 1.0) {
                S *= 10.0
            }
            while(S >= 10.0) {
                S /= 10.0
            }
            
            //     Calculate STEP
            X = S - BIAS
            var j: Int = 0
            for i in 0..<UNIT.count {
                if X <= UNIT[i] {
                    j = i
                    break
                }
                
            }
            step = step * UNIT[j] / S
            let RANGE = step * Double(RN)
            
            //     Make first estimate of VALMIN
            X = 0.5 * (1.0 + (FMIN + FMAX - RANGE) / step)
            j = Int(X - BIAS)
            if X < 0.0 {
                j -= 1
            }
            valueMin = step * Double(j)
                
                //     Test if VALMIN could be zero
            if FMIN >= 0.0 && RANGE >= FMAX {
                valueMin = 0.0
            }
            valueMax = valueMin + RANGE
            
            //    Test if VALMAX could be zero
            if FMAX > 0.0 || RANGE < -FMIN {
            }
            else {
                valueMax = 0.0
                valueMin = -RANGE
            }
        }
        
        return iFault
    }
    
    class func ColorRGBtoHSL(red: CGFloat, green: CGFloat, blue: CGFloat) -> (hue: CGFloat, saturation: CGFloat, lightness: CGFloat) {
        let r = red;
        let g = green;
        let b = blue;

        let max = max(max(r, g), b)
        let min = min(min(r, g), b)

        var h: CGFloat = 0
        var s: CGFloat = 0
        let l = (max + min) / 2.0

        if max == min {
            h = 0.0
            s = 0.0
        }
        else {
            let d = max - min
            s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min)

            if max == r {
                h = (g - b) / d + (g < b ? 6.0 : 0.0)
            }

            else if max == g {
                h = (b - r) / d + 2.0
            }

            else if max == b {
                h = (r - g) / d + 4.0
            }

            h /= 6.0
        }
        return ( h, s, l )
    }
    
    // MARK - Quartz pixel-alignment functions

    /**
     *  @brief Aligns a point in user space to integral coordinates in device space.
     *
     *  Ensures that the x and y coordinates are at a pixel corner in device space.
     *  Drawn from <i>Programming with Quartz</i> by D. Gelphman, B. Laden.
     *
     *  @param  context The graphics context.
     *  @param  point   The point in user space.
     *  @return         The device aligned point in user space.
     **/
    class func alignPointToUserSpace(_ context: CGContext, point: inout CGPoint) -> Void {
        // Compute the coordinates of the point in device space.
        point = context.convertToDeviceSpace(point)

        // Ensure that coordinates are at exactly the corner
        // of a device pixel.
        point.x = round(point.x - CGFloat(0.5)) + CGFloat(0.5)
        point.y = ceil(point.y) - CGFloat(0.5)

        // Convert the device aligned coordinate back to user space.
        point = context.convertToUserSpace(point)
    }
    
    class func alignPointsToUserSpace(_ context: CGContext, points: inout [CGPoint]) -> Void {
        // Compute the coordinates of the point in device space.
        for i in 0..<points.count {
            var point = context.convertToDeviceSpace(points[i])
            
            // Ensure that coordinates are at exactly the corner
            // of a device pixel.
            point.x = round(point.x - 0.5) + 0.5
            point.y = ceil(point.y) - 0.5
            
            // Convert the device aligned coordinate back to user space.
            point = context.convertToUserSpace(point)
            points[i] = point
        }
    }
    
    /**
    *  @brief Aligns a point in user space between integral coordinates in device space.
    *
    *  Ensures that the x and y coordinates are between pixels in device space.
    *
    *  @param  context The graphics context.
    *  @param  inout point   The point in user space, converted to the device aligned point in user space
    **/
    class func alignIntegralPointToUserSpace(_ context: CGContext, point: inout CGPoint) -> Void {
        point = context.convertToDeviceSpace(point)

        point.x = round(point.x);
        point.y = ceil(point.y - 0.5)

        point = context.convertToUserSpace(point)
    }
    
    class func alignIntegralPointsToUserSpace(_ context: CGContext, points: inout [CGPoint]) -> Void {
        for i in 0..<points.count {
            var point = context.convertToDeviceSpace(points[i])
            
            point.x = round(point.x);
            point.y = ceil(point.y - 0.5)
            
            point = context.convertToUserSpace(point)
            points[i] = point
        }
    }
}

