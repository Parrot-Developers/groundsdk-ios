// Copyright (C) 2019 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import UIKit
import GroundSdk

@IBDesignable class VerticalSlider: UIView {

    @IBInspectable var bgColor: UIColor = UIColor.gray
    @IBInspectable var slideColor: UIColor = UIColor.red
    @IBInspectable var textColor: UIColor = UIColor.black

    @IBInspectable var textVerticalGap: CGFloat = 7
    @IBInspectable var cornerRadius: CGFloat = 10

    @IBInspectable private(set) var maxValue: Double = 0
    @IBInspectable private(set) var minValue: Double = 0
    @IBInspectable private(set) var currentValue: Double = 0

    private let textAttributes: [NSAttributedString.Key: AnyObject] = [
        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 5)
    ]

    private var maskPath: UIBezierPath!

    override func layoutSubviews() {
        maskPath = UIBezierPath(roundedRect: bounds, byRoundingCorners: .allCorners,
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
    }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()

        maskPath.addClip()

        // draw the background
        context!.addRect(rect)
        context!.setFillColor(bgColor.cgColor)
        context!.fillPath()

        let currentValPercent = (currentValue - minValue) / (maxValue - minValue)
        let speedHeight = (rect.height * CGFloat(currentValPercent))
        let topY = rect.height - speedHeight
        let speedRect = CGRect(x: rect.origin.x, y: topY, width: rect.width, height: speedHeight)
        context!.addRect(speedRect)
        context!.setFillColor(slideColor.cgColor)
        context!.fillPath()

        let textRect = CGRect(x: rect.origin.x + 2, y: topY - textVerticalGap, width: rect.width, height: 10)
        let str = NSString(format: "%.2f", currentValue)
        str.draw(in: textRect, withAttributes: textAttributes)
    }

    /// Set the max value of the slider
    ///
    /// - Parameter maxValue: the max value
    func set(maxValue value: Double) {
        if maxValue != value {
            maxValue = value
            setNeedsDisplay()
        }
    }

    /// Set the min value of the slider
    ///
    /// - Parameter minValue: the min value
    func set(minValue value: Double) {
        if minValue != value {
            minValue = value
            setNeedsDisplay()
        }
    }

    /// Set the current value of the slider
    ///
    /// - Parameter currentValue: the current value
    func set(currentValue value: Double) {
        if currentValue != value {
            currentValue = value
            setNeedsDisplay()
        }
    }
}
