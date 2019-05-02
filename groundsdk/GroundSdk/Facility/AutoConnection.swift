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

/// Automatic connection state.
@objc(GSAutoConnectionState)
public enum AutoConnectionState: Int, CustomStringConvertible {
    /// Automatic connection is stopped.
    case stopped

    /// Automatic connection is started, and may spontaneously connect or disconnect any device.
    case started

    /// Debug description.
    public var description: String {
        switch self {
        case .stopped:  return "stopped"
        case .started:  return "started"
        }
    }
}

/// A facility that provides control of automatic connection for drone and remote control devices.
///
/// The goal of auto-connection is to ensure that exactly one remote control and exactly one drone are connected
/// whenever it is possible to do so, based on rules as described below.
///
/// GroundSdk may be configured so that auto-connection is started automatically at GroundSdk startup.
/// This behaviour is enabled by setting `AutoConnectionAtStartup` configuration flag to `YES` in the dictionary entry
/// `GroundSdk` declared in the `info.plist`. It can be disabled (this is the default) by either removing the
/// `AutoConnectionAtStartup` entry or setting it to `NO`.
/// Auto-connection may also be started and stopped manually though this Facility API.
///
/// **Remote control auto-connection:**
///
/// When started, auto-connection will try to always maintain one, and only one remote control connected. It will pick
/// one remote control amongst all currently visible devices and ensure it is connecting or connected, and will connect
/// it otherwise.
/// All other connected remote control devices are forcefully disconnected.
///
/// To chose which device will get connected, visible remote control devices are sorted by connector technology:
/// Usb is considered better than Wifi, which is considered better than Bluetooth Low-Energy. The best available
/// remote control is picked up according to this criteria and will be auto-connected.
///
/// Also, if the best available remote control is currently connected (or connecting) and an even better connector
/// becomes available for it, then it will be auto-reconnected (that is, disconnected, then connected again) using this
/// better connector.
///
/// **Drone auto-connection:**
///
/// When started, auto-connection will try to always maintain at least one, and only one drone connected.
///
/// Two different cases must be distinguished:
/// - *When no remote control is currently connected*, then drone auto-connection behaves like remote control
///   auto-connection: drones are sorted by connector technology and the drone with best technology is
///   elected for auto-connection. Auto-reconnection using an even better connector may also happen, as for
///   control devices.
///
/// - *When a remote control is connected (or connecting)*, then auto-connection will ensure that no drones are
///   connected through any other connector (including local ones: WIFI or BLE) than this remote control.
///   Any drone that is currently connected or connecting though one of these connectors will get forcefully
///   disconnected.
///   If, by the time the remote control gets auto-connected, some drone is already connected through a local
///   connector, then auto-connection will try to connect it through the remote control if the latter also knows
///   and sees that drone; otherwise auto-connection lets the remote control decide which drone to connect.
@objc(GSAutoConnection)
public protocol AutoConnection: Facility {

    /// Current state of the auto-connection.
    var state: AutoConnectionState { get }

    /// Remote control currently elected for automatic connection.
    /// `nil` if auto-connection is not started or if no remote control is currently elected.
    var remoteControl: RemoteControl? { get }

    /// Drone currently elected for automatic connection.
    /// `nil` if auto-connection is not started or if no drone is currently elected.
    var drone: Drone? { get }

    /// Starts the autoconnection.
    ///
    /// - Note: When starting the autoconnection, all currently connected drones and remotes will be disconnected.
    /// - Returns: `true` if auto-connection will effectively start, `false` otherwise.
    @discardableResult func start() -> Bool

    /// Stops the autoconnection.
    ///
    /// - Returns: `true` if auto-connection will effectively stop, `false` otherwise.
    @discardableResult func stop() -> Bool
}

/// :nodoc:
/// AutoConnection facility descriptor
@objc(GSAutoConnectionDesc)
public class AutoConnectionDesc: NSObject, FacilityClassDesc {
    public typealias ApiProtocol = AutoConnection
    public let uid = FacilityUid.autoConnection.rawValue
    public let parent: ComponentDescriptor? = nil
}
