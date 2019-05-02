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

class CopterMotorsCell: PeripheralProviderContentCell {

    @IBOutlet weak var frontLeft: UILabel!
    @IBOutlet weak var frontRight: UILabel!
    @IBOutlet weak var rearLeft: UILabel!
    @IBOutlet weak var rearRight: UILabel!

    var viewController: UIViewController?

    private var copterMotors: Ref<CopterMotors>?

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        selectionStyle = .none
        copterMotors = provider.getPeripheral(Peripherals.copterMotors) { [weak self] copterMotors in
            if let copterMotors = copterMotors, let selfCpy = self {
                self?.show()
                selfCpy.setErrorText(on: selfCpy.frontLeft, for: .frontLeft, motors: copterMotors)
                selfCpy.setErrorText(on: selfCpy.frontRight, for: .frontLeft, motors: copterMotors)
                selfCpy.setErrorText(on: selfCpy.rearLeft, for: .rearLeft, motors: copterMotors)
                selfCpy.setErrorText(on: selfCpy.rearRight, for: .rearRight, motors: copterMotors)
            } else {
                self?.hide()
            }
        }
    }

    private func setErrorText(on label: UILabel, for motor: CopterMotor, motors: CopterMotors) {
        let error = motors.latestError(onMotor: motor)
        if error == .noError {
            label.text = "No Error"
        } else {
            label.text = error.description
        }
        if motors.motorsCurrentlyInError.contains(motor) {
            label.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
        } else {
            label.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        }
    }
}
