// Copyright (C) 2016-2017 Parrot SA
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
//    * Neither the name of Parrot nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import UIKit
import GroundSdk

class CopterSystemInfoCell: PeripheralProviderContentCell {
    @IBOutlet weak var firmwareVersion: UILabel!
    @IBOutlet weak var hardwareVersion: UILabel!
    @IBOutlet weak var serial: UILabel!
    @IBOutlet weak var cpuId: UILabel!
    @IBOutlet weak var timeDelta: UILabel!
    @IBOutlet weak var motorFrontLeftStatus: UILabel!
    @IBOutlet weak var motorFrontRightStatus: UILabel!
    @IBOutlet weak var motorBackRightStatus: UILabel!
    @IBOutlet weak var motorBackLeftStatus: UILabel!
    private var copterSystemInfo: Ref<CopterSystemInfo>?

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        selectionStyle = .none
        copterSystemInfo = provider.getPeripheral(PeripheralDesc.copterSystemInfo) { [unowned self] copterSystemInfo in
            if let copterSystemInfo = copterSystemInfo {
                self.show()
                self.firmwareVersion.text = copterSystemInfo.firmwareVersion.description
                self.hardwareVersion.text = copterSystemInfo.hardwareVersion
                self.serial.text = copterSystemInfo.serial
                self.cpuId.text = copterSystemInfo.cpuUid
                self.timeDelta.text = "\(copterSystemInfo.timeDelta)"

                let motorsAffected = copterSystemInfo.motorsCurrentlyInError

                self.motorFrontLeftStatus.text = copterSystemInfo.latestError(onMotor: .frontLeft).description
                self.motorFrontLeftStatus.textColor = (motorsAffected.contains(.frontLeft)) ?
                    UIColor.red : UIColor.black

                self.motorFrontRightStatus.text = copterSystemInfo.latestError(onMotor: .frontRight).description
                self.motorFrontRightStatus.textColor = (motorsAffected.contains(.frontRight)) ?
                    UIColor.red : UIColor.black

                self.motorBackRightStatus.text = copterSystemInfo.latestError(onMotor: .backRight).description
                self.motorBackRightStatus.textColor = (motorsAffected.contains(.backRight)) ?
                    UIColor.red : UIColor.black

                self.motorBackLeftStatus.text = copterSystemInfo.latestError(onMotor: .backLeft).description
                self.motorBackLeftStatus.textColor = (motorsAffected.contains(.backLeft)) ?
                    UIColor.red : UIColor.black

            } else {
                self.hide()
                self.firmwareVersion.text = "-"
                self.hardwareVersion.text = "-"
                self.serial.text = "-"
                self.cpuId.text = "-"
                self.timeDelta.text = "-"
                self.motorFrontLeftStatus.text = "-"
                self.motorFrontLeftStatus.textColor = UIColor.black
                self.motorFrontRightStatus.text = "-"
                self.motorFrontRightStatus.textColor = UIColor.black
                self.motorBackRightStatus.text = "-"
                self.motorBackRightStatus.textColor = UIColor.black
                self.motorBackLeftStatus.text = "_"
                self.motorBackLeftStatus.textColor = UIColor.black
            }
        }
    }
}
