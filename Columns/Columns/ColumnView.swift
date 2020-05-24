//
//  ColumnView.swift
//  Columns
//
//  Created by Rob Napier on 5/21/17.
//
//

import UIKit

class ColumnView: UIView {

    let layoutManager = NSLayoutManager()

    let textStorage: NSTextStorage = NSTextStorage(string: "Test")

    @objc var attributedString: NSAttributedString = NSAttributedString() {
        didSet {
//            textStorage.setAttributedString(attributedString)
        }
    }

    let kColumnCount = 3

    func columnRects() -> [CGRect] {
        let box = bounds.insetBy(dx: 20, dy: 20)
        let columnWidth = floor(box.width / CGFloat(kColumnCount))
        let size = CGSize(width: columnWidth, height: box.height)

        return stride(from: box.minX, through: (box.maxX - columnWidth), by: columnWidth)
            .map { leftX in CGRect(origin: CGPoint(x: leftX, y: box.minY), size: size) }
            .map { $0.insetBy(dx: 10, dy: 10) }
    }


    override init(frame: CGRect) {
        super.init(frame: frame)

        textStorage.addLayoutManager(layoutManager)

        let subviews = columnRects().map { rect -> UITextView in
            let container = NSTextContainer(size: rect.size)
            layoutManager.addTextContainer(container)
            return UITextView(frame: rect, textContainer: container)
        }

        for view in subviews {
            self.addSubview(view)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
