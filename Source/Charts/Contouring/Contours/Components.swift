//
//  Components.swift
//  DGCharts(Contouring)
//
//  Created by Steve Wainwright on 27/03/2023.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif
import CoreGraphics

struct Boundary {
    var leftEdge: CGFloat
    var bottomEdge: CGFloat
    var rightEdge: CGFloat
    var topEdge: CGFloat
}

public class ContourFill: NSObject {
    public var fill: Any?   // either EmptyFill, ColourFill or ImageFill
    public var first: Double?
    public var second: Double?
    
}
                                                                      
                    
struct LineStyle {
    var color: CGColor
    var lineWidth: CGFloat
    var lineCap: CGLineCap
    var lineJoin: CGLineJoin
    var miterLimit: CGFloat
    var dash: [CGFloat]
    var dashPhase: CGFloat
                                
    init() {
        color = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        lineWidth = 1
        lineCap = .butt
        lineJoin = .miter
        miterLimit = 0
        dash = []
        dashPhase = 0
    }
                                
    init(withLineStyle lineStyle: LineStyle) {
        color = lineStyle.color
        lineWidth = lineStyle.lineWidth
        lineCap = lineStyle.lineCap
        lineJoin = lineStyle.lineJoin
        miterLimit = lineStyle.miterLimit
        dash = lineStyle.dash
        dashPhase = lineStyle.dashPhase
    }
 }
                                                                      

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
      var addedDict = [Element: Bool]()

      return filter {
          addedDict.updateValue(true, forKey: $0) == nil
      }
    }

    mutating func removeDuplicates() {
      self = self.removingDuplicates()
    }
}
   
#if os(iOS) || os(tvOS)

extension NSUIColor {
    convenience init(hue: CGFloat, saturation: CGFloat, lightness: CGFloat, alpha: CGFloat) {
        precondition(0...1 ~= hue &&
                   0...1 ~= saturation &&
                   0...1 ~= lightness &&
                   0...1 ~= alpha, "input range is out of range 0...1")
      
          //From HSL TO HSB ---------
          var newSaturation: CGFloat = 0.0
          
          let brightness = lightness + saturation * min(lightness, 1-lightness)
          
          if brightness == 0 {
              newSaturation = 0.0
          }
          else {
              newSaturation = 2 * (1 - lightness / brightness)
          }
      //---------
      
        self.init(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
    }
}

#else
extension NSUIColor {
    convenience init(hue: CGFloat, saturation: CGFloat, lightness: CGFloat, alpha: CGFloat) {
        precondition(0...1 ~= hue &&
                   0...1 ~= saturation &&
                   0...1 ~= lightness &&
                   0...1 ~= alpha, "input range is out of range 0...1")
      
          //From HSL TO HSB ---------
          var newSaturation: CGFloat = 0.0
          
          let brightness = lightness + saturation * min(lightness, 1-lightness)
          
          if brightness == 0 {
              newSaturation = 0.0
          }
          else {
              newSaturation = 2 * (1 - lightness / brightness)
          }
      //---------
      
        self.init(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
    }
}
#endif


extension Hull {
    
    /**
     This main function allows to create the hull of a set of point by defining the desired concavity of the return
     hull.
     In this function, there is no need for the format
     - parameter cgPoints: The list of point as CGPoint
     - returns: An array of point in the same format as pointSet, which is the hull of the pointSet
     **
     **/
    
    public func hull(cgPoints: [CGPoint]) -> [CGPoint] {
        
        if cgPoints.count < 4 {
            return cgPoints
        }
        
        let pointSet = cgPoints.map { (point: CGPoint) -> [Double] in
            return [point.x, point.y]
        }
        
        hull = HullHelper().getHull(pointSet, concavity: self.concavity, format: self.format)
        
        return (hull as? [[Double]])!.map { (point: [Double]) -> CGPoint in
            return CGPoint(x: point[0], y: point[1])
        }
    }
}

extension Bool {
    static func ^ (left: Bool, right: Bool) -> Bool {
        return left != right
    }
}

