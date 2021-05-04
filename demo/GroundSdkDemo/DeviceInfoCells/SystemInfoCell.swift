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

class SystemInfoCell: PeripheralProviderContentCell {
    @IBOutlet weak var firmwareVersion: UILabel!
    @IBOutlet weak var isFirmwareBlacklisted: UILabel!
    @IBOutlet weak var isUpdateRequired: UILabel!
    @IBOutlet weak var hardwareVersion: UILabel!
    @IBOutlet weak var serial: UILabel!
    @IBOutlet weak var boardId: UILabel!

    @IBOutlet weak var factoryResetBt: UIButton!
    @IBOutlet weak var factoryResetSpinner: UIActivityIndicatorView!

    @IBOutlet weak var resetSettingsBt: UIButton!
    @IBOutlet weak var resetSettingsSpinner: UIActivityIndicatorView!

    private var systemInfo: Ref<SystemInfo>?

    private let groundSdk = GroundSdk()

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        selectionStyle = .none
        systemInfo = provider.getPeripheral(Peripherals.systemInfo) { [weak self] systemInfo in
            if let strongSelf = self {
                if let systemInfo = systemInfo {
                    strongSelf.show()
                    strongSelf.firmwareVersion.text = systemInfo.firmwareVersion
                    strongSelf.isFirmwareBlacklisted.text = systemInfo.isFirmwareBlacklisted.description
                    strongSelf.isUpdateRequired.text = systemInfo.isUpdateRequired.description
                    strongSelf.hardwareVersion.text = systemInfo.hardwareVersion
                    strongSelf.serial.text = systemInfo.serial
                    strongSelf.boardId.text = systemInfo.boardId

                    if systemInfo.isResetSettingsInProgress {
                        strongSelf.resetSettingsBt.isHidden = true
                        strongSelf.resetSettingsSpinner.startAnimating()
                        strongSelf.resetSettingsSpinner.isHidden = false
                    } else {
                        strongSelf.resetSettingsSpinner.isHidden = true
                        strongSelf.resetSettingsSpinner.stopAnimating()
                        strongSelf.resetSettingsBt.isHidden = false
                    }

                    if systemInfo.isFactoryResetInProgress {
                        strongSelf.factoryResetBt.isHidden = true
                        strongSelf.factoryResetSpinner.startAnimating()
                        strongSelf.factoryResetSpinner.isHidden = false
                    } else {
                        strongSelf.factoryResetSpinner.isHidden = true
                        strongSelf.factoryResetSpinner.stopAnimating()
                        strongSelf.factoryResetBt.isHidden = false
                    }
                } else {
                    strongSelf.hide()
                    strongSelf.firmwareVersion.text = "-"
                    strongSelf.hardwareVersion.text = "-"
                    strongSelf.serial.text = "-"
                    strongSelf.boardId.text = "-"
                    strongSelf.factoryResetBt.isHidden = true
                    strongSelf.factoryResetSpinner.isHidden = true
                    strongSelf.resetSettingsBt.isHidden = true
                    strongSelf.resetSettingsSpinner.isHidden = true
                }
            }
        }
    }

    @IBAction func resetSettingsPushed(_ sender: UIButton) {
        if let systemInfo = systemInfo?.value {
            _ = systemInfo.resetSettings()
        }
    }

    @IBAction func factoryResetPushed(_ sender: UIButton) {
        if let systemInfo = systemInfo?.value {
            _ = systemInfo.factoryReset()
        }
    }
}
