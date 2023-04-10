//
//  DefaultPolarFillFormatter.swift
//  DGCharts
//
//  Created by Steve Wainwright on 04/04/2023.
//

import Foundation
import CoreGraphics

/// Default formatter that calculates the radius of the filled line.
@objc(ChartDefaultPolarFillFormatter)
public class DefaultPolarFillFormatter: NSObject, PolarFillFormatter {
    public typealias Block = (
        _ dataSet: PolarChartDataSetProtocol,
        _ dataProvider: PolarChartDataProvider) -> CGFloat
    
    @objc public var block: Block?
    
    public override init() { }
    
    @objc public init(block: @escaping Block) {
        self.block = block
    }
    
    @objc public static func with(block: @escaping Block) -> DefaultPolarFillFormatter? {
        return DefaultPolarFillFormatter(block: block)
    }
    
    public func getFillLineRadius(dataSet: PolarChartDataSetProtocol, dataProvider: PolarChartDataProvider) -> CGFloat {
    
        if let _block = self.block {
            return _block(dataSet, dataProvider)
        }
        else {
            var fillMinRadius: CGFloat = 0.0
            
            if dataSet.radialMax > 0.0 && dataSet.radialMin < 0.0 {
                fillMinRadius = 0.0
            }
            else if let data = dataProvider.polarData {
                let max = data.radialMax > 0.0 ? 0.0 : dataProvider.chartRadialMax
                let min = data.radialMin < 0.0 ? 0.0 : dataProvider.chartRadialMin
                
                fillMinRadius = CGFloat(dataSet.radialMin >= 0.0 ? min : max)
            }
            
            return fillMinRadius
        }
    }
}

