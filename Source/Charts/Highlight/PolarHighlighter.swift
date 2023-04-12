//
//  PolarHighlighter.swift
//  DGCharts
//
//  Created by Steve Wainwright on 12/04/2023.
//

import UIKit
import CoreGraphics

@objc(PolarChartHighlighter)
public class PolarHighlighter:  PieRadarHighlighter {
    
    public override func closestHighlight(index: Int, x: CGFloat, y: CGFloat) -> Highlight? {
        if let chart = self.chart as? PolarChartView  {
            
            let highlights = getHighlights(forIndex: index)
            
            let distanceToCenter = Double(chart.distanceToCenter(x: x, y: y) / chart.factor)
            
            func closestToCenter(lhs: Highlight, rhs: Highlight) -> Bool {
                abs(lhs.y - distanceToCenter) < abs(rhs.y - distanceToCenter)
            }
            
            let closest = highlights.min(by: closestToCenter(lhs:rhs:))
            return closest
        }
        else {
            return nil
        }
    }
    
    /// - Parameters:
    ///   - index:
    /// - Returns: An array of Highlight objects for the given index.
    /// The Highlight objects give information about the value at the selected index and DataSet it belongs to.
    internal func getHighlights(forIndex index: Int) -> [Highlight] {
        var vals = [Highlight]()
        
        if let chart = self.chart as? PolarChartView,
           let chartData = chart.data as? PolarChartData {
            
            let phaseX = chart.chartAnimator.phaseX
            let phaseY = chart.chartAnimator.phaseY
            let sliceangle = chart.sliceAngle
            let factor = chart.factor
            
            for (i, dataSet) in chartData.indexed(){
                if let entry = dataSet.entryForIndex(index) {
                
                    let y = (entry.y - chart.chartYMin)
                
                    let p = chart.centerOffsets.moving(distance: CGFloat(y) * factor * CGFloat(phaseY), atAngle: sliceangle * CGFloat(index) * CGFloat(phaseX) + chart.rotationAngle)
                
                    let highlight = Highlight(x: Double(index), y: entry.y, xPx: p.x, yPx: p.y, dataSetIndex: i, axis: dataSet.axisDependency)
                    vals.append(highlight)
                }
            }
            
            return vals
        }
        else { return vals }
    }
}
