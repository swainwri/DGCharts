//
//  Contour.swift
//  DGCharts(Contouring)
//
//  Created by Steve Wainwright on 23/03/2023.
//

// _contour.swift: implementation of the Contour class.
//
//
// _contour implements Contour plot algorithm described in
//        IMPLEMENTATION OF
//        AN IMPROVED CONTOUR
//        PLOTTING ALGORITHM
//        BY
//
//        MICHAEL JOSEPH ARAMINI
//
//        B.S., Stevens Institute of Technology, 1980
// See http://www.ultranet.com/~aramini/thesis.html
//
// Ported to C++ by Jonathan de Halleux.
// Ported to ObjC by Steve Wainwright 2021.
// Ported to Swift by Steve Wainwright 2023.
//
// Using _Contour :
//
// _Contour is not directly usable. The user has to
//    1. derive the function ExportLine that is
//        supposed to draw/store the segment of the contour
//    2. Set the function draw contour of. (using  SetFieldFn
//        The function must be declared as follows
//        double (*myF)(double x , double y);
//
//    History:
//        31-07-2002:
//            - A lot of contribution from Chenggang Zhou (better strip compressions, merging, area, weight),
//

import Foundation

let NEGINF = ((-1.0) / 0.0)
let POSINF = ((1.0) / 0.0)

// A structure used internally by CPTContour
struct FunctionDatum {
    var value: Double
    var leftLength: Int16
    var rightLength: Int16
    var topLength: Int16
    var bottomLength: Int16
    
    init() {
        value = 0
        leftLength = 0
        rightLength = 0
        topLength = 0
        bottomLength = 0
    }
}

public class Contour: NSObject {
    
    var containsFunctionNans: Bool = false
    var containsFunctionInfinities: Bool = false
    var containsFunctionNegativeInfinities: Bool = false
    
    // Inaccessibles variables
    var noColumnsFirst: Int = 64           // primary    grid, number of columns
    var noRowsFirst: Int = 64              // primary    grid, number of rows
    var noColumnsSecondary: Int = 1024     // secondary grid, number of columns
    var noRowsSecondary: Int = 1024        // secondary grid, number of rows
    var limits: [Double] = [ -1, 1, -1, 1 ]   // left, right, bottom, top
        
    //    double (*fieldFunction)(double x, double y); // pointer to F(x,y) function
        
    var fieldBlock: ((Double, Double) -> Double)? // block to F(x,y) function
    var noPlanes: Int = 11     // no of isocurves to breakdown

    // Work functions and variables
    var deltaX: Double = 0
    var deltaY: Double = 0

    var contourPlanes: [Double] = []
    var discontinuities: [Int] = []
    var maxColumnsByRows: Int = 1025 * 1025

    var functionData: [[FunctionDatum]] = [] //mesh parts
    
    // MARK: - Construction
    
    override init() {
        noColumnsFirst = 64
        noRowsFirst = 64
        noColumnsSecondary = 1024
        noRowsSecondary = 1024

        deltaX = 0
        deltaY = 0
//        fieldBlock = NULL;
        limits[0] = -1.0
        limits[1] = 1.0
        limits[2] = -1.0
        limits[3] = 1.0

        noPlanes = 11
        
        for i in 0..<self.noPlanes {
            contourPlanes.append(Double(i - self.noPlanes / 2) * 0.1)
        }
        maxColumnsByRows = (noColumnsSecondary + 1) * (noRowsSecondary + 1)
    }
    
    init(noIsoCurves: Int, isoCurveValues:[Double], limits:[Double]) {
        
        assert(isoCurveValues.count == noIsoCurves, "No of isoCurveValues not equal to noIsoCurves")
        assert(limits.count == 4, "Limits needs min X, max X, minY & max Y, 4 values")
        assert(limits[0] < limits[1], "X: lower limit must be less than upper limit")
        assert(limits[2] < limits[3], "Y: lower limit must be less than upper limit")
        
        noColumnsFirst = 64
        noRowsFirst = 64
        noColumnsSecondary = 1024
        noRowsSecondary = 1024

        deltaX = 0
        deltaY = 0
//        fieldBlock = NULL;
        self.limits[0] = limits[0]
        self.limits[1] = limits[1]
        self.limits[2] = limits[2]
        self.limits[3] = limits[3]
//        functionData = NULL;
        noPlanes = noIsoCurves
        
        for i in 0..<self.noPlanes {
            contourPlanes.append(isoCurveValues[i])
        }
        maxColumnsByRows = (noColumnsSecondary + 1) * (noRowsSecondary + 1)
    }
    
    func initialiseMemory() {
        if functionData.isEmpty {
            functionData = Array(repeating: [], count: noColumnsSecondary + 1)
        }
    }
    
    func cleanMemory() {
        if !functionData.isEmpty {
            for i in 0..<noColumnsSecondary+1 {
                functionData[i].removeAll()
            }
            functionData.removeAll()
        }
    }
    
    // MARK: - Generate Contours

    private var once: Bool = false

    func generate() -> Void {
        let cols: Int = self.noColumnsSecondary + 1
        let rows: Int = self.noRowsSecondary + 1
        
        self.maxColumnsByRows = cols * rows
        
        // Initialize memory if needed
        self.initialiseMemory()
        
        self.deltaX = (self.limits[1] - self.limits[0]) / Double(self.noColumnsSecondary)
        self.deltaY = (self.limits[3] - self.limits[2]) / Double(self.noRowsSecondary)
        
        var xlow: Int = 0
        var oldx3: Int = 0
        var x3: Int = (cols - 1) / self.noRowsFirst
        var x4: Int = (2 * (cols - 1)) / self.noRowsFirst
        
        for x in oldx3...x4 {      // allocate new columns needed
            if x >= cols {
                break
            }
            if self.functionData[x].isEmpty {
                self.functionData[x] = Array(repeating: FunctionDatum(), count: rows)
            }
            for y in 0..<rows {
                self.functionData[x][y].topLength = -1
            }
        }
        
        var y4: Int = 0
        var y3: Int = 0
        for j in 0..<self.noColumnsFirst {
            y3 = y4
            y4 = ((j + 1) * (rows - 1)) / self.noColumnsFirst
            contour1(x1: oldx3, x2: x3, y1: y3, y2: y4)
        }
        
        for i in 1..<self.noRowsFirst {
            y4 = 0
            for j in 0..<self.noColumnsFirst {
                y3 = y4
                y4 = ((j + 1) * (rows - 1)) / self.noColumnsFirst
                contour1(x1: x3, x2: x4, y1: y3, y2: y4)
            }

            y4 = 0
            for j in 0..<self.noColumnsFirst {
                y3 = y4
                y4 = ((j + 1) * (rows - 1)) / self.noColumnsFirst
                pass2(x1: oldx3, x2: x3, y1: y3, y2: y4)
            }

            if i < self.noRowsFirst - 1 {     /* re-use columns no longer needed */
                oldx3 = x3
                x3 = x4
                x4 = ((i + 2) * (cols - 1)) / self.noRowsFirst
                for x in x3+1...x4 {
                    if xlow < oldx3 {
                        self.functionData[x] = self.functionData[xlow]
                        self.functionData[xlow].removeAll()
                        xlow += 1
                    }
                    else {
                        if self.functionData[x].isEmpty {
                            self.functionData[x] = Array(repeating: FunctionDatum(), count: Int(rows))
                        }
                    }
                    for y in 0..<rows {
                        self.functionData[x][y].topLength = -1
                    }
                }
            }
        }
        
        y4 = 0
        for j in 0..<self.noColumnsFirst {
            y3 = y4
            y4 = ((j + 1) * (rows - 1)) / self.noColumnsFirst
            pass2(x1: x3, x2: x4, y1: y3, y2: y4)
        }
        
        if discontinuities.count > 0 {
            self.containsFunctionNans = true
            
            if !once {
                once = true
//                [self cleanMemory];
                discontinuities.removeAll()
                contourPlanes.append(contourPlanes[contourPlanes.count - 1] * 10.0)
                contourPlanes.insert(contourPlanes[0] * (contourPlanes[0] < 0 ? 10.0 : -10), at: 0)
                self.noPlanes += 2
                generate()
            }
        }
    }
    
    private func contour1(x1: Int, x2: Int, y1: Int, y2: Int) -> Void {
    
        if x1 == x2 || y1 == y2 {  /* if not a real cell, punt */
            return
        }
        var f11: Double = self.field(forX: x1, y: y1)
        var f12: Double = self.field(forX: x1, y: y2)
        var f21: Double = self.field(forX: x2, y: y1)
        var f22: Double = self.field(forX: x2, y: y2)
        var f33: Double

        if f11.isNaN || f11 == POSINF || f11 == NEGINF {
            let index = y1 * (self.noRowsSecondary + 1) + x1
            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                discontinuities.append(index)
            }
            if f11.isNaN || f11 == NEGINF {
                f11 = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
            }
            else if f11 == POSINF {
                f11 = getIsoCurve(at: self.noPlanes - 1) * 10.0
            }
        }
        if f12.isNaN || f12 == POSINF || f12 == NEGINF {
            let index = y2 * (self.noRowsSecondary + 1) + x1
            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                discontinuities.append(index)
            }
            if f12.isNaN || f12 == NEGINF  {
                f12 = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
            }
            else if  f12 == POSINF {
                f12 = getIsoCurve(at: self.noPlanes - 1) * 10.0
            }
        }
        if f21.isNaN || f21 == POSINF || f21 == NEGINF {
            let index = y1 * (self.noRowsSecondary + 1) + x2
            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                discontinuities.append(index)
            }
            if f21.isNaN || f21 == NEGINF  {
                f21 = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
            }
            else if f21 == POSINF {
                f21 = getIsoCurve(at: self.noPlanes - 1) * 10.0
            }
        }
        if f22.isNaN || f22 == POSINF || f22 == NEGINF  {
            let index = y2 * (self.noRowsSecondary + 1) + x2
            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                discontinuities.append(index)
            }
            if f22.isNaN || f22 == NEGINF  {
                f22 = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
            }
            else if f22 == POSINF {
                f22 = getIsoCurve(at: self.noPlanes - 1) * 10.0
            }
        }
        
        if x2 > x1 + 1 || y2 > y1 + 1 {    /* is cell divisible? */
            let x3 = (x1 + x2) / 2
            let y3 = (y1 + y2) / 2
            f33 = self.field(forX: x3, y: y3)
            if f33.isNaN || f33 == POSINF || f33 == NEGINF {
                let index = y3 * (self.noRowsSecondary + 1) + x3
                if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                    discontinuities.append(index)
                }
                if f33.isNaN || f33 == NEGINF {
                    f33 = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
                }
                else if f33 == POSINF {
                    f33 = getIsoCurve(at: self.noPlanes - 1) * 10.0
                }
            }
            var i: Int = 0
            var j: Int = 0
            if f33 < f11 {
                i += 1
            }
            else if f33 > f11 {
                j += 1
            }
            if f33 < f12 {
                i += 1
            }
            else if f33 > f12 {
                j += 1
            }
            if f33 < f21 {
                i += 1
            }
            else if f33 > f21 {
                j += 1
            }
            if f33 < f22 {
                i += 1
            }
            else if f33 > f22 {
                j += 1
            }
            if i > 2 || j > 2 { // should we divide cell?
                /* subdivide cell */
                contour1(x1: x1, x2: x3, y1: y1, y2: y3)
                contour1(x1: x3, x2: x2, y1: y1, y2: y3)
                contour1(x1: x1, x2: x3, y1: y3, y2: y2)
                contour1(x1: x3, x2: x2, y1: y3, y2: y2)
                return
            }
        }
        /* install cell in array */
        self.functionData[x1][y2].bottomLength = Int16(x2 - x1)
        self.functionData[x1][y1].topLength = Int16(x2 - x1)
        self.functionData[x2][y1].leftLength = Int16(y2 - y1)
        self.functionData[x1][y1].rightLength = Int16(y2 - y1)
    }

    private func pass2(x1: Int, x2: Int, y1: Int, y2: Int) -> Void {
        
        if x1 == x2 || y1 == y2 {    // if not a real cell, punt
            return
        }
        
        var left: Int = 0, right: Int = 0, top: Int = 0, bot: Int = 0
        var yy0: Double = 0.0, yy1: Double = 0.0, xx0: Double = 0.0, xx1: Double = 0.0
        var xx3: Double, yy3: Double
        var v: Double, f33: Double, fold: Double, fnew: Double = 0, f: Double
        let xoff = self.limits[0]
        let yoff = self.limits[2]
        
        var f11 = self.functionData[x1][y1].value
        var f12 = self.functionData[x1][y2].value
        var f21 = self.functionData[x2][y1].value
        var f22 = self.functionData[x2][y2].value
        
        if f11.isNaN || f11 == POSINF || f11 == NEGINF  {
            let index = y1 * (self.noRowsSecondary + 1) + x1
            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                discontinuities.append(index)
            }
            if f11.isNaN || f11 == NEGINF  {
                f11 = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
            }
            else if f11 == POSINF {
                f11 = getIsoCurve(at: self.noPlanes - 1) * 10.0
            }
        }
        if f12.isNaN || f12 == POSINF || f12 == NEGINF  {
            let index = y2 * (self.noRowsSecondary + 1) + x1
            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                discontinuities.append(index)
            }
            if f12.isNaN || f12 == NEGINF  {
                f12 = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
            }
            else if f12 == POSINF {
                f12 = getIsoCurve(at: self.noPlanes - 1) * 10.0
            }
        }
        if f21.isNaN || f21 == POSINF || f21 == NEGINF  {
            let index = y1 * (self.noRowsSecondary + 1) + x2
            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                discontinuities.append(index)
            }
            if f21.isNaN || f21 == NEGINF {
                f21 = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
            }
            else if f21 == POSINF {
                f21 = getIsoCurve(at: self.noPlanes - 1) * 10.0
            }
        }
        if f22.isNaN || f22 == POSINF || f22 == NEGINF  {
            let index = y2 * (self.noRowsSecondary + 1) + x2
            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                discontinuities.append(index)
            }
            if f22.isNaN || f22 == NEGINF  {
                f22 = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
            }
            else if f22 == POSINF {
                f22 = getIsoCurve(at: self.noPlanes - 1) * 10.0
            }
        }
        
        if x2 > x1 + 1 || y2 > y1 + 1 {   // is cell divisible?
            let x3 = (x1 + x2) / 2
            let y3 = (y1 + y2) / 2
            f33 = self.functionData[x3][y3].value
            if f33.isNaN || f33 == POSINF || f33 == NEGINF {
                let index = y3 * (self.noRowsSecondary + 1) + x3
                if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                    discontinuities.append(index)
                }
                if f33.isNaN || f33 == NEGINF {
                    f33 = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
                }
                else if f33 == POSINF {
                    f33 = getIsoCurve(at: self.noPlanes - 1) * 10.0
                }
            }
            var i: Int = 0
            var j: Int = 0
             if f33 < f11 {
                 i += 1
             }
             else if f33 > f11 {
                 j += 1
             }
             if f33 < f12 {
                 i += 1
             }
             else if f33 > f12 {
                 j += 1
             }
             if f33 < f21 {
                 i += 1
             }
             else if f33 > f21 {
                 j += 1
             }
             if f33 < f22 {
                 i += 1
             }
             else if f33 > f22 {
                 j += 1
             }
            
            if i > 2 || j > 2 {   // should we divide cell?
                // subdivide cell
                pass2(x1: x1, x2: x3, y1: y1, y2: y3)
                pass2(x1: x3, x2: x2, y1: y1, y2: y3)
                pass2(x1: x1, x2: x3, y1: y3, y2: y2)
                pass2(x1: x3, x2: x2, y1: y3, y2: y2)
                return
            }
        }
        var old: Int = NSNotFound
        var iNew: Int = NSNotFound
        for i in 0..<contourPlanes.count {
            v = contourPlanes[i]
            var j: Int = 0
            if f21 > v { j += 1 }
            if f11 > v { j |= 2 }
            if f22 > v { j |= 4 }
            if f12 > v { j |= 0o10}  // octal
            
            if (f11 > v) ^ (f12 > v) {
                if self.functionData[x1][y1].leftLength != 0 &&
                    self.functionData[x1][y1].leftLength < self.functionData[x1][y1].rightLength {
                    old = y1
                    fold = f11
                    
                    while true {
                        iNew = old + Int(self.functionData[x1][old].leftLength)
                        fnew = self.functionData[x1][iNew].value
                        if fnew.isNaN || fnew == POSINF || fnew == NEGINF {
                            let index = iNew * (self.noRowsSecondary + 1) + x1
                            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                                discontinuities.append(index)
                            }
                            if fnew.isNaN || fnew == NEGINF {
                                fnew = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
                            }
                            else if fnew == POSINF  {
                                fnew = getIsoCurve(at: self.noPlanes - 1) * 10.0
                            }
                        }
                        if (fnew > v) ^ (fold > v)  {
                            break
                        }
                        old = iNew
                        fold = fnew
                    }
                    yy0 = (Double(old - y1) + Double(iNew - old) * (v - fold) / (fnew - fold)) / Double(y2 - y1)
                }
                else {
                    yy0 = (v - f11) / (f12 - f11)
                }
                left = Int((Double(y1) + Double(y2 - y1) * yy0 + 0.5))
            }
            if (f21 > v) ^ (f22 > v) {
                if self.functionData[x2][y1].rightLength != 0 &&
                    self.functionData[x2][y1].rightLength < self.functionData[x2][y1].leftLength {
                    old = y1
                    fold = f21
                    while true {
                        iNew = old + Int(self.functionData[x2][old].rightLength)
                        fnew = self.functionData[x2][iNew].value
                        if fnew.isNaN || fnew == POSINF || fnew == NEGINF {
                            let index = iNew * (self.noRowsSecondary + 1) + x1
                            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                                discontinuities.append(index)
                            }
                            if fnew.isNaN || fnew == NEGINF {
                                fnew = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
                            }
                            else if fnew == POSINF  {
                                fnew = getIsoCurve(at: self.noPlanes - 1) * 10.0
                            }
                        }
                        if (fnew > v) ^ (fold > v) {
                            break
                        }
                        old = iNew
                        fold = fnew
                    }
                    yy1 = (Double(old - y1) + Double(iNew - old) * (v - fold) / (fnew - fold)) / Double(y2 - y1)
                }
                else {
                    yy1 = (v - f21) / (f22 - f21)
                }
                right = Int(Double(y1) + Double(y2 - y1) * yy1 + 0.5)
            }
            if (f21 > v) ^ (f11 > v) {
                if self.functionData[x1][y1].bottomLength != 0 &&
                    self.functionData[x1][y1].bottomLength < self.functionData[x1][y1].topLength {
                    old = x1
                    fold = f11
                    while true {
                        iNew = old + Int(self.functionData[old][y1].bottomLength)
                        fnew = self.functionData[iNew][y1].value
                        if fnew.isNaN || fnew == POSINF || fnew == NEGINF {
                            let index = iNew * (self.noRowsSecondary + 1) + x1
                            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                                discontinuities.append(index)
                            }
                            if fnew.isNaN || fnew == NEGINF {
                                fnew = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
                            }
                            else if fnew == POSINF  {
                                fnew = getIsoCurve(at: self.noPlanes - 1) * 10.0
                            }
                        }
                        if (fnew > v) ^ (fold > v)  {
                            break
                        }
                        old = iNew
                        fold = fnew
                    }
                    xx0 = (Double(old - x1) + Double(iNew - old) * (v - fold) / (fnew - fold)) / Double(x2 - x1)
                }
                else {
                    xx0 = (v - f11) / (f21 - f11)
                }
                bot = Int(Double(x1) + Double(x2 - x1) * xx0 + 0.5)
            }
            if (f22 > v) ^ (f12 > v) {
                if self.functionData[x1][y2].topLength != 0 &&
                    self.functionData[x1][y2].topLength < self.functionData[x1][y2].bottomLength {
                    old = x1
                    fold = f12
                    while true {
                        iNew = old + Int(self.functionData[old][y2].topLength)
                        fnew = self.functionData[iNew][y2].value
                        if fnew.isNaN || fnew == POSINF || fnew == NEGINF {
                            let index = iNew * (self.noRowsSecondary + 1) + x1
                            if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                                discontinuities.append(index)
                            }
                            if fnew.isNaN || fnew == NEGINF {
                                fnew = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
                            }
                            else if fnew == POSINF  {
                                fnew = getIsoCurve(at: self.noPlanes - 1) * 10.0
                            }
                        }
                        if (fnew > v) ^ (fold > v)  {
                            break
                        }
                        old = iNew
                        fold = fnew
                    }
                    xx1 = (Double(old - x1) + Double(iNew - old) * (v - fold) / (fnew - fold)) / Double(x2 - x1)
                }
                else {
                    xx1 = (v - f12) / (f22 - f12)
                }
                top = Int(Double(x1) + Double(x2 - x1) * xx1 + 0.5)
            }

            if !(xx0.isNaN || yy0.isNaN || xx1.isNaN || yy1.isNaN) {
                switch (j) {
                    case 7, 0o10:
                        exportLineForIsoCurve(iPlane: i, x1: x1, y1: left, x2: top, y2: y2)
                    case 5, 0o12:
                        exportLineForIsoCurve(iPlane: i, x1: bot, y1: y1, x2: top, y2: y2)
                    case 2, 0o15:
                        exportLineForIsoCurve(iPlane: i, x1: x1, y1: left, x2: bot, y2: y1)
                    case 4, 0o13:
                        exportLineForIsoCurve(iPlane: i, x1: top, y1: y2, x2: x2, y2: right)
                    case 3, 0o14:
                        exportLineForIsoCurve(iPlane: i, x1: x1, y1: left, x2: x2, y2: right)
                    case 1, 0o16:
                        exportLineForIsoCurve(iPlane: i, x1: bot, y1: y1, x2: x2, y2: right)
                    case 0, 0o17:
                        break;
                    case 6, 0o11:
                        yy3 = (xx0 * (yy1 - yy0) + yy0) / (1.0 - (xx1 - xx0) * (yy1 - yy0))
                        xx3 = yy3 * (xx1 - xx0) + xx0
                        xx3 = Double(x1) + xx3 * Double(x2 - x1)
                        yy3 = Double(y1) + yy3 * Double(y2 - y1)
        //                x3 = (NSUInteger)xx3;
        //                y3 = (NSUInteger)yy3;
                        xx3 = xoff + xx3 * self.deltaX
                        yy3 = yoff + yy3 * self.deltaY
                        /*if (fieldFunction != NULL) {
                            f = (*fieldFunction)(xx3, yy3);
                        }
                        else*/
                        if let _fieldBlock = self.fieldBlock {
                            f = _fieldBlock(xx3, yy3)
                            if f.isNaN || f == POSINF || f == NEGINF  {
                                let index = self.getIndex(x: xx3, y: yy3)
//                                let index = iNew * (self.noRowsSecondary + 1) + x1
                                if index < maxColumnsByRows && self.discontinuities.contains(where: { $0 == index } ) {
                                    discontinuities.append(index)
                                }
                                if f.isNaN || f == NEGINF {
                                    f = getIsoCurve(at: 0) * (getIsoCurve(at: 0) < 0 ? 10.0 : -10)
                                }
                                else if f == POSINF  {
                                    f = getIsoCurve(at: self.noPlanes - 1) * 10.0
                                }
                            }
                        }
                        else {
                            f = 0.0
                        }
                        
                        if f == v {
                            exportLineForIsoCurve(iPlane: i, x1: bot, y1: y1, x2: top, y2: y2)
                            exportLineForIsoCurve(iPlane: i, x1: x1, y1: left, x2: x2, y2: right)
                        }
                        else {
                            if ((f > v) && (f22 > v)) || ((f < v) && (f22 < v)) {
                                exportLineForIsoCurve(iPlane: i, x1: x1, y1: left, x2: top, y2: y2)
                                exportLineForIsoCurve(iPlane: i, x1: bot, y1: y1, x2: x2, y2: right)
                            }
                            else {
                                exportLineForIsoCurve(iPlane: i, x1: x1, y1: left, x2: bot, y2: y1)
                                exportLineForIsoCurve(iPlane: i, x1: top, y1: y2, x2: x2, y2: right)
                            }
                        }
                    
                    default:
                        break
                }
            }
        }
    }

    private func field(forX x: Int, y: Int) -> Double {   /* evaluate funct if we must,    */
        if self.functionData[x][y].topLength != -1 { /* is it already in the array */
            return self.functionData[x][y].value
        }
        /* not in the array, create new array element */
        let x1: Double = self.limits[0] + self.deltaX * Double(x)
        let y1: Double = self.limits[2] + self.deltaY * Double(y)
        self.functionData[x][y].topLength = 0
        self.functionData[x][y].bottomLength = 0
        self.functionData[x][y].rightLength = 0
        self.functionData[x][y].leftLength = 0
        /*if (self.fieldFunction != NULL) {
            return (self.functionData[x][y].value = (*m_pFieldFcn)(x1, y1));
        }
        else*/ if let _fieldBlock = self.fieldBlock  {
            self.functionData[x][y].value = _fieldBlock(x1, y1)
            return self.functionData[x][y].value
        }
        else {
            return -0.0
        }
    }
    
    func exportLineForIsoCurve(iPlane: Int, x1: Int, y1: Int, x2: Int, y2: Int) {// plots a line from (x1,y1) to (x2,y2)
    }
                 
    // MARK: - Accessors & Setters
    
    func getNoIsoCurves() -> Int {
        return contourPlanes.count
    }

    func getContourPlanes() -> ContourPlanes {
        return self.contourPlanes
    }

    func getDiscontinuities() -> Discontinuities {
        return self.discontinuities
    }
    
    func getLimits() -> [Double] {
        return self.limits
    }
                
    func getIsoCurve(at i: Int) -> Double {
        assert(i != NSNotFound && i < self.contourPlanes.count, "Plane asked for is not between assigned")
        return self.contourPlanes[i]
    }

    // For an indexed point i on the sec. grid, returns x(i)
    func getX(at i: Int) -> Double {
        return self.limits[0] + Double(i % (self.noColumnsSecondary + 1)) * (self.limits[1] - self.limits[0]) / Double(self.noColumnsSecondary)
    }
                                                                                               
    // For an indexed point i on the fir. grid, returns y(i)
    func getY(at i: Int) -> Double {
        assert(i >= 0, "Index must be >= 0")
        return self.limits[2] + Double(i / (self.noColumnsSecondary + 1)) * (self.limits[3] - self.limits[2]) / Double(self.noRowsSecondary)
    }

    func getIndex(x: Double, y: Double) -> Int {
        var index: Int = NSNotFound
        if x >= self.limits[0] && x <= self.limits[1] && y >= self.limits[2] && y <= self.limits[3] {
            let row = Int((y - self.limits[2]) / (self.limits[3] - self.limits[2]) * Double(self.noRowsSecondary * (self.noColumnsSecondary + 1)))
            let col = Int((x - self.limits[0]) / (self.limits[1] - self.limits[0]) * Double(self.noColumnsSecondary))
            index = row + col
        }
        return index
    }

    func getFieldValue(x: Double, y: Double) -> Double {
        if let _fieldBlock = self.fieldBlock {
            return _fieldBlock(x, y)
        }
        else {
            return -0.0;
        }
    }
    
    func setIsoCurveValues(_ contourPlanes: [Double]) -> Void {
        self.contourPlanes = contourPlanes
    }

    func setLimits(_ limits: [Double]) -> Void {
        self.limits = limits
    }

    // Set the dimension of the primary grid
    func setFirstGridDimensionColumns(cols: Int, rows: Int) -> Void {
        self.noColumnsFirst = max(cols, 2)
        self.noRowsFirst = max(rows, 2)
    }

    // Set the dimension of the base grid
    func setSecondaryGridDimensionColumns(cols: Int, rows: Int) -> Void {
       // [self cleanMemory]
        self.noColumnsSecondary = max(cols, 2)
        self.noRowsSecondary = max(rows, 2)
    }

}


