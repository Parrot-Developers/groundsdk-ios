// Copyright (C) 2020 Parrot Drones SAS
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

/// Dri backend part.
public protocol DriBackend: class {
    /// Sets mode
    ///
    /// - Parameter mode: the new mode. `true` to activate DRI mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: Bool) -> Bool
}

/// Internal dri peripheral implementation
public class DriCore: PeripheralCore, Dri {
    /// Dri drone id
    public var droneId: (type: DriIdType, id: String)? {
        return _droneId
    }

    /// Dri mode setting
    public var mode: BoolSetting? {
        return _mode
    }

    /// Internal storage for mode settings
    private var _mode: BoolSettingCore?

    /// Internal storage for drone id
    private var _droneId: (type: DriIdType, id: String)?

    /// implementation backend
    private unowned let backend: DriBackend

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: Dri backend
    public init(store: ComponentStoreCore, backend: DriBackend) {
        self.backend = backend
        super.init(desc: Peripherals.dri, store: store)
    }
}

extension DriCore {

    /// Drone identifier.
    public struct DroneIdentifier {

        /// Identifier type.
        public let type: DriIdType

        /// Identifier.
        public let id: String

        /// Constructor.
        ///
        /// - Parameters:
        ///   - type: identifier type
        ///   - id: identifier
        public init(type: DriIdType, id: String) {
            self.type = type
            self.id = id
        }
    }

    /// Set the switch state
    ///
    /// - Parameter mode: tells the dri switch state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(mode newValue: Bool) -> DriCore {
        if _mode == nil {
            _mode = BoolSettingCore(didChangeDelegate: self) { [unowned self] newValue in
                return self.backend.set(mode: newValue)
            }
        }
        if _mode!.update(value: newValue) {
            markChanged()
        }
        return self
    }

    /// Updates the drone id
    ///
    /// - Parameter droneId : new drone identifier
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(droneId newValue: DroneIdentifier) -> DriCore {
        if _droneId?.type != newValue.type || _droneId?.id != newValue.id {
            self._droneId = (type: newValue.type, id: newValue.id)
            markChanged()
        }
        return self
    }

    /// Cancels all pending settings rollbacks.
    ///
    /// - Returns: self to allow call chaining
    /// - note: changes are not notified until notifyUpdated() is called
    @discardableResult public func cancelSettingsRollback() -> DriCore {
        _mode?.cancelRollback { markChanged() }
        return self
    }
}
