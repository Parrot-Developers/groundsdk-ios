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

import Foundation

/// Core implementation of CameraWhiteBalanceSettings
class CameraWhiteBalanceSettingsCore: CameraWhiteBalanceSettings, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    // default values
    private static let defaultMode = CameraWhiteBalanceMode.automatic
    private static let defaultCustomTemperature = CameraWhiteBalanceTemperature.k1500

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// closure to call to change the value
    private let backend: (_ mode: CameraWhiteBalanceMode, _ customTemperature: CameraWhiteBalanceTemperature) -> Bool

    /// Supported white balance modes
    private(set) var supportedModes = Set<CameraWhiteBalanceMode>()

    /// Supported temperatures when mode is `custom`
    private(set) var supporteCustomTemperature = Set<CameraWhiteBalanceTemperature>()

    /// White balance mode
    var mode: CameraWhiteBalanceMode {
        get {
            return _mode
        }
        set {
            if _mode != newValue {
                set(mode: newValue)
            }
        }
    }
    private var _mode = defaultMode

    /// White balance temperatures when mode is `custom`
    var customTemperature: CameraWhiteBalanceTemperature {
        get {
            return _customTemperature
        }
        set {
            if _customTemperature != newValue {
                set(mode: _mode, customTemperature: newValue)
            }
        }
    }
    private var _customTemperature = defaultCustomTemperature

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate,
         backend: @escaping (_ mode: CameraWhiteBalanceMode, _ customTemperature: CameraWhiteBalanceTemperature)
            -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Change white balance mode and custom temperature
    ///
    /// - Parameters:
    ///   - mode: requested white balance mode
    ///   - customTemperature: requested white balance temperature when mode is `custom`
    func set(mode: CameraWhiteBalanceMode, customTemperature: CameraWhiteBalanceTemperature? = nil) {
        guard supportedModes.contains(mode) else {
            ULog.w(.cameraTag, "Unsupported white balance mode: \(mode). Supported: \(supportedModes)")
            return
        }
        guard customTemperature == nil || supporteCustomTemperature.contains(customTemperature!) else {
            ULog.w(.cameraTag, "Unsupported white balance temperature: \(customTemperature!). " +
                "Supported: \(supporteCustomTemperature)")
            return
        }
        if backend(mode, customTemperature ?? _customTemperature) {
            let oldMode = _mode
            let oldCustomTemperature = _customTemperature
            // value sent to the backend, update setting value and mark it updating
            _mode = mode
            if let customTemperature = customTemperature {
                _customTemperature = customTemperature
            }
            timeout.schedule { [weak self] in

                if let `self` = self {
                    let modeUpdated = self.update(mode: oldMode)
                    let customTemperatureUpdated = self.update(customTemperature: oldCustomTemperature)
                    if modeUpdated || customTemperatureUpdated {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
            }
            didChangeDelegate.userDidChangeSetting()
        }
    }

    /// Called by the backend, sets supported modes
    ///
    /// - Parameter newSupportedModes: new supported modes
    /// - Returns: true if the setting has been changed, false else
    func update(supportedModes newSupportedModes: Set<CameraWhiteBalanceMode>) -> Bool {
        if supportedModes != newSupportedModes {
            supportedModes = newSupportedModes
            return true
        }
        return false
    }

    /// Called by the backend, sets current mode
    ///
    /// - Parameter newMode: new white balance mode
    /// - Returns: true if the setting has been changed, false else
    func update(mode newMode: CameraWhiteBalanceMode) -> Bool {
        if updating || _mode != newMode {
            _mode = newMode
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets supported custom temperature
    ///
    /// - Parameter newSupportedCustomTemperatures: new supported custom temperature
    /// - Returns: true if the setting has been changed, false else
    func update(supportedCustomTemperatures newSupportedCustomTemperatures: Set<CameraWhiteBalanceTemperature>)
        -> Bool {
            if supporteCustomTemperature != newSupportedCustomTemperatures {
                supporteCustomTemperature = newSupportedCustomTemperatures
                return true
            }
            return false
    }

    /// Called by the backend, sets custom temperature value
    ///
    /// - Parameter new custom temperature
    /// - Returns: true if the setting has been changed, false else
    func update(customTemperature newTemperature: CameraWhiteBalanceTemperature) -> Bool {
        if updating || _customTemperature != newTemperature {
            _customTemperature = newTemperature
            timeout.cancel()
            return true
        }
        return false
    }

    /// Resets setting values to defaults.
    func reset() {
        supportedModes = []
        supporteCustomTemperature = []
        _mode = CameraWhiteBalanceSettingsCore.defaultMode
        _customTemperature = CameraWhiteBalanceSettingsCore.defaultCustomTemperature
        timeout.cancel()
    }

    /// Cancels any pending rollback.
    ///
    /// - Parameter completionClosure: block that will be called if a rollback was pending
    func cancelRollback(completionClosure: () -> Void) {
        if timeout.isScheduled {
            timeout.cancel()
            completionClosure()
        }
    }

    /// Debug description
    var debugDescription: String {
        return "\(_mode) \(supportedModes) \(_customTemperature) \(supporteCustomTemperature) \(updating)]"
    }
}

/// ObjC support
extension CameraWhiteBalanceSettingsCore: GSCameraWhiteBalanceSettings {
    func isModeSupported(_ mode: CameraWhiteBalanceMode) -> Bool {
        return supportedModes.contains(mode)
    }

    func isCustomTemperatureSupported(_ temperature: CameraWhiteBalanceTemperature) -> Bool {
        return supporteCustomTemperature.contains(temperature)
    }

    func setCustomMode(temperature: CameraWhiteBalanceTemperature) {
        set(mode: .custom, customTemperature: temperature)
    }
}
