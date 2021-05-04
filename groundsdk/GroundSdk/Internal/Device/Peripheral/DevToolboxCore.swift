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

/// Development toolbox backend part.
public protocol DevToolboxBackend: class {
    /// Sets the value of a boolean debug setting.
    ///
    /// - Parameter setting: setting to set
    func set(setting: BoolDebugSettingCore)

    /// Sets the value of a textual debug setting.
    ///
    /// - Parameter setting: setting to set
    func set(setting: TextDebugSettingCore)

    /// Sets the value of a numerical debug setting.
    ///
    /// - Parameter setting: setting to set
    func set(setting: NumericDebugSettingCore)

    /// Sends a debug tag to the drone.
    ///
    /// - Parameter tag: debug tag to send, shall be a single-line string
    func sendDebugTag(tag: String)
}

/// Core implementation of a `DebugSetting`.
public class DebugSettingCore: DebugSetting {

    /// Delegate called when the setting value is changed by setting `value` property.
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Closure to call to change the value.
    private let backend: ((DebugSettingCore) -> Void)

    public var updating = false

    public let uid: UInt

    public let type: DebugSettingType

    public let name: String

    public let readOnly: Bool

    /// Constructor.
    ///
    /// - Parameters:
    ///   - uid: setting unique identifier
    ///   - type: setting type
    ///   - name: setting name
    ///   - readOnly: whether the setting can be modified
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting `value` property
    ///   - backend: closure to call to change the setting value
    init(uid: UInt, type: DebugSettingType, name: String, readOnly: Bool,
         didChangeDelegate: SettingChangeDelegate, backend: @escaping (DebugSettingCore) -> Void) {
        self.uid = uid
        self.type = type
        self.name = name
        self.readOnly = readOnly
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by subclasses when their value has changed.
    func onValueChanged() {
        updating = true
        didChangeDelegate.userDidChangeSetting()
        backend(self)
    }
}

/// Extension to `DebugSettingCore`to conform to `Equatable` protocol.
extension DebugSettingCore: Equatable {
    public static func == (lhs: DebugSettingCore, rhs: DebugSettingCore) -> Bool {
        return lhs.uid == rhs.uid
            && lhs.type == rhs.type
            && lhs.name == rhs.name
            && lhs.readOnly == rhs.readOnly
    }
}

/// Core implementation of a `BoolDebugSetting`.
public class BoolDebugSettingCore: DebugSettingCore, BoolDebugSetting {

    /// Setting value.
    public var value: Bool {
        get {
            return _value
        }

        set {
            if !readOnly, _value != newValue {
                _value = newValue
                onValueChanged()
            }
        }
    }
    /// Internal value.
    var _value = false

    /// Constructor.
    ///
    /// - Parameters:
    ///   - uid: setting unique identifier
    ///   - name: setting name
    ///   - readOnly: whether the setting can be modified
    ///   - value: setting value
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting `value` property
    ///   - backend: closure to call to change the setting value
    init(uid: UInt, name: String, readOnly: Bool, value: Bool,
         didChangeDelegate: SettingChangeDelegate, backend: @escaping (DebugSettingCore) -> Void) {
        super.init(uid: uid, type: .boolean, name: name, readOnly: readOnly,
                   didChangeDelegate: didChangeDelegate, backend: backend)
        self._value = value
    }

    /// Called by the backend, change the setting value.
    ///
    /// - Parameter value: the new setting value
    /// - Returns: `true` if the setting has been changed, `false` otherwise
    func update(value newValue: Bool) -> Bool {
        var changed = false
        if updating || _value != newValue {
            updating = false
            _value = newValue
            changed = true
        }
        return changed
    }
}

/// Core implementation of a `TextDebugSetting`.
public class TextDebugSettingCore: DebugSettingCore, TextDebugSetting {

    /// Setting value.
    public var value: String {
        get {
            return _value
        }

        set {
            if !readOnly, _value != newValue {
                _value = newValue
                onValueChanged()
            }
        }
    }
    /// Internal value.
    var _value = ""

    /// Constructor.
    ///
    /// - Parameters:
    ///   - uid: setting unique identifier
    ///   - name: setting name
    ///   - readOnly: whether the setting can be modified
    ///   - value: setting value
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting `value` property
    ///   - backend: closure to call to change the setting value
    init(uid: UInt, name: String, readOnly: Bool, value: String,
         didChangeDelegate: SettingChangeDelegate, backend: @escaping (DebugSettingCore) -> Void) {
        super.init(uid: uid, type: .text, name: name, readOnly: readOnly,
                   didChangeDelegate: didChangeDelegate, backend: backend)
        self._value = value
    }

    /// Called by the backend, change the setting value.
    ///
    /// - Parameter value: the new setting value
    /// - Returns: `true` if the setting has been changed, `false` otherwise
    func update(value newValue: String) -> Bool {
        var changed = false
        if updating || _value != newValue {
            updating = false
            _value = newValue
            changed = true
        }
        return changed
    }
}

/// Core implementation of a `NumericDebugSetting`.
public class NumericDebugSettingCore: DebugSettingCore, NumericDebugSetting {

    /// Setting value.
    public var value: Double {
        get {
            return _value
        }

        set {
            if !readOnly, _value != newValue {
                _value = newValue
                onValueChanged()
            }
        }
    }
    /// Internal value.
    var _value = 0.0

    /// Value bounds.
    public let range: ClosedRange<Double>?

    /// Value steps.
    public let step: Double?

    /// Constructor.
    ///
    /// - Parameters:
    ///   - uid: setting unique identifier
    ///   - name: setting name
    ///   - readOnly: whether the setting can be modified
    ///   - range: setting value bounds
    ///   - step: setting value step
    ///   - value: setting value
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting `value` property
    ///   - backend: closure to call to change the setting value
    init(uid: UInt, name: String, readOnly: Bool, range: ClosedRange<Double>?, step: Double?, value: Double,
         didChangeDelegate: SettingChangeDelegate, backend: @escaping (DebugSettingCore) -> Void) {
        self.range = range
        self.step = step
        super.init(uid: uid, type: .numeric, name: name, readOnly: readOnly,
                   didChangeDelegate: didChangeDelegate, backend: backend)
        self._value = value
    }

    /// Called by the backend, change the setting value.
    ///
    /// - Parameter value: the new setting value
    /// - Returns: `true` if the setting has been changed, `false` otherwise
    func update(value newValue: Double) -> Bool {
        var changed = false
        if updating || _value != newValue {
            updating = false
            _value = newValue
            changed = true
        }
        return changed
    }
}

/// Development toolbox peripheral implementation.
public class DevToolboxCore: PeripheralCore, DevToolbox {

    /// Implementation backend.
    private unowned let backend: DevToolboxBackend

    /// Debug settings.
    public var debugSettings: [DebugSetting] {
        return _debugSettings
    }
    /// Internal debug settings.
    private var _debugSettings: [DebugSettingCore] = []

    /// Latest debug tag id generated by the drone.
    public var latestDebugTagId: String? {
        return _latestDebugTagId
    }
    /// Internal latest debug tag id generated by the drone.
    public var _latestDebugTagId: String?

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: store where this peripheral will be stored
    ///   - backend: Antiflicker backend
    public init(store: ComponentStoreCore, backend: DevToolboxBackend) {
        self.backend = backend
        super.init(desc: Peripherals.devToolbox, store: store)
    }

    public func sendDebugTag(tag: String) {
        backend.sendDebugTag(tag: tag)
    }
}

/// Backend callback methods.
extension DevToolboxCore {

    /// Creates a boolean debug setting.
    ///
    /// - Parameters:
    ///   - uid: setting unique identifier
    ///   - name: setting name
    ///   - readOnly: whether the setting can be modified
    ///   - value: setting value
    /// - Returns: a new boolean debug setting
    public func createDebugSetting(uid: UInt, name: String, readOnly: Bool, value: Bool) -> BoolDebugSettingCore {
        return BoolDebugSettingCore(uid: uid, name: name, readOnly: readOnly, value: value,
                                       didChangeDelegate: self) { [unowned self] setting in
                                        self.backend.set(setting: setting as! BoolDebugSettingCore)
        }
    }

    /// Creates a textual debug setting.
    ///
    /// - Parameters:
    ///   - uid: setting unique identifier
    ///   - name: setting name
    ///   - readOnly: whether the setting can be modified
    ///   - value: setting value
    /// - Returns: a new textual debug setting
    public func createDebugSetting(uid: UInt, name: String, readOnly: Bool, value: String) -> TextDebugSettingCore {
        return TextDebugSettingCore(uid: uid, name: name, readOnly: readOnly, value: value,
                                    didChangeDelegate: self) { [unowned self] setting in
                                        self.backend.set(setting: setting as! TextDebugSettingCore)
        }
    }

    /// Creates a numerical debug setting.
    ///
    /// - Parameters:
    ///   - uid: setting unique identifier
    ///   - name: setting name
    ///   - readOnly: whether the setting can be modified
    ///   - range: setting value bounds
    ///   - step: setting value step
    ///   - value: setting value
    /// - Returns: a new numerical debug setting
    public func createDebugSetting(uid: UInt, name: String, readOnly: Bool, range: ClosedRange<Double>?, step: Double?,
                                   value: Double) -> NumericDebugSettingCore {
        return NumericDebugSettingCore(uid: uid, name: name, readOnly: readOnly, range: range,
                                         step: step, value: value,
                                         didChangeDelegate: self) { [unowned self] setting in
                                            self.backend.set(setting: setting as! NumericDebugSettingCore)
        }
    }

    /// Updates debug settings.
    ///
    /// - Parameter debugSettings: new debug settings
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    public func update(debugSettings newDebugSettings: [DebugSettingCore]) -> DevToolboxCore {
        if _debugSettings != newDebugSettings {
            _debugSettings = newDebugSettings
            markChanged()
        }
        return self
    }

    /// Updates the value of a given boolean debug setting.
    ///
    /// - Parameters:
    ///   - debugSetting: debug setting to update
    ///   - value: new value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    public func update(debugSetting: BoolDebugSettingCore, value newValue: Bool) -> DevToolboxCore {
        if debugSetting.update(value: newValue) {
            markChanged()
        }
        return self
    }

    /// Updates the value of a given textual debug setting.
    ///
    /// - Parameters:
    ///   - debugSetting: debug setting to update
    ///   - value: new value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    public func update(debugSetting: TextDebugSettingCore, value newValue: String) -> DevToolboxCore {
        if debugSetting.update(value: newValue) {
            markChanged()
        }
        return self
    }

    /// Updates the value of a given numerical debug setting.
    ///
    /// - Parameters:
    ///   - debugSetting: debug setting to update
    ///   - value: new value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    public func update(debugSetting: NumericDebugSettingCore, value newValue: Double) -> DevToolboxCore {
        if debugSetting.update(value: newValue) {
            markChanged()
        }
        return self
    }

    /// Updates the latest debug tag id generated by the drone.
    ///
    /// - Parameter debugTagId: new debug tag id
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    public func update(debugTagId: String) -> DevToolboxCore {
        if _latestDebugTagId != debugTagId {
            _latestDebugTagId = debugTagId
            markChanged()
        }
        return self
    }
}
