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

/// Leds backend part.
public protocol LedsBackend: class {
    /// Sets switch state
    ///
    /// - Parameter state: the new state
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(state: Bool) -> Bool
}

/// Internal light switch peripheral implementation
public class LedsCore: PeripheralCore, Leds {

    /// State settings
    public var state: BoolSetting? {
        return _state
    }
    /// Internal storage for state settings
    private var _state: BoolSettingCore?

    /// Whether switch is supported
    private (set) public var supportedSwitch: Bool = false

    /// implementation backend
    private unowned let backend: LedsBackend

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: leds backend
    public init(store: ComponentStoreCore, backend: LedsBackend) {
        self.backend = backend
        super.init(desc: Peripherals.leds, store: store)
    }
}

/// Backend callback methods
extension LedsCore {

    /// Set the switch state
    ///
    /// - Parameter state: tells the leds switch state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(state newValue: Bool) -> LedsCore {
        if _state == nil {
            _state = BoolSettingCore(didChangeDelegate: self) { [unowned self] newValue in
                return self.backend.set(state: newValue)
            }
        }
        if _state!.update(value: newValue) {
            markChanged()
        }
        return self
    }

    /// Set whether the switch is supported or not
    ///
    /// - Parameter supportedSwitch: tells whether the switch is supported
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(supportedSwitch newValue: Bool) -> LedsCore {
        if newValue != supportedSwitch {
            supportedSwitch = newValue
            markChanged()
        }
        return self
    }

    /// Cancels all pending settings rollbacks.
    ///
    /// - Returns: self to allow call chaining
    /// - note: changes are not notified until notifyUpdated() is called
    @discardableResult public func cancelSettingsRollback() -> LedsCore {
        _state?.cancelRollback { markChanged() }
        return self
    }
}
