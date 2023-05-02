//
//  PointFormatter.swift
//  DGCharts
//
//  Created by Steve Wainwright on 04/04/2023.
//

import Foundation

/// The default value formatter used for all chart components that needs a default
@objc(ChartDefaultPointFormatter)
public class DefaultPointFormatter: NSObject, PointFormatter {
    public typealias Block = (_ entry: ChartDataEntry, _ dataSetIndex: Int, _ viewPortHandler: ViewPortHandler?) -> String
    
    @objc open var block: Block?
    
    @objc open var hasAutoDecimals: Bool
    
    @objc open var formatter: NumberFormatter? {
        willSet  {
            hasAutoDecimals = false
        }
    }
    
    open var decimals: Int? {
        didSet {
            setupDecimals(decimals: decimals)
        }
    }

    private func setupDecimals(decimals: Int?)  {
        if let digits = decimals {
            formatter?.minimumFractionDigits = digits
            formatter?.maximumFractionDigits = digits
            formatter?.usesGroupingSeparator = true
        }
    }
    
    public override init() {
        formatter = NumberFormatter()
        formatter?.usesGroupingSeparator = true
        decimals = 1
        hasAutoDecimals = true

        super.init()
        setupDecimals(decimals: decimals)
    }
    
    @objc public init(formatter: NumberFormatter) {
        self.formatter = formatter
        hasAutoDecimals = false

        super.init()
    }
    
    @objc public init(decimals: Int) {
        formatter = NumberFormatter()
        formatter?.usesGroupingSeparator = true
        self.decimals = decimals
        hasAutoDecimals = true

        super.init()
        setupDecimals(decimals: decimals)
    }
    
    @objc public init(block: @escaping Block) {
        self.block = block
        hasAutoDecimals = false

        super.init()
    }

    /// This function is deprecated - Use `init(block:)` instead.
    // DEC 11, 2017
    @available(*, deprecated, message: "Use `init(block:)` instead.")
    @objc public static func with(block: @escaping Block) -> DefaultPointFormatter {
        return DefaultPointFormatter(block: block)
    }
    
    public func stringForPoint(entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        if let block = block {
            return block(entry, dataSetIndex, viewPortHandler)
        } else {
            if let _formatter = formatter,
               let _x = _formatter.string(from: NSNumber(floatLiteral: entry.x)),
               let _y = _formatter.string(from: NSNumber(floatLiteral: entry.y)) {
                return _x + "\n" + _y
            }
            else {
                return "\(entry.x)\n\(entry.y)"
            }
        }
    }
    
    public func stringForDataAtPoint(entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        if let block = block {
            return block(entry, dataSetIndex, viewPortHandler)
        }
        else if let _data = entry.data as? Field {
            if let _formatter = formatter {
                if _data.direction == 0.0 && _data.direction.sign == .minus {
                    if let _fxy = _formatter.string(from: NSNumber(floatLiteral: _data.magnitude)) {
                        return _fxy
                    }
                    else {
                        return "\(_data.magnitude)"
                    }
                }
                else {
                    if let _magnitude = _formatter.string(from: NSNumber(floatLiteral: _data.magnitude)),
                       let _direction = _formatter.string(from: NSNumber(floatLiteral: _data.direction)){
                        return _magnitude + "\n" + _direction
                    }
                    else {
                        return "\(_data.magnitude)\n\(_data.direction)"
                    }
                }
            }
            else {
                return "\(_data.magnitude)\n\(_data.direction)"
            }
        }
        else if let _data = entry.data as? Double {
            if let _formatter = formatter {
                if let _magnitude = _formatter.string(from: NSNumber(floatLiteral: _data)) {
                    return _magnitude
                }
                else {
                    return "\(_data)"
                }
            }
            else {
                return "\(_data)"
            }
        }
        else {
            return ""
        }
    }
}
