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

@IBDesignable class AltimeterView: UIView {

    // inspectable colors
    @IBInspectable var skyColor: UIColor = UIColor(red: 0.2, green: 0.7, blue: 0.9, alpha: 1)
    @IBInspectable var groundColor: UIColor = UIColor(red: 1, green: 0.53, blue: 0, alpha: 1)
    @IBInspectable var gradColor: UIColor = UIColor.black
    @IBInspectable var horizonColor: UIColor = UIColor.red

    // inspectable dimensions
    @IBInspectable var textMarginRight: CGFloat = 2
    @IBInspectable var textHeight: CGFloat = 10
    @IBInspectable var cornerRadius: CGFloat = 10
    @IBInspectable var subStepHalfWidth: CGFloat = 1
    @IBInspectable var stepHalfWidth: CGFloat = 10
    @IBInspectable var horizonHalfWidth: CGFloat = 30
    @IBInspectable var lineWidth: CGFloat = 2
    @IBInspectable var textVerticalGap: CGFloat = 7

    // inspectable step related values
    @IBInspectable var altitudeStepInCm: Int = 1000
    @IBInspectable var subAltitudeStepInCm: Int = 200
    @IBInspectable var pixelPerSubAltitudeStep: Int = 6

    private var takeOffRelativeAltitudeInCm = 0
    private var groundRelativeAltitudeInCm = 0

    private var textAttributes: [NSAttributedString.Key: AnyObject]!
    var pixelPerCmRatio: CGFloat {
        return CGFloat(pixelPerSubAltitudeStep) / CGFloat(subAltitudeStepInCm)
    }

    // dimension vars relative to view bounds
    private var halfHeight: CGFloat = 0
    private var halfWidth: CGFloat = 0
    private var maskPath: UIBezierPath!

    override init(frame: CGRect) {
        super.init(frame: frame)
        initValues()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initValues()
    }

    private func initValues() {
        let fieldFont = UIFont.systemFont(ofSize: 10)
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        textAttributes = [
            NSAttributedString.Key.font: fieldFont,
            NSAttributedString.Key.paragraphStyle: style
        ]
    }

    override func layoutSubviews() {
        halfHeight = bounds.height / 2
        halfWidth = bounds.width / 2

        maskPath = UIBezierPath(roundedRect: bounds, byRoundingCorners: .allCorners,
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
    }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context!.setLineWidth(lineWidth)

        drawBackground(context, rect: rect)

        context!.setStrokeColor(gradColor.cgColor)

        // calculate the top altitudes
        let topAltitude = CGFloat(takeOffRelativeAltitudeInCm) + (halfHeight / pixelPerCmRatio)
        let firstAltitudeToDisplay = topAltitude -
            (topAltitude.truncatingRemainder(dividingBy: CGFloat(subAltitudeStepInCm)))
        let yOfFirstAltitudeToDisplay = (topAltitude - firstAltitudeToDisplay) * pixelPerCmRatio

        // draw the steps and sub steps from the middle to the bottom
        var currentAltitude = Int(firstAltitudeToDisplay)
        var y = yOfFirstAltitudeToDisplay
        while y < rect.height + CGFloat(pixelPerSubAltitudeStep) {
            if currentAltitude % altitudeStepInCm == 0 {
                drawStep(context, yPos: y)
                context!.strokePath()
                drawText(context, text: "\(currentAltitude / 100)" as NSString, yPos: y)
            } else if currentAltitude != Int(takeOffRelativeAltitudeInCm) {
                drawSubStep(context, yPos: y)
                context!.strokePath()
            }
            y += CGFloat(pixelPerSubAltitudeStep)
            currentAltitude -= subAltitudeStepInCm
        }

        // draw the middle line
        context!.setStrokeColor(horizonColor.cgColor)
        drawHorizon(context)
        context!.strokePath()
    }

    /// Draw the borders of the view and the delimitation between sky and ground
    ///
    /// - Parameters:
    ///   - context: the context to draw in
    ///   - rect: the rect to draw in
    private func drawBackground(_ context: CGContext?, rect: CGRect) {
        var groundY = halfHeight - (CGFloat(-groundRelativeAltitudeInCm) *
                (CGFloat(pixelPerSubAltitudeStep) / CGFloat(subAltitudeStepInCm)))
        groundY = max(0, min(rect.size.height, groundY))

        maskPath.addClip()
        maskPath.stroke()

        context!.addRect(CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: groundY))
        context!.setFillColor(skyColor.cgColor)
        context!.fillPath()

        context!.addRect(CGRect(x: rect.origin.x, y: groundY,
            width: rect.size.width, height: rect.size.height - groundY))
        context!.setFillColor(groundColor.cgColor)
        context!.fillPath()
    }

    private func drawText(_ context: CGContext?, text: NSString, yPos: CGFloat) {
        let rect = CGRect(x: halfWidth, y: yPos - textVerticalGap, width: halfWidth - textMarginRight,
            height: textHeight)
        text.draw(in: rect, withAttributes: textAttributes)
    }

    private func drawHorizon(_ context: CGContext?) {
        drawLine(context, yPos: halfHeight, lineHalfWidth: horizonHalfWidth)
    }

    private func drawStep(_ context: CGContext?, yPos: CGFloat) {
        drawLine(context, yPos: yPos, lineHalfWidth: stepHalfWidth)
    }

    private func drawSubStep(_ context: CGContext?, yPos: CGFloat) {
        drawLine(context, yPos: yPos, lineHalfWidth: subStepHalfWidth)
    }

    private func drawLine(_ context: CGContext?, yPos: CGFloat, lineHalfWidth: CGFloat) {
        context!.move(to: CGPoint(x: halfWidth - lineHalfWidth, y: yPos))
        context!.addLine(to: CGPoint(x: halfWidth + lineHalfWidth, y: yPos))
    }

    /// Set the take off altitude in meters
    ///
    /// - Parameter takeOffAltitude: the take off altitude
    func set(takeOffAltitude value: Double) {
        let valueInCm = Int(value * 100)
        if takeOffRelativeAltitudeInCm != valueInCm {
            takeOffRelativeAltitudeInCm = valueInCm
            setNeedsDisplay()
        }
    }

    /// Set the ground altitude in meters
    ///
    /// - Parameter groundAltitude: the ground altitude
    func set(groundAltitude value: Double) {
        let valueInCm = Int(value * 100)
        if groundRelativeAltitudeInCm != valueInCm {
            groundRelativeAltitudeInCm = valueInCm
            setNeedsDisplay()
        }
    }
}
