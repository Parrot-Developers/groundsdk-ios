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

class ThermalCameraStyleParametresVC: UIViewController {
    private let groundSdk = GroundSdk()
    private var camera: Ref<ThermalCamera>?
    private var droneUid: String!

    @IBOutlet weak var saturationValue: UILabel!
    @IBOutlet weak var saturationStepper: UIStepper!
    @IBOutlet weak var contrastValue: UILabel!
    @IBOutlet weak var contrastStepper: UIStepper!
    @IBOutlet weak var sharpnessValue: UILabel!
    @IBOutlet weak var sharpnessStepper: UIStepper!

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let drone = groundSdk.getDrone(uid: droneUid) {
            camera = drone.getPeripheral(Peripherals.thermalCamera) { [weak self] camera in
                if let styleSettings = camera?.styleSettings, let `self` = self {
                    self.saturationValue.text = styleSettings.saturation.displayString
                    self.saturationStepper.isEnabled = !styleSettings.updating
                    self.saturationStepper.minimumValue = Double(styleSettings.saturation.min)
                    self.saturationStepper.maximumValue = Double(styleSettings.saturation.max)
                    self.saturationStepper.value = Double(styleSettings.saturation.value)
                    self.contrastValue.text = styleSettings.contrast.displayString
                    self.contrastStepper.isEnabled = !styleSettings.updating
                    self.contrastStepper.minimumValue = Double(styleSettings.contrast.min)
                    self.contrastStepper.maximumValue = Double(styleSettings.contrast.max)
                    self.contrastStepper.value = Double(styleSettings.contrast.value)
                    self.sharpnessStepper.isEnabled = !styleSettings.updating
                    self.sharpnessStepper.minimumValue = Double(styleSettings.sharpness.min)
                    self.sharpnessStepper.maximumValue = Double(styleSettings.sharpness.max)
                    self.sharpnessStepper.value = Double(styleSettings.sharpness.value)
                    self.sharpnessValue.text = styleSettings.sharpness.displayString
                } else {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    @IBAction func saturationValueChanged(_ sender: UIStepper) {
        camera?.value?.styleSettings.saturation.value = Int(sender.value)
    }

    @IBAction func contrastValueChanged(_ sender: UIStepper) {
        camera?.value?.styleSettings.contrast.value = Int(sender.value)
    }

    @IBAction func sharpnessValueChanged(_ sender: UIStepper) {
        camera?.value?.styleSettings.sharpness.value = Int(sender.value)
    }
}
