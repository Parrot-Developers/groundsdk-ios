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

class MagnetometerWith1StepCalibrationVC: UIViewController, DeviceViewController {

    @IBOutlet weak var rollProgress: UILabel!
    @IBOutlet weak var pitchProgress: UILabel!
    @IBOutlet weak var yawProgress: UILabel!

    private let groundSdk = GroundSdk()
    private var deviceUid: String?
    private var magnetometer: Ref<MagnetometerWith1StepCalibration>?

    func setDeviceUid(_ uid: String) {
        deviceUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let peripheralProvider: PeripheralProvider?
        if let drone = groundSdk.getDrone(uid: deviceUid!) {
            peripheralProvider = drone
        } else if let remoteControl = groundSdk.getRemoteControl(uid: deviceUid!) {
            peripheralProvider = remoteControl
        } else {
            peripheralProvider = nil
        }

        if let peripheralProvider = peripheralProvider {
            if let magneto = peripheralProvider.getPeripheral(Peripherals.magnetometerWith1StepCalibration) {
                magneto.startCalibrationProcess()
            }
            magnetometer = peripheralProvider
                .getPeripheral(Peripherals.magnetometerWith1StepCalibration) { [weak self] magnetometer in
                    if let magnetometer = magnetometer, let calibProcessState = magnetometer.calibrationProcessState {
                        self?.rollProgress.text = calibProcessState.rollProgress.description
                        self?.pitchProgress.text = calibProcessState.pitchProgress.description
                        self?.yawProgress.text = calibProcessState.yawProgress.description
                    } else {
                        self?.performSegue(withIdentifier: "exit", sender: self)
                    }
            }
        }
    }

    @IBAction func cancelPushed(_ sender: UIButton) {
        if let magnetometer = magnetometer?.value {
            magnetometer.cancelCalibrationProcess()
        }
    }
}
