//
//  VectorFieldChartData.swift
//  DGCharts
//
//  Created by Steve Wainwright on 09/04/2023.
//

import Foundation
import CoreGraphics

public class VectorFieldChartData: BarLineScatterCandleBubbleChartData {
    public required init() {
        super.init()
    }
    
    public override init(dataSets: [ChartDataSetProtocol]) {
        super.init(dataSets: dataSets)
    }

    public required init(arrayLiteral elements: ChartDataSetProtocol...) {
        super.init(dataSets: elements)
    }
    
    /// - Returns: The maximum arrow-size across all DataSets.
    @objc public func getGreatestArrowSize() -> CGFloat {
        return (_dataSets as? [VectorFieldChartDataSetProtocol])?
            .max { $0.arrowSize < $1.arrowSize }?
            .arrowSize ?? 0
    }
    
}
