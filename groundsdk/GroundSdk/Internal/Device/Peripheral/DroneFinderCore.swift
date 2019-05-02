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

/// Drone finder backend part.
public protocol DroneFinderBackend: class {
    /// Starts visible drones discovery.
    func discoverDrones()
    /// Connects a remote drone.
    ///
    /// - Parameters:
    ///   - uid: uid of the drone to connect
    ///   - password: password to use for connection. Use `nil` if the connection is not secured or to
    ///               use the RC's stored password for that drone, if any
    /// - Returns: `true` if the connection process has started, `false` otherwise
    func connectDrone(uid: String, password: String) -> Bool
}

/// Core class for `DiscoveredDrone`
public class DiscoveredDroneCore: DiscoveredDrone {

    /// Constructor
    ///
    /// - Parameters:
    ///    - uid: drone unique identifier
    ///    - model: drone model
    ///    - name: drone name
    ///    - known: whether the drone known
    ///    - rssi: rssi in dBm
    ///    - connectionSecurity: connection security
    override public init(
        uid: String, model: Drone.Model, name: String, known: Bool, rssi: Int, connectionSecurity: ConnectionSecurity) {
        super.init(uid: uid, model: model, name: name, known: known, rssi: rssi, connectionSecurity: connectionSecurity)
    }
}

/// Internal manual copter piloting interface implementation
public class DroneFinderCore: PeripheralCore, DroneFinder {

    /// Implementation backend
    private unowned let backend: DroneFinderBackend

    /// Current drone finder state
    private (set) public var state: DroneFinderState = .idle

    /// List of discovered drones
    private (set) public var discoveredDrones = [DiscoveredDrone]()

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: DroneFinder backend
    public init(store: ComponentStoreCore, backend: DroneFinderBackend) {
        self.backend = backend
        super.init(desc: Peripherals.droneFinder, store: store)
    }

    /// Clears the current list of discovered drones.
    ///
    /// After calling this method, discoveredDrones is an empty list
    public func clear() {
        discoveredDrones.removeAll()
        // notify the changes
        markChanged()
        notifyUpdated()
    }

    /// Asks for an update of the list of discovered drones.
    public func refresh() {
        backend.discoverDrones()
    }

    /// Connect a discovered drone
    ///
    /// - Parameter discoveredDrone: discovered drone to connect
    /// - Returns: true if the connection process has started
    public func connect(discoveredDrone: DiscoveredDrone) -> Bool {
        return backend.connectDrone(uid: discoveredDrone.uid, password: "")
    }

    /// Connect a discovered drone with a password
    ///
    /// - Parameters:
    ///    - discoveredDrone: discovered drone to connect
    ///    - password: password to use for connection
    /// - Returns: true if the connection process has started
    public func connect(discoveredDrone: DiscoveredDrone, password: String) -> Bool {
        return backend.connectDrone(uid: discoveredDrone.uid, password: password)
    }
}

/// Backend callback methods
extension DroneFinderCore {
    /// Changes current state.
    ///
    /// - Parameter state: new state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(state newValue: DroneFinderState) -> DroneFinderCore {
        if state != newValue {
            state = newValue
            markChanged()
        }
        return self
    }

    /// Changes current discovered drone list.
    ///
    /// - Parameter discoveredDrones: new discovered drone list
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(discoveredDrones newValue: [DiscoveredDrone]) -> DroneFinderCore {
        discoveredDrones = newValue
        markChanged()
        return self
    }
}
