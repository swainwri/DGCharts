//
//  SpinnerView.swift
//  ElevationPlot
//
//  Created by Steve Wainwright on 17/07/2022.
//

import UIKit

class SpinnerView: UIView {
    
    var indicator = UIActivityIndicatorView(style: .large)
    var titleLabel: UILabel?
    var subTitleLabel: UILabel?
    private var titleMessage: String?
    private var titleLabelFont = UIFont(name: "Helvetica", size: 14)!
    
    var message: String {
        get { return titleMessage ?? "" }
        set {
            titleMessage = newValue
            if let _titleMessage = titleMessage {
                let height = _titleMessage.height(constraintedWidth: self.frame.width - 48, font: titleLabelFont)
                initialiseLabel(width: self.frame.width - 48, height: height, titleMessage: _titleMessage)
            }
        }
    }
    
    var font: UIFont {
        get { return titleLabelFont  }
        set {
            titleLabelFont = newValue
            if let _titleMessage = titleMessage {
                let height = _titleMessage.height(constraintedWidth: self.frame.width - 48, font: titleLabelFont)
                initialiseLabel(width: self.frame.width - 48, height: height, titleMessage: _titleMessage)
            }
        }
    }
    
    private func initialiseLabel(width: CGFloat, height: CGFloat, titleMessage: String) {
        //let height = titleMessage.height(constraintedWidth: width, font: titleLabelFont)
        if titleLabel == nil {
            titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: height))
        }
        if let _label = titleLabel {
            _label.translatesAutoresizingMaskIntoConstraints = false
            if !self.subviews.contains(_label) {
                self.addSubview(_label)
                self.addConstraints([NSLayoutConstraint(item: _label, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0), NSLayoutConstraint(item: _label, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 40), NSLayoutConstraint(item: _label, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: width), NSLayoutConstraint(item: _label, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: height)])
                
                _label.numberOfLines = 0
                _label.text = titleMessage
                _label.font = self.titleLabelFont
                _label.textAlignment = .center
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
        self.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.layer.cornerRadius = 20.0
        self.addSubview(self.indicator)
        self.indicator.translatesAutoresizingMaskIntoConstraints = false
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
                    self.indicator.stopAnimating()
                }
                else {
                    self.indicator.startAnimating()
                }
            }
        }
    
    /// Tap handler
    ///
    /// - Parameters:
    ///   - tap: The tap handler closure
    ///   - subtitleText: The optional subtitle
    func addTapHandler(_ tap: @escaping (() -> Void), subtitle subtitleText: String? = nil) {
        clearTapHandler()

        tapHandler = tap

        if let _subtitleText = subtitleText {
            self.subTitleLabel = UILabel()
            if let subtitle = self.subTitleLabel {
                subtitle.text = _subtitleText
                subtitle.font = UIFont(name:  self.titleLabelFont.familyName, size: titleLabelFont.pointSize * 0.8)
                subtitle.textColor = UIColor.white
                subtitle.numberOfLines = 0
                subtitle.textAlignment = .center
                subtitle.lineBreakMode = .byWordWrapping
                self.addSubview(subtitle)
                
                subtitle.translatesAutoresizingMaskIntoConstraints = false
                self.addConstraints([NSLayoutConstraint(item: subtitle, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0), NSLayoutConstraint(item: subtitle, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 80), NSLayoutConstraint(item: subtitle, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: subtitle.bounds.size.width), NSLayoutConstraint(item: subtitle, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: subtitle.bounds.size.height)])
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        if tapHandler != nil {
            tapHandler?()
            tapHandler = nil
        }
    }

    /// Remove the tap handler
    func clearTapHandler() {
        isUserInteractionEnabled = false
        self.subTitleLabel?.removeFromSuperview()
        tapHandler = nil
    }

    // MARK: - Tap handler
    private var tapHandler: (() -> Void)?
    func didTapSpinner() {
        tapHandler?()
    }
    
}

extension String {
    func height(constraintedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let label = UILabel(frame: .zero)
        label.numberOfLines = 0 // multiline
        label.font = font // your font
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = width // max width
        label.text = self // the text to display in the label
        return label.intrinsicContentSize.height
    }
    
    func getLabelHeight(constraintedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let textAttributes = [NSAttributedString.Key.font: font]

        let rect = self.boundingRect(with: CGSize(width: width, height: 2000), options: .usesLineFragmentOrigin, attributes: textAttributes, context: nil)
        return rect.size.height
    }
}

