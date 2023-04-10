//
//  FieldChartDataSetProtocol.swift
//  DGCharts
//
//  Created by Steve Wainwright on 06/04/2023.
//

import Foundation
import CoreGraphics

@objc
public protocol VectorFieldChartDataSetProtocol: LineScatterCandleRadarChartDataSetProtocol {

    // MARK: - Data functions and accessors
    
    // MARK: - Styling functions and accessors
    
    var arrowType: VectorFieldChartDataSet.ArrowType { get set }
    
    /// - Returns: The size the vector field arrow will have
    var arrowSize: CGFloat { get set }
    
    /// - Returns: Thickness of the vector. 
    /// **default**: 5
    var vectorWidth: CGFloat { get set }
    
    /// - Returns / Sets a custom normalised Vector Length in pixels
    var normalisedVectorLength: Double { get set }
    
    /// - Returns: the max vectorlength in the entries array
    var maxVectorMagnitude: Double { get }
    
    /** @property BOOL usesEvenOddClipRule
     *  @brief If @YES, the even-odd rule is used to draw the arrow, otherwise the non-zero winding number rule is used.
     *  @see <a href="http://developer.apple.com/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_paths/dq_paths.html#//apple_ref/doc/uid/TP30001066-CH211-TPXREF106">Filling a Path</a> in the Quartz 2D Programming Guide.
     **/
    var usesEvenOddClipRule: Bool { get set }
    
}
