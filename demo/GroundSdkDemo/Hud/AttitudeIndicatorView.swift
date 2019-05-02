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

@IBDesignable class AttitudeIndicatorView: UIView {

    // inspectable colors
    @IBInspectable var skyColor: UIColor = UIColor(red: 0.2, green: 0.7, blue: 0.9, alpha: 1)
    @IBInspectable var groundColor: UIColor = UIColor(red: 1, green: 0.53, blue: 0, alpha: 1)
    @IBInspectable var gradColor: UIColor = UIColor.black
    @IBInspectable var horizonColor: UIColor = UIColor.red

    // inspectable dimensions
    @IBInspectable var textMargin: CGFloat = 2
    @IBInspectable var textSize: CGFloat = 10
    @IBInspectable var textVerticalGap: CGFloat = 7
    @IBInspectable var longBankIndexWidth: CGFloat = 10
    @IBInspectable var bankIndexWidth: CGFloat = 5
    @IBInspectable var bankIndexMargin: CGFloat = 2
    @IBInspectable var bankIndexLineThinkness: CGFloat = 1
    @IBInspectable var longPitchIndexHalfWidth: CGFloat = 5
    @IBInspectable var pitchIndexHalfWidth: CGFloat = 2
    @IBInspectable var pitchIndexLineThinkness: CGFloat = 2

    // inspectable step related values
    @IBInspectable var angleStep: Int = 10
    @IBInspectable var angleSubStep: Int = 5 {
        didSet(newVal) {
            pixelPerDegreeRatio = CGFloat(pixelPerAngleSubStep) / CGFloat(angleSubStep)
        }
    }

    @IBInspectable var pixelPerAngleSubStep: Int = 10 {
        didSet(newVal) {
            pixelPerDegreeRatio = CGFloat(pixelPerAngleSubStep) / CGFloat(angleSubStep)
        }
    }

    private var roll: Double = 0
    private var pitch: Double = 0

    private var textAttributesRight: [NSAttributedString.Key: AnyObject]!
    private var textAttributesLeft: [NSAttributedString.Key: AnyObject]!

    private let bankIndexes: [CGFloat] = [
        CGFloat.pi * -45 / 180,
        CGFloat.pi * -20 / 180,
        CGFloat.pi * -10 / 180,
        CGFloat.pi * 0 / 180,
        CGFloat.pi * 10 / 180,
        CGFloat.pi * 20 / 180,
        CGFloat.pi * 45 / 180]
    private let longBankIndexes: [CGFloat] = [
        CGFloat.pi * -90 / 180,
        CGFloat.pi * -60 / 180,
        CGFloat.pi * -30 / 180,
        CGFloat.pi * 0 / 180,
        CGFloat.pi * 30 / 180,
        CGFloat.pi * 60 / 180,
        CGFloat.pi * 90 / 180]

    // dimension vars relative to view bounds
    private var halfHeight: CGFloat = 0
    private var halfWidth: CGFloat = 0
    private var circlePath: UIBezierPath!
    private var bankRad: CGFloat = 0
    private var circleRad: CGFloat = 0
    private var circleX: CGFloat = 0
    private var circleY: CGFloat = 0
    // do not set this var, it is automatically set when changing either pixelPerAngleSubStep or angleSubStep values
    private var pixelPerDegreeRatio: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        initValues()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initValues()
    }

    private func initValues() {
        let fieldFont = UIFont.systemFont(ofSize: textSize)
        let styleRight = NSMutableParagraphStyle()
        styleRight.alignment = .right

        let styleLeft = NSMutableParagraphStyle()
        styleLeft.alignment = .left
        textAttributesRight = [
            NSAttributedString.Key.font: fieldFont,
            NSAttributedString.Key.paragraphStyle: styleRight
        ]
        textAttributesLeft = [
            NSAttributedString.Key.font: fieldFont,
            NSAttributedString.Key.paragraphStyle: styleLeft
        ]

        pixelPerDegreeRatio = CGFloat(pixelPerAngleSubStep) / CGFloat(angleSubStep)
    }

    override func layoutSubviews() {
        halfWidth = bounds.midX
        halfHeight = bounds.midY
        bankRad = halfWidth - longBankIndexWidth
        circleRad = bankRad - bankIndexMargin
        circleX = bounds.origin.x + longBankIndexWidth + bankIndexMargin
        circleY = bounds.origin.y + longBankIndexWidth + bankIndexMargin

        circlePath = UIBezierPath(ovalIn:
                CGRect(x: circleX, y: circleY, width: circleRad * 2, height: circleRad * 2))
    }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        let topDegree = CGFloat(pitch) + (circleRad / pixelPerDegreeRatio)
        let rollInRad = degree2radian(CGFloat(roll))

        drawBankMarkers(context, rect: rect)

        context!.saveGState()
        circlePath.addClip()
        context!.translateBy(x: halfWidth, y: halfHeight)
        context!.rotate(by: degree2radian(CGFloat(roll)))
        context!.translateBy(x: -halfWidth, y: -halfHeight)

        // draw sky and ground
        drawSkyAndGround(context, topDegree: topDegree)

        // draw the steps and sub steps from the top to the bottom
        drawPitchSteps(context, topDegree: topDegree)

        // need restore and save to remove the clipping
        context!.restoreGState()

        context!.saveGState()
        context!.translateBy(x: halfWidth, y: halfHeight)
        context!.rotate(by: rollInRad)
        context!.translateBy(x: -halfWidth, y: -halfHeight)

        // draw roll indicator
        context!.setStrokeColor(horizonColor.cgColor)
        context!.move(to: CGPoint(x: halfWidth, y: circleY - 5))
        context!.addLine(to: CGPoint(x: halfWidth, y: circleY + 5))
        context!.strokePath()

        context!.restoreGState()

        // draw horizon
        context!.setStrokeColor(horizonColor.cgColor)
        context!.move(to: CGPoint(x: halfWidth - 15, y: halfHeight))
        context!.addLine(to: CGPoint(x: halfWidth + 15, y: halfHeight))
        context!.strokePath()
    }

    func degree2radian(_ deg: CGFloat) -> CGFloat {
        return CGFloat.pi * deg / 180
    }

    func drawBankMarkers(_ context: CGContext?, rect: CGRect) {
        context!.setLineWidth(bankIndexLineThinkness)
        context!.setStrokeColor(gradColor.cgColor)

        for angle in bankIndexes {
            drawBankMarker(context, rect: rect, xVal: bankRad, width: bankIndexWidth, angle: angle)
        }

        for angle in longBankIndexes {
            drawBankMarker(context, rect: rect, xVal: bankRad, width: longBankIndexWidth, angle: angle)
        }
    }

    private func drawBankMarker(_ context: CGContext?, rect: CGRect, xVal: CGFloat, width: CGFloat, angle: CGFloat) {
        context!.saveGState()
        context!.translateBy(x: halfWidth, y: halfHeight)
        context!.rotate(by: angle - CGFloat(Double.pi / 2))

        // draw
        context!.move(to: CGPoint(x: xVal, y: 0))
        context!.addLine(to: CGPoint(x: xVal + width, y: 0))
        context!.strokePath()

        context!.restoreGState()
    }

    private func drawSkyAndGround(_ context: CGContext?, topDegree: CGFloat) {
        let horizonHeight = topDegree * pixelPerDegreeRatio

        context!.setFillColor(skyColor.cgColor)
        context!.addRect(CGRect(x: circleX, y: circleY, width: circleRad * 2, height: horizonHeight))
        context!.fillPath()

        context!.setFillColor(groundColor.cgColor)
        context!.addRect(CGRect(x: circleX, y: circleY + horizonHeight, width: circleRad * 2,
            height: circleRad * 2 - horizonHeight))
        context!.fillPath()

        context!.setStrokeColor(gradColor.cgColor)
        context!.addArc(center: CGPoint(x: halfWidth, y: halfHeight),
                        radius: circleRad, startAngle: CGFloat(-Double.pi), endAngle: CGFloat(-Double.pi),
                        clockwise: true)

        context!.strokePath()
    }

    private func drawPitchSteps(_ context: CGContext?, topDegree: CGFloat) {
        let firstDegreeToDisplay = topDegree - (topDegree.truncatingRemainder(dividingBy: CGFloat(angleSubStep)))
        let yOfFirstDegreeToDisplay = (topDegree - firstDegreeToDisplay) * pixelPerDegreeRatio + circleY

        var currentDegree = Int(firstDegreeToDisplay)
        var y = yOfFirstDegreeToDisplay
        while y < circleY + (2 * circleRad) + CGFloat(pixelPerDegreeRatio) {
            if currentDegree == 0 {
                context!.move(to: CGPoint(x: circleX, y: y))
                context!.addLine(to: CGPoint(x: circleX + circleRad * 2, y: y))
                context!.strokePath()
            } else if currentDegree % angleStep == 0 {
                context!.move(to: CGPoint(x: halfWidth - longPitchIndexHalfWidth, y: y))
                context!.addLine(to: CGPoint(x: halfWidth + longPitchIndexHalfWidth, y: y))
                context!.strokePath()

                let str = String(format: "%d", currentDegree)
                let rectLeft = CGRect(x: halfWidth + longPitchIndexHalfWidth + textMargin,
                    y: y - textVerticalGap, width: 20,
                    height: 20)
                let rectRight = CGRect(x: halfWidth - longPitchIndexHalfWidth - 20 - textMargin,
                    y: y - textVerticalGap, width: 20,
                    height: 20)
                str.draw(in: rectLeft, withAttributes: textAttributesLeft)
                str.draw(in: rectRight, withAttributes: textAttributesRight)

            } else {
                context!.move(to: CGPoint(x: halfWidth - pitchIndexHalfWidth, y: y))
                context!.addLine(to: CGPoint(x: halfWidth + pitchIndexHalfWidth, y: y))
                context!.strokePath()
            }
            y += CGFloat(pixelPerAngleSubStep)
            currentDegree -= angleSubStep
        }
    }

    /// Set the roll angle
    ///
    /// - Parameter roll: the roll
    func set(roll value: Double) {
        if roll != value {
            roll = value
            setNeedsDisplay()
        }
    }

    /// Set the pitch angle
    ///
    /// - Parameter pitch: the pitch
    func set(pitch value: Double) {
        if pitch != value {
            pitch = value
            setNeedsDisplay()
        }
    }
}
