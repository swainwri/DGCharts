//
//  PolarChartData.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics

public class PolarChartData: RadarChartData {

    @objc public internal(set) var radialMax: Double {
        get {
            return yMax
        }
        set {
            yMax = newValue
        }
    }
    @objc public internal(set) var radialMin: Double {
        get {
            return yMin
        }
        set {
            yMin = newValue
        }
    }
    @objc public var radialRange: Double {
        get {
            return yMax - yMin
        }
    }
    
    @objc public internal(set) var thetaMax: Double {
        get {
            return xMax
        }
        set {
            xMax = newValue
        }
    }
    
    @objc public internal(set) var thetaMin: Double {
        get {
            return xMin
        }
        set {
            xMin = newValue
        }
    }
    
    @objc public var thetaRange: Double {
        get {
            return xMax - xMin
        }
    }
    
    var majorAxisMax: Double {
        get {
            return self.leftAxisMax
        }
        set {
            self.leftAxisMax = newValue
        }
    }
    var minorAxisMax: Double {
        get {
            return self.rightAxisMax
        }
        set {
            self.rightAxisMax = newValue
        }
    }
    var majorAxisMin: Double {
        get {
            return self.leftAxisMin
        }
        set {
            self.leftAxisMin = newValue
        }
    }
    var minorAxisMin: Double {
        get {
            return self.rightAxisMin
        }
        set {
            self.rightAxisMin = newValue
        }
    }
    
    private var radialAxisMin: Double = Double.greatestFiniteMagnitude
    private var radialAxisMax: Double = -Double.greatestFiniteMagnitude

    @objc open func calcMinMaxRadial(fromTheta: Double, toTheta: Double) {
        forEach { dataSet in
                if let _dataSet = dataSet as? PolarChartDataSet {
                    _dataSet.calcMinMaxRadial(fromTheta: fromTheta, toTheta: toTheta)
                }
            }
        
        // apply the new data
        calcMinMax()
    }
    
    /// calc minimum and maximum y value over all datasets
    @objc open override func calcMinMax() {
        
        majorAxisMax = -.greatestFiniteMagnitude
        minorAxisMax = -.greatestFiniteMagnitude
        radialMax = -.greatestFiniteMagnitude
        radialMin = .greatestFiniteMagnitude
        
        forEach { calcMinMax(dataSet: $0 as! PolarChartDataSet) }
        
        
        // major axis
        if let firstLeft = getFirstLeft(dataSets: dataSets) as? PolarChartDataSetProtocol {
            radialAxisMax = firstLeft.radialMax
            radialAxisMin = -radialAxisMax
            
            for dataSet in _dataSets where dataSet.axisDependency == .left {
                if dataSet.yMin < radialAxisMin {
                    radialAxisMin = dataSet.yMin
                }

                if dataSet.yMax > radialAxisMax {
                    radialAxisMax = dataSet.yMax
                }
            }
        }
        
        // minor axis
        if let firstRight = getFirstRight(dataSets: dataSets) as? PolarChartDataSetProtocol {
            radialAxisMax = firstRight.radialMax
            radialAxisMax = -radialAxisMax
            
            for dataSet in _dataSets where dataSet.axisDependency == .right {
                if dataSet.yMin < rightAxisMin  {
                    radialAxisMax = dataSet.yMin
                }

                if dataSet.yMax > rightAxisMax {
                    rightAxisMax = dataSet.yMax
                }
            }
        }
    }

    /// Adjusts the current minimum and maximum values based on the provided Entry object.
    @objc public func calcMinMax(entry e: ChartDataEntry) {
        if let _e = e as? PolarChartDataEntry {
            radialMax = Swift.max(radialMax, _e.radial)
            radialMin = -radialMax
            majorAxisMax = Swift.max(majorAxisMax, _e.radial)
            majorAxisMin = -majorAxisMax
        }
    }
    
    /// Adjusts the minimum and maximum values based on the given DataSet.
    @objc open override func calcMinMax(dataSet d: Element) {
        if let _d = d as? PolarChartDataSet {
            radialMax = Swift.max(radialMax, _d.radialMax)
            radialMin = -radialMax
            majorAxisMax = Swift.max(majorAxisMax, _d.radialMax)
            majorAxisMin = -majorAxisMax
        }
    }
    
    @objc public func getRadialMax(axis: RadialAxis.PolarAxisDependency) -> Double {
        if axis == .major {
            if majorAxisMax == -.greatestFiniteMagnitude {
                return minorAxisMax
            }
            else {
                return majorAxisMax
            }
        }
        else {
            if minorAxisMax == -.greatestFiniteMagnitude {
                return majorAxisMax
            }
            else {
                return minorAxisMax
            }
        }
    }
    
    
    
    /// Removes the Entry object closest to the given xIndex from the ChartDataSet at the
    /// specified index.
    ///
    /// - Returns: `true` if an entry was removed, `false` ifno Entry was found that meets the specified requirements.
    @objc @discardableResult open func removeEntry(thetaValue: Double, dataSetIndex: Index) -> Bool {
        guard
            dataSets.indices.contains(dataSetIndex),
            let entry = self[dataSetIndex].entryForXValue(thetaValue, closestToY: .nan)
            else { return false }

        return removeEntry(entry, dataSetIndex: dataSetIndex)
    }
    
    /// - Returns: The DataSet that contains the provided Entry, or null, if no DataSet contains this entry.
    @objc open override func getDataSetForEntry(_ e: ChartDataEntry) -> Element? {
        if let _e = e as? PolarChartDataEntry {
            return first { $0.entryForXValue(_e.theta, closestToY: _e.radial) === e }
        }
        else {
            return nil
        }
    }

    /// Sets a custom PointFormatter for all DataSets this data object contains.
    @objc open func setPointFormatter(_ formatter: PointFormatter){
        forEach { ($0 as? PolarChartDataSet)?.pointFormatter = formatter }
    }
}

