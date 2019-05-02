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

class ManualCopterPilotingItfCell: PilotingItfProviderContentCell {

    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var canTakeoffLandLabel: UILabel!
    @IBOutlet weak var maxPitchRoll: UILabel!
    @IBOutlet weak var maxPitchRollVelocity: UILabel!
    @IBOutlet weak var maxVerticalSpeed: UILabel!
    @IBOutlet weak var maxYawSpeed: UILabel!
    @IBOutlet weak var bankedTurnMode: UILabel!
    @IBOutlet weak var useThrownTakeOff: UILabel!
    @IBOutlet weak var resultSmartAction: UILabel!
    @IBOutlet weak var activationBt: UIButton!

    private var pilotingItf: Ref<ManualCopterPilotingItf>?

    override func set(pilotingItfProvider provider: PilotingItfProvider) {
        super.set(pilotingItfProvider: provider)
        pilotingItf = provider.getPilotingItf(PilotingItfs.manualCopter) { [weak self] pilotingItf in
            if let pilotingItf = pilotingItf {
                self?.show()
                self?.stateLabel.text = "\(pilotingItf.state)"

                if pilotingItf.canTakeOff {
                    self?.canTakeoffLandLabel.text = "Can Takeoff"
                } else if pilotingItf.canLand {
                    self?.canTakeoffLandLabel.text = "Can Land"
                } else {
                    self?.canTakeoffLandLabel.text = "-"
                }

                self?.maxPitchRoll.text = pilotingItf.maxPitchRoll.displayString

                if let value = pilotingItf.maxPitchRollVelocity {
                    self?.maxPitchRollVelocity.text = value.displayString
                } else {
                    self?.maxPitchRollVelocity.text = "Unsupported"
                }

                self?.maxVerticalSpeed.text = pilotingItf.maxVerticalSpeed.displayString

                self?.maxYawSpeed.text = pilotingItf.maxYawRotationSpeed.displayString

                if let value = pilotingItf.bankedTurnMode {
                    self?.bankedTurnMode.text = value.displayString
                } else {
                    self?.bankedTurnMode.text = "Unsupported"
                }

                switch pilotingItf.state {
                case .active:
                    self?.activationBt.isEnabled = true
                    self?.activationBt.setTitle("Deactivate", for: .normal)
                case .idle:
                    self?.activationBt.isEnabled = true
                    self?.activationBt.setTitle("Activate", for: .normal)
                case .unavailable:
                    self?.activationBt.isEnabled = false
                }

                if let value = pilotingItf.thrownTakeOffSettings {
                    self?.useThrownTakeOff.text = value.displayString
                } else {
                    self?.useThrownTakeOff.text = "Unsupported"
                }
                self?.resultSmartAction.text = pilotingItf.smartTakeOffLandAction.description

            } else {
                self?.hide()
            }
        }
    }

    @IBAction func activatePushed(_ sender: Any) {
        if let pilotingItf = pilotingItf?.value {
            if pilotingItf.state == .active {
                _ = pilotingItf.deactivate()
            } else if pilotingItf.state == .idle {
                _ = pilotingItf.activate()
            }
        }
    }
}
