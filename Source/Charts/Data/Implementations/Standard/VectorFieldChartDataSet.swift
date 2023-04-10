//
//  VectorFieldChartDataSet.swift
//  DGCharts
//
//  Created by Steve Wainwright on 06/04/2023.
//

import Foundation
import CoreGraphics

public class VectorFieldChartDataSet: LineRadarChartDataSet, VectorFieldChartDataSetProtocol {
    /**
     *  @brief vector field arrow  types.
     **/
    @objc(VectorFieldArrowType)
    public enum ArrowType: Int {
        case none  ///< No arrow.
        case open  ///< Open arrow .
        case solid ///< Solid arrow .
        case swept ///< Swept arrow.
    }
    
    public var arrowType: ArrowType = .none
    
    /// - Returns: The size the vector field arrow will have
    public var arrowSize: CGFloat = 10
    
    /// - Returns: Thickness of the vector.
    /// **default**: 1
    public var vectorWidth: CGFloat = 5
    
    /// - Returns / Sets the normalisedVectorLength one wishes to see on chart
    /// **default**: 1
    public var normalisedVectorLength: Double = 1
    
    /** @property BOOL usesEvenOddClipRule
     *  @brief If @YES, the even-odd rule is used to draw the arrow, otherwise the non-zero winding number rule is used.
     *  @see <a href="http://developer.apple.com/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_paths/dq_paths.html#//apple_ref/doc/uid/TP30001066-CH211-TPXREF106">Filling a Path</a> in the Quartz 2D Programming Guide.
     **/
    public var usesEvenOddClipRule: Bool = true
    
    public var maxVectorMagnitude: Double {
        get {
            if let _entries = entries as? [FieldChartDataEntry] {
                return _entries.map( { $0.magnitude } ).reduce(-Double.infinity,  { Swift.max($0, $1) })
            }
            else {
                return .infinity
            }
        }
    }
    // MARK: NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! VectorFieldChartDataSet
        copy.arrowType = arrowType
        copy.arrowSize = arrowSize
        copy.fill = fill
        copy.vectorWidth = vectorWidth
        copy.normalisedVectorLength = normalisedVectorLength
        return copy
    }
}
