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

class ManualCopterPilotingItfViewController: UIViewController, DeviceViewController {

    @IBOutlet weak var maxPitchRollView: NumSettingView!
    @IBOutlet weak var maxPitchRollVelocityView: NumSettingView!
    @IBOutlet weak var maxVerticalSpeedView: NumSettingView!
    @IBOutlet weak var maxYawSpeed: NumSettingView!
    @IBOutlet weak var bankedTurnMode: BoolSettingView!
    @IBOutlet weak var thrownTakeoffSetting: BoolSettingView!

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var pilotingItf: Ref<ManualCopterPilotingItf>?

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let drone = groundSdk.getDrone(uid: droneUid!) {
            pilotingItf = drone.getPilotingItf(PilotingItfs.manualCopter) { [weak self] pilotingItf in
                if let pilotingItf = pilotingItf {
                    self?.maxPitchRollView.updateWith(doubleSetting: pilotingItf.maxPitchRoll)
                    self?.maxPitchRollVelocityView.updateWith(doubleSetting: pilotingItf.maxPitchRollVelocity)
                    self?.maxVerticalSpeedView.updateWith(doubleSetting: pilotingItf.maxVerticalSpeed)
                    self?.maxYawSpeed.updateWith(doubleSetting: pilotingItf.maxYawRotationSpeed)
                    self?.bankedTurnMode.updateWith(boolSetting: pilotingItf.bankedTurnMode)
                    self?.thrownTakeoffSetting.updateWith(boolSetting: pilotingItf.thrownTakeOffSettings)
                } else {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    @IBAction func maxPitchRollDidChange(_ sender: NumSettingView) {
        pilotingItf?.value?.maxPitchRoll.value = Double(sender.value)
    }

    @IBAction func maxPitchRollVelocityDidChange(_ sender: NumSettingView) {
        pilotingItf?.value?.maxPitchRollVelocity!.value = Double(sender.value)
    }

    @IBAction func maxMaxVerticalSpeedDidChange(_ sender: NumSettingView) {
        pilotingItf?.value?.maxVerticalSpeed.value = Double(sender.value)
    }

    @IBAction func maxYawSpeedDidChange(_ sender: NumSettingView) {
        pilotingItf?.value?.maxYawRotationSpeed.value = Double(sender.value)
    }

    @IBAction func bankedTurnModeDidChange(_ sender: BoolSettingView) {
        pilotingItf?.value?.bankedTurnMode!.value = sender.value
    }

    @IBAction func thrownTakeOffDidChange(_ sender: BoolSettingView) {
        pilotingItf?.value?.thrownTakeOffSettings!.value = sender.value
    }
}
