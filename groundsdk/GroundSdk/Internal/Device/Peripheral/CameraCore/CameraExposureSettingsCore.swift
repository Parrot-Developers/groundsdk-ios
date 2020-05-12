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

/// Core implementation of CameraExposureSettings
class CameraExposureSettingsCore: CameraExposureSettings, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    // default values
    private static let defaultMode = CameraExposureMode.automatic
    private static let defaultManualShutterSpeed = CameraShutterSpeed.one
    private static let defaultManualIsoSensitivity = CameraIso.iso50
    private static let defaultMaximumIsoSensitivity = CameraIso.iso3200
    private static let defaultAutoExposureMeteringMode = CameraAutoExposureMeteringMode.standard

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// Closure to call to change the value
    private let backend: (_ mode: CameraExposureMode, _ shutterSpeedCameraShutterSpeed: CameraShutterSpeed,
    _ isoSensitivity: CameraIso, _ maximumIsoSensitivity: CameraIso,
    _ autoExposureMeteringMOde: CameraAutoExposureMeteringMode) -> Bool

    /// Supported exposure modes
    private(set) var supportedModes = Set<CameraExposureMode>()
    /// Supported shutter speed `manualShutterSpeed` and `manual` mode
    private(set) var supportedManualShutterSpeeds = Set<CameraShutterSpeed>()
    /// Supported iso sensitivity `manualIsoSensitivity` and `manual` mode
    private(set) var supportedManualIsoSensitivity = Set<CameraIso>()
    /// Supported maximum iso sensitivity values
    private(set) var supportedMaximumIsoSensitivity = Set<CameraIso>()

    /// Exposure mode
    var mode: CameraExposureMode {
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

    var autoExposureMeteringMode: CameraAutoExposureMeteringMode {
        get {
            return _autoExposureMeteringMode
        }
        set {
            if _autoExposureMeteringMode != newValue {
                set(mode: _mode, autoExposureMeteringMode: newValue)
            }
        }
    }
    private var _autoExposureMeteringMode = defaultAutoExposureMeteringMode

    /// Shutter speed when exposure mode is `manualShutterSpeed` or `manual` mode.
    var manualShutterSpeed: CameraShutterSpeed {
        get {
            return _manualShutterSpeed
        }
        set {
            if _manualShutterSpeed != newValue {
                set(mode: _mode, manualShutterSpeed: newValue)
            }
        }
    }
    private var _manualShutterSpeed = defaultManualShutterSpeed

    /// Iso sensitivity when exposure mode is `manualIsoSensitivity` or `manual` mode
    var manualIsoSensitivity: CameraIso {
        get {
            return _manualIsoSensitivity
        }
        set {
            if _manualIsoSensitivity != newValue {
                set(mode: _mode, manualIsoSensitivity: newValue)
            }
         }
    }
    private var _manualIsoSensitivity = defaultManualIsoSensitivity

    /// Maximum Iso sensitivity when exposure mode is `automatic`
    var maximumIsoSensitivity: CameraIso {
        get {
            return _maximumIsoSensitivity
        }
        set {
            if _maximumIsoSensitivity != newValue {
                set(mode: _mode, maximumIsoSensitivity: newValue)
            }
        }
    }
    private var _maximumIsoSensitivity = defaultMaximumIsoSensitivity

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate,
         backend: @escaping (_ mode: CameraExposureMode, _ shutterSpeedCameraShutterSpeed: CameraShutterSpeed,
        _ isoSensitivity: CameraIso, _ maximumIsoSensitivity: CameraIso,
        _ autoExposureMeteringMode: CameraAutoExposureMeteringMode) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Change mode, manualShutterSpeed, manualIsoSensitivity and maximumIsoSensitivity
    ///
    /// - Parameters:
    ///   - mode: requested exposire mode
    ///   - manualShutterSpeed: requested manual shutter speed if mode is `manualShutterSpeed` or `manual`
    ///   - manualIsoSensitivity: requested iso sensitivity if exposure mode is `manualIsoSensitivity` or `manual`
    ///   - maximumIsoSensitivity: requested maximum iso sensitivity when exposure mode is `automatic`
    func set(mode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed? = nil,
             manualIsoSensitivity: CameraIso? = nil, maximumIsoSensitivity: CameraIso? = nil) {

        if supportedModes.contains(mode) &&
            (manualShutterSpeed == nil || supportedManualShutterSpeeds.contains(manualShutterSpeed!)) &&
            (manualIsoSensitivity == nil || supportedManualIsoSensitivity.contains(manualIsoSensitivity!)) &&
            (maximumIsoSensitivity == nil || supportedMaximumIsoSensitivity.contains(maximumIsoSensitivity!)) {
            sendToBackend(mode: mode, manualShutterSpeed: manualShutterSpeed ?? _manualShutterSpeed,
                          manualIsoSensitivity: manualIsoSensitivity ?? _manualIsoSensitivity,
                          maximumIsoSensitivity: maximumIsoSensitivity ?? _maximumIsoSensitivity,
                          autoExposureMeteringMode: .standard)
        }
    }

    /// Change mode, manualShutterSpeed, manualIsoSensitivity and maximumIsoSensitivity
    ///
    /// - Parameters:
    ///   - mode: requested exposire mode
    ///   - manualShutterSpeed: requested manual shutter speed if mode is `manualShutterSpeed` or `manual`
    ///   - manualIsoSensitivity: requested iso sensitivity if exposure mode is `manualIsoSensitivity` or `manual`
    ///   - maximumIsoSensitivity: requested maximum iso sensitivity when exposure mode is `automatic`
    ///   - autoExposureMeteringMode: requested auto exposure metering mode
    func set(mode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed? = nil,
             manualIsoSensitivity: CameraIso? = nil, maximumIsoSensitivity: CameraIso? = nil,
             autoExposureMeteringMode: CameraAutoExposureMeteringMode? = nil) {

        if supportedModes.contains(mode) &&
            (manualShutterSpeed == nil || supportedManualShutterSpeeds.contains(manualShutterSpeed!)) &&
            (manualIsoSensitivity == nil || supportedManualIsoSensitivity.contains(manualIsoSensitivity!)) &&
            (maximumIsoSensitivity == nil || supportedMaximumIsoSensitivity.contains(maximumIsoSensitivity!)) {
            sendToBackend(mode: mode, manualShutterSpeed: manualShutterSpeed ?? _manualShutterSpeed,
                          manualIsoSensitivity: manualIsoSensitivity ?? _manualIsoSensitivity,
                          maximumIsoSensitivity: maximumIsoSensitivity ?? _maximumIsoSensitivity,
                          autoExposureMeteringMode: autoExposureMeteringMode ?? _autoExposureMeteringMode)
        }
    }

    private func sendToBackend(mode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed,
                               manualIsoSensitivity: CameraIso, maximumIsoSensitivity: CameraIso,
                               autoExposureMeteringMode: CameraAutoExposureMeteringMode) {
        if backend(mode, manualShutterSpeed, manualIsoSensitivity, maximumIsoSensitivity, autoExposureMeteringMode) {
            let oldMode = _mode
            let oldManualShutterSpeed = _manualShutterSpeed
            let oldManualIsoSensitivity = _manualIsoSensitivity
            let oldMaximumIsoSensitivity = _maximumIsoSensitivity
            let oldAutoExposureMeteringMode = _autoExposureMeteringMode

            _mode = mode
            _manualShutterSpeed = manualShutterSpeed
            _manualIsoSensitivity = manualIsoSensitivity
            _maximumIsoSensitivity = maximumIsoSensitivity
            _autoExposureMeteringMode = autoExposureMeteringMode
            timeout.schedule { [weak self] in
                if let `self` = self {
                    let modeUpdated = self.update(mode: oldMode)
                    let manualShutterSpeedUpdated = self.update(manualShutterSpeed: oldManualShutterSpeed)
                    let manualIsoSensitivityUpdated = self.update(manualIsoSensitivity: oldManualIsoSensitivity)
                    let maximumIsoSensitivityUpdated = self.update(maximumIsoSensitivity: oldMaximumIsoSensitivity)
                    let autoExposureMeteringModeUpdated = self.update(autoExposureMeteringMode:
                        oldAutoExposureMeteringMode)
                    if modeUpdated || manualShutterSpeedUpdated || manualIsoSensitivityUpdated ||
                        maximumIsoSensitivityUpdated || autoExposureMeteringModeUpdated {

                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
            }
            didChangeDelegate.userDidChangeSetting()
        }
    }

    /// Called by the backend, sets supported modes
    ///
    /// - Parameter newSupportedModes: new supported mode
    /// - Returns: true if the setting has been changed, false else
    func update(supportedModes newSupportedModes: Set<CameraExposureMode>) -> Bool {
        if supportedModes != newSupportedModes {
            supportedModes = newSupportedModes
            return true
        }
        return false
    }

    /// Called by the backend, sets current mode
    ///
    /// - Parameter newMode: new mode
    /// - Returns: true if the setting has been changed, false else
    func update(mode newMode: CameraExposureMode) -> Bool {
        if updating || _mode != newMode {
            _mode = newMode
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets supported manual shutter speeds
    ///
    /// - Parameter newSupportedShutterSpeeds: new supported shutter speeds
    /// - Returns: true if the setting has been changed, false else
    func update(supportedManualShutterSpeeds newSupportedShutterSpeeds: Set<CameraShutterSpeed>) -> Bool {
        if supportedManualShutterSpeeds != newSupportedShutterSpeeds {
            supportedManualShutterSpeeds = newSupportedShutterSpeeds
            return true
        }
        return false
    }

    /// Called by the backend, sets  manual shutter speeds
    /// - Parameter newShutterSpeed: new shutter speed
    /// - Returns: true if the setting has been changed, false else
    func update(manualShutterSpeed newShutterSpeed: CameraShutterSpeed) -> Bool {
        if updating || _manualShutterSpeed != newShutterSpeed {
            _manualShutterSpeed = newShutterSpeed
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets supported manual iso sensitivities
    ///
    /// - Parameter newSupportedIsoSensitivity: new supported iso sensitivities
    /// - Returns: true if the setting has been changed, false else
    func update(supportedManualIsoSensitivity newSupportedIsoSensitivity: Set<CameraIso>) -> Bool {
        if supportedManualIsoSensitivity != newSupportedIsoSensitivity {
            supportedManualIsoSensitivity = newSupportedIsoSensitivity
            return true
        }
        return false
    }

    /// Called by the backend, sets manual shutter speeds
    ///
    /// - Parameter newIsoSensitivity: new iso sensitivity
    /// - Returns: true if the setting has been changed, false else
    func update(manualIsoSensitivity newIsoSensitivity: CameraIso) -> Bool {
        if updating || _manualIsoSensitivity != newIsoSensitivity {
            _manualIsoSensitivity = newIsoSensitivity
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets supported maximum iso sensitivities
    ///
    /// - Parameter newSupportedMaximumIsoSensitivity: new supported maximum iso sensitivity
    /// - Returns: true if the setting has been changed, false else
    func update(supportedMaximumIsoSensitivity newSupportedMaximumIsoSensitivity: Set<CameraIso>) -> Bool {
        if supportedMaximumIsoSensitivity != newSupportedMaximumIsoSensitivity {
            supportedMaximumIsoSensitivity = newSupportedMaximumIsoSensitivity
            return true
        }
        return false
    }

    /// Called by the backend, sets manual shutter speeds
    ///
    /// - Parameter newMaximumIsoSensitivity: new maximum iso sensitivity
    /// - Returns: true if the setting has been changed, false else
    func update(maximumIsoSensitivity newMaximumIsoSensitivity: CameraIso) -> Bool {
        if updating || _maximumIsoSensitivity != newMaximumIsoSensitivity {
            _maximumIsoSensitivity = newMaximumIsoSensitivity
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets current auto exposure metering mode
    ///
    /// - Parameter newAutoExposureMeteringMode: new auto exposure metering mode
    /// - Returns: true if the setting has been changed, false else
    func update(autoExposureMeteringMode newAutoExposureMeteringMode: CameraAutoExposureMeteringMode) -> Bool {
        if updating || _autoExposureMeteringMode != newAutoExposureMeteringMode {
            _autoExposureMeteringMode = newAutoExposureMeteringMode
            timeout.cancel()
            return true
        }
        return false
    }

    /// Resets setting values to defaults.
    func reset() {
        supportedModes = []
        supportedManualShutterSpeeds = []
        supportedManualIsoSensitivity = []
        supportedMaximumIsoSensitivity = []
        _mode = CameraExposureSettingsCore.defaultMode
        _manualShutterSpeed = CameraExposureSettingsCore.defaultManualShutterSpeed
        _manualIsoSensitivity = CameraExposureSettingsCore.defaultManualIsoSensitivity
        _maximumIsoSensitivity = CameraExposureSettingsCore.defaultMaximumIsoSensitivity
        _autoExposureMeteringMode = CameraAutoExposureMeteringMode.standard
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
        return "(mode: \(_mode) \(supportedModes)) " +
            "(shutterSpeed: {\(_manualShutterSpeed) \(supportedManualShutterSpeeds)) " +
            "(isoSensitivy: \(_manualIsoSensitivity) \(supportedManualIsoSensitivity)) " +
            "(maxIso: \(_maximumIsoSensitivity) \(supportedMaximumIsoSensitivity)) " +
            "[\(updating)]"
    }
}

/// Objc support
extension CameraExposureSettingsCore: GSCameraExposureSettings {

    /// Checks if a mode is supported
    ///
    /// - Parameter mode: mode to check
    /// - Returns: true if the mode is supported
    func isModeSupported(_ mode: CameraExposureMode) -> Bool {
        return supportedModes.contains(mode)
    }

    /// Checks if a manual shutter speed value is supported
    ///
    /// - Parameter shutterSpeed: shutter speed to test
    /// - Returns: true if the shutter speed is supported
    func isManualShutterSpeedSupported(_ shutterSpeed: CameraShutterSpeed) -> Bool {
        return supportedManualShutterSpeeds.contains(shutterSpeed)
    }

    /// Checks if a manual iso sensitivity value is supported
    ///
    /// - Parameter iso: iso sensitivity to check
    /// - Returns: true if the iso sensitivity is supported
    func isManualIsoSensitivitySupported(_ iso: CameraIso) -> Bool {
        return supportedManualIsoSensitivity.contains(iso)
    }

    /// Checks if a maximum iso sensitivity value is supported
    ///
    /// - Parameter iso: maximum iso sensitivity to check
    /// - Returns: true if the maximum iso sensitivity is supported
    func isMaximumIsoSensitivitySupported(_ iso: CameraIso) -> Bool {
        return supportedMaximumIsoSensitivity.contains(iso)
    }

    /// Change exposure mode, manualShutterSpeed, manualIsoSensitivity, maximumIsoSensitivity and
    /// auto exposure metering mode
    ///
    /// - Parameters:
    ///   - mode: requested exposure mode
    ///   - manualShutterSpeed: requested manual shutter speed if mode is `manualShutterSpeed` or `manual`, or -1 to
    ///     keep the current value
    ///   - manualIsoSensitivity: requested iso sensitivity if exposure mode is `manualIsoSensitivity` or `manual`, or
    ///     -1 to keep the current value
    ///   - maximumIsoSensitivity: requested maximum iso sensitivity when exposure mode is `automatic`, or -1 to keep
    ///     the current value
    ///   - autoExposureMeteringMode: requested auto exposure metering mode
    func set(mode: CameraExposureMode, manualShutterSpeed: Int, manualIsoSensitivity: Int,
             maximumIsoSensitivity: Int, autoExposureMeteringMode: Int) {
        set(mode: mode, manualShutterSpeed: CameraShutterSpeed(rawValue: manualShutterSpeed),
            manualIsoSensitivity: CameraIso(rawValue: manualIsoSensitivity),
            maximumIsoSensitivity: CameraIso(rawValue: maximumIsoSensitivity),
            autoExposureMeteringMode: CameraAutoExposureMeteringMode(rawValue: autoExposureMeteringMode))
    }
}
