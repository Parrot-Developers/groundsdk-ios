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

@IBDesignable class NumSettingView: UIControl {

    @IBInspectable var label: String? {
        get {
            return labelView.text!
        }
        set {
            labelView.text = newValue
        }
    }

    var value: Float {
        return sliderView.value
    }

    @IBOutlet weak var labelView: UILabel!
    @IBOutlet weak var textView: UILabel!
    @IBOutlet weak var sliderView: UISlider!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        xibSetup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        xibSetup()
    }

    func updateWith(doubleSetting setting: DoubleSetting?) {
        if let setting = setting {
            sliderView.isEnabled = true
            sliderView.minimumValue = Float(setting.min)
            sliderView.maximumValue = Float(setting.max)
            sliderView.setValue(Float(setting.value), animated: true)
            if setting.updating {
                textView.text = "Updating..."
            } else {
                textView.text = setting.displayString
            }
        } else {
            sliderView.isEnabled = false
            textView.text = "Not Supported"
        }
    }

    func updateWith(intSetting setting: IntSetting?) {
        if let setting = setting {
            sliderView.isEnabled = true
            sliderView.minimumValue = Float(setting.min)
            sliderView.maximumValue = Float(setting.max)
            sliderView.setValue(Float(setting.value), animated: true)
            if setting.updating {
                textView.text = "Updating..."
            } else {
                textView.text = setting.displayString
            }
        } else {
            sliderView.isEnabled = false
            textView.text = "Not Supported"
        }
    }

    @IBAction func valueChanged(_ sender: UISlider) {
        sendActions(for: .valueChanged)
    }

    func xibSetup() {
        let view = loadViewFromNib()
        if let view = view {
            // use bounds not frame or it'll be offset
            view.frame = bounds
            // Make the view stretch with containing view
            view.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleHeight]
            // Adding custom subview on top of our view (over any custom drawing > see note below)
            addSubview(view)
        }
    }

    func loadViewFromNib() -> UIView? {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: "NumSettingView", bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil)[0] as? UIView
        return view
    }
}
