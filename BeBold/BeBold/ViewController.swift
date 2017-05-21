//
//  ViewController.swift
//  BeBold
//
//  Created by Rob Napier on 5/21/17.
//  Copyright © 2017 Rob Napier. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var textView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let string = "Be Bold! And a little color wouldn’t hurt either."
        let attrs = [NSFontAttributeName: UIFont.systemFont(ofSize: 36)]
        let attrib = NSMutableAttributedString(string: string, attributes: attrs)

        let s = attrib.string as NSString

        attrib.addAttribute(NSFontAttributeName,
                            value: UIFont.boldSystemFont(ofSize: 36),
                            range: s.range(of: "Bold!"))

        attrib.addAttribute(NSForegroundColorAttributeName,
                            value: UIColor.blue,
                            range: s.range(of: "little color"))

        attrib.addAttribute(NSFontAttributeName,
                            value: UIFont.systemFont(ofSize: 18),
                            range: s.range(of: "little"))

        label.attributedText = attrib

        //=====

        let paragraphs = """
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi ac urna id augue volutpat tempus at vitae libero. Donec venenatis faucibus erat, et feugiat nunc dignissim sed. Curabitur egestas quam ut ante tincidunt dignissim. Nunc non nulla eros. Donec elementum auctor augue, dapibus blandit augue sollicitudin in. Proin dictum, neque sit amet venenatis facilisis, orci ligula vestibulum dolor, non pulvinar ipsum magna quis leo. Mauris id magna dui. In vehicula gravida mattis. Aliquam semper purus quis enim feugiat sit amet dapibus nunc ultrices. Nam nec lacus et quam molestie viverra sed sit amet orci. Fusce laoreet pulvinar libero, eget commodo urna scelerisque vel. Aenean eget lectus in quam scelerisque blandit vel in ligula. Etiam ac urna sagittis risus lobortis viverra varius ac enim. Maecenas hendrerit, tellus quis tristique dignissim, nibh libero pretium dolor, non pellentesque est nibh at erat.
Integer eget enim at erat rhoncus volutpat a sit amet ligula. Suspendisse potenti. Curabitur faucibus vulputate nibh vel condimentum. Mauris tortor arcu, tincidunt sit amet auctor nec, consectetur vel ipsum. Proin vitae magna risus, non aliquam tortor. Nunc ut purus eu diam semper laoreet. Sed accumsan ante id elit imperdiet a vehicula nunc dapibus. Nam risus augue, tempor ut dictum at, euismod sit amet ipsum. Integer et facilisis ipsum. In nulla felis, feugiat in ultrices bibendum, fringilla quis est. Curabitur eleifend rhoncus turpis sed luctus. Donec sed nisi orci. Nam rutrum volutpat nibh, in blandit lectus ultricies eget.
Suspendisse potenti. Ut eu mi elit, eu tincidunt mauris. Nullam ut egestas ante. Proin suscipit convallis nisi sed convallis. Nullam convallis posuere venenatis. Curabitur in mauris nulla, in tempus est. Etiam augue metus, viverra eget cursus interdum, malesuada eu nisl. Nunc vel nibh sit amet purus blandit malesuada. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse ipsum arcu, facilisis vitae fringilla vitae, luctus non dui. Donec sit amet mauris non urna auctor tincidunt sit amet at massa. Vestibulum tempus viverra sem, quis tempor ante feugiat quis. Etiam ac ultrices diam. Duis laoreet nulla quis nibh condimentum tempus. Nullam rutrum vehicula neque, vitae tincidunt ante aliquam vel. Maecenas vel dapibus augue.
"""

        let wholeDocStyle = NSMutableParagraphStyle()
        wholeDocStyle.paragraphSpacing = 34
        wholeDocStyle.firstLineHeadIndent = 10
        wholeDocStyle.alignment = .justified

        let pas = NSMutableAttributedString(string: paragraphs, attributes: [NSParagraphStyleAttributeName: wholeDocStyle])

        let nsParagraphs = paragraphs as NSString

        let secondParagraphStart = NSMaxRange(nsParagraphs.range(of: "\n"))

        let secondParagraphStyle = (pas.attribute(NSParagraphStyleAttributeName, at: secondParagraphStart, effectiveRange: nil)! as! NSParagraphStyle).mutableCopy() as! NSMutableParagraphStyle

        secondParagraphStyle.headIndent += 50
        secondParagraphStyle.firstLineHeadIndent += 50
        secondParagraphStyle.tailIndent -= 50

        pas.addAttribute(NSParagraphStyleAttributeName, value: secondParagraphStyle, range: NSMakeRange(secondParagraphStart, 1))

        textView.attributedText = pas
    }
    
    @IBAction func applyBold(_ sender: Any) {
        let attrib = label.attributedText?.mutableCopy() as! NSMutableAttributedString

        attrib.enumerateAttribute(NSFontAttributeName, in: NSMakeRange(0, attrib.length), options: .longestEffectiveRangeNotRequired) { (value, range, stop) in
            let font = value as! UIFont
            if let boldFont = font.bolded() {
                attrib.addAttribute(NSFontAttributeName, value: boldFont, range: range)
            }
        }

        label.attributedText = attrib
    }
}

// Returns the bold version of a font. May return nil if there is no bold version.
extension UIFont {
    func bolded() -> UIFont? {
        let ctFont = CTFontCreateWithName(fontName as CFString, pointSize, nil)

        // You can't add bold to a bold font
        // (don't really need this, since the ctBoldFont check would handle it)
        guard !CTFontGetSymbolicTraits(ctFont).contains(.boldTrait),
            let ctBoldFont = CTFontCreateCopyWithSymbolicTraits(ctFont,
                                                                pointSize,
                                                                nil,
                                                                .boldTrait,
                                                                .boldTrait)
            else { return nil }

        let boldFontName = CTFontCopyPostScriptName(ctBoldFont) as String
        return UIFont(name: boldFontName, size: pointSize)
    }
}
