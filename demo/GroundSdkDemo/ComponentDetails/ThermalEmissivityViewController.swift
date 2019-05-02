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

/// A view controller that can modify the emissivity
class ThermalEmissivityViewController: UIViewController {

    @IBOutlet weak var emissivityLabel: UILabel!
    @IBOutlet weak var emissivitySlider: UISlider!

    private let groundSdk = GroundSdk()
    private var thermalControl: Ref<ThermalControl>?
    private var droneUid: String!

    private var isEditingLevel = false

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        emissivitySlider.minimumValue = 0.0
        emissivitySlider.maximumValue = 1.0
        set(emissivity: 0.0)

        if let drone = groundSdk.getDrone(uid: droneUid) {
            thermalControl = drone.getPeripheral(Peripherals.thermalControl) { [weak self] thermalControl in
                if thermalControl == nil, let `self` = self {
                    self.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    private func set(emissivity: Double) {
        emissivitySlider.value = Float(emissivity)
        emissivitySlider.sendActions(for: .valueChanged)
    }

    @IBAction func emissivityDidChange(_ sender: UISlider) {
        thermalControl?.value?.sendEmissivity(Double(sender.value))
        emissivityLabel.text = String(sender.value)
    }
}
