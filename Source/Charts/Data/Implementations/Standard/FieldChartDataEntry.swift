//
//  FieldChartDataEntry.swift
//  DGCharts
//
//  Created by Steve Wainwright on 06/04/2023.
//

import Foundation
import CoreGraphics

@objc public class Field: NSObject, Decodable {
    var magnitude: Double
    var direction: Double
    
    init(magnitude: Double, direction: Double) {
        self.magnitude = magnitude
        self.direction = direction
    }
}

public class FieldChartDataEntry: ChartDataEntry {
    
    /// the magnitude value
    @objc public var magnitude: Double {
        get {
            if let _data = self.data as? Field {
                return _data.magnitude
            }
            else {
                return 0
            }
        }
        set {
            if let _data = self.data as? Field {
                _data.magnitude = newValue
            }
        }
    }
    
    /// the direction value
    @objc public var direction: Double {
        get {
            if let _data = self.data as? Field {
                return _data.direction
            }
            else {
                return 0
            }
        }
        set {
            if let _data = self.data as? Field {
                _data.direction = newValue
            }
        }
    }
    
    /// the magnitude value
    @objc public var fxy: Double {
        get {
            if let _data = self.data as? Field {
                return _data.magnitude
            }
            else {
                return 0
            }
        }
        set {
            if let _data = self.data as? Field {
                _data.magnitude = newValue
            }
        }
    }
    
    public required init() {
        super.init()
        
        self.x = 0
        self.y = 0
        self.data = Field(magnitude: 0, direction: 0)
    }
    
    /// An Entry represents one single entry in the chart.
    ///
    /// - Parameters:
    ///   - x: the x value
    ///   - y: the y value
    ///   - data: Space for additional Field data this Entry represents.
    
    @objc public init(x: Double, y: Double, data: Any?) {
        super.init()
        
        self.x = x
        self.y = y
        if data is Field {
            self.data = data as? Field
        }
    }
    
    /// An Entry represents one single entry in the chart.
    ///
    /// - Parameters:
    ///   - x: the x value
    ///   - y: the y value
    ///   - magnitude: magnitude  value.
    ///   - direction: direction  value.
    
    @objc public init(x: Double, y: Double, magnitude: Double, direction: Double) {
        super.init()
        
        self.x = x
        self.y = y
        self.data = Field(magnitude: magnitude, direction: direction)
    }
    
    /// An Entry represents one single entry in the chart.
    ///
    /// - Parameters:
    ///   - x: the x value
    ///   - y: the y value
    ///   - fxy: magnitude  value.
    
    @objc public init(x: Double, y: Double, fxy: Double) {
        super.init()
        
        self.x = x
        self.y = y
        self.data = Field(magnitude: fxy, direction: -0)
    }
    
    /// An Entry represents one single entry in the chart.
    ///
    /// - Parameters:
    ///   - x: the x value
    ///   - y: the y value
    ///   - icon: icon image
    
    @objc public convenience init(x: Double, y: Double, icon: NSUIImage?) {
        self.init(x: x, y: y, data: Field(magnitude: 0, direction: -0))
        self.icon = icon
    }
    
    /// An Entry represents one single entry in the chart.
    ///
    /// - Parameters:
    ///   - x: the x value
    ///   - y: the y value
    ///   - icon: icon image
    ///   - data: Space for additional data this Entry represents.
    
    @objc public convenience init(x: Double, y: Double, icon: NSUIImage?, data: Any?) {
        if data is Field {
            self.init(x: x, y: y, data: data as? Field)
        }
        else {
            self.init(x: x, y: y, data: nil)
        }
        self.icon = icon
    }
        
    // MARK: NSObject
    
    open override var description: String {
        if let _data = data as? Field {
            if _data.direction == 0 && _data.direction.sign == .minus {
                return "FieldChartDataEntry, x: \(x), y:\(y), f(x,y):\(_data.magnitude)"
            }
            else {
                return "FieldChartDataEntry, x: \(x), y:\(y), magnitude:\(_data.magnitude), direction:\(_data.direction)"
            }
        }
        else {
            return "FieldChartDataEntry, x: \(x), y:\(y)"
        }
        
    }
    
    // MARK: NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! FieldChartDataEntry
        
        return copy
    }
    
}
