//
//  SpinnerView.swift
//  ElevationPlot
//
//  Created by Steve Wainwright on 17/07/2022.
//

import Cocoa

class SpinnerView: NSView {
    
    var indicator =  NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
    var label: NSTextField?
    private var labelMessage: String?
    private var labelFont = NSFont(name: "Helvetica", size: 14)!
    
    var message: String {
        get { return labelMessage ?? "" }
        set {
            labelMessage = newValue
            if let _labelMessage = labelMessage {
                let height = _labelMessage.height(constraintedWidth: self.frame.width - 48, font: labelFont)
                initialiseLabel(width: self.frame.width - 48, height: height, labelMessage: _labelMessage)
            }
        }
    }
    
    var font: NSFont {
        get { return labelFont  }
        set {
            labelFont = newValue
            if let _labelMessage = labelMessage {
                let height = _labelMessage.height(constraintedWidth: self.frame.width - 48, font: labelFont)
                initialiseLabel(width: self.frame.width - 48, height: height, labelMessage: _labelMessage)
            }
        }
    }
    
    private func initialiseLabel(width: CGFloat, height: CGFloat, labelMessage: String) {
        //let height = labelMessage.height(constraintedWidth: width, font: labelFont)
        if label == nil {
            self.label = NSTextField(frame: CGRect(x: 0, y: 0, width: width, height: height))
        }
        if let _label = label {
            _label.translatesAutoresizingMaskIntoConstraints = false
            if !self.subviews.contains(_label) {
                self.addSubview(_label)
                self.addConstraints([NSLayoutConstraint(item: _label, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0), NSLayoutConstraint(item: _label, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 40), NSLayoutConstraint(item: _label, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: width), NSLayoutConstraint(item: _label, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: height)])
                
                _label.stringValue = labelMessage
                _label.backgroundColor = .clear
                _label.isBezeled = false
                _label.isEditable = false
                _label.font = self.labelFont
                _label.alignment = .center
                _label.maximumNumberOfLines = 0
                _label.sizeToFit()
            }
        }
    }
    
    convenience init() {
        self.init(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        
        initCommon()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        initCommon()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        initCommon()
    }
    
    func initCommon() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor(white: 0, alpha: 0.2).cgColor
        self.layer?.cornerRadius = 10
        
        self.indicator.style = .spinning
        self.indicator.controlTint = .graphiteControlTint
        self.indicator.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.indicator)
        
        self.addConstraints([
                NSLayoutConstraint(item: self.indicator, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: self.indicator, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: -30.0),
                NSLayoutConstraint(item: self.indicator, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0.0, constant:  self.indicator.bounds.size.width),
                NSLayoutConstraint(item: self.indicator, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0.0, constant:  self.indicator.bounds.size.height)])
    }
    
    override var isHidden: Bool {
            get {
                super.isHidden
            }
            set {
                super.isHidden = newValue
                if newValue {
                    self.indicator.stopAnimation(self)
                }
                else {
                    self.indicator.startAnimation(self)
                }
            }
        }
    
}

extension String {
    func height(constraintedWidth width: CGFloat, font: NSFont) -> CGFloat {
        let label = NSTextField(frame: .zero)
        label.maximumNumberOfLines = 0 // multiline
        label.font = font // your font
        label.lineBreakMode = .byWordWrapping
        label.isBezeled = false
        label.isEditable = false
        label.alignment = .center
        label.preferredMaxLayoutWidth = width // max width
        label.stringValue = self // the text to display in the label
        return label.intrinsicContentSize.height
    }
    
    func getLabelHeight(constraintedWidth width: CGFloat, font: NSFont) -> CGFloat {
        let textAttributes = [NSAttributedString.Key.font: font]

        let rect = self.boundingRect(with: CGSize(width: width, height: 2000), options: .usesLineFragmentOrigin, attributes: textAttributes, context: nil)
        return rect.size.height
    }
}

