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

/// Device state information.
@objcMembers
@objc(GSDeviceState)
public class DeviceState: NSObject {
    /// Connection state.
    @objc(GSDeviceConnectionState)
    public enum ConnectionState: Int, CustomStringConvertible {
        /// Device is not connected.
        case disconnected

        /// Device is connecting.
        case connecting

        /// Device is connected.
        case connected

        /// Device is disconnecting following a user request.
        case disconnecting

        /// Debug description.
        public var description: String {
            switch self {
            case .disconnected: return "disconnected"
            case .connecting: return "connecting"
            case .connected: return "connected"
            case .disconnecting: return "disconnecting"
            }
        }
    }

    /// Detail on connection state cause.
    @objc(GSDeviceConnectionStateCause)
    public enum ConnectionStateCause: Int, CustomStringConvertible {
        /// No specific cause, valid for all states.
        case none

        /// Due to an explicit user request. Valid on all states.
        case userRequest

        /// Because the connection with the device has been lost.
        /// Valid in `connecting` state when trying to reconnect to the device
        /// and in `disconnected` state.
        case connectionLost

        /// Device refused the connection because it's already connected to a controller.
        /// Only in `disconnected` state.
        case refused

        /// Connection failed due to a bad password.
        /// Only in `disconnected` state, when connecting using a `RemoteControl` connector.
        case badPassword

        /// Connection has failed. Only in `disconnected` state.
        case failure

        /// Debug description.
        public var description: String {
            switch self {
            case .none: return "none"
            case .userRequest: return "userRequest"
            case .connectionLost: return "connectionLost"
            case .refused: return "refused"
            case .badPassword: return "badPassword"
            case .failure: return "failure"
            }
        }
    }

    /// Device connection state.
    public internal(set) var connectionState = ConnectionState.disconnected

    /// Device connection state reason.
    public internal(set) var connectionStateCause = ConnectionStateCause.none

    /// Available connectors.
    public var connectors: [DeviceConnector] { return _connectors }

    /// Active connector.
    public var activeConnector: DeviceConnector? { return _activeConnector }

    /// Whether the device can be forgotten.
    public internal(set) var canBeForgotten = false

    /// Whether the device can be connected.
    public internal(set) var canBeConnected = false

    /// Whether the device can be disconnected.
    public internal(set) var canBeDisconnected = false

    internal var _connectors = [DeviceConnectorCore]()

    internal var _activeConnector: DeviceConnectorCore?

    /// Debug description.
    override public var description: String {
        return "[\(connectionState)[\(connectionStateCause)]) \(connectors.debugDescription)]"
    }
}

/// Objective-C wrapper of Ref<DroneState>. Required because swift generics can't be used from Objective-C.
/// - Note: This class is for Objective-C only and must not be used in Swift.
@objcMembers
public class GSDeviceStateRef: NSObject {
    let ref: Ref<DeviceState>

    /// Referenced drone state.
    public var value: DeviceState? {
        return ref.value
    }

    init(ref: Ref<DeviceState>) {
        self.ref = ref
    }
}
