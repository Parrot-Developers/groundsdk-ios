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

/// A view controller that can modify the background temperature
class ThermalBackgroundTemperatureVC: UIViewController {

    @IBOutlet weak var backgroundTemperatureLabel: UILabel!
    @IBOutlet weak var backgroundTemperatureSlider: UISlider!

    private let groundSdk = GroundSdk()
    private var thermalControl: Ref<ThermalControl>?
    private var droneUid: String!

    private var isEditingLevel = false

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundTemperatureSlider.minimumValue = 200.0
        backgroundTemperatureSlider.maximumValue = 673.15
        set(backgroundTemperature: 200.0)

        if let drone = groundSdk.getDrone(uid: droneUid) {
            thermalControl = drone.getPeripheral(Peripherals.thermalControl) { [weak self] thermalControl in
                if thermalControl == nil, let `self` = self {
                    self.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    private func set(backgroundTemperature: Double) {
        backgroundTemperatureSlider.value = Float(backgroundTemperature)
        backgroundTemperatureSlider.sendActions(for: .valueChanged)
    }

    @IBAction func backgroundTemperatureTouchUpInside(_ sender: UISlider) {
        thermalControl?.value?.sendBackgroundTemperature(Double(sender.value))
        backgroundTemperatureLabel.text = String(sender.value)
    }
}
