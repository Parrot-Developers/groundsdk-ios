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

protocol ThermalPaletteAddColorDelegate: class {
    func addColor(thermalColor: ThermalColor)
    func removeColor(thermalColor: ThermalColor)
}

/// A view controller to add / edit / remove a color from the palette
class ThermalPaletteAddColorVC: UIViewController {

    @IBOutlet weak var redLabel: UILabel!
    @IBOutlet weak var redSlider: UISlider!
    @IBOutlet weak var greenLabel: UILabel!
    @IBOutlet weak var greenSlider: UISlider!
    @IBOutlet weak var blueLabel: UILabel!
    @IBOutlet weak var blueSlider: UISlider!
    @IBOutlet weak var positionLabel: UILabel!
    @IBOutlet weak var positionSlider: UISlider!
    @IBOutlet weak var addColor: UIButton!
    @IBOutlet weak var saveColor: UIButton!
    @IBOutlet weak var resetColor: UIButton!
    @IBOutlet weak var deleteColor: UIButton!
    @IBOutlet weak var colorView: UIView!

    weak var delegate: ThermalPaletteAddColorDelegate?
    var thermalColor: ThermalColor?

    func setColor(_ thermalColor: ThermalColor) {
        self.thermalColor = thermalColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        redSlider.minimumValue = 0.0
        redSlider.maximumValue = 1.0

        greenSlider.minimumValue = 0.0
        greenSlider.maximumValue = 1.0

        blueSlider.minimumValue = 0.0
        blueSlider.maximumValue = 1.0

        positionSlider.minimumValue = 0.0
        positionSlider.maximumValue = 1.0

        resetColor.isHidden = true
        if thermalColor != nil {
            redSlider.value = Float(thermalColor!.red)
            redLabel.text = String(thermalColor!.red)
            greenSlider.value = Float(thermalColor!.green)
            greenLabel.text = String(thermalColor!.green)
            blueSlider.value = Float(thermalColor!.blue)
            blueLabel.text = String(thermalColor!.blue)
            positionSlider.value = Float(thermalColor!.position)
            positionLabel.text = String(thermalColor!.position)
            addColor.isHidden = true
        } else {
            saveColor.isHidden = true
            deleteColor.isHidden = true
            redSlider.value = 0.0
            greenSlider.value = 0.0
            blueSlider.value = 0.0
            positionSlider.value = 0.0
        }
        colorView.backgroundColor = UIColor(red: CGFloat(redSlider.value), green: CGFloat(greenSlider.value),
                                            blue: CGFloat(blueSlider.value), alpha: 1.0)
        addColor.layer.cornerRadius = 0.5 * addColor.bounds.size.height
        addColor.clipsToBounds = true
        addColor.layer.borderWidth = 1
        addColor.layer.borderColor = addColor.tintColor.cgColor

        saveColor.layer.cornerRadius = 0.5 * saveColor.bounds.size.height
        saveColor.clipsToBounds = true
        saveColor.layer.borderWidth = 1
        saveColor.layer.borderColor = saveColor.tintColor.cgColor

        resetColor.layer.cornerRadius = 0.5 * saveColor.bounds.size.height
        resetColor.clipsToBounds = true
        resetColor.layer.borderWidth = 1
        resetColor.layer.borderColor = saveColor.tintColor.cgColor

        deleteColor.layer.cornerRadius = 0.5 * deleteColor.bounds.size.height
        deleteColor.clipsToBounds = true
        deleteColor.layer.borderWidth = 1
        deleteColor.layer.borderColor = UIColor.red.cgColor
        deleteColor.tintColor = UIColor.red
    }

    @IBAction func sliderDidChange(_ sender: UISlider) {
        switch sender {
        case redSlider:
            redLabel.text = String(sender.value)
        case blueSlider:
            blueLabel.text = String(sender.value)
        case greenSlider:
            greenLabel.text = String(sender.value)
        case positionSlider:
            positionLabel.text = String(sender.value)
        default:
            break
        }
        colorView.backgroundColor = UIColor(red: CGFloat(redSlider.value), green: CGFloat(greenSlider.value),
                                            blue: CGFloat(blueSlider.value), alpha: 1.0)
        updateButton()

    }

    func updateButton() {
        if thermalColor != nil {
            if Float(thermalColor!.position) == positionSlider.value {
                saveColor.isHidden = false
                deleteColor.isHidden = false
                addColor.isHidden = true
                if Float(thermalColor!.red) != redSlider.value || Float(thermalColor!.blue) != blueSlider.value
                    || Float(thermalColor!.green) != greenSlider.value {
                    resetColor.isHidden = false
                } else {
                    resetColor.isHidden = true
                }
            } else {
                resetColor.isHidden = false
                saveColor.isHidden = true
                deleteColor.isHidden = true
                addColor.isHidden = false
            }
        }
    }

    @IBAction func touchUpInside(_ sender: UIButton) {
        if sender == addColor || sender == saveColor {
            delegate?.addColor(thermalColor: ThermalColor(Double(redSlider.value), Double(greenSlider.value),
                                                          Double(blueSlider.value), Double(positionSlider.value)))
            _ = navigationController?.popViewController(animated: true)
        } else if sender == deleteColor {
            delegate?.removeColor(thermalColor: thermalColor!)
            _ = navigationController?.popViewController(animated: true)
        } else if sender == resetColor {
            colorView.backgroundColor = UIColor(red: CGFloat(thermalColor!.red), green: CGFloat(thermalColor!.green),
                                                blue: CGFloat(thermalColor!.blue), alpha: 1.0)
            redSlider.value = Float(thermalColor!.red)
            redLabel.text = String(thermalColor!.red)
            greenSlider.value = Float(thermalColor!.green)
            greenLabel.text = String(thermalColor!.green)
            blueSlider.value = Float(thermalColor!.blue)
            blueLabel.text = String(thermalColor!.blue)
            positionSlider.value = Float(thermalColor!.position)
            positionLabel.text = String(thermalColor!.position)
            updateButton()
        }
    }
}
