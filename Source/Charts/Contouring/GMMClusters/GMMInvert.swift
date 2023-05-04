//
//  GMMInvert.swift
//  DiscontinuityMeshGenerator
//
//  Created by Steve Wainwright on 16/09/2022.
//  Copyright © 2022 sakrist. All rights reserved.
//

import Foundation

let TINY: Double = 1.0e-20

class GMMInvert: NSObject {
    
    
    /* inverts a matrix of arbitrary size input as a 2D array. */
    class func invert(a: inout [[Double]], n: Int, det_man: inout Double, det_exp: inout Int) -> Int {
        /* 'a' input/output matrix */
        /* 'n' dimension */
        /* 'det_man' determinant mantisa */
        /* 'det_exp' determinant exponent */
        
        var indx: [Int] = Array(repeating: 0, count: n)
        var y: [[Double]] = Array(repeating: Array(repeating: 0, count: n), count: n)
        var col: [Double] = Array(repeating: 0, count: n)
        var d : Double = 0
        let status = GMMInvert.G_ludcmp(a: &a, n: n, indx: &indx, d: &d)
        det_man = d
        det_exp = 0
        if status > 0 {
            for j in 0..<n {
                det_man *= a[j][j]
                while fabs(det_man) > 10 {
                    det_man = det_man / 10
                    det_exp += 1
                }
                while fabs(det_man) < 0.1 && fabs(det_man) > 0 {
                    det_man = det_man * 10
                    det_exp -= 1
                }
            }
            
            for j in 0..<n {
                for i in 0..<n {
                    col[i] = 0.0
                }
                col[j] = 1.0
                GMMInvert.G_lubksb(a: a, n: n, indx: indx, b: &col)
                for i in 0..<n {
                    y[i][j] = col[i]
                }
            }

            for i in 0..<n {
                for j in 0..<n {
                    a[i][j] = y[i][j]
                }
            }
        }
        else {
            det_man = 0.0
            det_exp = 0
        }

        return status
    }


    /* From Numerical Recipies in C */

    static func G_ludcmp(a: inout [[Double]], n: Int, indx: inout [Int], d: inout Double) -> Int {
        var imax: Int = 0
        var big: Double, dum: Double, sum: Double, temp: Double
        
        var vv: [Double] = Array(repeating: 0, count: n)
        d = 1.0
        
        for i in 0..<n {
            big = 0.0
            for j in 0..<n {
                temp = fabs(a[i][j])
                if temp > big {
                   big = temp
                }
            }
            if big == 0.0 {
                return 0 /* Singular matrix  */
            }
            vv[i] = 1.0 / big
        }
        for j in 0..<n {
            for i in 0..<j {
                sum = a[i][j]
                for k in 0..<i {
                    sum -= a[i][k] * a[k][j]
                }
                a[i][j] = sum
            }
            big = 0.0
            for i in j..<n {
                sum = a[i][j]
                for k in 0..<j {
                    sum -= a[i][k] * a[k][j]
                }
                a[i][j] = sum
                dum = vv[i] * fabs(sum)
                if dum >= big {
                    big = dum
                    imax = i
                }
            }
            if j != imax {
                for k in 0..<n {
                    dum = a[imax][k]
                    a[imax][k] = a[j][k]
                    a[j][k] = dum
                }
                d = -d;
                vv[imax] = vv[j]
            }
            indx[j] = imax
            if a[j][j] == 0.0 {
                a[j][j] = TINY
            }
            if j != n {
                dum = 1.0 / (a[j][j]);
                for i in j + 1..<n {
                    a[i][j] *= dum
                }
            }
        }
        return 1
    }

    
    static func G_lubksb(a: [[Double]], n: Int, indx: [Int], b: inout [Double]) -> Void {
        var ii: Int = -1, ip: Int
        var sum: Double = 0.0

        for i in 0..<n {
            ip = indx[i]
            sum = b[ip]
            b[ip] = b[i]
            if ii >= 0 {
                for j in ii..<i {
                    sum -= a[i][j] * b[j]
                }
            }
            else if sum > 0.0 {
                ii = i
            }
            b[i] = sum
        }
        for i in stride(from: n - 1, to: -1, by: -1) {
            sum = b[i]
            for j in i+1..<n {
                sum -= a[i][j] * b[j]
            }
            b[i] = sum / a[i][i]
        }
    }

}
