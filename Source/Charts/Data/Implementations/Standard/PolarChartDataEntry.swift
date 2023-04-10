//
//  PolarChartDataEntry.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics

public class PolarChartDataEntry: ChartDataEntry {
    /// the radial value
    @objc var radial: Double {
        get {
            return y
        }
        set {
            y = newValue
        }
    }
    /// the theta value
    @objc var theta: Double {
        get {
            return x
        }
        set {
            x = newValue
        }
    }
    
    public required init() {
        super.init()
        
        self.radial = 0
        self.theta = 0
    }
    
    /// An Entry represents one single entry in the chart.
    ///
    /// - Parameters:
    ///   - radial: the radial value
    ///   - theta: the theta value
    @objc public init(radial: Double, theta: Double) {
        super.init()
        
        self.radial = radial
        self.theta = theta
    }
    
    /// An Entry represents one single entry in the chart.
    ///
    /// - Parameters:
    ///   - radial: the radial value
    ///   - theta: the theta value
    ///   - data: Space for additional data this Entry represents.
    
    @objc public convenience init(radial: Double, theta: Double, data: Any?) {
        self.init(radial: radial, theta: theta)
        self.data = data
    }
    
    /// An Entry represents one single entry in the chart.
    ///
    /// - Parameters:
    ///   - radial: the radial value
    ///   - theta: the theta value
    ///   - icon: icon image
    
    @objc public convenience init(radial: Double, theta: Double, icon: NSUIImage?) {
        self.init(radial: radial, theta: theta)
        self.icon = icon
    }
    
    /// An Entry represents one single entry in the chart.
    ///
    /// - Parameters:
    ///   - radial: the radial value
    ///   - theta: the theta value
    ///   - icon: icon image
    ///   - data: Space for additional data this Entry represents.
    
    @objc public convenience init(radial: Double, theta: Double, icon: NSUIImage?, data: Any?) {
        self.init(radial: radial, theta: theta)
        self.icon = icon
        self.data = data
    }
        
    // MARK: NSObject
    
    open override var description: String {
        return "PolarChartDataEntry, radial: \(radial), theta \(theta)"
    }
    
    // MARK: NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! PolarChartDataEntry
        
        return copy
    }
    
}
