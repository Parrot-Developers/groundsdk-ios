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

class ReturnHomePilotingItfCell: PilotingItfProviderContentCell {

    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var autoTriggerEnabledLabel: UILabel!
    @IBOutlet weak var autoTriggerModeBt: UIButton!
    @IBOutlet weak var reasonLabel: UILabel!
    @IBOutlet weak var latitude: UILabel!
    @IBOutlet weak var longitude: UILabel!
    @IBOutlet weak var altitude: UILabel!
    @IBOutlet weak var targetLabel: UILabel!
    @IBOutlet weak var minAltitude: UILabel!
    @IBOutlet weak var disconnectDelay: UILabel!
    @IBOutlet weak var preferredTarget: UILabel!
    @IBOutlet weak var activationBt: UIButton!
    @IBOutlet weak var cancelAutoTriggerBt: UIButton!
    @IBOutlet weak var homeReachability: UILabel!
    @IBOutlet weak var delayValue: UILabel!

    private var pilotingItf: Ref<ReturnHomePilotingItf>?

    /// formatter for the delay
    private lazy var delayFormatter: DateComponentsFormatter = {
        let durationFormatter = DateComponentsFormatter()
        durationFormatter.unitsStyle = .abbreviated
        return durationFormatter
    }()

    override func set(pilotingItfProvider provider: PilotingItfProvider) {
        super.set(pilotingItfProvider: provider)
        pilotingItf = provider.getPilotingItf(PilotingItfs.returnHome) { [weak self] pilotingItf in
            if let pilotingItf = pilotingItf {
                self?.show()
                self?.stateLabel.text = pilotingItf.state.description
                self?.reasonLabel.text = pilotingItf.reason.description
                if let homeLocation = pilotingItf.homeLocation {
                    self?.latitude.text = "\(homeLocation.coordinate.latitude)"
                    self?.longitude.text = "\(homeLocation.coordinate.longitude)"
                    self?.altitude.text = "\(homeLocation.altitude)"
                } else {
                    self?.latitude.text = ""
                    self?.longitude.text = ""
                    self?.altitude.text = ""
                }

                let firstFix = (pilotingItf.gpsWasFixedOnTakeOff) ? "" : "!"
                self?.targetLabel.text = "\(firstFix) \(pilotingItf.currentTarget)"

                if let minAltitude = pilotingItf.minAltitude {
                    self?.minAltitude.text = minAltitude.displayString
                } else {
                    self?.minAltitude.text = "-"
                }
                let value = pilotingItf.autoStartOnDisconnectDelay
                self?.disconnectDelay.text = value.displayString

                self?.preferredTarget.text = "\(pilotingItf.preferredTarget.target)"

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

                if let autoTriggerEnabled = pilotingItf.autoTriggerMode {
                    if autoTriggerEnabled.value {
                        self?.autoTriggerEnabledLabel.text = "ON"
                        self?.autoTriggerModeBt.setTitle("Disable auto trigger", for: .normal)
                    } else {
                        self?.autoTriggerEnabledLabel.text = "OFF"
                        self?.autoTriggerModeBt.setTitle("Enable auto trigger", for: .normal)
                    }
                } else {
                    self?.autoTriggerEnabledLabel.text = "ON"
                    self?.autoTriggerModeBt.isEnabled = false
                }

                self?.homeReachability.text = pilotingItf.homeReachability.description
                if pilotingItf.homeReachability == .warning {
                    self?.delayValue.text = self?.delayFormatter.string(from: pilotingItf.autoTriggerDelay)
                    self?.cancelAutoTriggerBt.isEnabled = true
                } else {
                    self?.delayValue.text = "-"
                    self?.cancelAutoTriggerBt.isEnabled = false
                }
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

    @IBAction func cancelAutoTriggerPushed(_ sender: Any) {
        if let pilotingItf = pilotingItf?.value {
            pilotingItf.cancelAutoTrigger()
        }
    }

    @IBAction func autoTriggerPushed(_ sender: Any) {
        if let pilotingItf = pilotingItf?.value, let autoTriggerEnabled = pilotingItf.autoTriggerMode {
            pilotingItf.autoTriggerMode?.value = !autoTriggerEnabled.value
        }
    }
}
