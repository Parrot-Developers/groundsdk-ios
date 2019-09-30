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

class GimbalCell: PeripheralProviderContentCell {

    private var gimbal: Ref<Gimbal>?

    @IBOutlet weak var supportedAxesLabel: UILabel!
    @IBOutlet weak var currentErrorsLabel: UILabel!
    @IBOutlet weak var lockedAxesLabel: UILabel!
    @IBOutlet weak var stabilizedAxesLabel: UILabel!
    @IBOutlet weak var boundsLabel: UILabel!
    @IBOutlet weak var maxSpeedsLabel: UILabel!
    @IBOutlet weak var absoluteAttitudeLabel: UILabel!
    @IBOutlet weak var relativeAttitudeLabel: UILabel!
    @IBOutlet weak var calibratedLabel: UILabel!

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        gimbal = provider.getPeripheral(Peripherals.gimbal) { [unowned self] gimbal in
            if let gimbal = gimbal {
                self.supportedAxesLabel.text = gimbal.supportedAxes.map { $0.description }.joined(separator: ", ")
                self.currentErrorsLabel.text = gimbal.currentErrors.map { $0.description }.joined(separator: ", ")
                self.lockedAxesLabel.text = gimbal.lockedAxes.map { $0.description }.joined(separator: ", ")
                self.stabilizedAxesLabel.text = gimbal.stabilizationSettings.filter { $0.value.value }
                    .map { $0.key.description }.joined(separator: ", ")
                self.boundsLabel.text = gimbal.attitudeBounds.map { "(\($0.value.description))" }
                    .joined(separator: ", ")
                self.maxSpeedsLabel.text = gimbal.maxSpeedSettings.map { $0.value.value.description }
                    .joined(separator: ", ")

                let absolute = gimbal.currentAttitude(frameOfReference: .absolute)
                self.absoluteAttitudeLabel.text =
                    "Pitch: \(absolute[.pitch] ?? 0) Roll: \( absolute[.roll] ?? 0)"
                let relative = gimbal.currentAttitude(frameOfReference: .relative)
                self.relativeAttitudeLabel.text =
                    "Pitch: \(relative[.pitch] ?? 0) Roll: \(relative[.roll] ?? 0)"
                self.calibratedLabel.text = "\(gimbal.calibrated)"

                self.show()
            } else {
                self.hide()
            }
        }
    }
}
