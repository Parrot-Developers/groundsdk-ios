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

/// Cell for the Follow Me Interface
class FollowMePilotingItfCell: PilotingItfProviderContentCell {

    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var unavailabilityValue: UILabel!
    @IBOutlet weak var activateButton: UIButton!
    @IBOutlet weak var qualityValue: UILabel!
    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var behaviorValue: UILabel!

    private var pilotingItf: Ref<FollowMePilotingItf>?

    override func set(pilotingItfProvider provider: PilotingItfProvider) {
        super.set(pilotingItfProvider: provider)
        pilotingItf = provider.getPilotingItf(PilotingItfs.followMe) { [weak self] pilotingItf in
            if let pilotingItf = pilotingItf {
                self?.show()
                self?.stateLabel.text = "\(pilotingItf.state)"
                self?.activateButton.isEnabled = pilotingItf.state == .active
                // availability issues
                if pilotingItf.availabilityIssues.isEmpty {
                    self?.unavailabilityValue.text = "-"
                } else {
                    self?.unavailabilityValue.text = pilotingItf.availabilityIssues.map { $0.description }
                        .joined(separator: ", ")
                }
                // mode
                self?.modeSegmentedControl.selectedSegmentIndex = pilotingItf.followMode.value.rawValue
                // disable tabs that are not supported
                FollowMode.allCases.forEach { mode in
                    self?.modeSegmentedControl.setEnabled(
                        pilotingItf.followMode.supportedModes.contains(mode), forSegmentAt: mode.rawValue)
                }
                self?.modeSegmentedControl.isEnabled = !pilotingItf.followMode.updating
                // quality issues
                if pilotingItf.qualityIssues.isEmpty {
                    self?.qualityValue.text = "-"
                } else {
                    self?.qualityValue.text = pilotingItf.qualityIssues.map { $0.description }
                        .joined(separator: ", ")
                }
                // behaviour
                if let behavior = pilotingItf.followBehavior {
                    self?.behaviorValue.text = behavior.description
                } else {
                    self?.behaviorValue.text = "-"
                }
                // Activate / Deactivate button
                switch pilotingItf.state {
                case .active:
                    self?.activateButton.isEnabled = true
                    self?.activateButton.setTitle("Deactivate", for: .normal)
                case .idle:
                    self?.activateButton.isEnabled = true
                    self?.activateButton.setTitle("Activate", for: .normal)
                case .unavailable:
                    self?.activateButton.isEnabled = false
                }
            } else {
                self?.hide()
            }
        }
    }
    @IBAction func activateAction(_ sender: Any) {
        if let followMeItf = pilotingItf?.value {
            if followMeItf.state == .active {
                _ = followMeItf.deactivate()
            } else if followMeItf.state == .idle {
                _ = followMeItf.activate()
            }
        }
    }

    @IBAction func modeDidChange(_ sender: Any) {
        if let followMeItf = pilotingItf?.value,
            let followMode = FollowMode(rawValue: modeSegmentedControl.selectedSegmentIndex) {

            followMeItf.followMode.value = followMode
        }
    }
}
