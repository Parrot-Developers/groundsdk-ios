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

class ThermalCameraCell: PeripheralProviderContentCell {

    private var camera: Ref<ThermalCamera>?

    @IBOutlet weak var exposureModeLabel: UILabel!
    @IBOutlet weak var exposureCompensationLabel: UILabel!
    @IBOutlet weak var whiteBalanceLabel: UILabel!
    @IBOutlet weak var whiteBalanceLockLabel: UILabel!
    @IBOutlet weak var exposureLockLabel: UILabel!
    @IBOutlet weak var photoRecordingModeLablel: UILabel!

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        camera = provider.getPeripheral(Peripherals.thermalCamera) { [unowned self] camera in
            if let camera = camera {
                // exposure mode
                switch camera.exposureSettings.mode {
                case .automatic, .automaticPreferIsoSensitivity, .automaticPreferShutterSpeed:
                    self.exposureModeLabel.text = camera.exposureSettings.mode.description
                case .manualIsoSensitivity:
                    self.exposureModeLabel.text = camera.exposureSettings.manualIsoSensitivity.description
                case .manualShutterSpeed:
                    self.exposureModeLabel.text = camera.exposureSettings.manualShutterSpeed.description
                case .manual:
                    self.exposureModeLabel.text =
                    "\(camera.exposureSettings.manualIsoSensitivity) \(camera.exposureSettings.manualShutterSpeed)"
                }
                // exposure compensation
                if !camera.exposureCompensationSetting.supportedValues.isEmpty {
                    self.exposureCompensationLabel.text = camera.exposureCompensationSetting.value.description
                } else {
                    self.exposureCompensationLabel.text = "-"
                }

                // white balance
                if !camera.whiteBalanceSettings.supportedModes.isEmpty {
                    if camera.whiteBalanceSettings.mode != .custom {
                        self.whiteBalanceLabel.text = camera.whiteBalanceSettings.mode.description
                    } else {
                        self.whiteBalanceLabel.text = camera.whiteBalanceSettings.customTemperature.description
                    }
                } else {
                    self.whiteBalanceLabel.text = "-"
                }

                if let whiteBalanceLock = camera.whiteBalanceLock, let isLockable = whiteBalanceLock.isLockable {
                    self.whiteBalanceLockLabel.text = isLockable ? "Lockable" : "Not Lockable"
                } else {
                    self.whiteBalanceLockLabel.text = "Not Supported"
                }
                // exposure lock
                if let exposureLock = camera.exposureLock {
                    self.exposureLockLabel.text = exposureLock.mode.description
                } else {
                    self.exposureLockLabel.text = "-"
                }

                // photo/video mode
                var modeStr = "\(camera.modeSetting.mode) "
                switch camera.modeSetting.mode {
                case .recording:
                    let settings = camera.recordingSettings
                    modeStr += "\(settings.mode) \(settings.resolution) \(settings.framerate) fps " +
                    "\(settings.bitrate) bit/s"
                case .photo:
                    let settings = camera.photoSettings
                    modeStr += "\(settings.mode) \(settings.format) \(settings.fileFormat)"
                }
                self.photoRecordingModeLablel.text = modeStr

                self.show()
            } else {
                self.hide()
            }
        }
    }
}
