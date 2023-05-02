//
//  _contourMemory.swift
//  SwiftCharts_Contouring
//
//  Created by Steve Wainwright on 23/03/2023.
//

import Foundation


/**
 *  @brief Enumeration of contour  border dimension & direction
 **/

enum ContourBorderDimensionDirection: Int, CaseIterable {
    
    static var allCases: [ContourBorderDimensionDirection] {
        return [.xForward, .yForward, .xBackward, .yBackward, .none ]
    }
    
    case xForward ///< contour border dimension & direction along x and small to large dimension
    case yForward ///< contour border dimension & direction along y and small to large dimension
    case xBackward ///< contour border dimension & direction along x and large to small dimension
    case yBackward ///< contour border dimension & direction along y and large to small dimension
    case none
}

/**
 *  @brief Enumeration of contour  border dimension & direction
 **/
enum ContourIntersectionOrdering: Int {
    case distances   ///< contour intersection ordering by distance from reference point
    case distancesAngles   ///< contour  intersection ordering by distance then angle from reference point
    case angles   ///< contour intersection ordering by distance then angle
}

/**
 *  @brief Enumeration of contour  polygon status
 **/
enum ContourPolygonStatus: Int, CustomStringConvertible {
    case notCreated   ///< contour polygon was not created
    case created   ///< contour polygon was created
    case alreadyExists    ///< contour polygon was already exists
    
    var description: String {
        get {
            switch self {
                case .notCreated:
                    return "not created"
                case .created:
                    return "created"
                case .alreadyExists:
                    return "already exists"
            }
        }
    }
}

/**
 *  @brief Enumeration of contour inner, outer or both search
 **/
enum ContourSearchType: Int {
    case inner   ///< contour inner search
    case outer   ///< contour outer search
    case both    ///< contour search both ways
}

/**
 *  @brief Enumeration of contour inner, outer or both search
 **/
enum ContourBetweenNodeRotation: Int {
    case none  ///< no contour between nodes
    case clockwise   ///<  clockwise contour between nodes
    case anticlockwise    ///<  anticlockwise contour between nodes
};



typealias LineStrip = [Int]

extension Array where Element == Int {
    func clone() -> LineStrip {
        var copiedArray: LineStrip = []
        for element in self {
            copiedArray.append(element)
        }
        return copiedArray
    }
    
    func checkLineStripToAnotherForSameDifferentOrder(_ other: LineStrip) -> Bool {
        var same: Bool = false
        var count: Int = 0
        if self.count == other.count {
            var _other = other.clone()
            while true {
                same = self == other ? true : false
                if same {
                    break
                }
                
                let temp = _other[0]
                for i in 1..<_other.count {
                    _other[i - 1] =  other[i]
                }
                _other[other.count - 1] = temp
                count += 1
                if count == _other.count  {
                    break
                }
            }
        }
        return same
    }

}

typealias LineStripList = [LineStrip]
typealias IsoCurvesList = [LineStripList]
typealias IntersectionIndicesList = [IntersectionIndices]
typealias ContourPlanes = [Double]
typealias Discontinuities = [Int]


/** @brief A structure used internally by CPTContourPlot to search for isoCurves intersecting the border.
 **/

struct Strip: Hashable {
    var startPoint: CGPoint
    var endPoint: CGPoint
    var plane: Int
    var index: Int
    var stripList: LineStripList?
    var startBorderdirection: ContourBorderDimensionDirection
    var endBorderdirection: ContourBorderDimensionDirection
    var reverse: Bool
    var extra: Bool
    var usedInExtra: Bool
    
    init() {
        startPoint = .zero
        endPoint = .zero
        index = NSNotFound
        plane = NSNotFound
        stripList = nil
        startBorderdirection = .none
        endBorderdirection = .none
        reverse = false
        extra = false
        usedInExtra = false
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(plane)
        hasher.combine(index)
    }
        
    static func == (lhs: Strip, rhs: Strip) -> Bool {
            return lhs.plane == rhs.plane && lhs.index == rhs.index
    }
    
    var isReverse: Bool {
        get {
            // make sure all paths are anticlockwise
            var reverseOrder = false
            switch self.startBorderdirection {
                case .xForward:
                    if (self.endBorderdirection == .xForward && self.startPoint.x > self.endPoint.x) || self.endBorderdirection == .yBackward {
                        reverseOrder = true
                    }
                    
                case .yForward:
                    if (self.endBorderdirection == .yForward && self.startPoint.y > self.endPoint.y) || self.endBorderdirection == .xForward {
                        reverseOrder = true
                    }
                    
                case .xBackward:
                    if (self.endBorderdirection == .xBackward && self.startPoint.x < self.endPoint.x) || self.endBorderdirection == .yForward {
                        reverseOrder = true
                    }
                    
                case .yBackward:
                    if (self.endBorderdirection == .yBackward && self.startPoint.y < self.endPoint.y) || self.endBorderdirection == .xBackward {
                        reverseOrder = true
                    }
                    
                case .none:
                    break
            }
            
            return reverseOrder
        }
    }
    
}

extension Array where Element == Strip {
    
    func clone() -> [Strip] {
        var copiedArray: [Strip] = []
        for element in self {
            copiedArray.append(element)
        }
        return copiedArray
    }
    
    func removingDuplicates() -> [Element] {
      var addedDict = [Element: Bool]()

      return filter {
          addedDict.updateValue(true, forKey: $0) == nil
      }
    }

    mutating func removeDuplicates() {
      self = self.removingDuplicates()
    }
    
    mutating func sortStripsByPlanes() {
        self.sort(by: { $0.plane > $1.plane })
    }
    
    mutating func sortStripsByBorderDirection(_ startBorderdirection: ContourBorderDimensionDirection) {
        switch startBorderdirection {
        case .xForward:
            self.sort(by: { strip0, strip1 in
                if strip0.startPoint.x == strip1.startPoint.x {
                    return strip0.endBorderdirection != .xForward
                }
                else {
                    return strip0.startPoint.x < strip1.startPoint.x
                }
            })
               
        case .yForward:
            self.sort(by: { strip0, strip1 in
                if strip0.startPoint.y == strip1.startPoint.y {
                    return strip0.endBorderdirection != .yForward
                }
                else {
                    return strip0.startPoint.y < strip1.startPoint.y
                }
            })
                
        case .xBackward:
            self.sort(by: { strip0, strip1 in
                if strip0.startPoint.x == strip1.startPoint.x {
                    return strip0.endBorderdirection != .xBackward
                }
                else {
                    return strip0.startPoint.x > strip1.startPoint.x
                }
            })
                
        case .yBackward:
            self.sort(by: { strip0, strip1 in
                if strip0.startPoint.y == strip1.startPoint.y {
                    return strip0.endBorderdirection != .yBackward
                }
                else {
                    return strip0.startPoint.y > strip1.startPoint.y
                }
            })
            
        case .none:
            break
        }
    }

    
    func sortStripsIntoStartEndPointPositions(_ indices: inout [BorderIndex]) -> Void {
        
        var borders: [[BorderIndex]] = []
        borders.reserveCapacity(4)
        for i in 0..<4 {
            borders.append([])
            borders[i].reserveCapacity(self.count)
        }
        for i in 0..<self.count {
            var element0 = BorderIndex()
            element0.index = i
            element0.point = self[i].startPoint
            element0.borderdirection = self[i].startBorderdirection
            element0.end = false
            switch self[i].startBorderdirection {
                case .xForward:
                    borders[0].append(element0)
                   
                case .yForward:
                    borders[1].append(element0)
                
                case .xBackward:
                    borders[2].append(element0)
                
                case .yBackward:
                    borders[3].append(element0)
                
                case .none:
                    break
            }
            var element1 = BorderIndex()
            element1.index = i
            element1.point = self[i].endPoint
            element1.borderdirection = self[i].endBorderdirection
            element1.end = true
            switch ( self[i].endBorderdirection ) {
                case .xForward:
                    borders[0].append(element1)
                   
                case .yForward:
                    borders[1].append(element1)
                
                case .xBackward:
                    borders[2].append(element1)
                
                default:
                    borders[3].append(element1)
                    break
            }
            
        }
        for i in 0..<4 {
            borders[i] = borders[i].sortBorderIndicesByBorderDirection(ContourBorderDimensionDirection(rawValue: i)!)
            for j in 0..<borders[i].count {
                indices.append(borders[i][j])
            }
            borders[i].removeAll()
        }
    }
    
    func searchForStripForPlanes(plane1: Int, plane2: Int, exceptPosition: Int) -> Int {
        var foundPos: Int = NSNotFound
        for i in exceptPosition+1..<self.count {
            if plane1 == self[i].plane || (plane2 != NSNotFound && plane2 == self[i].plane) {
                foundPos = i
                break
            }
        }
        return foundPos
    }

    func searchForStripIndicesForPlane(plane: Int) -> [Int] {
        
        var indices: [Int] = []
        for i in 0..<self.count {
            if plane == self[i].plane {
                indices.append(i)
            }
        }
        return indices
    }

    func searchForStripIndicesForPlanes(plane1: Int, plane2: Int) -> [Int] {
        
        var indices: [Int] = []
        for i in 0..<self.count {
            if plane1 == self[i].plane || (plane2 != NSNotFound && plane2 == self[i].plane) {
                indices.append(i)
            }
        }
        return indices
    }

    func searchForPlanesWithinStrips(planes: inout [Int]) -> Int {
        
        var b: [Strip] = self.clone()
        
    //    removeDuplicatesStrips(&b);
        b.sortStripsByPlanes()
        
        for i in 0..<b.count {
            for var j in i+1..<b.count {
                if b[i].plane == b[j].plane {
                    // delete the current position of the duplicate element
                    for k in j..<b.count-1 {
                        b[k] = b[k + 1]
                    }
                   // if the position of the elements is changes, don't increase the index j
                    j -= 1
                }
            }
        }
        planes.removeAll()
        for i in 0..<b.count {
            planes.append(b[i].plane)
        }
        
        return b.count
    }
}

/** @brief A structure used internally by CPTContourPlot to sorting border strips ordering.
 **/

struct BorderIndex {
    var point: CGPoint
    var index: Int
    var extra: Int
    var angle: Double
    var borderdirection: ContourBorderDimensionDirection
    var end: Bool
    var used: Bool
    
    init() {
        point = .zero
        index = NSNotFound
        extra = NSNotFound
        angle = -0.0
        borderdirection = .none
        end = false
        used = false
    }
}

extension Array where Element == BorderIndex {
    
    func clone() -> [BorderIndex] {
        var copiedArray: [BorderIndex] = []
        for element in self {
            copiedArray.append(element)
        }
        return copiedArray
    }
    
    func sortBorderIndicesWithExtraContours() -> [BorderIndex] {
        var arr: [BorderIndex] = self.clone()
        var element: BorderIndex
        var j: Int = 1, k: Int = arr.count - 1
        for var i in 0..<arr.count {
            if j == arr.count {
                j = 0
            }
            if k == arr.count {
                k = 0
            }
            if arr[i].point.equalTo(arr[j].point) {
                if !arr[i].end && arr[j].end {
                    element = arr[j]
                    arr.remove(at: j)
                    arr.insert(element, at: i)
                    i += 1
                    j += 1
                    k += 1
                    if j == arr.count {
                        j = 0
                    }
                    if k == arr.count {
                        k = 0
                    }
                }
            }
            j += 1
            k += 1
        }
        return arr
    }

    func authenticateNextToDuplicatesBorderIndices() -> [BorderIndex] {
        var arr: [BorderIndex] = self.clone()
        var nextPosition: Int = NSNotFound, k: Int = NSNotFound
        var j: Int = 1
        for i in 0..<arr.count  {
            if j == arr.count {
                j = 0
            }
            arr[i].extra = NSNotFound
            if arr[i].point.equalTo(arr[j].point) {
                let positionsForBorderStripIndex = arr.searchBorderIndicesForBorderStripIndex(arr[i].index)
                nextPosition = positionsForBorderStripIndex[1]
                
                if nextPosition > i {
                    k = nextPosition + 1
                    if k == arr.count {
                        k = 0
                    }
                    if arr[nextPosition].point.equalTo(arr[k].point) {
                        arr[i].extra = nextPosition
                        arr[nextPosition].extra = i
                        arr[j].extra = k
                        arr[k].extra = j
                    }
                    else {
                        k = nextPosition - 1
                        if k == -1 {
                            k = arr.count - 1
                        }
                        if arr[nextPosition].point.equalTo(arr[k].point) {
                            arr[i].extra = nextPosition
                            arr[nextPosition].extra = i
                            arr[j].extra = k
                            arr[k].extra = j
                        }
                    }
                }
            }
            j += 1
        }
        return arr
    }

    func searchBorderIndicesForBorderStripIndex(_ index: Int) -> [Int] {
        return self.indices.filter{ self[$0].index == index }
    }

    func sortBorderIndicesByBorderDirection(_ borderDirection: ContourBorderDimensionDirection) -> [BorderIndex] {
        var arr: [BorderIndex] = self.clone()
        switch borderDirection {
            case .xForward:
                arr.sort(by: { borderIndex0, borderIndex1 in
                    if borderIndex0.point.x == borderIndex1.point.x {
                        if ( borderIndex0.borderdirection != .xForward ) {
                            return true
                        }
                        return (!borderIndex0.end && borderIndex0.index > borderIndex1.index) || (borderIndex0.end && borderIndex0.index < borderIndex1.index)
                    }
                    else {
                        return borderIndex0.point.x < borderIndex1.point.x
                    }
                })
                
            case .yForward:
                arr.sort(by: { borderIndex0, borderIndex1 in
                    if borderIndex0.point.y == borderIndex1.point.y {
                        if ( borderIndex0.borderdirection != .yForward ) {
                            return true
                        }
                        return (!borderIndex0.end && borderIndex0.index > borderIndex1.index) || (borderIndex0.end && borderIndex0.index < borderIndex1.index)
                    }
                    else {
                        return borderIndex0.point.y < borderIndex1.point.y
                    }
                })
                
            case .xBackward:
                arr.sort(by: { borderIndex0, borderIndex1 in
                    if borderIndex0.point.x == borderIndex1.point.x {
                        if ( borderIndex0.borderdirection != .xBackward ) {
                            return true
                        }
                        return (!borderIndex0.end && borderIndex0.index > borderIndex1.index) || (borderIndex0.end && borderIndex0.index < borderIndex1.index)
                    }
                    else {
                        return borderIndex0.point.x > borderIndex1.point.x
                    }
                })
            
            case .yBackward:
                arr.sort(by: { borderIndex0, borderIndex1 in
                    if borderIndex0.point.y == borderIndex1.point.y {
                        if ( borderIndex0.borderdirection != .yBackward) {
                            return true
                        }
                        return (!borderIndex0.end && borderIndex0.index > borderIndex1.index) || (borderIndex0.end && borderIndex0.index < borderIndex1.index)
                    }
                    else {
                        return borderIndex0.point.y > borderIndex1.point.y
                    }
                })
            
            case .none:
                break
        }
        
        return arr
    }
    
    func sortBorderIndicesByAngle() -> [BorderIndex] {
        var arr: [BorderIndex] = self.clone()
        arr.sort(by:{ borderIndex0, borderIndex1 in
            if borderIndex0.angle == borderIndex1.angle {
                return (!borderIndex0.end && borderIndex0.index > borderIndex1.index) || (borderIndex0.end && borderIndex0.index < borderIndex1.index)
            }
            else {
                return borderIndex0.angle < borderIndex1.angle
            }
        })
        return arr
    }
}

/** @brief A structure used internally by ContourPlot to plot boundary points.
 **/

struct CGPathBoundaryPoint: Equatable, Hashable {
    var point: CGPoint
    var position: Int
    var direction: ContourBorderDimensionDirection
    var used: Bool
    
    init() {
        point = .zero
        position = NSNotFound
        direction = .none
        used = false
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(position)
    }
        
    static func == (lhs: CGPathBoundaryPoint, rhs: CGPathBoundaryPoint) -> Bool {
        return lhs.point == rhs.point
    }
}

extension Array where Element == CGPathBoundaryPoint {
    
    func clone() -> [CGPathBoundaryPoint] {
        var copiedArray: [CGPathBoundaryPoint] = []
        for element in self {
            copiedArray.append(element)
        }
        return copiedArray
    }
    
    func removingDuplicates() -> [Element] {
      var addedDict = [Element: Bool]()

      return filter {
          addedDict.updateValue(true, forKey: $0) == nil
      }
    }
    
    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
    
    func sortCGPathBoundaryPointsByPosition() -> [CGPathBoundaryPoint] {
        var arr = self.clone()
        arr.sort(by: { $0.position > $1.position })
        
        return arr
    }

    func sortCGPathBoundaryPointsByBottomEdge() -> [CGPathBoundaryPoint] {
        var arr = self.clone()
        arr.sort(by: { pt0, pt1 in
            if pt0.point.x > pt1.point.x {
                return true
            }
            else if pt0.point.x == pt1.point.x {
                if pt0.direction != .xForward {
                    return true
                }
                return pt0.position > pt1.position
            }
            else {
                return false
            }
        })
        
        return arr
    }

    func sortCGPathBoundaryPointsByRightEdge() -> [CGPathBoundaryPoint] {
        var arr = self.clone()
        arr.sort(by: { pt0, pt1 in
            if pt0.point.y > pt1.point.y {
                return true
            }
            else if pt0.point.y == pt1.point.y {
                if pt0.direction != .yForward {
                    return true
                }
                return pt0.position > pt1.position
            }
            else {
                return false
            }
        })
        
        return arr
    }

    func sortCGPathBoundaryPointsByTopEdge() -> [CGPathBoundaryPoint] {
        var arr = self.clone()
        arr.sort(by: { pt0, pt1 in
            if pt0.point.x < pt1.point.x {
                return true
            }
            else if pt0.point.x == pt1.point.x {
                if pt0.direction != .xBackward {
                    return true
                }
                return pt0.position > pt1.position
            }
            else {
                return false
            }
        })
        
        return arr
    }

    func sortCGPathBoundaryPointsByLeftEdge() -> [CGPathBoundaryPoint] {
        var arr = self.clone()
        arr.sort(by: { pt0, pt1 in
            if pt0.point.y < pt1.point.y {
                return true
            }
            else if pt0.point.y == pt1.point.y {
                if pt0.direction != .yBackward {
                    return true
                }
                return pt0.position > pt1.position
            }
            else {
                return false
            }
        })
        
        return arr
    }
    
    func filterCGPathBoundaryPoints(predicate: (_ item: CGPathBoundaryPoint, _ direction: ContourBorderDimensionDirection, _ edge: CGFloat) -> Bool, direction: ContourBorderDimensionDirection, edge: CGFloat) -> [CGPathBoundaryPoint] {
        var filtered: [CGPathBoundaryPoint] = []
        for i in 0..<self.count {
            if ( predicate(self[i], direction, edge) ) {
                filtered.append(self[i])
            }
        }
        
        return filtered
    }
    
    func filterCGPathBoundaryPointsForACorner(predicate: (_ item: CGPathBoundaryPoint, _ corner: CGPoint) -> Bool,  corner: CGPoint) -> [CGPathBoundaryPoint] {
        var filtered: [CGPathBoundaryPoint] = []
        for i in 0..<self.count {
            if ( predicate(self[i], corner) ) {
                filtered.append(self[i])
            }
        }
        
        return filtered
    }
    
    func checkCGPathBoundaryPointsAreUniqueForEdge(direction: ContourBorderDimensionDirection) -> Bool {
        var isUnique = true
        for i in 0..<self.count {
            for j in 0..<self.count {
                if i != j && ((self[i].point.x == self[j].point.x && (direction == .yBackward || direction == .yForward) ) || (self[i].point.y == self[j].point.y && (direction == .xForward || direction == .xBackward))) {
                    isUnique = false
                    break
                }
            }
            if !isUnique {
                break
            }
        }
        return isUnique
    }
}

/** @brief A structure used internally by CPTContourPlot to search for intersections within the contours .
 **/

struct Intersection {
    var strip0: LineStrip?
    var strip1: LineStrip?
    var index: Int
    var jndex: Int
    var intersectionIndex: Int
    var useStrips: Bool
    var isCorner: Bool
    var usedCount: Int16
    var point: CGPoint
    
    init() {
        strip0 = nil
        strip1 = nil
        index = NSNotFound
        jndex = NSNotFound
        intersectionIndex = NSNotFound
        useStrips = false
        isCorner = false
        usedCount = 0
        point = .zero
    }
    
    func closestKIntersections(_ intersections: inout [Intersection]) {
        intersections.sort(by: { i0, i1 in
            return self.point.distance(point: i0.point) < self.point.distance(point: i1.point)
        })
    }
}

extension Array where Element == Intersection {
    
    func clone() -> [Intersection] {
        var copiedArray: [Intersection] = []
        for element in self {
            copiedArray.append(element)
        }
        return copiedArray
    }
    
    mutating func insertIntersection(index: Int, jndex:Int, strip0: LineStrip?, strip1: LineStrip?, point: CGPoint, useStrips: Bool) -> Void {
        var newIntersection = Intersection()
        newIntersection.index = index
        newIntersection.jndex = jndex
        newIntersection.strip0 = strip0
        newIntersection.strip1 = strip1
        newIntersection.point = point
        newIntersection.useStrips = useStrips
        newIntersection.isCorner = false
        newIntersection.usedCount = 0
        newIntersection.intersectionIndex = NSNotFound
        self.append(newIntersection)
    }
    
    mutating func insertCorner(_ point: CGPoint, index: Int) -> Int {
        
        var check: Int = 0
        if let _check = self.firstIndex(where: { intersection in
            return abs(point.x - intersection.point.x) < 1.0 && abs(point.y - intersection.point.y) < 1.0
            }) {
            check = _check
            var newIntersection = Intersection()
            newIntersection.index = index
            newIntersection.jndex = index
            newIntersection.strip0 = nil
            newIntersection.strip1 = nil
            newIntersection.point = point
            newIntersection.useStrips = false
            newIntersection.isCorner = true
            newIntersection.usedCount = 0
            newIntersection.intersectionIndex = NSNotFound
            
            if self.contains(where: { intersection in
                if abs(newIntersection.point.x - intersection.point.x) < 5.01 {
                    if abs(newIntersection.point.y - intersection.point.y) < 5.01 {
                        return true
                    }
                    else {
                        return false
                    }
                }
                else {
                    return false
                }
            }) {
                self.append(newIntersection)
                check = self.count - 1
            }
        }
        else {
            self[check].isCorner = false
        }
        return check
    }
    
    mutating func sortIntersectionsByPointIncreasingXCoordinate() {
        let arr: [Intersection] = self.clone().sorted { intersection0, intersection1 in
            if abs(intersection0.point.x - intersection1.point.x) < 0.001 {
                return intersection0.point.y < intersection1.point.y
            }
            else {
                return intersection0.point.x < intersection1.point.x
            }
        }
        self = arr.clone()
    }
    
    mutating func sortIntersectionsByPointIncreasingYCoordinate() {
        let arr: [Intersection] = self.clone().sorted { intersection0, intersection1 in
            if abs(intersection0.point.y - intersection1.point.y) < 0.001 {
                return intersection0.point.x < intersection1.point.x
            }
            else {
                return intersection0.point.y < intersection1.point.y
            }
        }
        self = arr.clone()
    }
    
    mutating func sortIntersectionsByPointDecreasingXCoordinate() {
        let arr: [Intersection] = self.clone().sorted { intersection0, intersection1 in
            if abs(intersection0.point.x - intersection1.point.x) < 0.001 {
                return intersection0.point.y > intersection1.point.y
            }
            else {
                return intersection0.point.x > intersection1.point.x
            }
        }
        self = arr.clone()
    }
    
    mutating func sortIntersectionsByPointDecreasingYCoordinate() {
        let arr: [Intersection] = self.clone().sorted { intersection0, intersection1 in
            if abs(intersection0.point.y - intersection1.point.y) < 0.001 {
                return intersection0.point.x > intersection1.point.x
            }
            else {
                return intersection0.point.y > intersection1.point.y
            }
        }
        self = arr.clone()
    }
    

    mutating func sortIntersectionsByOrderAntiClockwiseFromBottomLeftCorner(corners: [CGPoint], tolerance: CGFloat) {
        let n = self.count
        
        if !( n == 0 || n == 1 ) {
            
            var temp1: [Intersection] = []
            temp1.reserveCapacity(n)
            var temp2: [Intersection] = []
            temp2.reserveCapacity(n)
            
            for i in 0..<n {
                if abs(self[i].point.y - corners[0].y) < tolerance  {
                    temp1.append(self[i])
                    
                }
            }
            temp1.sortIntersectionsByPointIncreasingXCoordinate()
            
            for i in 0..<temp1.count {
                temp2.append(temp1[i])
            }
            temp1.removeAll()
            
            for i in 0..<n {
                if abs(self[i].point.x - corners[1].x) < tolerance  {
                    temp1.append(self[i])
                }
            }
            temp1.sortIntersectionsByPointIncreasingYCoordinate()
            
            for i in 0..<temp1.count {
                temp2.append(temp1[i])
            }
            temp1.removeAll()
            
            for i in 0..<n {
                if abs(self[i].point.y - corners[2].y) < tolerance {
                    temp1.append(self[i])
                }
            }
            temp1.sortIntersectionsByPointDecreasingXCoordinate()
            
            for i in 0..<temp1.count {
                temp2.append(temp1[i])
            }
            temp1.removeAll()
            
            for i in 0..<n {
                if abs(self[i].point.x - corners[3].x) < tolerance {
                    temp1.append(self[i])
                }
            }
            temp1.sortIntersectionsByPointDecreasingYCoordinate()
            for i in 0..<temp1.count {
                temp2.append(temp1[i])
            }
            temp1.removeAll()
            temp2.removeDuplicates(withinTolerance: 0.01)
            
            self.removeAll()
            self.append(contentsOf: temp2)
            
            temp2.removeAll()
        }
    }
    
    func removingDuplicates(withinTolerance tolerance: CGFloat) -> [Intersection] {
        var uniqueElements: [Intersection] = self.clone()
        for x in uniqueElements {
            let interested = uniqueElements.enumerated().filter({ $0.element.point.distance(point: x.point) <= tolerance }).map({ $0.offset })
            uniqueElements = uniqueElements.remove(elementsAtIndices: interested)
        }
        return uniqueElements
    }

    mutating func removeDuplicates(withinTolerance tolerance: CGFloat) {
        self = self.removingDuplicates(withinTolerance: tolerance)
    }
    
    mutating func removeSimilarIntersections(_ intersections: [Intersection]) {
        let n = self.count
        
        if !(n == 0 || n == 1) {
            
            var temp: [Intersection] = []
            temp.reserveCapacity(n)
            
            for i in 0..<n {
                if let item = intersections.first(where: { intersection in
                    if abs(intersection.point.x - self[i].point.x) < 5.01 {
                        return abs(intersection.point.y - self[i].point.y) < 5.01
                    }
                    else {
                        return false
                    }
                }) {
                    temp.append(item/*self[i]*/)
                }
            }
            self = temp.clone()
        }
    }
    
    
//    func closestChild(point: CGPoint, maxDistance: CGFloat) -> CGPoint? {
//        return self.filter { $0.point.distance(point) <= maxDistance }
//                .minElement { $0.0.position.distance(point) < $0.1.position.distance(point) }
//        }
}


struct Index_DistanceAngle {
    var index: Int
    var distance: CGFloat
    var angle:CGFloat
}

struct Centroid {
    var noVertices: Int
    var centre: CGPoint
    var boundingBox: CGRect
    
    init() {
        noVertices = 0
        centre = .zero
        boundingBox = .zero
    }
    
    init(noVertices: Int, centre: CGPoint, boundingBox: CGRect) {
        self.noVertices = noVertices
        self.centre = centre
        self.boundingBox = boundingBox
    }
}

extension Array where Element == Centroid {
    func sort() -> [Centroid] {
        let arr = self.sorted { centroid0, centroid1 in
            if ( abs(centroid0.centre.x - centroid1.centre.x) < 0.5 ) {
                if ( abs(centroid0.centre.y - centroid1.centre.y ) < 0.5 ) {
                    return false
                }
                else {
                    return centroid0.centre.y < centroid1.centre.y
                }
            }
            else {
                return centroid0.centre.x < centroid1.centre.x
            }
        }
        return arr
    }
    
    func search(_ centroid: Centroid) -> Int? {
        let index = self.firstIndex { element in
            if ( abs(element.centre.x - centroid.centre.x) < 0.5 ) {
                if ( abs(element.centre.y - centroid.centre.y ) < 0.5 ) {
                    return false
                }
                else {
                    return element.centre.y < centroid.centre.y
                }
            }
            else {
                return element.centre.x < centroid.centre.x
            }
        }
        return index
    }
}

struct Line {
    var index0: Int
    var index1: Int
    var gradient: CGFloat
    var constant: CGFloat
}

struct IntersectionIndices: Equatable {
    var index: Int
    var jndex: Int
    
    static func == (lhs: IntersectionIndices, rhs: IntersectionIndices) -> Bool {
        return lhs.index == rhs.index && lhs.jndex == rhs.jndex
    }
}

extension Array where Element == IntersectionIndices {
    // returns unique array
    func unique() -> [IntersectionIndices] {
        var uniqueIndices: [IntersectionIndices] = []
        for index in self {
            if !uniqueIndices.contains(index) {
                uniqueIndices.append(index)
            }
        }
        return uniqueIndices
    }
}

extension Array where Element == Int {
    // returns unique array
    func unique() -> [Int] {
        var uniqueIndices: [Int] = []
        for index in self {
            if !uniqueIndices.contains(index) {
                uniqueIndices.append(index)
            }
        }
        return uniqueIndices
    }
}


extension Array {
    var bytes: [UInt8] { withUnsafeBytes { .init($0) } }
    var data: Data { withUnsafeBytes { .init($0) } }
}

extension Array where Element: Copying {
    func clone() -> Array<Element> {
        var copiedArray:[Element] = []
        for element in self {
            copiedArray.append(element.copy())
        }
        return copiedArray
    }
}
    
extension ContiguousBytes {
    func object<T>() -> T { withUnsafeBytes { $0.load(as: T.self) } }
    func objects<T>() -> [T] { withUnsafeBytes { .init($0.bindMemory(to: T.self)) } }
}

extension CGRect {
    func toleranceCGRectEqualToRect(_ a: CGRect) -> Bool {
        return abs(self.origin.x - a.origin.x) < 0.5 && abs(self.origin.y - a.origin.y) < 0.5 && abs(self.size.width - a.size.width) < 0.5 && abs(self.size.height - a.size.height) < 0.5
    }
}

