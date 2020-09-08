// Copyright (C) 2020 Parrot Drones SAS
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

class BlendedThermalCameraExposureLockVC: UIViewController {

    @IBOutlet weak var modeLabel: UILabel!
    @IBOutlet weak var updatingLabel: UILabel!
    @IBOutlet weak var lockOnRegionCenterXLabel: UILabel!
    @IBOutlet weak var lockOnRegionCenterXSlider: UISlider!
    @IBOutlet weak var lockOnRegionCenterYLabel: UILabel!
    @IBOutlet weak var lockOnRegionCenterYSlider: UISlider!

    private let groundSdk = GroundSdk()
    private var camera: Ref<BlendedThermalCamera>?
    private var droneUid: String!

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        lockOnRegionCenterXSlider.minimumValue = 0.0
        lockOnRegionCenterXSlider.maximumValue = 1.0
        lockOnRegionCenterXSlider.value = 0.5
        lockOnRegionCenterXLabel.text = "0.5"
        lockOnRegionCenterYSlider.minimumValue = 0.0
        lockOnRegionCenterYSlider.maximumValue = 1.0
        lockOnRegionCenterYSlider.value = 0.5
        lockOnRegionCenterYLabel.text = "0.5"

        if let drone = groundSdk.getDrone(uid: droneUid) {
            camera = drone.getPeripheral(Peripherals.blendedThermalCamera) { [weak self] camera in
                if let exposureLock = camera?.exposureLock, let `self` = self {
                    self.modeLabel.text = exposureLock.mode.description
                    self.updatingLabel.text = exposureLock.updating.description
                } else {
                    self?.navigationController?.popViewController(animated: true)
                }
            }
        }
    }

    @IBAction func unlock(_ sender: UIButton) {
        camera?.value?.exposureLock?.unlock()
    }

    @IBAction func lockOnCurrentValues(_ sender: UIButton) {
        camera?.value?.exposureLock?.lockOnCurrentValues()
    }

    @IBAction func lockOnRegion(_ sender: UIButton) {
        let centerX = Double(lockOnRegionCenterXSlider.value)
        let centerY = Double(lockOnRegionCenterYSlider.value)
        camera?.value?.exposureLock?.lockOnRegion(centerX: centerX, centerY: centerY)
    }

    @IBAction func lockOnRegionCenterXDidChange(_ sender: UISlider) {
        lockOnRegionCenterXLabel.text = "\(String(format: "%.2f", sender.value))"
    }

    @IBAction func lockOnRegionCenterYDidChange(_ sender: UISlider) {
        lockOnRegionCenterYLabel.text = "\(String(format: "%.2f", sender.value))"
    }
}
