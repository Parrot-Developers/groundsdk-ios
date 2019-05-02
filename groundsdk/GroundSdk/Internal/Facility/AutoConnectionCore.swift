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

/// Backend of the Autoconnection facility
public protocol AutoConnectionBackend: class {
    /// Requests auto-connection to start.
    ///
    /// Returns: true if auto-connection did start, false otherwise.
    func startAutoConnection() -> Bool
    /// Requests auto-connection to stop.
    ///
    /// Returns: true if auto-connection did stop, false otherwise.
    func stopAutoConnection() -> Bool
}

/// Core implementation of the Autoconnection facility
class AutoConnectionCore: FacilityCore, AutoConnection {
    private(set) var state: AutoConnectionState = .stopped

    /// Remote control device elected for auto-connection
    var remoteControlCore: RemoteControlCore?
    var remoteControl: RemoteControl? {
        if let remoteControlCore = remoteControlCore {
            return RemoteControl(remoteControlCore: remoteControlCore)
        }
        return nil
    }

    /// Drone device elected for auto-connection
    var droneCore: DroneCore?
    var drone: Drone? {
        if let droneCore = droneCore {
            return Drone(droneCore: droneCore)
        }
        return nil
    }

    /// Implementation backend
    private unowned let backend: AutoConnectionBackend

    override var description: String {
        return "AutoConnection: [\(state.description), drone = \(String(describing: drone)), " +
            "rc: \(String(describing: remoteControl))]"
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: component store owning this component
    ///   - backend: auto-connection backend
    init(store: ComponentStoreCore, backend: AutoConnectionBackend) {
        self.backend = backend
        super.init(desc: Facilities.autoConnection, store: store)
    }

    func start() -> Bool {
        return backend.startAutoConnection()
    }

    func stop() -> Bool {
        return backend.stopAutoConnection()
    }
}

/// Backend callback methods
extension AutoConnectionCore {
    /// Changes current state.
    ///
    /// - Parameter state: new state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(state newValue: AutoConnectionState) -> AutoConnectionCore {
        if state != newValue {
            state = newValue
            markChanged()
        }
        return self
    }

    /// Changes current drone selected for auto-connection.
    ///
    /// - Parameter drone: new drone
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(drone newValue: DroneCore?) -> AutoConnectionCore {
        if droneCore != newValue {
            droneCore = newValue
            markChanged()
        }
        return self
    }

    /// Changes current remote control elected for auto-connection.
    ///
    /// - Parameter remoteControl: new remote control
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(remoteControl newValue: RemoteControlCore?) -> AutoConnectionCore {
        if remoteControlCore != newValue {
            remoteControlCore = newValue
            markChanged()
        }
        return self
    }

    /// Directly notify a change on the state of the auto-connected remote control
    public func notifyRemoteControlStateChanged() {
        if remoteControlCore != nil {
            markChanged()
            notifyUpdated()
        }
    }

    /// Directly notify a change on the state of the auto-connected drone
    public func notifyDroneStateChanged() {
        if droneCore != nil {
            markChanged()
            notifyUpdated()
        }
    }
}
