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

class TargetTrackerCell: PeripheralProviderContentCell {

    @IBOutlet weak var trackingValue: UILabel!
    @IBOutlet weak var trackingButton: UIButton!
    @IBOutlet weak var trajectoryValue: UILabel!
    private var targetTracker: Ref<TargetTracker>?

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        targetTracker = provider.getPeripheral(Peripherals.targetTracker) { [unowned self] targetTracker in
            if let targetTracker = targetTracker {
                self.trackingValue.text = targetTracker.targetIsController.description
                let titleAction = targetTracker.targetIsController ?
                    "Disable Controller Tracking" : "Enable Controller Tracking"
                self.trackingButton.setTitle(titleAction, for: .normal)
                // trajectory
                if let targetTrajectory = targetTracker.targetTrajectory {
                    self.trajectoryValue.text = targetTrajectory.description
                } else {
                    self.trajectoryValue.text = "-"
                }
                self.show()
            } else {
                self.hide()
            }
        }
    }

    @IBAction func trackingAction(_ sender: Any) {
        if let targetTracker = targetTracker?.value {
            if targetTracker.targetIsController {
                targetTracker.disableControllerTracking()
            } else {
                targetTracker.enableControllerTracking()
            }
        }
    }
}
