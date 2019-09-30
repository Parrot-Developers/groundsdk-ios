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

/// PilotingControl backend part.
public protocol PilotingControlBackend: class {
    /// Sets piloting behaviour
    ///
    /// - Parameter behaviour: the new behaviour
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(behaviour: PilotingBehaviour) -> Bool
}

/// Piloting behaviour setting implementation.
class PilotingBehaviourSettingCore: PilotingBehaviourSetting, CustomDebugStringConvertible {

    public internal(set) var supportedBehaviours: Set<PilotingBehaviour> = Set()

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// Current piloting behaviour
    var value: PilotingBehaviour {
        get {
            return _value
        }
        set {
            guard supportedBehaviours.contains(newValue) else {
                self.didChangeDelegate.userDidChangeSetting()
                return
            }
            if _value != newValue {
                if backend(newValue) {
                    let oldValue = _value
                    // value sent to the backend, update setting value and mark it updating
                    _value = newValue
                    timeout.schedule { [weak self] in
                        if let `self` = self, self.update(behaviour: oldValue) {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                    didChangeDelegate.userDidChangeSetting()
                }
            }
        }
    }
    /// Piloting Behaviour (internal value)
    private var _value: PilotingBehaviour = .standard

    /// Closure to call to change the value
    private let backend: ((PilotingBehaviour) -> Bool)

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (PilotingBehaviour) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, change the current behaviour
    ///
    /// - Parameter behaviour: new behaviour
    func update(behaviour newBehaviour: PilotingBehaviour) -> Bool {
        if updating || _value != newBehaviour {
            _value = newBehaviour
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
        return "value: \(_value) updating: [\(updating)]"
    }
}

extension PilotingBehaviourSettingCore: GSPilotingBehaviourSetting {
    func isSupportedBehaviour(_ behaviour: PilotingBehaviour) -> Bool {
        return supportedBehaviours.contains(behaviour)
    }
}

/// Internal Piloting Control peripheral implementation
public class PilotingControlCore: PeripheralCore, PilotingControl {

    ///  Behaviour setting
    public var  behaviourSetting: PilotingBehaviourSetting {
        return _behaviourSetting
    }
    private var _behaviourSetting: PilotingBehaviourSettingCore!

    /// Implementation backend
    private unowned let backend: PilotingControlBackend

    /// Debug description
    public override var description: String {
        return "PilotingControl : behaviourSetting = \(behaviourSetting)]"
    }

    /// Constructor.
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: piloting control backend
    public init(store: ComponentStoreCore, backend: PilotingControlBackend) {
        self.backend = backend
        super.init(desc: Peripherals.pilotingControl, store: store)
        _behaviourSetting = PilotingBehaviourSettingCore(didChangeDelegate: self, backend: { [unowned self] behaviour in
            return self.backend.set(behaviour: behaviour)})
    }

    /// Sends the piloting behaviour to drone.
    ///
    /// - Parameter source: new source
    public func setPilotingBehaviour(_ behaviour: PilotingBehaviour) {
        _ = backend.set(behaviour: behaviour)
    }
}

/// Extension of PilotingControlCore that implements ObjC API
extension PilotingControlCore: GSPilotingControl {
    public var gsBehaviourSetting: GSPilotingBehaviourSetting {
        return _behaviourSetting
    }
}

/// Backend callback methods
extension PilotingControlCore {

    /// Set the piloting behaviour
    ///
    /// - Parameter behaviour: the piloting behaviour
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(behaviour newBehaviour: PilotingBehaviour) -> PilotingControlCore {
        if _behaviourSetting.update(behaviour: newBehaviour) {
            markChanged()
        }
        return self
    }

    /// Set the supported piloting behaviours
    ///
    /// - Parameter behaviours: the supported behaviours
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        supportedBehaviours newSupportedBehaviours: Set<PilotingBehaviour>) -> PilotingControlCore {
        if _behaviourSetting.supportedBehaviours != newSupportedBehaviours {
            _behaviourSetting.supportedBehaviours = newSupportedBehaviours
            markChanged()
        }
        return self
    }
}
