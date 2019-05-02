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

/// Device connector types.
@objc(GSDeviceConnectorType)
public enum DeviceConnectorType: Int, CustomStringConvertible {

    /// Connect using local connectivity.
    case local

    /// Connect using a remote control.
    case remoteControl

    /// Debug description.
    public var description: String {
        switch self {
        case .local: return "local"
        case .remoteControl: return "remoteControl"
        }
    }
}

extension DeviceConnectorType {
    /// Tells whether a given connector type is better than this type.
    ///
    /// - Parameter connectorType: the connector type to compare to
    /// - Returns: `true` if this connector type is remoteControl and the other one is local
    func betterThan(_ connectorType: DeviceConnectorType) -> Bool {
        return self == .remoteControl && connectorType == .local
    }
}

/// Technology used device connection.
@objc(GSDeviceConnectorTechnology)
public enum DeviceConnectorTechnology: Int, CustomStringConvertible {

    /// Connect using Wifi.
    case wifi
    /// Connect using USB.
    case usb
    /// Connect using Bluetooth Low Energy.
    case ble

    /// Debug description.
    public var description: String {
        switch self {
        case .wifi: return "wifi"
        case .usb: return "usb"
        case .ble: return "ble"
        }
    }
}

/// Connector providing device connection.
/// Available connector of a device can be retrieved from the device state and used to connect a device.
@objc(GSDeviceConnector)
public protocol DeviceConnector {

    /// Connector type.
    var connectorType: DeviceConnectorType { get }

    /// Uid of the connector.
    var uid: String { get }

    /// Connector technology.
    var technology: DeviceConnectorTechnology { get }

    /// Debug description.
    var description: String { get }
}

/// DeviceConnector comparator.
///
/// - Parameters:
///    - lhs: left operand
///    - rhs: right operand
///
/// - Returns: `true` if connector type, connector technology and uid are the same
public func == (lhs: DeviceConnector, rhs: DeviceConnector) -> Bool {
    return lhs.connectorType == rhs.connectorType && lhs.uid == rhs.uid
}

/// DeviceConnector inequality comparator.
///
/// - Parameters:
///    - lhs: left operand
///    - rhs: right operand
///
/// - returns: `true` if not equals
public func != (lhs: DeviceConnector, rhs: DeviceConnector) -> Bool {
    return !(lhs == rhs)
}
