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

class BatteryGaugeUpdaterCell: PeripheralProviderContentCell {

    @IBOutlet weak var batteryGaugeUpdaterStateLabel: UILabel!
    @IBOutlet weak var batteryGaugeUpdaterProgressLabel: UILabel!
    @IBOutlet weak var prepareOrUpdateButton: UIButton!
    @IBOutlet weak var missingRequierementLabel: UILabel!

    private var batteryGaugeUpdater: Ref<BatteryGaugeUpdater>?

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        batteryGaugeUpdater = provider
            .getPeripheral(Peripherals.batteryGaugeUpdater) { [unowned self] batteryGaugeUpdater in
            if let batteryGaugeUpdater = batteryGaugeUpdater {
                switch batteryGaugeUpdater.state {
                case .readyToPrepare:
                    self.prepareOrUpdateButton.setTitle("Prepare to update", for: .normal)
                    self.prepareOrUpdateButton.isHidden = false
                case .readyToUpdate:

                    self.prepareOrUpdateButton.setTitle("Update", for: .normal)
                    self.prepareOrUpdateButton.isHidden = false
                default:
                    self.prepareOrUpdateButton.isHidden = true
                }
                self.batteryGaugeUpdaterProgressLabel.text = "\(batteryGaugeUpdater.currentProgress)"
                self.batteryGaugeUpdaterStateLabel.text = "\(batteryGaugeUpdater.state)"
                var text = ""
                for reason in batteryGaugeUpdater.unavailabilityReasons {
                    text.append("\(reason.description) ")
                }
                self.missingRequierementLabel.text = "\(text.isEmpty ? "-" : text)"
                self.show()
            } else {
                self.hide()
            }
        }
    }

    @IBAction func prepareOrUpdate() {
        if let batteryGaugeFirmwareUpdater = batteryGaugeUpdater?.value {
            switch batteryGaugeFirmwareUpdater.state {
            case .readyToPrepare:
                _ = batteryGaugeFirmwareUpdater.prepareUpdate()
            case .readyToUpdate:
                _ = batteryGaugeFirmwareUpdater.update()
            default:
                break
            }
        }
    }
}
