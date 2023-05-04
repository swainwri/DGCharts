//
//  GMMEigen.swift
//  DiscontinuityMeshGenerator
//
//  Ported by Steve Wainwright on 14/09/2022.
//  Copyright © 2022 sakrist. All rights reserved.
//

import Foundation

class GMMEigen: NSObject {
    
    /* Computes eigenvalues (and eigen vectors if desired) for */
    /*  symmetric matices.                                     */
    //  double **M,     /* Input matrix */
    //  double *lambda, /* Output eigenvalues */
    //  int n           /*
    class func eigen(M: inout [[Double]], lambda: inout [Double], n: Int) -> Void {
        
        var a: [[Double]] = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        var e: [Double] = Array(repeating: 0.0, count: n)

        for i in 0..<n {
            for j in 0..<n {
                a[i][j] = M[i][j]
            }
        }
        GMMEigen.G_tred2(a: &a, n: n, d: &lambda, e: &e)
        let _ = GMMEigen.G_tqli(d: &lambda, e: &e, n: n, z: &a)
        
       /* Returns eigenvectors    */
        for i in 0..<n {
            for j in 0..<n {
                M[i][j] = a[i][j]
            }
        }
    }


    /* From Numerical Recipies in C */
    class func G_tqli(d: inout [Double], e: inout [Double], n: Int, z: inout [[Double]]) -> Int {
        
        func SIGN(_ a: Double, _ b: Double) -> Double {
            return b < 0 ? -fabs(a) : fabs(a)
        }
        
        let MAX_ITERS: Int = 30
        
        var iter: Int = 0
        var s: Double, r: Double, p: Double, g: Double
        var f: Double, dd: Double, c: Double, b: Double

        for i in 1..<n {
            e[i-1] = e[i]
        }
        e[n-1] = 0.0
        for l in 0..<n {
            iter = 0
            var mm = l
            repeat {
                mm = l
                for m in l..<n-1 {
                    dd = fabs(d[m]) + fabs(d[m+1])
                    if fabs(e[m]) + dd == dd {
                        break
                    }
                    mm += 1
                }
                if mm != l {
                    iter += 1
                    if iter == MAX_ITERS {
                        return 0 /* Too many iterations in TQLI */
                    }
                    g = (d[l+1] - d[l]) / (2.0 * e[l])
                    r = sqrt((g * g) + 1.0)
                    g = d[mm] - d[l] + e[l] / (g + SIGN(r, g))
                    s = 1.0
                    c = 1.0
                    p = 0.0
                    for i in stride(from: mm - 1, through: l, by: -1) { //for i in m-1; i>=l; i-- )
                        f = s * e[i]
                        b = c * e[i]
                        if fabs(f) >= fabs(g) {
                            c = g / f
                            r = sqrt((c * c) + 1.0)
                            e[i+1] = f * r
                            s = 1.0 / r
                            c *= s
                        }
                        else {
                            s = f / g
                            r = sqrt((s * s) + 1.0)
                            e[i+1] = g * r
                            c = 1.0 / r
                            s *= c
                        }
                        g = d[i+1] - p
                        r = (d[i] - g) * s + 2.0 * c * b
                        p = s * r
                        d[i+1] = g + p
                        g = c * r - b
                        /* Next loop can be omitted if eigenvectors not wanted */
                        for k in 0..<n {
                            f = z[k][i+1]
                            z[k][i+1] = s * z[k][i] + c * f
                            z[k][i] = c * z[k][i] - s * f
                        }
                    }
                    d[l] = d[l]-p
                    e[l] = g
                    e[mm] = 0.0
                }
            } while mm != l
        }
        
        return 1
    }


    class func G_tred2(a: inout [[Double]], n: Int, d: inout [Double], e: inout [Double]) -> Void {
        var scale: Double, hh: Double, h: Double, g: Double, f: Double
        var l: Int
        
//        for var i=10; i>=0; --i {
//        for i in 10.stride (through: 0, by: -1) {
        
        for i in stride(from: n-1, through: 1, by: -1) { // for i = n - 1; i >= 1; i-- )
            l = i - 1
            h = 0.0
            scale = 0.0
            if l > 0 {
                for k in 0...l {
                    scale += fabs(a[i][k])
                }
                if scale == 0.0 {
                    e[i] = a[i][l]
                }
                else {
                    for k in 0...l {
                        a[i][k] /= scale
                        h += a[i][k] * a[i][k]
                    }
                    f = a[i][l]
                    g = f > 0 ? -sqrt(h) : sqrt(h)
                    e[i] = scale * g
                    h -= f * g
                    a[i][l] = f - g
                    f = 0.0
                    for j in 0...l {
                    /* Next statement can be omitted if eigenvectors not wanted */
                        a[j][i] = a[i][j] / h
                        g = 0.0
                        for k in 0...j {
                            g += a[j][k] * a[i][k]
                        }
                        for k in j + 1...l {
                            g += a[k][j] * a[i][k]
                        }
                        e[j] = g / h
                        f += e[j] * a[i][j]
                    }
                    hh = f / (h + h)
                    for j in 0...l {
                        f = a[i][j]
                        e[j] = e[j] - hh * f
                        g = e[j]
                        for k in 0...j {
                            a[j][k] -= (f * e[k] + g * a[i][k])
                        }
                    }
                }
            }
            else {
                e[i] = a[i][l]
            }
            d[i] = h
        }
        /* Next statement can be omitted if eigenvectors not wanted */
        d[0] = 0.0
        e[0] = 0.0
        /* Contents of this loop can be omitted if eigenvectors not
                wanted except for statement d[i]=a[i][i]; */
        for i in 0..<n {
            l = i - 1
            if d[i] != 0 {
                for j in 0...l {
                    g = 0.0;
                    for k in 0...l {
                        g += a[i][k] * a[k][j]
                    }
                    for k in 0...l {
                        a[k][j] -= g * a[k][i]
                    }
                }
            }
            d[i] = a[i][i]
            a[i][i] = 1.0
            if l > -1 {
                for j in 0...l {
                    a[j][i] = 0.0
                    a[i][j] = 0.0
                }
            }
        }
    }

}
