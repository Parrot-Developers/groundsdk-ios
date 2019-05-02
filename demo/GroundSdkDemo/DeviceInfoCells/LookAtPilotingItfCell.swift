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

/// Cell for the Look At Interface
class LookAtPilotingItfCell: PilotingItfProviderContentCell {

    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var unavailabilityValue: UILabel!
    @IBOutlet weak var activateButton: UIButton!
    @IBOutlet weak var qualityValue: UILabel!

    private var pilotingItf: Ref<LookAtPilotingItf>?

    override func set(pilotingItfProvider provider: PilotingItfProvider) {
        super.set(pilotingItfProvider: provider)
        pilotingItf = provider.getPilotingItf(PilotingItfs.lookAt) { [weak self] pilotingItf in
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
                // quality issues
                if pilotingItf.qualityIssues.isEmpty {
                    self?.qualityValue.text = "-"
                } else {
                    self?.qualityValue.text = pilotingItf.qualityIssues.map { $0.description }
                        .joined(separator: ", ")
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
        if let lookAtItf = pilotingItf?.value {
            if lookAtItf.state == .active {
                _ = lookAtItf.deactivate()
            } else if lookAtItf.state == .idle {
                _ = lookAtItf.activate()
            }
        }
    }
}
