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

/// Drone connection security type.
@objc(GSConnectionSecurity)
public enum ConnectionSecurity: Int {

    /// Drone is not secured, i.e. it can be connected to without password.
    case none

    /// Drone is secured with a password, i.e. the user is required to provide it for connection.
    case password

    /// Drone is secured, yet the RemoteControl  device that discovered it has a stored password to
    /// use for connection, so the user is not required to provide a password for connection.
    ///
    /// Note however, that the RC's saved password might be wrong and the user might need to fallback providing
    /// a password for connection.
    case savedPassword

    /// Debug description.
    public var description: String {
        switch self {
        case .none:
            return "none"
        case .password:
            return "password"
        case .savedPassword:
            return "savedPassword"
        }
    }
}

/// Represents a remote drone seen during discovery.
@objcMembers
@objc(GSDiscoveredDrone)
public class DiscoveredDrone: NSObject {

    /// Drone unique identifier.
    public let uid: String

    /// Drone model.
    public let model: Drone.Model

    /// Drone name.
    public let name: String

    /// Rssi in dBm, usually between -30 (good signal) and -80 (very bad signal level).
    public let rssi: Int

    /// Whether the drone known.
    public let known: Bool

    /// Connection security.
    public let connectionSecurity: ConnectionSecurity

    /// Constructor.
    /// - Parameters:
    ///    - uid: drone unique identifier
    ///    - model: drone model
    ///    - name: drone name
    ///    - known: is the drone known
    ///    - rssi: rssi in dBm
    ///    - connectionSecurity: connection security
    init(uid: String, model: Drone.Model, name: String, known: Bool, rssi: Int,
         connectionSecurity: ConnectionSecurity) {
        self.uid = uid
        self.model = model
        self.name = name
        self.known = known
        self.rssi = rssi
        self.connectionSecurity = connectionSecurity
    }

    /// Debug description.
    override open var description: String {
        return "DiscoveredDrone \(uid) \(model) \(name) \(known ? "known " : "") " +
        "rssi:\(rssi) secutity:\(connectionSecurity)"
    }
}

/// DroneFinder state.
@objc(GSDroneFinderState)
public enum DroneFinderState: Int {

    /// Not scanning for drone at the moment.
    case idle

    /// Currently scanning for visible drones.
    case scanning

    /// Debug description.
    public var description: String {
        switch self {
        case .idle:
            return "idle"
        case .scanning:
            return "scanning"
        }
    }
}

/// DroneFinder peripheral for RemoteControl devices.
///
/// Allows scanning for visible drones and provides a way to connect to such discovered drones.
///
/// This peripheral can be obtained from a remote control using:
/// ```
/// remoteControl.getPeripheral(Peripherals.droneFinder)
/// ```
@objc(GSDroneFinder)
public protocol DroneFinder: Peripheral {

    /// Current drone finder state.
    var state: DroneFinderState { get }

    /// List of drones discovered during last discovery.
    var discoveredDrones: [DiscoveredDrone] { get }

    /// Clears the current list of discovered drones.
    ///
    /// After calling this method, discoveredDrones is an empty list.
    func clear()

    /// Asks for an update of the list of discovered drones.
    func refresh()

    /// Connects a discovered drone.
    ///
    /// - Parameter discoveredDrone: discovered drone to connect
    /// - Returns: `true` if the connection process has started
    func connect(discoveredDrone: DiscoveredDrone) -> Bool

    /// Connects a discovered drone with a password.
    ///
    /// - Parameters:
    ///    - discoveredDrone: discovered drone to connect
    ///    - password: password to use for connection
    /// - Returns: `true` if the connection process has started
    func connect(discoveredDrone: DiscoveredDrone, password: String) -> Bool
}

/// :nodoc:
/// Drone finder descriptor
@objc(GSDroneFinderDesc)
public class DroneFinderDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = DroneFinder
    public let uid = PeripheralUid.droneFinder.rawValue
    public let parent: ComponentDescriptor? = nil
}
