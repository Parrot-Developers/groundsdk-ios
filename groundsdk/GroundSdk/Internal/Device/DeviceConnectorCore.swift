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

/// Device connector implementation
public class DeviceConnectorCore: NSObject, DeviceConnector {

    /// Connector type
    public let connectorType: DeviceConnectorType

    /// For type remote control, uid of the remote control
    public let uid: String

    /// Technology used for device connection
    public let technology: DeviceConnectorTechnology

    /// `true` if the connector supports disconnect
    public let supportsDisconnect: Bool

    /// Constructor
    ///
    /// - Parameters:
    ///    - connectorType: connector type
    ///    - uid: connector description
    ///    - technology: technology used for device connection
    ///    - supportsDisconnect: true if the connector supports disconnect
    public init(connectorType: DeviceConnectorType, uid: String, technology: DeviceConnectorTechnology,
                supportsDisconnect: Bool) {
        self.connectorType = connectorType
        self.uid = uid
        self.technology = technology
        self.supportsDisconnect = supportsDisconnect
    }

    /// Debug description
    public override var description: String {
        switch connectorType {
        case .local: return "local-\(technology)"
        case .remoteControl: return "remoteControl-\(uid)"
        }
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? DeviceConnectorCore {
            return connectorType == object.connectorType && uid == object.uid &&
                technology == object.technology
        }
        return false
    }
}

/// Singleton of a local connector
@objcMembers    // objc availability for testing purpose
public class LocalDeviceConnectorCore: DeviceConnectorCore {
    /// Local connection through Wifi
    public static let wifi = DeviceConnectorCore(
        connectorType: .local, uid: "local-wifi", technology: .wifi, supportsDisconnect: true)
    /// Local connection through USB
    public static let usb = DeviceConnectorCore(
        connectorType: .local, uid: "local-usb", technology: .usb, supportsDisconnect: true)
    /// Local connection through Bluetooth Low Energy
    public static let ble = DeviceConnectorCore(
        connectorType: .local, uid: "local-ble", technology: .ble, supportsDisconnect: true)
}

/// Connector for a Remote control
public class RemoteControlDeviceConnectorCore: DeviceConnectorCore {

    /// Constructor
    ///
    /// - Parameter uid: remote control uid
    public init(uid: String) {
        super.init(connectorType: .remoteControl, uid: uid, technology: .wifi, supportsDisconnect: false)
    }
}

extension DeviceConnector {
    /// Gets whether a given connector is better than this one
    ///
    /// - Parameter connector: the connector to compare to
    /// - Returns: `true` if this connector's type is better than the other.
    ///   If they are equals, returns `true` if they have the same type and the technology is better than the other one.
    func betterThan(_ connector: DeviceConnector) -> Bool {
        if connectorType.betterThan(connector.connectorType) {
            return true
        }
        return connectorType == connector.connectorType && technology.betterThan(connector.technology)
    }

    /// Gets whether a given connector is better or equal to this one
    ///
    /// - Parameter connector: the connector to compare to
    /// - Returns: `true` if this connector's type is better or equal to the other.
    ///   If they are equals, returns `true` if they have the same type and the technology is better than the other one.
    func betterOrEqualTo(_ connector: DeviceConnector) -> Bool {
        if connectorType.betterThan(connector.connectorType) {
            return true
        }
        if connectorType == connector.connectorType && technology.betterThan(connector.technology) {
            return true
        }
        return connectorType == connector.connectorType && technology == connector.technology
    }
}

extension DeviceConnectorTechnology {
    /// Gets whether a given technology is better than this one
    ///
    /// Order is given like that:
    ///    usb is better than wifi which is better than ble.
    ///
    /// - Parameter technology: the technology to compare to
    /// - Returns: `true` if the technology is strictly better
    func betterThan(_ technology: DeviceConnectorTechnology) -> Bool {
        let ranks: [DeviceConnectorTechnology: Int] = [
            .ble: 0,
            .wifi: 1,
            .usb: 2]
        return ranks[self]! > ranks[technology]!
    }
}
