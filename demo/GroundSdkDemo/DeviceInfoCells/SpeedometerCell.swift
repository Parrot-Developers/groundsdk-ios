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

class SpeedometerCell: InstrumentProviderContentCell {

    @IBOutlet var groundSpeed: UILabel!
    @IBOutlet var northSpeed: UILabel!
    @IBOutlet var eastSpeed: UILabel!

    @IBOutlet var forwardSpeed: UILabel!

    @IBOutlet var rightSpeed: UILabel!

    @IBOutlet var downSpeed: UILabel!

    private var speedometer: Ref<Speedometer>?

    override func set(instrumentProvider provider: InstrumentProvider) {
        super.set(instrumentProvider: provider)
        selectionStyle = .none
        speedometer = provider.getInstrument(Instruments.speedometer) { [unowned self] speedometer in
            if let speedometer = speedometer {
                self.groundSpeed.text = String(format: "%.2f m/s", speedometer.groundSpeed)
                self.northSpeed.text = String(format: "%.2f m/s", speedometer.northSpeed)
                self.eastSpeed.text = String(format: "%.2f m/s", speedometer.eastSpeed)
                self.forwardSpeed.text = String(format: "%.2f m/s", speedometer.forwardSpeed)
                self.rightSpeed.text = String(format: "%.2f m/s", speedometer.rightSpeed)
                self.downSpeed.text = String(format: "%.2f m/s", speedometer.downSpeed)
                self.show()
            } else {
                self.hide()
            }
        }
    }
}
