//
//  Listcontour.swift
//  DGCharts (Contouring)
//
//  Created by Steve Wainwright on 23/03/2023.
//
// _ListContour.m: implementation of the _ListContour class.
//
// _ListContour.h: interface for the _ListContour class.
//
// _ListContour implements Contour plot algorithm described in
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

public class ListCountour: Contour {
    
    var overrideWeldDistance: Bool = false
    var overrideWeldDistMultiplier: Double = 1.0
    
    private var stripLists: IsoCurvesList = []
    
    override init(noIsoCurves: Int, isoCurveValues: [Double], limits: [Double]) {
        
        assert(isoCurveValues.count == noIsoCurves, "No of isoCurveValues not equal to noIsoCurves")
        assert(limits.count == 4, "Limits needs min X, max X, minY & max Y, 4 values")
        assert(limits[0] < limits[1], "X: lower limit must be less than upper limit")
        assert(limits[2] < limits[3], "Y: lower limit must be less than upper limit")
        
        super.init(noIsoCurves: noIsoCurves, isoCurveValues: isoCurveValues, limits: limits)
        self.overrideWeldDistance = false
        overrideWeldDistMultiplier = 1.0
        
        for _ in 0..<noIsoCurves {
            let list: LineStripList = []
            self.stripLists.append(list)
        }
    }
    
    override func exportLineForIsoCurve(iPlane: Int, x1: Int, y1: Int, x2: Int, y2: Int) {// plots a line from
   
        assert(iPlane != NSNotFound && iPlane < self.contourPlanes.count, "Plane index is not valid 0 to no. Planes");
        // check that the two points are not at the beginning or end of the some line strip
        let i1 = y1 * (self.noColumnsSecondary + 1) + x1
        let i2 = y2 * (self.noColumnsSecondary + 1) + x2
        
        if i1 < 0 || i2 < 0 {
            self.overrideWeldDistance = true
    //        return;
        }
        
        if self.stripLists[iPlane].count == 0 {
            var strip = LineStrip()
            strip.append(i1)
            strip.append(i2)
            self.stripLists[iPlane].append(strip)
        }
        else {
            var added = false
            for pos in 0..<self.stripLists[iPlane].count {
                if !added {
                    let strip = self.stripLists[iPlane][pos]
                    if i1 == strip[0] {
                        self.stripLists[iPlane][pos].insert(i2, at: 0)
                        added = true
                        break
                    }
                    else if i1 == strip[strip.count - 1] {
                        self.stripLists[iPlane][pos].append(i2)
                        added = true
                        break
                    }
                    else if i2 == strip[0] {
                        self.stripLists[iPlane][pos].insert(i1, at: 0)
                        added = true
                        break
                    }
                    else if i2 == strip[strip.count - 1] {
                        self.stripLists[iPlane][pos].append(i1)
                        added = true
                        break
                    }
                }
            }
            if !added {
                // segment was not part of any line strip, creating new one
                var strip = LineStrip()
                strip.append(i1)
                strip.append(i2)
                self.stripLists[iPlane].insert(strip, at: 0)
            }
        }
        
    }
    
    func generateAndCompactStrips() -> Void {
        // generate line strips
        generate()
        // compact strips
        compactStrips()
    }
    
    override func initialiseMemory() {
        if  self.stripLists.count > 0 {
            super.cleanMemory()
        }
        super.initialiseMemory()
        
        let noIsoCurves = self.contourPlanes.count
        self.stripLists.removeAll()
        
        for _ in 0..<noIsoCurves {
            self.stripLists.append([])
        }
    }

    func forceMerge(_ strip1: inout LineStrip, with strip2: inout LineStrip) -> Bool {
        
        if strip2.count == 0 {
            return false
        }
        
        var x: [Double] = Array(repeating: 0.0, count: 4)
        var y: [Double] = Array(repeating: 0.0, count: 4)
        var weldDist: Double = 0
        var edge: [Bool] = Array(repeating: false, count: 4)
        var index = strip1[0]
        x[0] = getX(at: index)
        y[0] = getY(at: index)
        edge[0] = isNodeOnBoundary(index)
        index = strip1[strip1.count - 1]
        x[1] = getX(at:index)
        y[1] = getY(at:index)
        edge[1] = isNodeOnBoundary(index)
    //    double gradient01 = (y[1] - y[0]) / (x[1] - x[0]);
        
        index = strip2[0]
        x[2] = getX(at:index)
        y[2] = getY(at:index)
        edge[2] = isNodeOnBoundary(index)
        index = strip2[strip2.count - 1]
        x[3] = getX(at:index)
        y[3] = getY(at:index)
        edge[3] = isNodeOnBoundary(index)
    //    double gradient23 = (y[3] - y[2]) / (x[3] - x[2]);
        
    //    BOOL centreLine = (isinf(gradient01) || gradient01 == 0.0) && (isinf(gradient23) || gradient23 == 0.0) && self.containsFunctionNans;
        
        weldDist = overrideWeldDistMultiplier * (pow(self.deltaX, 2.0) + pow(self.deltaY, 2.0))
        if self.overrideWeldDistance {
            weldDist *= overrideWeldDistMultiplier
        }
        let diff12 = (x[1] - x[2]) * (x[1] - x[2]) + (y[1] - y[2]) * (y[1] - y[2])
        if (diff12 < weldDist || (diff12 < weldDist * overrideWeldDistMultiplier && self.containsFunctionNans)) && !edge[1] && !edge[2] {
            for i in 0..<strip2.count {
                index = strip2[i]
                assert(index >= 0, "index has to be >= 0")
                strip1.append(index)
            }
            strip2.removeAll()
            return true
        }
        let diff30 = (x[3] - x[0]) * (x[3] - x[0]) + (y[3] - y[0]) * (y[3] - y[0])
        if (diff30 < weldDist || (diff30 < weldDist * overrideWeldDistMultiplier && self.containsFunctionNans)) && !edge[3] && !edge[0] {
            for i in stride(from: strip2.count - 1, through: 0, by: -1) {
                index = strip2[i]
                assert(index >= 0, "index has to be >= 0")
                strip1.insert(index, at: 0)
            }
            strip2.removeAll()
            return true
        }
        let diff13 = (x[1] - x[3]) * (x[1] - x[3]) + (y[1] - y[3]) * (y[1] - y[3])
        if (diff13 < weldDist || (diff13 < weldDist * overrideWeldDistMultiplier && self.containsFunctionNans)) && !edge[1] && !edge[3] {
            for i in stride(from: strip2.count - 1, through: 0, by: -1) {
                index = strip2[i]
                assert(index >= 0, "index has to be >= 0")
                strip1.append(index)
            }
            strip2.removeAll()
            return true
        }
        let diff02 = (x[0] - x[2]) * (x[0] - x[2]) + (y[0] - y[2]) * (y[0] - y[2])
        if (diff02 < weldDist || (diff02 < weldDist * overrideWeldDistMultiplier && self.containsFunctionNans)) && !edge[0] && !edge[2] {
            for i in 0..<strip2.count {
                index = strip2[i]
                assert(index >= 0, "index has to be >= 0")
                strip1.insert(index, at: 0)
            }
            strip2.removeAll()
            return true
        }
                       
        return false
    }
                       
    func mergeStrips(_ strip1: inout LineStrip, with strip2: inout LineStrip) -> Bool {
        if strip2.count == 0 {
            return false
        }
                           
        var index: Int = NSNotFound
        // debugging stuff
        if strip2[0] == strip1[0] {
            // not using first element
            // adding the rest to strip1
            for pos in 1..<strip2.count {
                index = strip2[pos]
                assert(index >= 0 && index != NSNotFound, "index not valid")
                strip1.insert(index, at: 0)
            }
            strip2.removeAll()
            return true
        }
                           
        if strip2[0] == strip1[strip1.count - 1] {
            // adding the rest to strip1
            for pos in 1..<strip2.count {
                index = strip2[pos]
                assert(index >= 0 && index != NSNotFound, "index not valid")
                strip1.append(index)
            }
            strip2.removeAll()
            return true
        }
                           
        if strip2[strip2.count - 1] == strip1[0] {
            for pos in stride(from: strip2.count - 2 , through: 0, by: -1) {
                index = strip2[pos]
                assert(index >= 0, "index not valid");
                strip1.insert(index, at: 0)
            }
            strip2.removeAll()
            return true
       }
                           
        if strip2[strip2.count - 1] == strip1[strip1.count - 1] {
            for pos in stride(from: strip2.count - 2 , through: 0, by: -1) {
                index = strip2[pos]
                assert(index >= 0, "index not valid");
                strip1.append(index)
            }
            strip2.removeAll()
            return true
        }
        return false
    }

    // Basic algorithm to concatanate line strip. Not optimized at all !
    func compactStrips() -> Void {
        assert(stripLists.count == self.contourPlanes.count, "No of Planes(isocurves) not the same a striplist used")
        if stripLists.count > 0  {
            
            var again: Bool = false
            var newList: LineStripList = []
            var distinctStrip1: LineStrip = []
            var distinctStrip2: LineStrip = []
            
            let diffSecondaryToPrimaryColumns = self.noColumnsSecondary / self.noColumnsFirst
            let diffSecondaryToPrimaryRows = self.noRowsSecondary / self.noRowsFirst
            self.overrideWeldDistMultiplier = sqrt(pow(Double(diffSecondaryToPrimaryColumns), 2) + pow(Double(diffSecondaryToPrimaryRows), 2))
            let weldDist = overrideWeldDistMultiplier * (pow(max(self.deltaX, self.deltaY), 2.0))
            //    NSLog(@"wellDist: %f\n", weldDist);
            //    NSLog(@"deltaX: %f\n", [self getDX]);
            //    NSLog(@"deltaY: %f\n", [self getDY]);
            
            for i in 0..<stripLists.count {
                again = true
                while again {
                    // REPEAT COMPACT PROCESS UNTIL LAST PROCESS MAKES NO CHANGE
                    again = false
                    // building compacted list
                    assert(newList.count == 0, "newList is empty")
                    var pos: Int = 0
                    while pos < self.stripLists[i].count {
                        var strip = self.stripLists[i][pos]
                        //#if DEBUG
                        //                  for k in 0..<strip.count {
                        //                      printf("%ld\n", pStrip[k])
                        //                  }
                        //                  printf("\n");
                        //#endif
                        for pos2 in 0..<newList.count {
                            if mergeStrips(&newList[pos2], with: &strip) {
                                again = true
                            }
                            if strip.count == 0 {
                                break
                            }
                        }
                        if strip.count == 0 {
                            //                        pStripList->array[pos].array = NULL;
                            //                        pStripList->array[pos].size = pStripList->array[pos].used = 0;
                            self.stripLists[i].remove(at: pos)
                            pos -= 1
                        }
                        else {
                            newList.insert(strip, at: 0)
                        }
                        pos += 1
                    }
                    
                    // deleting old list
                    self.stripLists[i].removeAll()
                    
                    // Copying all
                    for pos2 in 0..<newList.count {
                        var pos1: Int = 0
                        var pos3: Int
                        while pos1 < newList[pos2].count {
                            pos3 = pos1
                            pos3 += 1
                            if pos3 > newList[pos2].count - 1 {
                                break
                            }
                            if newList[pos2][pos1] == newList[pos2][pos3] {
                                newList[pos2].remove(at: pos3)
                            }
                            else {
                                pos1 += 1
                            }
                        }
                        if newList[pos2].count != 1 {
                            self.stripLists[i].insert(newList[pos2], at: 0)
                        }
                        else {
                            //                        pStripList->array[pos2].array = NULL;
                            //                        pStripList->array[pos2].size = pStripList->array[pos2].used = 0;
                            if pos2 < self.stripLists[i].count {
                                self.stripLists[i].remove(at: pos2)
                            }
                        }
                    }
                    // emptying temp list
                    newList.removeAll()
                    
                } // OF WHILE(AGAIN) (LAST COMPACT PROCESS MADE NO CHANGES)
                
                if self.stripLists[i].count == 0 {
                    continue;
                }
                ///////////////////////////////////////////////////////////////////////
                // compact more
                
                var closed: [Bool] = Array(repeating: false, count: self.stripLists[i].count)
                var x: Double
                var y: Double
                var index: Int
                var count: Int = 0
                var Nstrip: Int = self.stripLists[i].count
                // First let's find the open and closed lists in m_vStripLists
                for j in 0..<self.stripLists[i].count {
                    let strip = self.stripLists[i][j]
                    // is it open ?
                    if strip[0] != strip[strip.count - 1] {
                        index = strip[0]
                        x = getX(at:index)
                        y = getY(at:index)
                        index = strip[strip.count - 1]
                        x -= getX(at:index)
                        y -= getY(at:index)
                        
                        if  x * x + y * y < weldDist && strip.count > 2 { // is it "almost closed" ?
                            closed[j] = true
                        }
                        else {
                            closed[j] = false;
                            count += 1 // updating not closed counter...
                        }
                    }
                    else {
                        closed[j] = true
                    }
                }
                // added S.Wainwright 10/11/2022
                // now find if tiny closed strips are close enough to form an open strip
//                if  /*count > 0 &&*/ self.stripLists[i].count > 2 && self.stripLists[i].count - count > self.stripLists[i].count * 8 / 10 {
//                    var stripNext: LineStrip
//                    var newLineStrip: LineStrip = []
//                    var j: Int = 0
//                    while j < self.stripLists[i].count - 1  {
//                        let strip = self.stripLists[i][j]
//                        var lastPoint = strip.count - 1
//                        var newLastPoint = 0
//                        if !closed[j] && strip.count > 2 {
//                            newLastPoint = newLineStrip.count - 1
//                            lastPoint = strip.count - 1
//                            if strip[0] == newLineStrip[newLastPoint] || strip[lastPoint] == newLineStrip[newLastPoint]  {
//                                distinctStrip1 = distinctElementsInLineStrip(strip)
//                                if distinctStrip1[0] == newLineStrip[newLineStrip.count - 1]  {
//                                    for k in 1..<distinctStrip1.count {
//                                        newLineStrip.append(distinctStrip1[k])
//                                    }
//                                }
//                                else {
//                                    for k in stride(from: distinctStrip1.count - 2 , through: 0, by: -1) {
//                                        newLineStrip.append(distinctStrip1[k])
//                                    }
//                                }
//                                closed.remove(at: j)
//                                self.stripLists[i].remove(at: j)
//                                j -= 1
//                            }
//                            else  {
//                                if newLineStrip.count > 1 {
//                                    let addLineStrip = newLineStrip.clone()
//                                    self.stripLists[i].append(addLineStrip)
//                                    closed[self.stripLists[i].count - 1] = false
//                                    closed.remove(at: j)
//                                    self.stripLists[i].remove(at: j)
//                                }
//                                newLineStrip.removeAll()
//                            }
//                        }
//                        else {
//                            stripNext = self.stripLists[i][j + 1]
//                            let nextLastPoint = stripNext.count - 1
//                            if strip[0] == strip[lastPoint] && stripNext[0] == stripNext[nextLastPoint] {
//                                distinctStrip1 = distinctElementsInLineStrip(strip)
//                                if distinctStrip1.count > 0 && (newLineStrip.count == 0 || newLineStrip[newLastPoint] != distinctStrip1[distinctStrip1.count - 1]) {
//                                    for k in 1..<distinctStrip1.count {
//                                        newLineStrip.append(distinctStrip1[k])
//                                    }
//                                }
//                                distinctStrip2 = distinctElementsInLineStrip(stripNext)
//                                if distinctStrip2.count > 0 && distinctStrip2[0] > distinctStrip1[distinctStrip1.count - 1] && (distinctStrip2[0] - distinctStrip1[distinctStrip1.count - 1]) / self.noColumnsSecondary <= diffSecondaryToPrimaryColumns {
//                                    for k in 1..<distinctStrip2.count {
//                                        newLineStrip.append(distinctStrip2[k])
//                                    }
//                                }
//                                else {
//                                    if  (distinctStrip1[distinctStrip1.count - 1] - distinctStrip2[0]) / self.noColumnsSecondary <= diffSecondaryToPrimaryColumns {
//                                        for k in stride(from: distinctStrip2.count - 1, through: 0, by: -1) {
//                                            newLineStrip.append(distinctStrip2[k])
//                                        }
//                                    }
//                                }
//                                closed.remove(at: j)
//                                self.stripLists[i].remove(at: j)
//                                j -= 1
//                            }
//                            distinctStrip1.removeAll()
//                            distinctStrip2.removeAll()
//                        }
//                        j += 1
//                    }
//                    if newLineStrip.count > 1 {
//                        let addLineStrip = newLineStrip
//                        
//                        //                           copyLineStrip(&newLineStrip, &addLineStrip);
//                        self.stripLists[i].append(addLineStrip)
//                        closed.append(false)
//                        count = 0
//                        Nstrip = self.stripLists[i].count
//                        for j in 0..<self.stripLists[i].count {
//                            if !closed[j] {
//                                count += 1
//                            }
//                        }
//                    }
//                    newLineStrip.removeAll()
//                }
                
                // is there any open strip ?
                if count > 1 {
                    // Merge the open strips into NewList
                    var pos: Int = 0
                    for j in 0..<Nstrip {
                        if !closed[j] {
                            newList.insert(self.stripLists[i][pos], at: 0)
                            self.stripLists[i].remove(at: pos)
                        }
                        else {
                            pos += 1
                        }
                    }
                    
                    // are there open strips to process ?
                    while newList.count > 1 {
                        // merge the rest to newList[0]
                        again = true
                        while again {
                            again = false
                            var pos: Int = 1
                            while pos < newList.count {
                                var strip = newList[pos]
                                if forceMerge(&newList[0], with: &strip) {
                                    again = true
                                    newList.remove(at: pos)
                                    pos -= 1
                                }
                                pos += 1
                            }
                        } // while(again)
                        
                        index = newList[0][0]
                        x = getX(at:index)
                        y = getY(at:index)
                        index = newList[0][newList[0].count - 1]
                        x -= getX(at:index)
                        y -= getY(at:index)
                        
                        let stripBase = newList[0]
                        // if pStripBase is closed or not
                        if x * x + y * y < weldDist && !self.overrideWeldDistance {
                            print(String(format: "# Plane %ld: open strip ends close enough based on weldDist  %ld && %ld, continue.\n\n", i, stripBase[0], stripBase[stripBase.count - 1]))
                            self.stripLists[i].insert(stripBase, at: 0)
                            newList.remove(at: 0)
                        }
                        else {
                            if onBoundaryWithStrip(stripBase) {
                                print(String(format: "# Plane %ld: open strip ends on boundary %ld(%f,%f) && %ld(%f,%f), continue.\n\n", i, stripBase[0], getX(at:stripBase[0]), getY(at:stripBase[0]), stripBase[stripBase.count - 1], getX(at:stripBase[stripBase.count - 1]), getY(at:stripBase[stripBase.count - 1])))
                                self.stripLists[i].insert(stripBase, at: 0)
                                newList.remove(at: 0)
                            }
                            else {
                                print(String(format: "# Plane %ld: unpaired open strip %ld(%f,%f) && %ld(%f,%f) at 1, override Weld Distance: %@!\n\n", i, stripBase[0], getX(at:stripBase[0]), getY(at:stripBase[0]), stripBase[stripBase.count - 1], getX(at:stripBase[stripBase.count - 1]), getY(at:stripBase[stripBase.count - 1]), (self.overrideWeldDistance ? "Y" : "N")))
                                if self.overrideWeldDistance {
                                    self.stripLists[i].insert(stripBase, at: 0)
                                    newList.remove(at: 0)
                                }
                                else {
                                    //                            [self dumpPlane:i];
                                    //                        delete pStripBase;
                                    //                            if ( newList.used > 0 ) {
                                    //                                insertLineStripListAtIndex(&newList, newList.array[newList.used-1], 0);
                                    //                                removeLineStripListAtIndex(&newList, newList.used-1);
                                    //                            }
                                    //                            newList.front() = newList.back();
                                    //                            newList.pop_back();
                                    //                        }
                                    //            //            exit(0);
                                    newList.remove(at: 0)
                                    //                            break;
                                }
                            }
                        }
                    } // while(newList.size()>1);
                    
                    
                    if newList.count == 1 {
                        let stripBase = newList[0]
                        if onBoundaryWithStrip(stripBase) {
                            print(String(format: "# Plane %ld: open strip ends on boundary %ld(%f,%f) && %ld(%f,%f), continue.\n\n", i, stripBase[0], getX(at:stripBase[0]), getY(at:stripBase[0]), stripBase[stripBase.count - 1], getX(at:stripBase[stripBase.count - 1]), getY(at:stripBase[stripBase.count - 1])))
                            self.stripLists[i].insert(stripBase, at: 0)
                            newList.remove(at: 0)
                        }
                        else {
                            print(String(format: "# Plane %ld: unpaired open strip %ld(%f,%f) && %ld(%f,%f) at 2, override Weld Distance:%@!\n\n", i, stripBase[0], getX(at:stripBase[0]), getY(at:stripBase[0]), stripBase[stripBase.count - 1], getX(at:stripBase[stripBase.count - 1]), getY(at:stripBase[stripBase.count - 1]), self.overrideWeldDistance ? "Y" : "N"))
                            if ( self.overrideWeldDistance ) {
                                self.stripLists[i].insert(stripBase, at: 0)
                                newList.remove(at: 0)
                            }
                            else {
                                newList.remove(at: 0)
                            }
                            //                    [self dumpPlane:i];
                            //                    delete pStripBase;
                            //                    if ( newList.size() > 0 ) {
                            //                        newList.front() = newList.back();
                            //                        newList.pop_back();
                            //                    }
                            //exit(0);
                        }
                    }
                    newList.removeAll()
                }
                else if count == 1 {
                    var pos: Int = 0
                    var stripBase: LineStrip?
                    for j in 0..<Nstrip {
                        if !closed[j] {
                            stripBase = self.stripLists[i][pos]
                            break
                        }
                        pos += 1
                    }
                    if let _stripBase = stripBase {
                        if onBoundaryWithStrip(_stripBase) {
                            print(String(format: "# Plane %ld: open strip ends on boundary %ld(%f,%f) && %ld(%f,%f), continue.\n\n", i, _stripBase[0], getX(at: _stripBase[0]),  getY(at: _stripBase[0]), _stripBase[_stripBase.count - 1], getX(at: _stripBase[_stripBase.count - 1]), getY(at: _stripBase[_stripBase.count - 1])))
                        }
                        else {
                            print(String(format: "# Plane %ld: unpaired open strip %ld(%f,%f) && %ld(%f,%f) at 3!\n\n", i, _stripBase[0], getX(at: _stripBase[0]), getY(at: _stripBase[0]), _stripBase[_stripBase.count - 1], getX(at: _stripBase[_stripBase.count - 1]), getY(at: _stripBase[_stripBase.count - 1])))
                            stripBase?.removeAll()
                            if newList.count > 0 {
                                newList.remove(at: 0)
                            }
                            
                            //                [self dumpPlane:i];
                            //                delete pStripBase;
                            //                if ( newList.size() > 0 ) {
                            //                    newList.front() = newList.back();
                            //                    newList.pop_back();
                            //                }
                            // exit(0);
                        }
                    }
                }
                
                for j in 0..<self.stripLists[i].count {
                    if !closed[j] {
                        let stripBase = self.stripLists[i][j]
                        var newBorderList: LineStripList = []
                        if checkOpenStripNoMoreThan2Boundaries(stripBase, list: &newBorderList) {
                            self.stripLists[i].remove(at: j)
                            for k in 0..<newBorderList.count {
                                self.stripLists[i].append(newBorderList[k])
                            }
                        }
                        else {
                            newBorderList.removeAll()
                        }
                    }
                }
                closed.removeAll()
                //////////////////////////////////////////////////////////////////////////////////////////////////
                newList.removeAll()
                distinctStrip1.removeAll()
                distinctStrip2.removeAll()
                // clean up any lists with no elements
                for i in 0..<stripLists.count {
                    var stripList = stripLists[i]
                    for j in stride(from: stripList.count - 1, through: 0, by: -1) {
                        let strip = stripList[j]
                        if strip.count == 0 {
                            stripList.remove(at: j)
                        }
                    }
                }
            }
        }
    }
                       
    func checkOpenStripNoMoreThan2Boundaries(_ strip: LineStrip, list: inout LineStripList) -> Bool {
        var e1 = false
        let limits = getLimits()
        
        var start: Int = 0
        var end: Int
        for pos in 0..<strip.count {
            let index = strip[pos]
            let x = getX(at: index)
            let y = getY(at: index)
            if (x == limits[0] || x == limits[1] || y == limits[2] || y == limits[3] || fabs(x - limits[0]) < 1E-6 || fabs(x - limits[1]) < 1E-6 || fabs(y - limits[2]) < 1E-6 || fabs(y - limits[3]) < 1E-6) && !(pos == 0 || pos == strip.count - 1) {
                end = pos
                if end - start > 1  {
                    var newStrip: LineStrip = []
                    for pos2 in start..<end + 1 {
                        newStrip.append(strip[pos2])
                    }
                    list.append(newStrip)
                    e1 = true
                }
                start = end
            }
        }
        return e1
    }
                       
    func onBoundaryWithStrip(_ strip: LineStrip?) -> Bool {
        var e1: Bool = false
        var e2: Bool = false
        if let _strip = strip {
            var index: Int = _strip[0]
            var x = getX(at: index)
            var y = getY(at: index)
            let limits = getLimits()
            if x == limits[0] || x == limits[1] || y == limits[2] || y == limits[3] {
               e1 = true
            }
            else if fabs(x - limits[0]) < 1E-6 || fabs(x - limits[1]) < 1E-6 || fabs(y - limits[2]) < 1E-6 || fabs(y - limits[3]) < 1E-6 {
                e1 = true
            }
            else {
                e1 = false;
            }
            index = _strip[_strip.count - 1]
            x = getX(at: index)
            y = getY(at: index)
            if x == limits[0] || x == limits[1] || y == limits[2] || y == limits[3] {
                e2 = true
            }
            else if fabs(x - limits[0]) < 1E-6 || fabs(x - limits[1]) < 1E-6 || fabs(y - limits[2]) < 1E-6 || fabs(y - limits[3]) < 1E-6 {
                e1 = true
            }
            else {
                e2 = false
            }
        }
        return e1 && e2
   }
        
    // returns true if node is touching boundary
    func isNodeOnBoundary(_ index: Int) -> Bool {
        var e1 = false
        let x = getX(at: index)
        let y = getY(at: index)
        let limits = getLimits()
        if x == limits[0] || x == limits[1] || y == limits[2] || y == limits[3] {
            e1 = true
        }
        else if fabs(x - limits[0]) < 1E-6 || fabs(x - limits[1]) < 1E-6 || fabs(y - limits[2]) < 1E-6 || fabs(y - limits[3]) < 1E-6 {
            e1 = true
        }
        return e1
    }
    
    // Area given by this function can be positive or negative depending on the winding direction of the contour.
    func area(_ line: LineStrip) -> Double {
        // if Line is not closed, return 0
        var index = line[0]
        var x =  getX(at: index)
        var y =  getY(at: index)
        let x0 = x
        let y0 = y
        var Ar: Double = 0
        for i in 1..<line.count {
            index =  line[i]
            let x1 =  getX(at: index)
            let y1 =  getY(at: index)
            // Ar += (x1-x)*(y1+y);
            Ar += (y1 - y) * (x1 + x) - (x1 - x) * (y1 + y)
            x = x1
            y = y1
        }

        //Ar += (x0-x)*(y0+y);
        Ar += (y0 - y) * (x0 + x) - (x0 - x) * (y0 + y)
        // if not closed curve, return 0;
        if (x0 - x) * (x0 - x) + (y0 - y) * (y0 - y) > 20.0 * pow(self.deltaX, 2.0) + pow(self.deltaY, 2.0)  {
            Ar = 0.0
    //        NSLog(@"# open curve!\n");
        }
        //else   Ar /= -2;
        else {
            Ar /= 4.0
        }
        // result is \int ydex/2 alone the implicit direction.
        return Ar
    }

    func edgeWeight(_ line: LineStrip, R: Double) -> Double {
        var count: Int = 0
        for i in 0..<line.count {
            let index = line[i]
            let x = getX(at: index)
            let y = getY(at: index)
            if fabs(x) > R || fabs(y) > R {
                count += 1
            }
        }
        return Double(count / line.count)
    }

    func printEdgeWeightContour(_ fname: String) -> Bool {
        var OK = false
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let filePath = String(format: "%@%@.contour", documentsPath, fname)
        
        if let filenameUrl = URL(string: filePath) {
            var textfilestring: String = ""
            
            for i in 0..<Int(self.getNoIsoCurves()) {
                let stripList = self.stripLists[i]
                for j in 0..<stripList.count {
                    let strip = stripList[j]
                    for k in 0..<strip.count {
                        let index = strip[k]
                        textfilestring += textfilestring.appendingFormat("%f\t%f\n", getX(at: index), getY(at: index))
                    }
                    textfilestring += "\n"
                }
            }
            
            do {
                try textfilestring.write(to: filenameUrl, atomically: true, encoding: .utf16)
                OK = true
            }
            catch let error as NSError {
                print(error)
                OK = false
            }
        }
        return OK
    }

    
    func setLinesForPlane(_ iPlane: Int, lineStripList: LineStripList) -> Void {
        assert(iPlane != NSNotFound && iPlane < self.noPlanes, "Plane not between valid ranges")
    
        if lineStripList.count != 0 {
            for  i in 0..<lineStripList.count {
                let strip = lineStripList[i]
                if strip.count != 0 {
                    var stripList = self.stripLists[Int(iPlane)]
                    stripList.insert(strip, at: 0)
                }
            }
        }
    }
    
    // debugging
    func dumpPlane(_ iPlane: Int) -> Void {
        assert(iPlane >= 0 && iPlane < self.noPlanes, "iPlane index not between range")
        let stripList = self.stripLists[iPlane]
        print(String(format: "Level: \(getIsoCurve(at: iPlane))"))
        print(String(format: "Number of strips : \(stripList.count)"))
        print(String(format: "i\tnp\tstart\tend\txstart\tystart\txend\tyend\n"))
        for i in 0..<stripList.count {
            let strip = stripList[i]
            if strip.count > 0 {
                print(String(format: "%ld\t%ld\t%ld\t%ld\t%0.7f\t%0.7f\t%0.7f\t%0.7f\n", i, strip.count, strip[0], strip[strip.count - 1], getX(at: strip[0]), getY(at: strip[0]), getX(at: strip[strip.count - 1]), getY(at: strip[strip.count - 1])))
            }
        }
    }
        
    // MARK: Accessors/Setters
               
    override func getContourPlanes() -> ContourPlanes {
        return super.getContourPlanes()
    }

    func getIsoCurvesLists() -> IsoCurvesList? {
        return self.stripLists
    }
        
    func getStripList(forIsoCurve iPlane: Int) -> LineStripList? {
        return self.stripLists[Int(iPlane)]
    }
        
    func setStripList(forIsoCurve iPlane: Int, stripList: LineStripList) -> Void {
        assert(iPlane < self.contourPlanes.count && iPlane != NSNotFound, "iPlane not in range")
        
        if var actualStripList = getStripList(forIsoCurve: iPlane) {
            for pos in 0..<stripList.count {
                let strip = stripList[pos]
                if strip.count > 0 {
                    actualStripList.append(strip)
                }
            }
        }
    }
    
        
    // MARK: - Searches / Sorting etc
        
    func searchForLineStripIndexForElement(_ a: LineStrip, element: Int, startPos: Int) -> Int {
        var foundPos: Int = NSNotFound
        var _startPos = startPos
        if startPos == NSNotFound {
            _startPos = 0
        }
        let subA = Array(a[_startPos..<a.count])
        if let index = subA.firstIndex(where: { $0 == element }) {
            foundPos = subA.distance(from: subA.startIndex, to: index) + _startPos
        }
        
        return foundPos
    }

    func searchForLineStripIndexForElementWithTolerance(_ a: LineStrip, element: Int, tolerance: Int, columnMutliplier: Int) -> Int {
        var startPos: Int = 0
        // try it without a tolerance first
        var foundPos = searchForLineStripIndexForElement(a, element: element, startPos: startPos)
        if foundPos == NSNotFound {
            var x: Int = 0
            var y: Int = 0
            var layer: Int = 1
            var leg: Int = 0
            var iteration: Int = 0
            while ( iteration < tolerance * tolerance ) {
                foundPos = searchForLineStripIndexForElement(a, element: element + x + y * columnMutliplier, startPos: startPos)
                if foundPos != NSNotFound && UInt(labs(Int(element) - Int(a[foundPos]))) < tolerance {
                    break
                }
                else if foundPos == NSNotFound {
                    startPos = 0
                }
                iteration += 1
                if leg == 0 {
                    x += 1
                    if x == layer {
                        leg += 1
                    }
                }
                else if leg == 1 {
                    y += 1
                    if y == layer {
                        leg += 1
                    }
                }
                else if leg == 2 {
                    x -= 1
                    if -x == layer {
                        leg += 1
                    }
                }
                else if leg == 3 {
                    y -= 1
                    if -y == layer {
                        leg = 0
                        layer += 1
                    }
                }
            }
        }
        return foundPos
    }

    private func distinctElementsInLineStrip(_ a: LineStrip) -> LineStrip {
        var b = Array(a)
        b = b.sorted { $0 < $1 }
        var distinctElements: LineStrip = []
        for index in b {
            if !distinctElements.contains(index) {
                distinctElements.append(index)
            }
        }
        return distinctElements
    }

//    private func checkLineStripToAnotherForSameDifferentOrder(_ a: inout LineStrip, b: inout LineStrip) -> Int {
//        var same: Int = -1
//        var count: Int = 0
//        if a.count == b.count {
//            while ( true ) {
//
//
////                same = (memcmp(a, b, a.count * sizeof(NSUInteger)) == 0) ? 0 : 1;
//                if same == 0 {
//                    break
//                }
//                let n = b.count
//                let temp: UInt = b[0]
//                b.remove(at: 0)
//                b.append(temp)
//                count += 1
//                if count == n {
//                    break
//                }
//            }
//        }
//        return same
//    }
}





