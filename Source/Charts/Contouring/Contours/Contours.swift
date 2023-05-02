//
//  _contours.swift
//  DGCharts (Contouring)
//
//  Created by Steve Wainwright on 23/03/2023.
//
// _Contours.m: implementation of the _Contours class.
//
// _Contours.swift: interface for the CContour class.
//
// _Contours implements Contour plot algorithm described in
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
//  additional routines by S.Wainwright in order to facilitate generating extra contour lines for a function based plot.
//  The contour algorithm will generate border to border lines from one border point to another, yet with a function based plot
//  there will be specific regions which have a coincidental border with other regions, we will have to generate these contour lines
//  since they aren't detected by the CPTContours algorithm. We therefore need to find intersections of contours, and will have to use
//  a tolerance.

import Foundation

@objc
public class Contours: ListCountour {
    
    private var intersectionIndicesList: IntersectionIndicesList? // array of intersection indices strips
    private var extraLineStripLists: IsoCurvesList? // array of line strips
    
    // MARK: - Construction/Destruction
    
    override init(noIsoCurves: Int, isoCurveValues: [Double], limits: [Double]) {
        super.init(noIsoCurves: noIsoCurves, isoCurveValues: isoCurveValues, limits: limits)
    }
    
    // MARK - Input/Output

    func readPlanesFromDisk(_ filePath: String) -> Bool {
        var OK = false
        
//        [self initialiseMemory];
        do {
            var dataFileURL: URL
            if #available(iOSApplicationExtension 16.0, *) {
                dataFileURL = URL(filePath: filePath)
            } else {
                dataFileURL = URL(fileURLWithPath: filePath)
            }
            let _data = try Data(contentsOf: dataFileURL, options: Data.ReadingOptions.alwaysMapped)
            if _data.count > 0 {
                var inRange: Swift.Range = 0..<MemoryLayout<UInt>.size
                var counter = MemoryLayout<Int>.size
                var subData = _data.subdata(in: inRange)
                let noIsoCurves: Int = subData.withUnsafeBytes { $0.load(as: Int.self) }
                if noIsoCurves == self.contourPlanes.count {
                    for iPlane in 0..<noIsoCurves {
                        inRange = counter..<(MemoryLayout<Int>.size + counter)
                        counter += MemoryLayout<Int>.size
                        subData = _data.subdata(in: inRange)
                        let stripLists_Size = subData.withUnsafeBytes { $0.load(as: Int.self) }
                        var stripList: LineStripList = []
                        for _ in 0..<stripLists_Size {
                            inRange = counter..<(MemoryLayout<Int>.size + counter)
                            counter += MemoryLayout<UInt>.size
                            subData = _data.subdata(in: inRange)
                            let strip_Size = subData.withUnsafeBytes { $0.load(as: Int.self) }
                            var strip: LineStrip = []
                            strip.reserveCapacity(strip_Size)
                            for _ in 0..<strip_Size {
                                inRange = counter..<(MemoryLayout<Int>.size + counter)
                                counter += MemoryLayout<UInt>.size
                                subData = _data.subdata(in: inRange)
                                let index = subData.withUnsafeBytes { $0.load(as: Int.self) }
                                strip.append(index)
                            }
                            stripList.append(strip)
                        }
                        
                        if stripList.count > 0 {
                            setStripList(forIsoCurve: iPlane, stripList: stripList)
                        }
                    }
                    var delta: Double
                    inRange = counter..<(MemoryLayout<Double>.size + counter)
                    counter += MemoryLayout<Double>.size
                    subData = _data.subdata(in: inRange)
                    delta = subData.withUnsafeBytes { $0.load(as: Double.self) }
                    self.deltaX = delta
                    inRange = counter..<(MemoryLayout<Double>.size + counter)
                    counter += MemoryLayout<Double>.size
                    subData = _data.subdata(in: inRange)
                    delta = subData.withUnsafeBytes { $0.load(as: Double.self) }
                    self.deltaY = delta
                    
                    inRange = counter..<(MemoryLayout<UInt>.size + counter)
                    counter += MemoryLayout<Int>.size
                    subData = _data.subdata(in: inRange)
                    let noDiscontinuities = subData.withUnsafeBytes { $0.load(as: Int.self) }
                    for _ in 0..<noDiscontinuities {
                        inRange = counter..<(MemoryLayout<Int>.size + counter)
                        counter += MemoryLayout<UInt>.size
                        subData = _data.subdata(in: inRange)
                        let index = subData.withUnsafeBytes { $0.load(as: Int.self) }
                        self.discontinuities.append(index)
                    }
                    OK = true
                }
            }
        }
        catch let error as NSError {
            OK = false
            print(error)
        }
         
        return OK
    }

    func writePlanesToDisk(_ filePath: String) -> Bool {
        var data = Data()
        let noIsoCurves = self.contourPlanes.count
        withUnsafeBytes(of: noIsoCurves.bigEndian) { data.append(contentsOf: $0) }
        for iPlane in 0..<noIsoCurves {
            if let stripList = getStripList(forIsoCurve: iPlane) {
                let noInStripList = stripList.count
                withUnsafeBytes(of: noInStripList.bigEndian) { data.append(contentsOf: $0) }
                if stripList.count > 0 {
                    for pos in 0..<stripList.count {
                        let strip = stripList[pos]
                        let noInStrip = strip.count
                        withUnsafeBytes(of: noInStrip.bigEndian) { data.append(contentsOf: $0) }
                        if strip.count > 0 {
                            for pos2 in 0..<strip.count {
                                let index = strip[pos2]
                                withUnsafeBytes(of: index) { data.append(contentsOf: $0) }
                            }
                        }
                    }
                }
            }
            else {
                let noInStrip: Int = 0
                withUnsafeBytes(of: noInStrip.bigEndian) { data.append(contentsOf: $0) }
            }
        }

        var delta = self.deltaX
        withUnsafeBytes(of: delta) { data.append(contentsOf: $0) }
        delta = self.deltaY
        withUnsafeBytes(of: delta) { data.append(contentsOf: $0) }
        
        let noDiscontinuities = self.discontinuities.count
        withUnsafeBytes(of: noDiscontinuities) { data.append(contentsOf: $0) }
        for i in 0..<noDiscontinuities {
            let index = Int(self.discontinuities[i])
            withUnsafeBytes(of: index) { data.append(contentsOf: $0) }
        }
        
        var OK = true
        var dataFileURL: URL
        if #available(iOSApplicationExtension 16.0, *) {
            dataFileURL = URL(filePath: filePath)
        }
        else {
            dataFileURL = URL(fileURLWithPath: filePath)
        }
        do {
            try data.write(to: dataFileURL, options: Data.WritingOptions.atomic)
        }
        catch let error as NSError {
            OK = false
            print(error)
        }
        
        return OK
    }
    
    // MARK: - Accessors / Setters
    
    override func getContourPlanes() -> ContourPlanes {
         return super.contourPlanes
    }

    override func getIsoCurvesLists() -> IsoCurvesList? {
        return super.getIsoCurvesLists()
    }

    func getExtraIsoCurvesList() -> IsoCurvesList? {
        if self.extraLineStripLists == nil {
            self.extraLineStripLists = []
            if let _isoCurvesLists = getIsoCurvesLists() {
                for _ in 0..<_isoCurvesLists.count {
                    let _extraLineStripList = LineStripList()
                    extraLineStripLists?.append(_extraLineStripList)
                }
            }
        }
        return self.extraLineStripLists
    }

    func getExtraIsoCurvesList(atIsoCurve plane: Int) -> LineStripList? {
        let _ = getExtraIsoCurvesList()
            
        return self.extraLineStripLists?[Int(plane)]
    }

    func getIntersectionIndicesList() -> [IntersectionIndices]? {
        if self.intersectionIndicesList == nil {
            self.intersectionIndicesList = []
        }
        return self.intersectionIndicesList
    }


    // MARK:- Intersections of Contours and Create Extra Contours

    func intersectionsWithAnotherList(_ strip0: LineStrip, other strip1: LineStrip, tolerance: Int) -> Void {
    
        if let _ = self.intersectionIndicesList {
            self.intersectionIndicesList?.removeAll()
        }
        else {
            self.intersectionIndicesList = []
        }
        
        var foundPos: Int = 0
        let columnMutliplier =  self.noColumnsSecondary + 1
    //    toleranceComparison = (long)tolerance;
    //    columnSize = (long)[self getNoColumnsSecondaryGrid] + 1;
        // if the lists are the same check for overlap
        if strip0 == strip1 {  // if the lists are the same check for overlap
            if var _intersectionIndicesList = intersectionIndicesList {
                // first check duplicates
                for pos0 in 0..<strip0.count {
                    for pos1 in 0..<strip1.count {
                        if strip0[pos0] == strip1[pos1] && pos0 != pos1 {
                            let indices = IntersectionIndices(index: pos0, jndex: pos0)
                            _intersectionIndicesList.insert(indices, at: 0)
                        }
                    }
                }
                self.intersectionIndicesList = _intersectionIndicesList.unique()
            }
           
    //        unsigned int testIndex1, row, row1, col, col1;
    //        for ( pos = pStrip0->begin(); pos != pStrip0->end(); pos++ ) {
    //            testIndex = *pos;
    //            row = testIndex / (columnMutliplier+1);
    //            col = testIndex % (columnMutliplier+1);
    //            for ( CLineStrip::reverse_iterator pos1 = pStrip1->rbegin(); pos1 != pStrip1->rend(); ++pos1 ) { //
    //                testIndex1 = *pos1;
    //                row1 = testIndex1 / (columnMutliplier+1);
    //                col1 = testIndex1 % (columnMutliplier+1);
    //                if ( row >= row1 - tolerance / 2 && row <= row1 + tolerance / 2  && col >= col1 - tolerance / 2 && col <= col1 + tolerance / 2 ) {
    //                    index = testIndex;
    //                    *jndex = testIndex;
    //                    found = true;
    //                    intersectionIndices->insert(intersectionIndices->begin(), index);
    //                    break;
    //                }
    //            }
    ////            if ( found ) {
    ////                break;
    ////            }
    //        }
        }
        else { // if lists not the same, search for intersections with a tolerance
            var weldDist: Double = Double(tolerance) * sqrt(pow(self.deltaX, 2.0) + pow(self.deltaX, 2.0))
            if self.overrideWeldDistance {
                let diffSecondaryToPrimaryColumns = self.noColumnsSecondary / self.noColumnsFirst
                let diffSecondaryToPrimaryRows = self.noRowsSecondary / self.noRowsFirst
                let overrideWeldDistMultiplier = sqrt(pow(Double(diffSecondaryToPrimaryColumns), 2) + pow(Double(diffSecondaryToPrimaryRows), 2));
                weldDist *= overrideWeldDistMultiplier
            }
            var x: Int
            var y: Int
            var layer: Int
            var leg: Int
            var iteration: Int
            var testIndex: Int
            var startPos: Int = 0
            for pos in 0..<strip0.count {
                testIndex = Int(strip0[pos])
                x = 0
                y = 0
                layer = 1
                leg = 0
                iteration = 0
                startPos = 0
                while ( iteration < tolerance * tolerance * 4 ) {
                    foundPos = searchForLineStripIndexForElement(strip1, element: testIndex + x + y * columnMutliplier, startPos: startPos)
                    if foundPos != NSNotFound && (labs(testIndex - strip1[foundPos]) < tolerance || labs(testIndex - strip1[foundPos]) / columnMutliplier < tolerance) &&
                       sqrt(pow(self.getX(at: testIndex) - self.getX(at: strip1[foundPos]), 2.0) + pow(self.getY(at: testIndex) - self.getY(at: strip1[foundPos]), 2.0)) < weldDist {
                        let indices = IntersectionIndices(index: testIndex, jndex: Int(strip1[foundPos]))
                        self.intersectionIndicesList?.insert(indices, at: 0)
                        break
                    }
                    else {
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
                    else if ( leg == 2 ) {
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
        }
        
        if let _intersectionIndicesList = intersectionIndicesList,
           _intersectionIndicesList.count > 1 {
    //        sortIndicesList(&intersectionIndicesList, compare_closeby_indices);
            intersectionIndicesList = _intersectionIndicesList.unique()
        }

    }
    
    func intersectionsWithAnotherListOrLimits(_ strip0: LineStrip, other strip1: LineStrip, tolerance: UInt) -> Void {
        
        if let _ = self.intersectionIndicesList {
            self.intersectionIndicesList?.removeAll()
        }
        else {
            self.intersectionIndicesList = []
        }

        if var _intersectionIndicesList = self.intersectionIndicesList {
            let columnMutliplier = self.noColumnsSecondary + 1
            //    unsigned int testIndex;
            var x: Int
            var y: Int
            var layer: Int
            var leg: Int
            var iteration: Int
            
            //        toleranceComparison = (long)tolerance;
            //        columnSize = (long)[self getNoColumnsSecondaryGrid] + 1;
            // if the lists are the same check for overlap
            if strip0 == strip1 {  // if the lists are the same check for overlap
                // first check duplicates
                for pos0 in 0..<strip0.count {
                    for pos1 in 0..<strip1.count {
                        if strip0[pos0] == strip1[pos1] {
                            if pos0 != pos1 {
                                var indices = IntersectionIndices(index: pos0, jndex: pos0)
                                indices.index = pos0
                                indices.jndex = pos0
                                _intersectionIndicesList.insert(indices, at: 0)
                            }
                        }
                    }
                }
                
                
                //        unsigned int testIndex1, row, row1, col, col1;
                //        for ( pos = pStrip0->begin(); pos != pStrip0->end(); pos++ ) {
                //            testIndex = *pos;
                //            row = testIndex / (columnMutliplier+1);
                //            col = testIndex % (columnMutliplier+1);
                //            for ( CLineStrip::reverse_iterator pos1 = pStrip1->rbegin(); pos1 != pStrip1->rend(); ++pos1 ) { //
                //                testIndex1 = *pos1;
                //                row1 = testIndex1 / (columnMutliplier+1);
                //                col1 = testIndex1 % (columnMutliplier+1);
                //                if ( row >= row1 - tolerance / 2 && row <= row1 + tolerance / 2  && col >= col1 - tolerance / 2 && col <= col1 + tolerance / 2 ) {
                //                    index = testIndex;
                //                    *jndex = testIndex;
                //                    found = true;
                //                    intersectionIndices->insert(intersectionIndices->begin(), index);
                //                    break;
                //                }
                //            }
                ////            if ( found ) {
                ////                break;
                ////            }
                //        }
            }
            else { // if lists not the same, search for intersections with a tolerance
                for pos in 0..<strip0.count {
                    let testIndex = strip0[pos]
                    x = 0
                    y = 0
                    layer = 1
                    leg = 0
                    iteration = 0
                    var foundPos: Int = 0
                    while ( iteration < tolerance * tolerance ) {
                        foundPos = searchForLineStripIndexForElement(strip1, element: testIndex + x + y * columnMutliplier, startPos: foundPos)
                        if foundPos != NSNotFound && labs(testIndex - strip1[foundPos]) < tolerance {
                            let indices = IntersectionIndices(index: testIndex, jndex: Int(strip0[foundPos]))
                            _intersectionIndicesList.insert(indices, at: 0)
                            //                    std::cout << iteration << "  " << x << "  " << y << "  " << *foundPos << "\n";
                            break
                        }
                        
                        iteration += 1
                        if ( leg == 0 ) {
                            x += 1
                            if ( x == layer ) {
                                leg += 1
                            }
                        }
                        else if ( leg == 1 ) {
                            y += 1
                            if ( y == layer) {
                                leg += 1
                            }
                        }
                        else if ( leg == 2 ) {
                            x -= 1
                            if -x == layer {
                                leg += 1
                            }
                        }
                        else if ( leg == 3 ) {
                            y -= 1
                            if -y == layer {
                                leg = 0
                                layer += 1
                            }
                        }
                    }
                }
            }
            
            if strip0[0] != strip0[strip0.count - 1] {
                let indicesStart = IntersectionIndices(index: Int(strip0[0]), jndex: Int(strip0[0]))
                _intersectionIndicesList.insert(indicesStart, at: 0)
                let indicesEnd = IntersectionIndices(index: Int(strip0[strip0.count - 1]), jndex: Int(strip0[strip0.count - 1]))
                _intersectionIndicesList.insert(indicesEnd, at: 0)
            }
            //    sortIndicesList(&intersectionIndicesList, compare_closeby_indices);
            self.intersectionIndicesList = _intersectionIndicesList.unique()
        }
    }
        
    func addIndicesInNewLineStripToLineStripList(_ stripList: inout LineStripList, indices: [Int]) -> Bool {
        var OK = false
        for iPlane in 0..<self.getNoIsoCurves() {
            if withUnsafePointer(to: stripList, { $0 }) == withUnsafePointer(to: self.getStripList(forIsoCurve: iPlane), { $0 }) {
//            if stripList == self.getStripList(forIsoCurve: iPlane) {
                OK = true
                break
            }
        }
        if OK {
            var strip: LineStrip = []
            for i in 0..<indices.count {
                strip.append(indices[i])
            }
            stripList.append(strip)
        }
        return OK
    }

    func add2StripsToIntersectionPtToLineStripList(_ stripList: inout LineStripList, strip0: LineStrip, strip1: LineStrip, index: Int, jndex: Int) -> Bool {
        var OK = false
        for iPlane in 0..<self.getNoIsoCurves() {
            if withUnsafePointer(to: stripList, { $0 }) == withUnsafePointer(to: self.getStripList(forIsoCurve: iPlane), { $0 }) {
//            if stripList == self.getStripList(forIsoCurve: iPlane) {
                OK = true
                break
            }
        }
        if OK {
            var strip: LineStrip = []
            for pos0 in 0..<strip0.count {
                strip.append(strip0[pos0])
                if strip0[pos0] == jndex {
                    break
                }
            }
            var foundPos: Int = searchForLineStripIndexForElement(strip1, element: index, startPos: 0)
            if foundPos != NSNotFound {
                if index == jndex {
                    foundPos += 1
                }
                for pos1 in foundPos..<strip1.count {
                    strip.append(strip1[pos1])
                }
            }
            stripList.append(strip)
        }
        return OK
    }

    func createNPointShapeFromIntersectionPtToLineStripList(_ stripList: inout LineStripList, striplist0: LineStripList, striplist1: LineStripList, indexs: [Int], jndexs: [Int], NPoints: Int, isoCurve plane: Int) -> Bool {
        assert(NPoints > 1, "Number of points has to be at least 2 for a triangle!")
        var OK = false
        if withUnsafePointer(to: stripList, { $0 }) == withUnsafePointer(to: self.getExtraIsoCurvesList(atIsoCurve: plane), { $0 }) {
//        if stripList == self.getExtraIsoCurvesList(atIsoCurve: plane) { // first check extra LineStripList
            OK = true
        }
        else {
            for iPlane in 0..<self.getNoIsoCurves() {
                if withUnsafePointer(to: stripList, { $0 }) == withUnsafePointer(to: self.getStripList(forIsoCurve: iPlane), { $0 }) {
    //            if stripList == self.getStripList(forIsoCurve: iPlane) {
                    OK = true
                    break
                }
            }
        }

        if OK {
            var newStrip: LineStrip = []
            var posStart: Int = 0, posEnd: Int = 0, posStart1: Int = 0, posStart2: Int = 0, posEnd1: Int = 0, posEnd2: Int = 0
            var strip0ContainsAllIntersections: Bool = false, strip1ContainsAllIntersections: Bool = false
            var index1: Int = NSNotFound, index2: Int = NSNotFound
            for i in 0..<NPoints {
                if i > striplist0.count - 1  {
                    break
                }
                strip0ContainsAllIntersections = true
                for j in 0..<NPoints {
                    posStart1 = searchForLineStripIndexForElement(striplist0[i], element:indexs[j], startPos: posStart1)
                    if posStart1 != NSNotFound {
                        strip0ContainsAllIntersections = strip0ContainsAllIntersections && true
                    }
                    else {
                        strip0ContainsAllIntersections = strip0ContainsAllIntersections && false
                    }
                    if posStart1 == striplist0[i].count - 1 {
                        posStart1 = 0
                    }
                }
                if strip0ContainsAllIntersections {
                    index1 = i
                    break
                }
            }
            for i in 0..<NPoints {
                if i > striplist1.count - 1 {
                    break
                }
                strip1ContainsAllIntersections = true
                for j in 0..<NPoints {
                    posStart2 = searchForLineStripIndexForElement(striplist1[i], element: indexs[j], startPos: posStart2)
                    if posStart2 != NSNotFound  {
                        strip1ContainsAllIntersections = strip1ContainsAllIntersections && true
                    }
                    else {
                        strip1ContainsAllIntersections = strip1ContainsAllIntersections && false
                    }
                    if posStart2 == striplist1[i].count - 1 {
                        posStart2 = 0
                    }
                }
                if strip1ContainsAllIntersections {
                    index2 = i
                    break
                }
            }
            if strip0ContainsAllIntersections {
                newStrip = striplist0[index1].clone()
            }
            else if ( strip1ContainsAllIntersections ) {
                newStrip = striplist1[index2].clone()
            }
            else {
                var strip: LineStrip?
                var counter0: Int, counter1: Int
                var useStrips: Bool = true, crossesover: Bool = false   // the contour crosses over itself
                var j: Int = 1
                for i in 0..<NPoints {
                    useStrips = true
                    if j == NPoints {
                        j = 0
                    }
                    if striplist0[i].count != 0 && striplist1[i].count != 0 {
                        // check which of intersecting strips contains both corner indexes
                        posStart = searchForLineStripIndexForElement(striplist0[i], element: indexs[i], startPos: posStart)
                        posEnd1 = searchForLineStripIndexForElement(striplist0[i], element: indexs[j], startPos: posEnd1)
                        posEnd2 = searchForLineStripIndexForElement(striplist0[i], element: jndexs[j], startPos: posEnd2)
                        if posStart != NSNotFound && (posEnd1 != NSNotFound || posEnd2 != NSNotFound) {
                            if searchForLineStripIndexForElement(newStrip, element: indexs[i], startPos: 0) != NSNotFound && (searchForLineStripIndexForElement(newStrip, element: indexs[j], startPos: 0) != NSNotFound || searchForLineStripIndexForElement(newStrip, element: jndexs[j], startPos: 0) != NSNotFound) {
                                continue
                            }
                            strip = striplist0[i]
                            if let _strip = strip {
                                if posEnd1 < _strip.count {
                                    crossesover = checkForCrossesOverOnStrip(_strip, index: indexs[i], jndex: indexs[j], startIndex: &posStart)
                                    posEnd = posEnd1
                                }
                                else {
                                    crossesover = checkForCrossesOverOnStrip(_strip, index: indexs[j], jndex: indexs[j], startIndex: &posStart)
                                    posEnd = posEnd2
                                }
                            }
                        }
                        else {
                            posStart = searchForLineStripIndexForElement(striplist0[i], element: jndexs[i], startPos: posStart)
                            posEnd1 = searchForLineStripIndexForElement(striplist0[i], element: jndexs[j], startPos: posEnd1)
                            posEnd2 = searchForLineStripIndexForElement(striplist0[i], element: indexs[j], startPos: posEnd2)
                            if posStart != NSNotFound && (posEnd1 != NSNotFound || posEnd2 != NSNotFound) {
                                if searchForLineStripIndexForElement(newStrip, element: jndexs[i], startPos: 0) != NSNotFound && (searchForLineStripIndexForElement(newStrip, element: jndexs[j], startPos: 0) != NSNotFound || searchForLineStripIndexForElement(newStrip, element: indexs[j], startPos: 0) != NSNotFound) {
                                    continue
                                }
                                strip = striplist0[i]
                                if let _strip = strip {
                                    if posEnd1 < _strip.count {
                                        crossesover = checkForCrossesOverOnStrip(_strip, index: jndexs[i], jndex: jndexs[j], startIndex: &posStart)
                                        posEnd = posEnd1
                                    }
                                    else {
                                        crossesover = checkForCrossesOverOnStrip(_strip, index: jndexs[j], jndex: indexs[j], startIndex: &posStart)
                                        posEnd = posEnd2
                                    }
                                }
                            }
                            else {
                                posStart = searchForLineStripIndexForElement(striplist1[i], element: indexs[i], startPos: posStart)
                                posEnd1 = searchForLineStripIndexForElement(striplist1[i], element: indexs[j], startPos: posEnd1)
                                posEnd2 = searchForLineStripIndexForElement(striplist1[i], element: jndexs[j], startPos: posEnd2)
                                if posStart != NSNotFound && (posEnd1 != NSNotFound || posEnd2 != NSNotFound) {
                                    if searchForLineStripIndexForElement(newStrip, element: indexs[i], startPos: 0) != NSNotFound && (searchForLineStripIndexForElement(newStrip, element: indexs[j], startPos: 0) != NSNotFound || searchForLineStripIndexForElement(newStrip, element: jndexs[j], startPos: 0) != NSNotFound) {
                                        continue
                                    }
                                    strip = striplist1[i]
                                    if let _strip = strip {
                                        if posEnd1 < _strip.count {
                                            crossesover = checkForCrossesOverOnStrip(_strip, index: indexs[i], jndex: indexs[j], startIndex: &posStart)
                                            posEnd = posEnd1
                                        }
                                        else {
                                            crossesover = checkForCrossesOverOnStrip(_strip, index: indexs[j], jndex: jndexs[j], startIndex: &posStart)
                                            posEnd = posEnd2
                                        }
                                    }
                                }
                                else {
                                    posStart = searchForLineStripIndexForElement(striplist1[i], element: jndexs[i], startPos: posStart)
                                    posEnd1 = searchForLineStripIndexForElement(striplist1[i], element: jndexs[j], startPos: posEnd1)
                                    posEnd2 = searchForLineStripIndexForElement(striplist1[i], element: indexs[j], startPos: posEnd2)
                                    if posStart != NSNotFound && (posEnd1 != NSNotFound || posEnd2 != NSNotFound) {
                                        if searchForLineStripIndexForElement(newStrip, element: jndexs[i], startPos: 0) != NSNotFound && (searchForLineStripIndexForElement(newStrip, element: jndexs[j], startPos: 0) != NSNotFound || searchForLineStripIndexForElement(newStrip, element: indexs[j], startPos: 0) != NSNotFound) {
                                            continue
                                        }
                                        strip = striplist1[i]
                                        if let _strip = strip {
                                            if posEnd1 < _strip.count {
                                                crossesover = checkForCrossesOverOnStrip(_strip, index: jndexs[i], jndex: jndexs[j], startIndex: &posStart)
                                                posEnd = posEnd1
                                            }
                                            else {
                                                crossesover = checkForCrossesOverOnStrip(_strip, index:jndexs[j], jndex:indexs[j], startIndex: &posStart)
                                                posEnd = posEnd2
                                            }
                                        }
                                    }
                                    else if searchForLineStripIndexForElement(newStrip, element: indexs[i], startPos: 0) != NSNotFound && searchForLineStripIndexForElement(newStrip, element: indexs[j], startPos: 0) != NSNotFound {
                                        continue
                                    }
                                    else if searchForLineStripIndexForElement(newStrip, element: jndexs[i], startPos: 0) != NSNotFound && searchForLineStripIndexForElement(newStrip, element: jndexs[j], startPos: 0) != NSNotFound {
                                        continue
                                    }
                                    else {
                                        if !crossesover {
                                            useStrips = false
                                            if newStrip.count == 0 || newStrip[newStrip.count-1] != indexs[i]  {
                                                newStrip.append(indexs[i])
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if useStrips,
                            let _strip = strip {
                            counter0 = posStart
                            counter1 = posEnd
                            
                            // make sure we order the new strip properly, since counter0 & counter1 tells us how far into strip is start and end corners
                            if i > 0 && newStrip.count > 1 {
                                newStrip.remove(at: newStrip.count - 1)
                            }
                            if counter1 < counter0 {
                                for pos in stride(from: posStart, through: posEnd, by: -1) {
                                    newStrip.append(_strip[pos])
                                }
                            }
                            else {
                                for pos in posStart..<posEnd {
                                    newStrip.append(_strip[pos])
                                }
                            }
                        }
                    }
                    else if striplist0[i].count != 0 || striplist1[i].count != 0 {
                        if striplist0[i].count > 0 {
                            strip = striplist0[i]
                        }
                        else {
                            strip = striplist1[i]
                        }
                        if let _strip = strip {
                            posStart = searchForLineStripIndexForElement(_strip, element: indexs[i], startPos: posStart)
                            posEnd = searchForLineStripIndexForElement(_strip, element: indexs[j], startPos: posEnd)
                            if posStart != NSNotFound && posEnd != NSNotFound {
                                if searchForLineStripIndexForElement(newStrip, element: indexs[i], startPos: 0) != NSNotFound && searchForLineStripIndexForElement(newStrip, element: indexs[j], startPos: 0) != NSNotFound {
                                    continue
                                }
                            }
                            else {
                                posStart = searchForLineStripIndexForElement(_strip, element: jndexs[i], startPos: posStart)
                                posEnd = searchForLineStripIndexForElement(_strip, element: jndexs[j], startPos: posEnd)
                                if posStart != NSNotFound && posEnd != NSNotFound {
                                    if searchForLineStripIndexForElement(newStrip, element: jndexs[i], startPos: 0) != NSNotFound && searchForLineStripIndexForElement(newStrip, element: jndexs[j], startPos: 0) != NSNotFound {
                                        continue
                                    }
                                }
                                else {
                                    useStrips = false
                                    if newStrip.count == 0 || newStrip[newStrip.count - 1] != indexs[i] {
                                        newStrip.append(indexs[i])
                                    }
                                }
                            }
                        }
                        
                        if useStrips,
                           let _strip = strip {
                            counter0 = posStart
                            counter1 = posEnd
                            
                            // make sure we order the new strip properly, since counter0 & counter1 tells us how far into strip is start and end corners
                            if i > 0 && newStrip.count > 1 {
                                newStrip.remove(at: newStrip.count - 1)
                            }
                            if counter1 < counter0 {
                                for pos in stride(from: posStart, through: posEnd, by: -1) {
                                    newStrip.append(_strip[pos])
                                }
                            }
                            else {
                                for pos in posStart..<posEnd {
                                    newStrip.append(_strip[pos])
                                }
                            }
                        }
                    }
                    else {
                        if newStrip.count == 0 || newStrip[newStrip.count-1] != indexs[i] {
                            newStrip.append(indexs[i])
                        }
                    }
                    if crossesover {
                        break
                    }
                    //            if i == 0  {
                    //                firstIndex = pNewStrip->front();
                    //            }
                    j += 1
                }
                //        if !crossesover {
                //            pNewStrip->insert(pNewStrip->end(), firstIndex);
                //        }
            }
            stripList.append(newStrip)
        }
        return OK
    }

    func addLineStripToLineStripList(_ stripList: inout LineStripList, lineStrip strip: LineStrip, isoCurve plane: Int) -> Bool {
        assert(strip.count > 1, "Number of points has to be at least 2 for a triangle!")
        var OK = false
        if stripList == self.getExtraIsoCurvesList(atIsoCurve: plane) { // first check extra LineStripList
            OK = true
        }
        else {
            for iPlane in 0..<self.getNoIsoCurves() {
                if stripList == self.getStripList(forIsoCurve: iPlane) {
                    OK = true
                    break
                }
            }
        }

        if ( OK ) {
            stripList.append(strip)
        }
        return OK
    
    }

    func checkForDirectConnectBetween2IndicesInAStrip(_ strip: LineStrip, index: Int, jndex: Int, indicesList: LineStrip) -> Bool {
        var connectedDirectly = false
        
        let pos0 = searchForLineStripIndexForElement(strip, element: index, startPos: 0)
        let pos1 = searchForLineStripIndexForElement(strip, element: jndex, startPos: 0)
        if pos0 != NSNotFound && pos1 != NSNotFound {
            connectedDirectly = true
            var posStart: Int
            var posEnd: Int
            if pos0 < pos1 {
                posStart = pos0
                posEnd = pos1
            }
            else {
                posStart = pos1
                posEnd = pos0
            }
            posStart += 1
            var element: Int
            var portionStrip: LineStrip = []
            for i in posStart..<posEnd {
                portionStrip.append(strip[i])
            }
            for j in 0..<indicesList.count {
                element = indicesList[j]
                if searchForLineStripIndexForElement(portionStrip, element: element, startPos: 0) != NSNotFound {
                    connectedDirectly = false
                    break
                }
            }
            portionStrip.removeAll()
        }
        
        return connectedDirectly
    }

    func checkForDirectConnectWithoutOtherIndicesBetween2IndicesInAStrip(_ strip: LineStrip?, index: Int, jndex: Int, indicesList: LineStrip, jndicesList: LineStrip) -> Bool {
       
        var connectedDirectly = false
        if let _strip = strip {
            
            let pos0 = searchForLineStripIndexForElement(_strip, element: index, startPos: 0)
            let pos1 = searchForLineStripIndexForElement(_strip, element: jndex, startPos: 0)
            if pos0 != NSNotFound && pos1 != NSNotFound && pos0 != pos1 {
                connectedDirectly = true
                var posStart: Int
                var posEnd: Int
                if pos0 < pos1 {
                    posStart = pos0
                    posEnd = pos1
                }
                else {
                    posStart = pos1
                    posEnd = pos0
                }
                posStart += 1
                var portionStrip: LineStrip = []
        
                for i in posStart..<posEnd {
                    portionStrip.append(_strip[i])
                }
                var pos: Int = NSNotFound
                for element in indicesList {
        //            if( (pos = searchForLineStripIndexForElementWithTolerance(&portionStrip, element, 4, [self getNoColumnsSecondaryGrid])) != NSNotFound ) {
                    pos = searchForLineStripIndexForElement(portionStrip, element: element, startPos: 0)
                    if pos != NSNotFound {
                        connectedDirectly = false
                        break
                    }
                }
                if pos == NSNotFound {
                    for element in jndicesList {
                        if searchForLineStripIndexForElement(portionStrip, element: element, startPos: 0) != NSNotFound {
                            connectedDirectly = false
                            break
                        }
                    }
                }
                portionStrip.removeAll()
            }
        }
        
        return connectedDirectly
    }

    func checkStripHasNoBigGaps(_ strip: LineStrip) -> Bool {
        var bigGaps = false
        var index: Int
        var x: Double
        var y: Double
        let weldDist: Double = 50.0 * (pow(self.deltaX, 2.0) + pow(self.deltaY, 2.0))
        for i in 0..<strip.count-1 {
            index = strip[i]
            x = self.getX(at: index)
            y = self.getY(at: index)
            index = strip[i + 1]
            x -= self.getX(at: index)
            y -= self.getY(at: index)
            if x * x + y * y > weldDist {
                bigGaps = true
                break
            }
        }
        return bigGaps
    }

    func removeExcessBoundaryNodeFromExtraLineStrip(_ strip: inout LineStrip) -> Bool {
        var anyRemoved = false
        if let boundaryPositions = searchExtraLineStripOfTwoBoundaryPoints(strip) {
            for pos in 0..<strip.count {
                if pos < boundaryPositions[0] || pos > boundaryPositions[1] {
                    strip.remove(at: pos)
                    anyRemoved = true
                }
            }
        }
        return anyRemoved
    }

    func searchExtraLineStripOfTwoBoundaryPoints(_ strip: LineStrip) -> [Int]? {
        var boundaryPositions: [Int] = []
        
        for pos2 in 0..<strip.count {
            // retreiving index
            let index = strip[pos2]
            if self.isNodeOnBoundary(index) { // if a border contour should only touch border twice
                // yet TContour class may have 2 or more boundary points next to each other, for CPTContourPlot can only have 2 border points
                boundaryPositions.append(pos2)
            }
        }
        if boundaryPositions.count > 2 {
            var pos: Int, pos2: Int, i: Int = 0
            let halfway = boundaryPositions.count / 2
            while ( i < halfway ) {
                pos = boundaryPositions[i]
                pos2 = boundaryPositions[i + 1]
                if pos2 - pos < 5 {
                    if i < boundaryPositions.count {
                        boundaryPositions.remove(at: i)
                    }
                }
                i += 1
            }
            i = boundaryPositions.count - 1
            while ( i > 1 ) {
                pos = boundaryPositions[i]
                pos2 = boundaryPositions[i - 1]
                if pos - pos2 < 5  {
                    if i < boundaryPositions.count {
                        boundaryPositions.remove(at: i)
                    }
                }
                i -= 1
            }
        }
        else if boundaryPositions.count == 0  {
            boundaryPositions.append(NSNotFound)
        }
        else if boundaryPositions.count == 1 {
            boundaryPositions.append(NSNotFound)
        }
        return boundaryPositions
    }

    private func checkForCrossesOverOnStrip(_ strip: LineStrip, index: Int, jndex: Int, startIndex: inout Int) -> Bool {
        var crossesover = false
        var occurences: [Int] = []
        var posTemp: Int = 0
        while ( true ) {
            posTemp = searchForLineStripIndexForElement(strip, element: index, startPos: posTemp)
            if posTemp != NSNotFound {
                break
            }
            occurences.append(posTemp)
            posTemp += 1
            if posTemp > strip.count - 1 {
                break
            }
        }
        
        if occurences.count < 2 {
            occurences.removeAll()
            posTemp = 0
            while ( true ) {
                posTemp = searchForLineStripIndexForElement(strip, element: jndex, startPos: posTemp)
                if posTemp != NSNotFound {
                    break
                }
                occurences.append(posTemp)
                posTemp += 1
                if posTemp > strip.count - 1 {
                    break
                }
            }
            if occurences.count > 1 {
                startIndex = occurences[1]
                crossesover = true
            }
        }
        else {
            startIndex = occurences[1]
            crossesover = true
        }
        occurences.removeAll()
        return crossesover
    }
}

