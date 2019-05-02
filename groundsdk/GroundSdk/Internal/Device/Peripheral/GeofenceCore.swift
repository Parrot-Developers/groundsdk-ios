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
import CoreLocation

/// Geofence backend part.
public protocol GeofenceBackend: class {
    /// Sets geofence mode
    ///
    /// - Parameter mode: the new geofence mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: GeofenceMode) -> Bool

    /// change the maximum altitude
    func set(maxAltitude value: Double) -> Bool

    /// change the maximum distance
    func set(maxDistance value: Double) -> Bool
}

/// Geofence Mode parameter
class GeofenceModeSettingCore: GeofenceModeSetting, CustomStringConvertible {

    /// Delegate called when the setting value is changed by setting `value` property
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    var value: GeofenceMode {
        get {
            return _value
        }

        set {
            if _value != newValue {
                if backend(newValue) {
                    let oldValue = _value
                    // value sent to the backend, update setting value and mark it updating
                    _value = newValue
                    timeout.schedule { [weak self] in
                        if let `self` = self, self.update(value: oldValue) {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                    didChangeDelegate.userDidChangeSetting()
                }
            }
        }
    }

    /// Current geofence mode value
    private var _value: GeofenceMode = .altitude
    /// Closure to call to change the value. Return true if the new value has been sent and setting must become updating
    private let backend: (GeofenceMode) -> Bool

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting `value` property
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (GeofenceMode) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, change the setting data
    ///
    /// - Parameter value: new environment
    /// - Returns: true if the setting has been changed, false otherwise
    func update(value newValue: GeofenceMode) -> Bool {
        if updating || _value != newValue {
            _value = newValue
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

    // CustomStringConvertible concordance
    var description: String {
        return "GeofenceModeSetting: \(_value)  updating: [\(updating)]"
    }
}

/// Internal Geofence peripheral implementation
public class GeofenceCore: PeripheralCore, Geofence {

    public var maxAltitude: DoubleSetting {
        return _maxAltitude
    }
    /// maxAltitude setting internal implementation
    private var _maxAltitude: DoubleSettingCore!

    public var maxDistance: DoubleSetting {
        return _maxDistance
    }
    /// maxDistance setting internal implementation
    private var _maxDistance: DoubleSettingCore!

    public var mode: GeofenceModeSetting {
        return _mode
    }
    /// Mode setting internal implementation
    private var _mode: GeofenceModeSettingCore!

    public private(set) var center: CLLocation?

    /// Implementation backend
    private unowned let backend: GeofenceBackend

    /// Debug description
    public override var description: String {
        return "Geofence: mode = \(mode) maxAltitude = \(maxAltitude) maxDistance = \(maxDistance)]"
    }

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: Geofence backend
    public init(store: ComponentStoreCore, backend: GeofenceBackend) {
        self.backend = backend
        super.init(desc: Peripherals.geofence, store: store)
        _mode = GeofenceModeSettingCore(didChangeDelegate: self) { [unowned self] mode in
            return self.backend.set(mode: mode)
        }
        _maxAltitude = DoubleSettingCore(didChangeDelegate: self) { [unowned self] newValue in
            return self.backend.set(maxAltitude: newValue)
        }
        _maxDistance = DoubleSettingCore(didChangeDelegate: self) { [unowned self] newValue in
            return self.backend.set(maxDistance: newValue)
        }

    }
}

/// Backend callback methods
extension GeofenceCore {

    /// Update current mode
    ///
    /// - Parameter mode: new geofence mode.
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(mode newValue: GeofenceMode) -> GeofenceCore {
        if _mode.update(value: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes maximum altitude settings
    ///
    /// - Parameter maxAltitude: tuple containing new values. Only not nil values are updated
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(maxAltitude newSetting: (min: Double?, value: Double?, max: Double?))
        -> GeofenceCore {
            if _maxAltitude!.update(min: newSetting.min, value: newSetting.value, max: newSetting.max) {
                markChanged()
            }
            return self
    }

    /// Changes maximum distance settings
    ///
    /// - Parameter maxDistance: tuple containing new values. Only not nil values are updated
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(maxDistance newSetting: (min: Double?, value: Double?, max: Double?))
        -> GeofenceCore {
            if _maxDistance!.update(min: newSetting.min, value: newSetting.value, max: newSetting.max) {
                markChanged()
            }
            return self
    }

    /// Update center location
    ///
    /// - Parameter value: new geofence value.
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(center newValue: CLLocation?) -> GeofenceCore {
        if newValue != center {
            center = newValue
            markChanged()
        }
        return self
    }

    /// Cancels all pending settings rollbacks.
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func cancelSettingsRollback() -> GeofenceCore {
        _mode.cancelRollback { markChanged() }
        _maxAltitude.cancelRollback { markChanged() }
        _maxDistance.cancelRollback { markChanged() }
        return self
    }
}
