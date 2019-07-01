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

/// Thermal control backend part.
public protocol ThermalControlBackend: class {
    /// Sets thermal control mode
    ///
    /// - Parameter mode: the new thermal control mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: ThermalControlMode) -> Bool

    /// Sets sensitivity range
    ///
    /// - Parameter range: the new sensitivity range
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(range: ThermalSensitivityRange) -> Bool

    /// Sets thermal camera calibration mode.
    ///
    /// - Parameter calibrationMode: the new calibration mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(calibrationMode: ThermalCalibrationMode) -> Bool

    /// Triggers a calibration of the thermal camera.
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func calibrate() -> Bool

    /// Sets emissivity
    ///
    /// - Parameter emissivity: the new emissivity
    func set(emissivity: Double)

    /// Set current palette configuration.
    ///
    /// - Parameter palette: palette configuration
    func set(palette: ThermalPalette)

    /// Set background temperature
    ///
    /// - Parameter backgroundTemperature: background temperature (Kelvin)
    func set(backgroundTemperature: Double)

    /// Set rendering
    ///
    /// - Parameter rendering: rendering configuration
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(rendering: ThermalRendering)
}

/// Thermal control setting implementation
class ThermalControlSettingCore: ThermalControlSetting, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// Supported modes
    private(set) var supportedModes: Set<ThermalControlMode> = []

    /// Current mode
    var mode: ThermalControlMode {
        get {
            return _mode
        }
        set {
            if _mode != newValue && supportedModes.contains(newValue) {
                if backend(newValue) {
                    let oldValue = _mode
                    // value sent to the backend, update setting value and mark it updating
                    _mode = newValue
                    timeout.schedule { [weak self] in
                        if let `self` = self, self.update(mode: oldValue) {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                    didChangeDelegate.userDidChangeSetting()
                }
            }
        }
    }
    /// Thermal control mode
    private var _mode: ThermalControlMode = .disabled

    /// Closure to call to change the value
    private let backend: ((ThermalControlMode) -> Bool)

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (ThermalControlMode) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, sets supported modes
    func update(supportedModes newSupportedModes: Set<ThermalControlMode>) -> Bool {
        if supportedModes != newSupportedModes {
            supportedModes = newSupportedModes
            return true
        }
        return false
    }

    /// Called by the backend, change the current mode
    ///
    /// - Parameter mode: new thermal control mode
    /// - Returns: true if the setting has been changed, false otherwise
    func update(mode newMode: ThermalControlMode) -> Bool {
        if updating || _mode != newMode {
            _mode = newMode
            timeout.cancel()
            return true
        }
        return false
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
        return "mode: \(_mode) \(supportedModes) updating: [\(updating)]"
    }
}

/// Thermal camera calibration implementation
class ThermalCalibrationCore: ThermalCalibration, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// Supported calibration modes
    var supportedModes: Set<ThermalCalibrationMode> = [.automatic, .manual]

    /// Current calibration mode
    var mode: ThermalCalibrationMode {
        get {
            return _mode
        }
        set {
            if _mode != newValue, supportedModes.contains(newValue) {
                if backend.set(calibrationMode: newValue) {
                    let oldValue = _mode
                    // value sent to the backend, update setting value and mark it updating
                    _mode = newValue
                    timeout.schedule { [weak self] in
                        if let `self` = self, self.update(mode: oldValue) {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                    didChangeDelegate.userDidChangeSetting()
                }
            }
        }
    }
    /// Calibration mode
    private var _mode: ThermalCalibrationMode = .automatic

    /// Implementation backend
    private unowned let backend: ThermalControlBackend

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: ThermalControlBackend) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, change the current calibration mode
    ///
    /// - Parameter mode: new thermal calibration mode
    /// - Returns: true if the setting has been changed, false otherwise
    func update(mode newMode: ThermalCalibrationMode) -> Bool {
        if updating || _mode != newMode {
            _mode = newMode
            timeout.cancel()
            return true
        }
        return false
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

    func calibrate() -> Bool {
        return backend.calibrate()
    }

    /// Debug description
    var debugDescription: String {
        return "calibration mode: \(_mode) \(supportedModes) updating: [\(updating)]"
    }
}

/// Sensitivity range peripheral implementation
class SensitivityRangeSettingCore: ThermalSensitivityRangeSetting, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// Supported sensitivity ranges
    var supportedSensitivityRanges: Set<ThermalSensitivityRange> = [.low, .high]

    /// closure to call to change the value
    private let backend: ((ThermalSensitivityRange) -> Bool)

    /// Sensitivity range
    var sensitivityRange: ThermalSensitivityRange {
        get {
            return _sensitivityRange
        }
        set {
            if _sensitivityRange != newValue && supportedSensitivityRanges.contains(newValue) {
                if backend(newValue) {
                    let oldValue = _sensitivityRange
                    // value sent to the backend, update setting value and mark it updating
                    _sensitivityRange = newValue
                    timeout.schedule { [weak self] in
                        if let `self` = self, self.update(range: oldValue) {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                    didChangeDelegate.userDidChangeSetting()
                }
            }
        }
    }

    private var _sensitivityRange: ThermalSensitivityRange = .high

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (ThermalSensitivityRange) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, change the current range
    ///
    /// - Parameter range: new range
    /// - Returns: true if the setting has been changed, false otherwise
    func update(range newRange: ThermalSensitivityRange) -> Bool {
        if updating || _sensitivityRange != newRange {
            _sensitivityRange = newRange
            timeout.cancel()
            return true
        }
        return false
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
        return "sensitivity range: \(_sensitivityRange) \(supportedSensitivityRanges) updating: [\(updating)]"
    }
}

/// Internal thermal control peripheral implementation
public class ThermalControlCore: PeripheralCore, ThermalControl {

    /// Thermal control mode setting
    public var setting: ThermalControlSetting {
        return _setting
    }
    private var _setting: ThermalControlSettingCore!

    public var sensitivitySetting: ThermalSensitivityRangeSetting {
        return _sensitivitySetting
    }
    private var _sensitivitySetting: SensitivityRangeSettingCore!

    /// Thermal camera calibration
    public var calibration: ThermalCalibration? {
        return _calibration
    }
    private var _calibration: ThermalCalibrationCore?

    /// Implementation backend
    private unowned let backend: ThermalControlBackend

    /// Debug description
    public override var description: String {
        return "ThermalControl : setting = \(setting)]"
    }

    /// Constructor.
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: thermal control backend
    public init(store: ComponentStoreCore, backend: ThermalControlBackend) {
        self.backend = backend
        super.init(desc: Peripherals.thermalControl, store: store)
        _setting = ThermalControlSettingCore(didChangeDelegate: self, backend: { [unowned self] mode in
            return self.backend.set(mode: mode)})

        _sensitivitySetting = SensitivityRangeSettingCore(didChangeDelegate: self, backend: { [unowned self] range in
            return self.backend.set(range: range)})
    }

    /// Sends the emissivity to drone.
    ///
    /// - Parameter emissivity: new emissivity
    /// - Note: emissivity value is in range [0, 1]
    public func sendEmissivity(_ emissivity: Double) {
        backend.set(emissivity: unsignedPercentIntervalDouble.clamp(emissivity))
    }

    /// Sends thermal palette configuration to drone.
    ///
    /// - Parameter palette: palette configuration
    public func sendPalette(_ palette: ThermalPalette) {
        backend.set(palette: palette)
    }

    /// Sends background temperature to drone.
    ///
    /// - Parameter backgroundTemperature: background temperature (Kelvin)
    public func sendBackgroundTemperature(_ backgroundTemperature: Double) {
         backend.set(backgroundTemperature: backgroundTemperature)
    }

    /// Sends rendering to drone.
    ///
    /// - Parameter rendering: rendering configuration
    public func sendRendering(rendering: ThermalRendering) {
        backend.set(rendering: rendering)
    }

    /// Sends sensitivity range to drone.
    ///
    /// - Parameter range: sensitivity range
    public func sendSensitivity(range: ThermalSensitivityRange) {
        _ = backend.set(range: range)
    }
}

/// Backend callback methods
extension ThermalControlCore {
    /// Updates supported modes.
    ///
    /// - Parameter supportedModes: new supported modes
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        supportedModes newSupportedMode: Set<ThermalControlMode>) -> ThermalControlCore {
        if _setting.update(supportedModes: newSupportedMode) {
            markChanged()
        }
        return self
    }

    /// Updates current mode.
    ///
    /// - Parameter mode: new thermal control mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(mode newMode: ThermalControlMode) -> ThermalControlCore {
        if _setting.update(mode: newMode) {
            markChanged()
        }
        return self
    }

    /// Updates sensitivity range.
    ///
    /// - Parameter range: new sensitivity range
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(range newRange: ThermalSensitivityRange) -> ThermalControlCore {
        if _sensitivitySetting.update(range: newRange) {
            markChanged()
        }
        return self
    }

    /// Updates thermal camera calibration mode.
    ///
    /// - Parameter mode: new calibration mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(mode newMode: ThermalCalibrationMode) -> ThermalControlCore {
        if _calibration == nil {
            _calibration = ThermalCalibrationCore(didChangeDelegate: self, backend: backend)
            markChanged()
        }
        if _calibration!.update(mode: newMode) {
            markChanged()
        }
        return self
    }

    /// Cancels all pending settings rollbacks.
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func cancelSettingsRollback() -> ThermalControlCore {
        _setting.cancelRollback { markChanged() }
        _calibration?.cancelRollback { markChanged() }
        return self
    }
}

/// Objc support
extension ThermalControlSettingCore: GSThermalControlSetting {
    func isModeSupported(_ mode: ThermalControlMode) -> Bool {
        return supportedModes.contains(mode)
    }
}

extension ThermalCalibrationCore: GSThermalCalibration {
    func isModeSupported(_ mode: ThermalCalibrationMode) -> Bool {
        return supportedModes.contains(mode)
    }
}

extension SensitivityRangeSettingCore: GSThermalSensitivityRangeSetting {
    func isSensitivityRangeSupported(_ range: ThermalSensitivityRange) -> Bool {
        return supportedSensitivityRanges.contains(range)
    }
}

extension ThermalControlCore: GSThermalControl {
    public var gsSetting: GSThermalControlSetting {
        return _setting
    }

    public var gsSensitivityRangeSetting: GSThermalSensitivityRangeSetting {
        return _sensitivitySetting
    }

    public var gsCalibration: GSThermalCalibration? {
        return _calibration
    }
}
