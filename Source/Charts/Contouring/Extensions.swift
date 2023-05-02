//
//  Extensions.swift
//  PlotterSwift
//
//  Created by Steve Wainwright on 23/09/2017.
//  Copyright © 2017 Whichtoolface.com. All rights reserved.
//

import Foundation
#if os(OSX)
import Cocoa
#else
import UIKit
#endif
//import PopMenu
#if canImport(MobileCoreServices)
import MobileCoreServices
#endif
import UniformTypeIdentifiers
#if targetEnvironment(macCatalyst)
import Dynamic
#endif

extension String {
    
    func path(withFont font: NSUIFont, withColor colour: NSUIColor = .black) -> CGPath {
        let attributedString = NSAttributedString(string: self, attributes: [.font: font, .foregroundColor: colour])
        let path = attributedString.path()
        return path
    }
    
    func fileName() -> String {
        if let fileNameWithoutExtension = NSURL(fileURLWithPath: self).deletingPathExtension?.lastPathComponent {
            return fileNameWithoutExtension
        } else {
            return ""
        }
    }
    
    func fileExtension() -> String {
        if let fileExtension = NSURL(fileURLWithPath: self).pathExtension {
            return fileExtension
        } else {
            return ""
        }
    }
    
    var isContainsNumericsNegativeOrPoint : Bool {
        var allowed = CharacterSet.decimalDigits
        allowed = allowed.union(CharacterSet(charactersIn: ".-"))
        return self.rangeOfCharacter(from: allowed) != nil
    }
    
    var length : Int {
        get{
            return self.count
        }
    }
    
    subscript (i: Int) -> String {
        return String(self[i ..< i + 1])
    }
    
    func substring(fromIndex: Int) -> String {
        return String(self[min(fromIndex, length) ..< length])
    }
    
    func substring(toIndex: Int) -> String {
        return String(self[0 ..< max(0, toIndex)])
    }
    
    subscript (r: Swift.Range<Int>) -> String {
        let range = Swift.Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
    
    func ranges(of substring: String, options: CompareOptions = [], locale: Locale? = nil) -> [Swift.Range<Index>] {
        var ranges: [Swift.Range<Index>] = []
        while let range = range(of: substring, options: options, range: (ranges.last?.upperBound ?? self.startIndex)..<self.endIndex, locale: locale) {
            ranges.append(range)
        }
        return ranges
    }
    
    var isNumber: Bool {
        guard self.count > 0 else { return false }
        let nums: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "."]
        return Set(self).isSubset(of: nums)
    }
}

extension NSAttributedString {
    func path() -> CGPath {
        let path = CGMutablePath()

        // Use CoreText to lay the string out as a line
        let line = CTLineCreateWithAttributedString(self as CFAttributedString)

        // Iterate the runs on the line
        let runArray = CTLineGetGlyphRuns(line)
        let numRuns = CFArrayGetCount(runArray)
        for runIndex in 0..<numRuns {

            // Get the font for this run
            let run = unsafeBitCast(CFArrayGetValueAtIndex(runArray, runIndex), to: CTRun.self)
            let runAttributes = CTRunGetAttributes(run) as Dictionary
            let runFont = runAttributes[kCTFontAttributeName] as! CTFont
            //let runForegroundColour = runAttributes[kCTForegroundColorAttributeName] as! CTColor

            // Iterate the glyphs in this run
            let numGlyphs = CTRunGetGlyphCount(run)
            for glyphIndex in 0..<numGlyphs {
                let glyphRange = CFRangeMake(glyphIndex, 1)

                // Get the glyph
                var glyph : CGGlyph = 0
                withUnsafeMutablePointer(to: &glyph) { glyphPtr in
                    CTRunGetGlyphs(run, glyphRange, glyphPtr)
                }

                // Get the position
                var position : CGPoint = .zero
                withUnsafeMutablePointer(to: &position) {positionPtr in
                    CTRunGetPositions(run, glyphRange, positionPtr)
                }

                // Get a path for the glyph
                guard let glyphPath = CTFontCreatePathForGlyph(runFont, glyph, nil) else {
                    continue
                }

                // Transform the glyph as it is added to the final path
                let t = CGAffineTransform(translationX: position.x, y: position.y)
                path.addPath(glyphPath, transform: t)
            }
        }

        return path
    }
    
    var hasImage: Bool {
        var hasImage = false
        let fullRange = NSRange(location: 0, length: self.length)
        self.enumerateAttribute(NSAttributedString.Key.attachment, in: fullRange, options: []) { (value, _, _) in
            guard let attachment = value as? NSTextAttachment else { return }
            if let _ = attachment.image {
                hasImage = true
            }
        }
        return hasImage
    }
    
    func getParts() -> [Dictionary<String, Any>] {
        var parts: [Dictionary<String, Any>] = []
        let range = NSRange(location: 0, length: self.length)
        self.enumerateAttributes(in: range, options: NSAttributedString.EnumerationOptions(rawValue: 0)) { (object, range, stop) in
            if object.keys.contains(NSAttributedString.Key.attachment) {
                if let attachment = object[NSAttributedString.Key.attachment] as? NSTextAttachment {
                    if let image = attachment.image {
                        parts.append(["key": NSAttributedString.Key.attachment, "part": image, "range": range])
                    } else if let image = attachment.image(forBounds: attachment.bounds, textContainer: nil, characterIndex: range.location) {
                        parts.append(["key": NSAttributedString.Key.attachment, "part": image, "range": range])
                    }
                }
            } else {
                let stringValue : String = self.attributedSubstring(from: range).string
                if (!stringValue.trimmingCharacters(in: .whitespaces).isEmpty) {
                    parts.append(["key": NSAttributedString.Key.none, "part": stringValue as AnyObject, "range": range])
                }
            }
        }
        return parts
    }
    
    convenience init(data: Data, documentType: DocumentType, encoding: String.Encoding = .utf8) throws {
        try self.init(attributedString: .init(data: data, options: [.documentType: documentType, .characterEncoding: encoding.rawValue], documentAttributes: nil))
    }

    func data(_ documentType: DocumentType) -> Data {
        // Discussion
        // Raises an rangeException if any part of range lies beyond the end of the receiver’s characters.
        // Therefore passing a valid range allow us to force unwrap the result
        try! data(from: .init(location: 0, length: length),
                  documentAttributes: [.documentType: documentType])
    }

    func height(containerWidth: CGFloat) -> CGFloat {
        let rect = self.boundingRect(with: CGSize.init(width: containerWidth, height: CGFloat.greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                     context: nil)
        return ceil(rect.size.height)
    }

    func width(containerHeight: CGFloat) -> CGFloat {
        let rect = self.boundingRect(with: CGSize.init(width: CGFloat.greatestFiniteMagnitude, height: containerHeight),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                     context: nil)
        return ceil(rect.size.width)
    }
 
#if os(OSX)
    func image() -> NSImage? {
        
        NSUIGraphicsBeginImageContextWithOptions(self.size(), false, 0.0)

        self.draw(in: CGRect(origin: .zero, size: self.size()))

        let image = NSUIGraphicsGetImageFromCurrentImageContext()
        NSUIGraphicsEndImageContext()
        
        return image
        
    }
#else
    func image() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.size(), false, 0.0)
        
        // draw in context
        self.draw(at: CGPoint(x: 0.0, y: 0.0))
        
        // transfer image
        let image = UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysOriginal)
        UIGraphicsEndImageContext()
        
        return image
    }
#endif

    static func + (left: NSAttributedString, right: NSAttributedString) -> NSAttributedString {
        let leftCopy = NSMutableAttributedString(attributedString: left)
        leftCopy.append(right)
        return leftCopy
    }

    static func + (left: NSAttributedString, right: String) -> NSAttributedString {
        let leftCopy = NSMutableAttributedString(attributedString: left)
        let rightAttr = NSMutableAttributedString(string: right)
        leftCopy.append(rightAttr)
        return leftCopy
    }

    static func + (left: String, right: NSAttributedString) -> NSAttributedString {
        let leftAttr = NSMutableAttributedString(string: left)
        leftAttr.append(right)
        return leftAttr
    }
}

extension NSAttributedString.Key {
    static let none = NSAttributedString.Key("None")
}

extension NSMutableAttributedString {

    func setAttachmentsAlignment(_ alignment: NSTextAlignment) {
        self.enumerateAttribute(NSAttributedString.Key.attachment, in: NSRange(location: 0, length: self.length), options: .longestEffectiveRangeNotRequired) { (attribute, range, stop) -> Void in
            if attribute is NSTextAttachment {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = alignment
                self.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: range)
            }
        }
    }

    static func += (left: NSMutableAttributedString, right: String) -> NSMutableAttributedString {
        let rightAttr = NSMutableAttributedString(string: right)
        left.append(rightAttr)
        return left
    }

    static func += (left: NSMutableAttributedString, right: NSAttributedString) -> NSMutableAttributedString {
        left.append(right)
        return left
    }
}

extension URL {
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = URL(fileURLWithPath: self.path)
        return copy
    }
}

protocol Copying {
    init(original: Self)
}

extension Copying {
    func copy() -> Self {
        return Self.init(original: self)
    }
}

extension Array where Element: Copying {
    
    func copy() -> Array<Element> {
        return self.map { $0.copy() }
    }
    
}

    
extension Array {
    
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
    
    mutating func remove(elementsAtIndices indicesToRemove: [Int]) -> [Element] {
        guard !indicesToRemove.isEmpty else {
            return []
        }
        
        // Copy the removed elements in the specified order.
        let removedElements = indicesToRemove.map { self[$0] }
        
        // Sort the indices to remove.
        let indicesToRemove = indicesToRemove.sorted()
        
        // Shift the elements we want to keep to the left.
        var destIndex = indicesToRemove.first!
        var srcIndex = destIndex + 1
        func shiftLeft(untilIndex index: Int) {
            while srcIndex < index {
                self[destIndex] = self[srcIndex]
                destIndex += 1
                srcIndex += 1
            }
            srcIndex += 1
        }
        for removeIndex in indicesToRemove[1...] {
            shiftLeft(untilIndex: removeIndex)
        }
        shiftLeft(untilIndex: self.endIndex)
        
        // Remove the extra elements from the end of the array.
        self.removeLast(indicesToRemove.count)
        
        return removedElements
    }
    
}

extension Collection where Element: SignedNumeric {
    func diff() -> [Element] {
        guard var last = first else { return [] }
        return dropFirst().reduce(into: []) {
            $0.append($1 - last)
            last = $1
        }
    }
}

extension Collection where Element: Equatable {
    func indices(of element: Element) -> [Index] { indices.filter { self[$0] == element } }
}

extension Collection {
    func indices(where isIncluded: (Element) throws -> Bool) rethrows -> [Index] { try indices.filter { try isIncluded(self[$0]) } }
}

extension Double {
    
    func roundUpTo(multiplier: Int) -> Int{
        let fractionNum = self / Double(multiplier)
        return Int(ceil(fractionNum)) * multiplier
    }
    
    /// Rounds the double to decimal places value
    func rounded(toPlaces places: Int) -> Double {
        let doublePlaces = Double(places)
        let divisor: Double = pow(10.0, doublePlaces)
        return (self * divisor).rounded() / divisor
    }

    func noDecimalPlaces() -> Int {
        if self > Double(Int64.max) || self == Double(Int64(self)) {
            return 0
        }

        let integerString = String(Int64(self))
        let doubleString = String(Double(self))
        let decimalCount = doubleString.count - integerString.count - 1

        return decimalCount
    }
    
    func removeZerosFromEnd() -> String {
        let formatter = NumberFormatter()
        let number = NSNumber(value: self)
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 16 //maximum digits in Double after dot (maximum precision)
        return String(formatter.string(from: number) ?? "")
    }
    
}

extension Float {
    func roundUpTo(multiplier: Int) -> Int{
        let fractionNum = self / Float(multiplier)
        return Int(ceil(fractionNum)) * multiplier
    }
    
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> Float {
        let floatPlaces = Float(places)
        let divisor = pow(10, floatPlaces)
        return (self * divisor).rounded() / divisor
    }
    
    func noDecimalPlaces() -> Int {
        if self == Float(Int(self)) {
            return 0
        }

        let integerString = String(Int(self))
        let floatString = String(Float(self))
        let decimalCount = floatString.count - integerString.count - 1

        return decimalCount
    }
    
    var clean: String {
       return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }
    
    func removeZerosFromEnd() -> String {
        let formatter = NumberFormatter()
        let number = NSNumber(value: self)
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8 //maximum digits in Double after dot (maximum precision)
        return String(formatter.string(from: number) ?? "")
    }
    
    func radiansToDegrees() -> Float {
        return self / Float.pi * 180.0
    }
    
    func degreesToRadians() -> Float {
        return self / 180.0 * Float.pi
    }
    
}

extension NumberFormatter {
    
    func stringWithSuffixesGreaterThanZero(for obj: Any?) -> String? {
        if let num = obj as? NSNumber {
            let suffixes = ["", "K", "M", "G", "T", "P", "E", "Z", "Y"]
            var idx = 0
            var d = num.doubleValue
            while idx < suffixes.count - 1 {
                if abs(d) < 1000.0 {
                    break
                }
                d /= 1000.0
                idx += 1
            }
            var currencyCode = ""
            if let _currencyCode = self.currencySymbol {
                currencyCode = _currencyCode
            }

            let numStr = String(format: "%.1f", d)

            return currencyCode + numStr + suffixes[idx]
        }
        return nil
    }
    
    func stringWithSuffixesLessThanZero(for obj: Any?) -> String? {
        if let num = obj as? NSNumber {
            let suffixes = ["", "m", "μ", "n", "p", "f", "a", "z", "y"]
            var idx = 0
            var d = num.doubleValue
            if d != 0.0 {
                while idx < suffixes.count - 1 && d != 0.0 {
                    if abs(d) >= 1 {
                        break
                    }
                    d *= 1000.0
                    idx += 1
                }
            }
            var currencyCode = ""
            if let _currencyCode = self.currencySymbol {
                currencyCode = _currencyCode
            }
            
            let numStr = String(format: "%.3f", d)

            return currencyCode + numStr + suffixes[idx]
        }
        return nil
    }
    
    func dividedByKM(_ number: Int) -> String {
        if (number % 1000000) == 0 {
            let numberM = Int(number / 1000000)
            return "\(numberM)M"
        }
        else if (number % 1000) == 0 {
            let numberK = Int(number / 1000)
            return "\(numberK)K"
        }
        return "\(number)"
    }
    
    func dividedByKM(_ number: NSNumber) -> String {
        let _number = number.doubleValue
        if _number / 1000000.0 > 0.0 {
            let numberM = _number / 1000000.0
            return "\(numberM)M"
        }
        else if _number / 1000.0 > 0.0 {
            let numberK = _number / 1000.0
            return "\(numberK)K"
        }
        return "\(_number)"
    }
}

extension CharacterSet {
    func characters() -> [Character] {
        // A Unicode scalar is any Unicode code point in the range U+0000 to U+D7FF inclusive or U+E000 to U+10FFFF inclusive.
        return codePoints().compactMap { UnicodeScalar($0) }.map { Character($0) }
    }

    func codePoints() -> [Int] {
        var result: [Int] = []
        var plane = 0
        // following documentation at https://developer.apple.com/documentation/foundation/nscharacterset/1417719-bitmaprepresentation
        for (i, w) in bitmapRepresentation.enumerated() {
            let k = i % 8193
            if k == 8192 {
                // plane index byte
                plane = Int(w) << 13
                continue
            }
            let base = (plane + k) << 3
            for j in 0 ..< 8 where w & 1 << j != 0 {
                result.append(base + j)
            }
        }
        return result
    }
}

extension Collection {
    func distance(to index: Index) -> Int { distance(from: startIndex, to: index) }
}

extension String.Index {
    func distance<S: StringProtocol>(in string: S) -> Int { string.distance(to: self) }
}

extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    
    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }
    
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        var indices: [Index] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...]
                .range(of: string, options: options) {
                indices.append(range.lowerBound)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return indices
    }
    
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Swift.Range<Index>] {
        var result: [Swift.Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...]
                .range(of: string, options: options) {
                result.append(range)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
    
    func distance(of element: Element) -> Int? { firstIndex(of: element)?.distance(in: self) }
    
    func distance<S: StringProtocol>(of string: S) -> Int? { range(of: string)?.lowerBound.distance(in: self) }
    
    var double: Double? { Double(self) }
    var float: Float? { Float(self) }
    var integer: Int? { Int(self) }
}

#if os(OSX)

extension NSBezierPath {
    
    convenience init(cgPath: CGPath) {
        self.init()

        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                move(to: element.points[0])

            case .addLineToPoint:
                line(to: element.points[0])

            case .addQuadCurveToPoint:
                let qp0 = self.currentPoint
                let qp1 = element.points[0]
                let qp2 = element.points[1]
                let m = CGFloat(2.0 / 3.0)
                let cp1 = NSPoint(x: qp0.x + ((qp1.x - qp0.x) * m),
                                  y: qp0.y + ((qp1.y - qp0.y) * m))
                let cp2 = NSPoint(x: qp2.x + ((qp1.x - qp2.x) * m),
                                  y: qp2.y + ((qp1.y - qp2.y) * m))
                curve(to: qp2, controlPoint1: cp1, controlPoint2: cp2)

            case .addCurveToPoint:
                curve(to: element.points[2], controlPoint1: element.points[0], controlPoint2: element.points[1])

            case .closeSubpath:
                close()

            @unknown default:
                break
            }
        }
    }
    
    /// A `CGPath` object representing the current `NSBezierPath`.
    var cgPath: CGPath {
        let path = CGMutablePath()
        let points = UnsafeMutablePointer<NSPoint>.allocate(capacity: 3)

        if elementCount > 0 {
            var didClosePath = true

            for index in 0..<elementCount {
                let pathType = element(at: index, associatedPoints: points)

                switch pathType {
                case .moveTo:
                    path.move(to: points[0])
                case .lineTo:
                    path.addLine(to: points[0])
                    didClosePath = false
                case .curveTo:
                    path.addCurve(to: points[2], control1: points[0], control2: points[1])
                    didClosePath = false
                case .closePath:
                    path.closeSubpath()
                    didClosePath = true
                @unknown default:
                    break
                }
            }

            if !didClosePath { path.closeSubpath() }
        }

        points.deallocate()
        return path
    }
}

#else

extension UIColor {
    func lighter(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: abs(percentage) )
    }
    
    func darker(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: -1 * abs(percentage) )
    }
    
    func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if(self.getRed(&r, green: &g, blue: &b, alpha: &a)){
            return UIColor(red: min(r + percentage/100, 1.0),
                           green: min(g + percentage/100, 1.0),
                           blue: min(b + percentage/100, 1.0),
                           alpha: a)
        }
        else {
            return nil
        }
    }
    
    class func color(data: Data) -> UIColor? {
        var colour: UIColor?
        do {
            colour = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)!
        }
        catch {
            print(error)
        }
        return colour
    }

    func encode() -> Data? {
        var data: Data?
        do {
            data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
        }
        catch {
            print(error)
        }
        return data
    }
    
    var colour4Float: [CGFloat] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha]
    }
    
    func image(_ size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}

extension UIImage {
    
    func isEqualToImage(_ image: UIImage) -> Bool {
        return self.pngData() == image.pngData()
    }

    func imageIsEmpty() -> Bool {
        guard let cgImage = self.cgImage,
            let dataProvider = cgImage.dataProvider else {
            return true
        }

        let pixelData = dataProvider.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let imageWidth = Int(self.size.width)
        let imageHeight = Int(self.size.height)
        for x in 0..<imageWidth {
            for y in 0..<imageHeight {
                let pixelIndex = ((imageWidth * y) + x) * 4
                let r = data[pixelIndex]
                let g = data[pixelIndex + 1]
                let b = data[pixelIndex + 2]
                let a = data[pixelIndex + 3]
                if a != 0 {
                    if r != 0 || g != 0 || b != 0 {
                        return false
                    }
                }
            }
        }
        return true
    }

    func shapeImage(with bezierPath: UIBezierPath, fill fillColor: UIColor?, stroke strokeColor: UIColor?, strokeWidth: CGFloat) -> UIImage {
        //: Normalize bezier path. We will apply a transform to our bezier path to ensure that it's placed at the coordinate axis. Then we can get its size.
        bezierPath.apply(CGAffineTransform(translationX: -bezierPath.bounds.origin.x, y: -bezierPath.bounds.origin.y))
        let size = CGSize(width: bezierPath.bounds.size.width, height: bezierPath.bounds.size.height)
        //: Initialize an image context with our bezier path normalized shape and save current context
        UIGraphicsBeginImageContext(size)
        //// General Declarations
        let context: CGContext? = UIGraphicsGetCurrentContext()
        context?.saveGState()
        //: Set path
        context?.addPath(bezierPath.cgPath)
        //: Set parameters and draw
        if strokeColor != nil {
            strokeColor?.setStroke()
            context?.setLineWidth(strokeWidth)
        }
        else {
            UIColor.clear.setStroke()
        }
        fillColor?.setFill()
        context?.drawPath(using: CGPathDrawingMode.fillStroke)
        //: Get the image from the current image context
        let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        //: Restore context and close everything
        context?.restoreGState()
        UIGraphicsEndImageContext()
        //: Return image
        return image!
    }
    
    func imageWithBorder(width: CGFloat, color: UIColor, cornerRadius: CGFloat = 0.0) -> UIImage? {
        let square = CGSize(width: min(size.width, size.height)/* + width * 2*/, height: min(size.width, size.height) /*+ width * 2*/)
        let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: square))
        imageView.contentMode = .center
        imageView.image = self
        imageView.layer.borderWidth = width
        imageView.layer.borderColor = color.cgColor
        imageView.layer.cornerRadius = cornerRadius
        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        imageView.layer.render(in: context)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    func tinted(with color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        color.set()
        withRenderingMode(.alwaysTemplate)
            .draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func alpha(_ value:CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: CGPoint.zero, blendMode: .normal, alpha: value)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    /// Returns a version of this image any non-transparent pixels filled with the specified color
    /// - Parameter color: The color to fill
    /// - Returns: A re-colored version of this image with the specified color
    func imageByFillingWithColor(_ color: UIColor) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(context.format.bounds)
            draw(in: context.format.bounds, blendMode: .destinationIn, alpha: 1.0)
        }
    }
    
    /// Applies a stroke around the image
    /// - Parameters:
    ///   - strokeColor: The color of the desired stroke
    ///   - inputThickness: The thickness, in pixels, of the desired stroke
    ///   - rotationSteps: The number of rotations to make when applying the stroke. Higher rotationSteps will result in a more precise stroke. Defaults to 8.
    ///   - extrusionSteps: The number of extrusions to make along a given rotation. Higher extrusions will make a more precise stroke, but aren't usually needed unless using a very thick stroke. Defaults to 1.
    func imageByApplyingStroke(strokeColor: UIColor = .white, strokeThickness inputThickness: CGFloat = 2, rotationSteps: Int = 8, extrusionSteps: Int = 1) -> UIImage {

        let thickness: CGFloat = inputThickness > 0 ? inputThickness : 0

        // Create a "stamp" version of ourselves that we can stamp around our edges
        let strokeImage = imageByFillingWithColor(strokeColor)

        let inputSize: CGSize = size
        let outputSize: CGSize = CGSize(width: size.width + (thickness * 2), height: size.height + (thickness * 2))
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let stroked = renderer.image { ctx in

            // Compute the center of our image
            let center = CGPoint(x: outputSize.width / 2, y: outputSize.height / 2)
            let centerRect = CGRect(x: center.x - (inputSize.width / 2), y: center.y - (inputSize.height / 2), width: inputSize.width, height: inputSize.height)

            // Compute the increments for rotations / extrusions
            let rotationIncrement: CGFloat = rotationSteps > 0 ? 360 / CGFloat(rotationSteps) : 360
            let extrusionIncrement: CGFloat = extrusionSteps > 0 ? thickness / CGFloat(extrusionSteps) : thickness

            for rotation in 0..<rotationSteps {

                for extrusion in 1...extrusionSteps {

                    // Compute the angle and distance for this stamp
                    let angleInDegrees: CGFloat = CGFloat(rotation) * rotationIncrement
                    let angleInRadians: CGFloat = angleInDegrees * .pi / 180.0
                    let extrusionDistance: CGFloat = CGFloat(extrusion) * extrusionIncrement

                    // Compute the position for this stamp
                    let x = center.x + extrusionDistance * cos(angleInRadians)
                    let y = center.y + extrusionDistance * sin(angleInRadians)
                    let vector = CGPoint(x: x, y: y)

                    // Draw our stamp at this position
                    let drawRect = CGRect(x: vector.x - (inputSize.width / 2), y: vector.y - (inputSize.height / 2), width: inputSize.width, height: inputSize.height)
                    strokeImage.draw(in: drawRect, blendMode: .destinationOver, alpha: 1.0)

                }

            }

            // Finally, re-draw ourselves centered within the context, so we appear in-front of all of the stamps we've drawn
            self.draw(in: centerRect, blendMode: .normal, alpha: 1.0)

        }

        return stroked
    }
    
    func imageRotated(byRadians radians: CGFloat) -> UIImage? {
        var newImage: UIImage?
        if let _cgImage = self.cgImage {
            // calculate the size of the rotated view's containing box for our drawing space
            let rotatedViewBox = UIView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            let t = CGAffineTransform(rotationAngle: radians)
            rotatedViewBox.transform = t
            let rotatedSize = rotatedViewBox.frame.size

            // Create the bitmap context
            UIGraphicsBeginImageContext(rotatedSize)
            let bitmap = UIGraphicsGetCurrentContext()

            // Move the origin to the middle of the image so we will rotate and scale around the center.
            bitmap?.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)

            //   // Rotate the image context
            bitmap?.rotate(by: radians)

            // Now, draw the rotated/scaled image into the context
            bitmap?.scaleBy(x: 1.0, y: -1.0)
            bitmap?.draw(_cgImage, in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
            
            newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }
        return newImage
    }

    func fixedOrientation() -> UIImage? {
        if self.imageOrientation == UIImage.Orientation.up {
            return self
        }
        var transform = CGAffineTransform.identity
        switch self.imageOrientation {
            case .down, .downMirrored:
                transform = CGAffineTransform(translationX: self.size.width, y: self.size.height)
                transform = CGAffineTransform(rotationAngle: CGFloat.pi)
            case .left, .leftMirrored:
                transform = CGAffineTransform(translationX: self.size.width, y: 0)
                transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)
            case .right, .rightMirrored:
                transform = CGAffineTransform(translationX: 0, y: self.size.height)
                    transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2.0)
            default:
                break
        }
            
        switch self.imageOrientation {
            case .upMirrored, .downMirrored:
                transform = CGAffineTransform(translationX: self.size.width, y: 0)
                transform = CGAffineTransform(scaleX: -1, y: 1)
            case .leftMirrored, .rightMirrored:
                transform = CGAffineTransform(translationX: self.size.height, y: 0)
                transform = CGAffineTransform(scaleX: -1, y: 1)
            default:
                break
        }
        var uiImage: UIImage?
        if let _cgImage = self.cgImage,
           let _colorSpace = _cgImage.colorSpace,
           let ctx = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: _cgImage.bitsPerComponent, bytesPerRow: 0, space: _colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.concatenate(transform)
            switch self.imageOrientation {
                case .left, .leftMirrored, .right, .rightMirrored:
                    ctx.draw(_cgImage, in: CGRect(x: 0, y: 0, width: self.size.height, height:self.size.width))
                default:
                    ctx.draw(_cgImage, in: CGRect(x: 0, y: 0, width: self.size.width, height:self.size.height))
                    break
            }
            if let cgImage = ctx.makeImage() {
                uiImage = UIImage(cgImage: cgImage)
            }
        }
        return uiImage
    }
}

extension UIBezierPath {

    /** Returns an image of the path drawn using a stroke */
    func strokeImageWithColor(strokeColor: UIColor, fillColor: UIColor) -> UIImage? {

        // get your bounds
        let bounds: CGRect = self.bounds

        UIGraphicsBeginImageContextWithOptions(CGSize(width: bounds.size.width + self.lineWidth * 2, height: bounds.size.height + self.lineWidth * 2), false, UIScreen.main.scale)

        // get reference to the graphics context
        let reference: CGContext = UIGraphicsGetCurrentContext()!

        // translate matrix so that path will be centered in bounds
        reference.translateBy(x: self.lineWidth, y: self.lineWidth)

        // set the color
        fillColor.setFill()
        strokeColor.setStroke()

        // draw the path
        fill()
        stroke()


        // grab an image of the context
        let image = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()

        return image
    }

}

extension UITextInput {
    var selectedRange: NSRange? {
        if let selectedRange = self.selectedTextRange {
            return NSRange(location: self.offset(from: self.beginningOfDocument, to: selectedRange.start),
                           length: self.offset(from: selectedRange.start, to: selectedRange.end))
        }
        else {
            return nil
        }
    }
}

extension UIPasteboard {
    func set(attributedString: NSAttributedString?, options: [UIPasteboard.OptionsKey: Any] = [:]) {

        guard let attributedString = attributedString else {
            return
        }
        
        if attributedString.hasImage {
            do {
                let rtfd = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtfd])
                self.setItems([[UTType.rtfd.description as String: rtfd, UTType.utf8PlainText.description as String: attributedString.string]], options: options)
            } catch let error as NSError {
                print(error)
            }
        }
        else {
            do {
                let rtf = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf])
                self.setItems([[UTType.rtf.description as String: rtf, UTType.utf8PlainText.description as String: attributedString.string]], options: options)
            } catch let error as NSError {
                print(error)
            }
        }
    }
}

extension UIButton {
    func setColorFilledImage(_ color: UIColor, forState controlState: UIControl.State) {
        let colorImage = UIGraphicsImageRenderer(size: CGSize(width: self.bounds.size.width, height: self.bounds.size.height)).image { _ in
            color.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height)).fill()
        }
        setImage(colorImage, for: controlState)
    }
}

extension UIImageView {
    func setColorFilledImage(_ color: UIColor) {
        let colorImage = UIGraphicsImageRenderer(size: CGSize(width: self.bounds.size.width, height: self.bounds.size.height)).image { _ in
            color.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height)).fill()
        }
        self.image = colorImage
    }
}

extension UITextField {
    func textFieldDesignWithLeftPadding(padding: CGFloat, image: UIImage) {
        let viewPadding = UIView(frame: CGRect(x: 0, y: 0, width: padding, height: self.frame.size.height))
        let imageView = UIImageView (frame:CGRect(x: 0, y: 0, width: image.size.width, height: self.frame.size.height))
        
        imageView.center = viewPadding.center
        imageView.image  = image
        viewPadding .addSubview(imageView)
        
        self.leftView = viewPadding
        self.leftViewMode = .always
        self.rightViewMode = .whileEditing
    }
}

extension UIView {
    func addBlurToView(_ style: UIBlurEffect.Style, alpha: CGFloat) {
        let blurEffect = UIBlurEffect(style: style)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.alpha = alpha
        blurEffectView.frame = self.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(blurEffectView)
    }
    
    func removeBlurFromView() {
        for subview in self.subviews {
            if subview is UIVisualEffectView {
                subview.removeFromSuperview()
            }
        }
    }
    
    func removeAllConstraints() {
        var view: UIView? = self
        while let currentView = view {
            currentView.removeConstraints(currentView.constraints.filter {
                return $0.firstItem as? UIView == self || $0.secondItem as? UIView == self
            })
            view = view?.superview
        }
    }
    
    var heightConstraint: NSLayoutConstraint? {
        get {
            return constraints.first(where: {
                $0.firstAttribute == .height && $0.relation == .equal
            })
        }
        set { setNeedsLayout() }
    }

    var widthConstraint: NSLayoutConstraint? {
        get {
            return constraints.first(where: {
                $0.firstAttribute == .width && $0.relation == .equal
            })
        }
        set { setNeedsLayout() }
    }
}

extension UIWindow {
    #if targetEnvironment(macCatalyst)
    var nsWindow: NSObject? {
        Dynamic.NSApplication.sharedApplication.delegate.hostWindowForUIWindow(self)
    }
    
    var scaleFactor: CGFloat {
      get {
        Dynamic.NSApplication.sharedApplication
          .windows.firstObject.contentView
          .subviews.firstObject.scaleFactor ?? 1.0
      }
      set {
        Dynamic.NSApplication.sharedApplication
          .windows.firstObject.contentView
          .subviews.firstObject.scaleFactor = newValue
      }
    }
    #endif
}

extension UIDevice {
    
    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        func mapToDevice(identifier: String) -> String { // swiftlint:disable:this cyclomatic_complexity
            #if os(iOS)
            switch identifier {
            case "iPod5,1":                                 return "iPod Touch 5"
            case "iPod7,1":                                 return "iPod Touch 6"
            case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
            case "iPhone4,1":                               return "iPhone 4s"
            case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
            case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
            case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
            case "iPhone7,2":                               return "iPhone 6"
            case "iPhone7,1":                               return "iPhone 6 Plus"
            case "iPhone8,1":                               return "iPhone 6s"
            case "iPhone8,2":                               return "iPhone 6s Plus"
            case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
            case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
            case "iPhone8,4":                               return "iPhone SE"
            case "iPhone10,1", "iPhone10,4":                return "iPhone 8"
            case "iPhone10,2", "iPhone10,5":                return "iPhone 8 Plus"
            case "iPhone10,3", "iPhone10,6":                return "iPhone X"
            case "iPhone11,2":                              return "iPhone XS"
            case "iPhone11,4", "iPhone11,6":                return "iPhone XS Max"
            case "iPhone11,8":                              return "iPhone XR"
            case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
            case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
            case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
            case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
            case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
            case "iPad6,11", "iPad6,12":                    return "iPad 5"
            case "iPad7,5", "iPad7,6":                      return "iPad 6"
            case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
            case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
            case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
            case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
            case "iPad6,3", "iPad6,4":                      return "iPad Pro 9.7 Inch"
            case "iPad6,7", "iPad6,8":                      return "iPad Pro 12.9 Inch"
            case "iPad7,1", "iPad7,2":                      return "iPad Pro 12.9 Inch 2. Generation"
            case "iPad7,3", "iPad7,4":                      return "iPad Pro 10.5 Inch"
            case "AppleTV5,3":                              return "Apple TV"
            case "AppleTV6,2":                              return "Apple TV 4K"
            case "AudioAccessory1,1":                       return "HomePod"
            case "i386", "x86_64":                          return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS"))"
            default:                                        return identifier
            }
            #elseif os(tvOS)
            switch identifier {
            case "AppleTV5,3": return "Apple TV 4"
            case "AppleTV6,2": return "Apple TV 4K"
            case "i386", "x86_64": return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "tvOS"))"
            default: return identifier
            }
            #endif
        }
        
        return mapToDevice(identifier: identifier)
    }()
    
}

extension UINavigationBar {
    func toggle() {
        if self.layer.zPosition == -1 {
            self.layer.zPosition = 0
            self.isUserInteractionEnabled = true
        } else {
            self.layer.zPosition = -1
            self.isUserInteractionEnabled = false
        }
    }
}
#endif

extension NSRange {
    private init(string: String, lowerBound: String.Index, upperBound: String.Index) {
        let utf16 = string.utf16

        let lowerBound = lowerBound.samePosition(in: utf16)
        let location = utf16.distance(from: utf16.startIndex, to: lowerBound ?? string.startIndex)
        let length = utf16.distance(from: lowerBound ?? string.startIndex, to: upperBound.samePosition(in: utf16) ?? string.endIndex)

        self.init(location: location, length: length)
    }

    init(range: Swift.Range<String.Index>, in string: String) {
        self.init(string: string, lowerBound: range.lowerBound, upperBound: range.upperBound)
    }

    init(range: Swift.ClosedRange<String.Index>, in string: String) {
        self.init(string: string, lowerBound: range.lowerBound, upperBound: range.upperBound)
    }
}

extension CGPoint {
    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func /(lhs: CGPoint, divisor: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x / divisor, y: lhs.y / divisor)
    }
    
    static func *(lhs: CGPoint, divisor: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * divisor, y: lhs.y * divisor)
    }
    
    func rotatePointAroundOrigin(_ origin: CGPoint, rotation: CGFloat) -> CGPoint {
        let dx = self.x - origin.x
        let dy = self.y - origin.y
        let radius = sqrt(dx * dx + dy * dy)
        let azimuth = atan2(dy, dx) // in radians
        let newAzimuth = azimuth + rotation;
        return CGPoint(x: origin.x + radius * cos(newAzimuth), y: origin.y + radius * sin(newAzimuth))
    }
    //// 2D Points P=[x,y] and R are points on line,
    //// Q is point for which we want to find reflection
    //function mirror(Q,[P,R]) {
    //  let [vx,vy]= [ R[0]-P[0], R[1]-P[1] ];
    //  let [x,y]  = [ P[0]-Q[0], P[1]-Q[1] ];
    //  let r= 1/(vx*vx+vy*vy);
    //  return [ Q[0] +2*(x -x*vx*vx*r -y*vx*vy*r),
    //           Q[1] +2*(y -y*vy*vy*r -x*vx*vy*r)  ];
    //}
    // 2D Points P=[x,y] and R are points on line,
    // Q is point for which we want to find reflection
    func mirrorPointAboutALine(_ line: [CGPoint]) -> CGPoint {
        let vx = line[1].x - line[0].x
        let vy = line[1].y - line[0].y
        let x = line[0].x - self.x
        let y = line[0].y - self.y
        let r = 1 / (vx * vx + vy * vy)
        return CGPoint(x: self.x + 2.0 * (x - x * vx * vx * r - y * vx * vy * r), y: self.y + 2.0 * (y - y * vy * vy * r - x * vx * vy * r))
    }
    
    
    func distance(point: CGPoint) -> CGFloat {
        return CGFloat(hypotf(Float(point.x - self.x), Float(point.y - self.y)))
    }

    mutating func closestKPoints(_ points: inout [CGPoint]) {
        points.sort(by: { pt0, pt1 in
            return self.distance(point: pt0) < self.distance(point: pt1)
        })
    }
    
}

extension Array where Element == CGPoint {
    
    func findCentroidOfShape() -> CGPoint {
        let off = self[0]
        var twicearea: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
    
        var j : Int = self.count - 1
        for i in 0..<self.count {
            let f = (self[i].x - off.x) * (self[j].y - off.y) - (self[j].x - off.x) * (self[i].y - off.y)
            twicearea += f
            x += (self[i].x + self[j].x - 2 * off.x) * f
            y += (self[i].y + self[j].y - 2 * off.y) * f
            j = i
        }

        let f = twicearea * 3
        
        if f == 0 {
            return CGPoint(x: (self[1].x + off.x) / 2, y: (self[1].y + off.y) / 2)
        }

        return CGPoint(x: x / f + off.x, y: y / f + off.y)
    }
}

extension CGPath {
    
    /// this is a computed property, it will hold the points we want to extract
    var points: [CGPoint] {
        /// this is a local transient container where we will store our CGPoints
        var arrPoints: [CGPoint] = []
        // applyWithBlock lets us examine each element of the CGPath, and decide what to do
        self.applyWithBlock { element in
              switch element.pointee.type  {
                  case .moveToPoint, .addLineToPoint:
                    arrPoints.append(element.pointee.points.pointee)

                  case .addQuadCurveToPoint:
                    arrPoints.append(element.pointee.points.pointee)
                    arrPoints.append(element.pointee.points.advanced(by: 1).pointee)

                  case .addCurveToPoint:
                    arrPoints.append(element.pointee.points.pointee)
                    arrPoints.append(element.pointee.points.advanced(by: 1).pointee)
                    arrPoints.append(element.pointee.points.advanced(by: 2).pointee)

                  default:
                    break
              }
        }
        // We are now done collecting our CGPoints and so we can return the result
        return arrPoints
    }
         
    
//    func points() -> [CGPoint] {
//        var bezierPoints = [CGPoint]()
//        self.forEach(body: { (element: CGPathElement) in
//            guard element.type != .closeSubpath else {
//                return
//            }
//            let numberOfPoints: Int = {
//                switch element.type {
//                    case .moveToPoint, .addLineToPoint: // contains 1 point
//                        return 1
//                    case .addQuadCurveToPoint: // contains 2 points
//                        return 2
//                    case .addCurveToPoint: // contains 3 points
//                        return 3
//                    case .closeSubpath:
//                        return 0
//                    @unknown default:
//                        return 0
//                }
//            }()
//            for index in 0..<numberOfPoints {
//                let point = element.points[index]
//                bezierPoints.append(point)
//            }
//        })
//        return bezierPoints
//    }
//
//    func forEach(body: @convention(block) @escaping (CGPathElement) -> Void) {
//        typealias Body = @convention(block) (CGPathElement) -> Void
//        func callback(_ info: UnsafeMutableRawPointer?, _ element: UnsafePointer<CGPathElement>) {
//            let body = unsafeBitCast(info, to: Body.self)
//            body(element.pointee)
//        }
//        let unsafeBody = unsafeBitCast(body, to: UnsafeMutableRawPointer.self)
//        self.apply(info: unsafeBody, function: callback as CGPathApplierFunction)
//    }
    
    var centre: CGPoint {
        return centroid
    }
    
    var noVertices: Int {
        return points.count
    }
                                
    var centroid: CGPoint {
        var cx: CGFloat = 0, cy: CGFloat = 0
        let _points = self.points
        let area = polygonArea
        if area == 0 {
            for i in 0..<_points.count {
                cx += _points[i].x
                cy += _points[i].y;
            }
            cx /= CGFloat(_points.count)
            cy /= CGFloat(_points.count)
        }
        else {
            var factor: CGFloat = 0
            var j: Int
            for i in 0..<_points.count {
                j = (i + 1) % _points.count
                factor = (_points[i].x * _points[j].y - _points[j].x * _points[i].y)
                cx += (_points[i].x + _points[j].x) * factor
                cy += (_points[i].y + _points[j].y) * factor
            }
            cx *= 1 / (6.0 * area)
            cy *= 1 / (6.0 * area)
        }
        return CGPoint(x: cx, y: cy)
    }
    
    var area: CGFloat {
        return self.polygonArea
    }
    
    var polygonArea: CGFloat {
        var area: CGFloat = 0
        var j: Int
        let _points = self.points
        for i in 0..<_points.count {
            j = (i + 1) % _points.count
            area += _points[i].x * _points[j].y;
            area -= _points[i].y * _points[j].x;
        }
        area /= 2
        return area
    }
    
    var isCGPathClockwise: Bool {
        return self.polygonArea < 0
    }
    
    func reverse() -> CGMutablePath {
        
        let _points = self.points
        let reversedCGPath: CGMutablePath = CGMutablePath()
        if _points.count > 1 {
            reversedCGPath.move(to: _points[0])
        
            for i in stride(from: _points.count - 2, through: 0, by: -1) {
                reversedCGPath.addLine(to: _points[i])
            }
            reversedCGPath.addLine(to: _points[0])
        }
        
        return reversedCGPath
    }

    func stripCGPathOfExtraMoveTos() -> CGMutablePath? {
        
        if !self.points.isEmpty {
            let newCGPath = CGMutablePath()
            newCGPath.move(to: self.points[0])
            var prevPoint = self.points[0]
            for i in 1..<self.points.count {
                if !self.points[i].equalTo(prevPoint) {
                    newCGPath.addLine(to: self.points[i])
                }
                prevPoint = self.points[i]
            }
            return newCGPath
        }
        else {
            return nil
        }
    }
    
    //  Globals which should be set before calling these functions:
    //
    //  int    polyCorners  =  how many corners the polygon has (no repeats)
    //  float  polyX[]      =  horizontal coordinates of corners
    //  float  polyY[]      =  vertical coordinates of corners
    //  float  x, y         =  point to be tested
    //
    //  The following global arrays should be allocated before calling these functions:
    //
    //  float  constant[] = storage for precalculated constants (same size as polyX)
    //  float  multiple[] = storage for precalculated multipliers (same size as polyX)
    //
    //  (Globals are used in this example for purposes of speed.  Change as
    //  desired.)
    //
    //  USAGE:
    //  Call precalc_values() to initialize the constant[] and multiple[] arrays,
    //  then call pointInPolygon(x, y) to determine if the point is in the polygon.
    //
    //  The function will return YES if the point x,y is inside the polygon, or
    //  NO if it is not.  If the point is exactly on the edge of the polygon,
    //  then the function may return YES or NO.
    //
    //  Note that division by zero is avoided because the division is protected
    //  by the "if" clause which surrounds it.

    func pointBetweenOuterInnerCGPaths(_ innerPath: CGPath) -> CGPoint {
        
        let outerPoints: [CGPoint] = [ self.centre, self.currentPoint ]
        // get constants in Ax + By + c = 0 equation
        //  𝐴=𝑦1−𝑦2, 𝐵=𝑥2−𝑥1 and 𝐶=𝑥1𝑦2−𝑥2𝑦1.
        let a = outerPoints[1].y - outerPoints[0].y
        let b = outerPoints[0].x - outerPoints[1].x
        var c = outerPoints[1].x * outerPoints[0].y - outerPoints[0].x * outerPoints[1].y
        let m: CGFloat = a / b
        c /= b

        // Convert path to an array of points
        let innerPoints = innerPath.points
        var constant: [CGFloat] = Array(repeating: 0, count: innerPoints.count)
        var multiple: [CGFloat] = Array(repeating: 0, count: innerPoints.count)
        
        var j = innerPoints.count - 1
        for i in 0..<innerPoints.count {
    
            if innerPoints[j].y == innerPoints[i].y {
                constant[i] = innerPoints[i].x
                multiple[i] = 0
            }
            else {
                constant[i] = innerPoints[i].x - (innerPoints[i].y * innerPoints[j].x) / (innerPoints[j].y - innerPoints[i].y) + (innerPoints[i].y * innerPoints[i].x) / (innerPoints[j].y - innerPoints[i].y);
                multiple[i] = (innerPoints[j].x - innerPoints[i].x) / (innerPoints[j].y - innerPoints[i].y);
            }
            j = i
        }
      
        let dX = abs(outerPoints[1].x - outerPoints[0].x) / 40.0
        var pt: CGPoint = .zero
        if  outerPoints[0].x < outerPoints[1].x {
            pt.x = outerPoints[1].x - dX
        }
        else {
            pt.x = outerPoints[1].x + dX
        }
        pt.y = -m * pt.x - c
        
        var oddNode = false
    //    BOOL samePaths = CGPathEqualToPath(outerPath, innerPath);
        while ( (outerPoints[0].x < outerPoints[1].x && pt.x >= outerPoints[0].x) || (outerPoints[0].x > outerPoints[1].x && pt.x <= outerPoints[0].x) ) {
    //    while ( (!samePaths && !CGPathContainsPoint(outerPath, NULL, pt, YES) && CGPathContainsPoint(innerPath, NULL, pt, YES)) || (samePaths && !CGPathContainsPoint(outerPath, NULL, pt, YES)) ) {
            j = innerPoints.count - 1;
            for i in 0..<innerPoints.count {
                if  ( innerPoints[i].y < pt.y && innerPoints[j].y > pt.y ) || ( innerPoints[j].y < pt.y && innerPoints[i].y >= pt.y )  {
                    oddNode = oddNode ^^ (pt.y * multiple[i] + constant[i] < pt.x)
                }
                j = i
            }
            if oddNode {
                break
            }
            if outerPoints[0].x < outerPoints[1].x {
                pt.x -= dX
            }
            else {
                pt.x += dX
            }
            pt.y = -m * pt.x - c
        }
        
        return pt
    }
    
    func checkCGPathHasCGPoint(_ point: CGPoint) -> Bool {
        let _points = self.points
        if let _ = _points.firstIndex(where: { $0.equalTo(point) } ) {
            return true
        }
        else {
            return false
        }
    }

    func isEqualToPath(_ otherPath: CGPath) -> Bool {
        let _points = self.points
        let _otherPoints = otherPath.points
        
        return _points.sorted { point0, point1 in
            if point0.x == point1.x {
                return point0.y < point1.y
            }
            else {
                return point0.x < point1.x
            }
        } == _otherPoints.sorted { point0, point1 in
            if point0.x == point1.x {
                return point0.y < point1.y
            }
            else {
                return point0.x < point1.x
            }
        }
    }

}


extension CGContext {

    /// Draw `image` flipped vertically, positioned and scaled inside `rect`.
    public func drawFlipped(_ image: CGImage, in rect: CGRect) {
        self.saveGState()
        self.translateBy(x: 0, y: rect.origin.y + rect.height)
        self.scaleBy(x: 1.0, y: -1.0)
        self.draw(image, in: CGRect(origin: CGPoint(x: rect.origin.x, y: 0), size: rect.size))
        self.restoreGState()
    }
}

infix operator ^^
extension Bool {
    static func ^^(lhs:Bool, rhs:Bool) -> Bool {
        if (lhs && !rhs) || (!lhs && rhs) {
            return true
        }
        return false
    }
}

extension UserDefaults {

    @objc dynamic var backgroundColorValue: Int {
        return integer(forKey: "backgroundColorValue")
    }
    
    @objc dynamic var someRandomOption: Bool {
        return bool(forKey: "someRandomOption")
    }

}
