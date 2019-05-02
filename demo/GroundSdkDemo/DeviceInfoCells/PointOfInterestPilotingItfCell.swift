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

/// Cell for the Point Of Interest Interface
class PointOfInterestPilotingItfCell: PilotingItfProviderContentCell {

    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var latitudeValue: UILabel!
    @IBOutlet weak var longitudeValue: UILabel!
    @IBOutlet weak var altitudeValue: UILabel!

    @IBOutlet weak var deactivateButton: UIButton!

    private var pilotingItf: Ref<PointOfInterestPilotingItf>?

    override func set(pilotingItfProvider provider: PilotingItfProvider) {
        super.set(pilotingItfProvider: provider)
        pilotingItf = provider.getPilotingItf(PilotingItfs.pointOfInterest) { [weak self] pilotingItf in
            if let pilotingItf = pilotingItf {
                self?.show()
                self?.stateLabel.text = "\(pilotingItf.state)"
                self?.deactivateButton.isEnabled = pilotingItf.state == .active
                self?.latitudeValue.text = pilotingItf.currentPointOfInterest?.latitude.description ?? "-"
                self?.longitudeValue.text = pilotingItf.currentPointOfInterest?.longitude.description ?? "-"
                self?.altitudeValue.text = pilotingItf.currentPointOfInterest?.altitude.description ?? "-"
            } else {
                self?.hide()
            }
        }
    }
    @IBAction func deactivateAction(_ sender: Any) {
        let pointOfInterestItf = pilotingItf?.value

        _ = pointOfInterestItf?.deactivate()
    }
}
