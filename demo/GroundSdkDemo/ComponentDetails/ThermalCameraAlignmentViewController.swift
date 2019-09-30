// Copyright (C) 2018 Parrot Drones SAS
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

class ThermalCameraAlignmentViewController: UIViewController, DeviceViewController {

    @IBOutlet weak var yawSlider: UISlider!
    @IBOutlet weak var yawValue: UILabel!
    @IBOutlet weak var pitchSlider: UISlider!
    @IBOutlet weak var pitchValue: UILabel!
    @IBOutlet weak var rollSlider: UISlider!
    @IBOutlet weak var rollValue: UILabel!

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var thermalCamera: ThermalCamera?

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let drone = groundSdk.getDrone(uid: droneUid!)

        if let drone = drone {
            _ = drone.getPeripheral(Peripherals.thermalCamera) { [weak self] camera in
                self?.thermalCamera = camera
                if let camera = camera,
                    let alignment = camera.alignment {
                    self?.yawSlider.value = Float(alignment.yaw)
                    self?.yawSlider.minimumValue = Float(alignment.supportedYawRange.lowerBound)
                    self?.yawSlider.maximumValue = Float(alignment.supportedYawRange.upperBound)
                    self?.pitchSlider.value = Float(alignment.pitch)
                    self?.pitchSlider.minimumValue = Float(alignment.supportedPitchRange.lowerBound)
                    self?.pitchSlider.maximumValue = Float(alignment.supportedPitchRange.upperBound)
                    self?.rollSlider.value = Float(alignment.roll)
                    self?.rollSlider.minimumValue = Float(alignment.supportedRollRange.lowerBound)
                    self?.rollSlider.maximumValue = Float(alignment.supportedRollRange.upperBound)
                } else {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    @IBAction func valueDidChange(_ sender: UISlider) {
        let value = Double(sender.value).roundedToDecimal(2)
        if sender == rollSlider {
            rollValue.text = String(value)
            thermalCamera?.alignment?.roll = value
        } else if sender == pitchSlider {
            pitchValue.text = String(value)
            thermalCamera?.alignment?.pitch = value
        } else if sender == yawSlider {
            yawValue.text = String(value)
            thermalCamera?.alignment?.yaw = value
        }
    }

    @IBAction func reset(_ sender: UIButton) {
        _ = thermalCamera?.alignment?.reset()
    }
}
