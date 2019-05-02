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

class FlightPlanPilotingItfCell: PilotingItfProviderContentCell {

    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var unavailabilityReasonsLabel: UILabel!
    @IBOutlet weak var latestActivationErrorLabel: UILabel!
    @IBOutlet weak var latestUploadStateLabel: UILabel!
    @IBOutlet weak var flightPlanFileIsKnownLabel: UILabel!
    @IBOutlet weak var isPausedLabel: UILabel!
    @IBOutlet weak var latestMissionItemExecutedLabel: UILabel!
    @IBOutlet weak var activationBt: UIButton!
    @IBOutlet weak var restartBt: UIButton!

    var viewController: UIViewController?

    private var pilotingItf: Ref<FlightPlanPilotingItf>?

    override func set(pilotingItfProvider provider: PilotingItfProvider) {
        super.set(pilotingItfProvider: provider)
        pilotingItf = provider.getPilotingItf(PilotingItfs.flightPlan) { [weak self] pilotingItf in
            if let `self` = self, let pilotingItf = pilotingItf {
                self.show()
                self.stateLabel.text = "\(pilotingItf.state)"
                self.unavailabilityReasonsLabel.text = pilotingItf.unavailabilityReasons.map { $0.description }
                    .joined(separator: ", ")
                self.latestActivationErrorLabel.text = pilotingItf.latestActivationError.description
                self.latestUploadStateLabel.text = pilotingItf.latestUploadState.description
                self.flightPlanFileIsKnownLabel.text = pilotingItf.flightPlanFileIsKnown ? "true" : "false"
                self.isPausedLabel.text = pilotingItf.isPaused ? "true" : "false"
                self.latestMissionItemExecutedLabel.text = pilotingItf.latestMissionItemExecuted?.description ?? "-"

                switch pilotingItf.state {
                case .active:
                    self.activationBt.isEnabled = true
                    self.activationBt.setTitle("Deactivate", for: .normal)
                case .idle:
                    self.activationBt.isEnabled = true
                    self.activationBt.setTitle("Activate", for: .normal)
                case .unavailable:
                    self.activationBt.isEnabled = false
                }

                if pilotingItf.state != .unavailable && pilotingItf.isPaused {
                    self.restartBt.isEnabled = true
                } else {
                    self.restartBt.isEnabled = false
                }
            } else {
                self?.hide()
            }
        }
    }

    @IBAction func uploadPushed(_ sender: Any) {
        let alert = UIAlertController(title: "Flight plan file", message: "Chose the flight plan file to use.\n" +
            "Files should be put in Documents/flightPlans.",
                                      preferredStyle: .actionSheet)

        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let flightPlanFolderPath = documentPath.appendingPathComponent("flightPlans")
        let fileManager = FileManager.default
        let handler: (UIAlertAction) -> Void = { action in
            if let filename = action.title {
                self.pilotingItf?.value?.uploadFlightPlan(
                    filepath: flightPlanFolderPath.appendingPathComponent(filename).path)
            }
        }
        if let flightPlans = try? fileManager.contentsOfDirectory(atPath: flightPlanFolderPath.path) {
            for flightPlan in flightPlans {
                alert.addAction(UIAlertAction(title: flightPlan, style: .default, handler: handler))
            }
        }
        if let presenter = alert.popoverPresentationController {
            presenter.sourceView = self
            presenter.sourceRect = self.bounds
        }

        viewController?.present(alert, animated: true, completion: nil)
    }

    @IBAction func activatePushed(_ sender: Any) {
        if let pilotingItf = pilotingItf?.value {
            if pilotingItf.state == .active {
                _ = pilotingItf.deactivate()
            } else if pilotingItf.state == .idle {
                _ = pilotingItf.activate(restart: false)
            }
        }
    }

    @IBAction func restartPushed(_ sender: Any) {
        if let pilotingItf = pilotingItf?.value {
            _ = pilotingItf.activate(restart: true)
        }
    }
}
