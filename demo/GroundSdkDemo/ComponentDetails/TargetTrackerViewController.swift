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

class TargetTrackerViewController: UIViewController, DeviceViewController {

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var targetTracker: Ref<TargetTracker>?
    private var slidersAreEditing = false

    @IBOutlet weak var horizontalValue: UILabel!
    @IBOutlet weak var horizontalSlider: UISlider!
    @IBOutlet weak var verticalValue: UILabel!
    @IBOutlet weak var verticalSlider: UISlider!

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let drone = groundSdk.getDrone(uid: droneUid!) {
            targetTracker = drone.getPeripheral(Peripherals.targetTracker) { [weak self] targetTracker in
                if let targetTracker = targetTracker, let `self` = self {
                    self.horizontalSlider.isEnabled = !targetTracker.framing.updating
                    self.verticalSlider.isEnabled = !targetTracker.framing.updating
                    if !self.slidersAreEditing {
                        self.updateSlidersWith(framing: targetTracker.framing.value)
                    }
                } else {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    private func updateSlidersWith(framing: (horizontal: Double, vertical: Double) ) {
        horizontalSlider.setValue(Float(framing.horizontal), animated: true)
        verticalSlider.setValue(Float(framing.vertical), animated: true)
        sliderValueChanged(horizontalSlider)
        sliderValueChanged(verticalSlider)
    }

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        let labelValue: UILabel
        switch sender {
        case verticalSlider:
            labelValue = verticalValue
        case horizontalSlider:
            labelValue = horizontalValue
        default:
            return
        }
        labelValue.text = sender.getFramingValue().description
    }

    @IBAction func endEditingSlider(_ sender: UISlider) {
        slidersAreEditing = false
        if let targetTracker = targetTracker?.value {
            targetTracker.framing.value = (horizontalSlider.getFramingValue(), verticalSlider.getFramingValue())
        }
    }
    @IBAction func beginEditingSlider(_ sender: UISlider) {
        slidersAreEditing = true
    }
}

// MARK: - UISlider extension for framing Values
extension UISlider {
    func getFramingValue() -> Double {
        return unsignedPercentIntervalDouble.clamp(round(Double(value)*100.0)/100.0)
    }
}
