//
//  TGLabel.swift
//  TGLabelDemo
//
//  Created by targetcloud on 2017/3/3.
//  Copyright © 2017年 targetcloud. All rights reserved.
// 0.0.6

import UIKit

@objc
public protocol TGLabelDelegate: NSObjectProtocol {
    @objc optional func labelDidSelectedLinkText(label: TGLabel, text: String)
}

public class TGLabel: UILabel {
    
    public var linkTextColor = UIColor.blue
    public var selectedBackgroudColor = UIColor.lightGray
    public weak var delegate: TGLabelDelegate?
    private lazy var linkRanges = [NSRange]()
    private var selectedRange: NSRange?
    private lazy var textStorage = NSTextStorage()
    private lazy var layoutManager = NSLayoutManager()
    private lazy var textContainer = NSTextContainer()
    private let patterns = ["[a-zA-Z]*://[a-zA-Z0-9/\\.]*", "#.*?#", "@[\\u4e00-\\u9fa5a-zA-Z0-9_-]*"]
    
    override public var text: String? {
        didSet {
            updateTextStorage()
        }
    } 
    
    override public var attributedText: NSAttributedString? {
        didSet {
            updateTextStorage()
        }
    }
    
    override public var font: UIFont! {
        didSet {
            updateTextStorage()
        }
    }
    
    override public var textColor: UIColor! {
        didSet {
            updateTextStorage()
        }
    }
    
    private func updateTextStorage() {
        if attributedText == nil {
            attributedText = NSAttributedString(string: text ?? "")
        }
        let attrStringM = addLineBreak(attributedText!)
        regexLinkRanges(attrStringM)
        addLinkAttribute(attrStringM)
        textStorage.setAttributedString(attrStringM)
        setNeedsDisplay()
    }
    
    private func addLinkAttribute(_ attrStringM: NSMutableAttributedString) {
        if attrStringM.length == 0 {
            return
        }
        var range = NSRange(location: 0, length: 0)
        var attributes = attrStringM.attributes(at: 0, effectiveRange: &range)
        attributes[NSFontAttributeName] = font
        attributes[NSForegroundColorAttributeName] = textColor
        attrStringM.addAttributes(attributes, range: range)
        attributes[NSForegroundColorAttributeName] = linkTextColor
        for r in linkRanges {
            attrStringM.setAttributes(attributes, range: r)
        }
    }
    
    private func regexLinkRanges(_ attrString: NSAttributedString) {
        linkRanges.removeAll()
        let regexRange = NSRange(location: 0, length: attrString.string.characters.count)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.dotMatchesLineSeparators) else{
                continue
            }
            let results = regex.matches(in: attrString.string, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: regexRange)
            for r in results {
                linkRanges.append(r.rangeAt(0))
            }
        }
    }
    
    private func addLineBreak(_ attrString: NSAttributedString) -> NSMutableAttributedString {
        let attrStringM = NSMutableAttributedString(attributedString: attrString)
        if attrStringM.length == 0 {
            return attrStringM
        }
        var range = NSRange(location: 0, length: 0)
        var attributes = attrStringM.attributes(at: 0, effectiveRange: &range)
        guard let paragraphStyle = attributes[NSParagraphStyleAttributeName] as? NSMutableParagraphStyle else{
            let paragraphStyleM = NSMutableParagraphStyle()
            paragraphStyleM.lineBreakMode = NSLineBreakMode.byWordWrapping
            attributes[NSParagraphStyleAttributeName] = paragraphStyleM
            attrStringM.setAttributes(attributes, range: range)
            return attrStringM
        }
        paragraphStyle.lineBreakMode = NSLineBreakMode.byWordWrapping
        return attrStringM
    }
    
    public override func drawText(in rect: CGRect) {
        let range = glyphsRange()
        let offset = glyphsOffset(range)
        layoutManager.drawBackground(forGlyphRange: range, at: offset)
        layoutManager.drawGlyphs(forGlyphRange: range, at: CGPoint.zero)
    }
    
    private func glyphsRange() -> NSRange {
        return NSRange(location: 0, length: textStorage.length)
    }
    
    private func glyphsOffset(_ range: NSRange) -> CGPoint {
        let rect = layoutManager.boundingRect(forGlyphRange: range, in: textContainer)
        let height = (bounds.height - rect.height) * 0.5
        return CGPoint(x: 0, y: height)
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else {
            return
        }
        selectedRange = linkRangeAtLocation(location)
        modifySelectedAttribute(true)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else {
            return
        }
        if let range = linkRangeAtLocation(location) {
            if !(range.location == selectedRange?.location && range.length == selectedRange?.length) {
                modifySelectedAttribute(false)
                selectedRange = range
                modifySelectedAttribute(true)
            }
        } else {
            modifySelectedAttribute(false)
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if selectedRange != nil {
            let text = (textStorage.string as NSString).substring(with: selectedRange!)
            delegate?.labelDidSelectedLinkText?(label: self, text: text)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.25) {
                self.modifySelectedAttribute(false)
            }
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        modifySelectedAttribute(false)
    }
    
    private func modifySelectedAttribute(_ isSet: Bool) {
        if selectedRange == nil {
            return
        }
        var attributes = textStorage.attributes(at: 0, effectiveRange: nil)
        attributes[NSForegroundColorAttributeName] = linkTextColor
        attributes[NSBackgroundColorAttributeName] = isSet ?  selectedBackgroudColor : UIColor.clear
        textStorage.addAttributes(attributes, range: selectedRange!)
        selectedRange = !isSet ? nil : selectedRange
        setNeedsDisplay()
    }
    
    private func linkRangeAtLocation(_ location: CGPoint) -> NSRange? {
        if textStorage.length > 0 {
            let offset = glyphsOffset(glyphsRange())
            let point = CGPoint(x: offset.x + location.x, y: offset.y + location.y)
            let index = layoutManager.glyphIndex(for: point, in: textContainer)
            for r in linkRanges {
                if  NSLocationInRange(index, r) { //index >= r.location && index <= r.location + r.length
                    return r
                }
            }
        }
        return nil
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        prepareLabel()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepareLabel()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        textContainer.size = bounds.size
    }
    
    private func prepareLabel() {
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        textContainer.lineFragmentPadding = 0
        isUserInteractionEnabled = true
    }
    
}

