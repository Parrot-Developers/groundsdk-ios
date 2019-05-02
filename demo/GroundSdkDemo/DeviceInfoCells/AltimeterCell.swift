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

class AltimeterCell: InstrumentProviderContentCell {

    @IBOutlet weak var takeOffRelativeAltitude: UILabel!
    @IBOutlet weak var groundRelativeAltitude: UILabel!
    @IBOutlet weak var absoluteAltitude: UILabel!
    @IBOutlet weak var verticalSpeed: UILabel!
    private var altimeter: Ref<Altimeter>?

    override func set(instrumentProvider provider: InstrumentProvider) {
        super.set(instrumentProvider: provider)
        selectionStyle = .none
        altimeter = provider.getInstrument(Instruments.altimeter) { [unowned self] altimeter in
            if let altimeter = altimeter {
                if let takeoffRelativeAltitude = altimeter.takeoffRelativeAltitude {
                    self.takeOffRelativeAltitude.text = String(format: "%.2f", takeoffRelativeAltitude)
                } else {
                    self.takeOffRelativeAltitude.text = "Unavailable"
                }
                if let groundRelativeAltitude = altimeter.groundRelativeAltitude {
                    self.groundRelativeAltitude.text = String(format: "%.2f", groundRelativeAltitude)
                } else {
                    self.groundRelativeAltitude.text = "Unavailable"
                }
                if let absoluteAltitude = altimeter.absoluteAltitude {
                    self.absoluteAltitude.text = String(format: "%.2f", absoluteAltitude)
                } else {
                    self.absoluteAltitude.text = "Unavailable"
                }
                if let verticalSpeed = altimeter.verticalSpeed {
                    self.verticalSpeed.text = String(format: "%.2f", verticalSpeed)
                } else {
                    self.verticalSpeed.text = "Unavailable"
                }
                self.show()
            } else {
                self.hide()
            }
        }
    }
}
