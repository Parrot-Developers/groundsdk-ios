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

/// Model of a device.
public enum DeviceModel: CustomStringConvertible {

    /// Drone model.
    case drone(Drone.Model)

    /// Remote control model.
    case rc(RemoteControl.Model)

    /// Internal unique identifier.
    public var internalId: Int {
        switch self {
        case .drone(let drone): return drone.internalId
        case .rc(let rc):       return rc.internalId
        }
    }

    /// Debug description.
    public var description: String {
        switch self {
        case .drone(let drone): return drone.description
        case .rc(let rc):       return rc.description
        }
    }

    /// Uid of the default model.
    /// A default model will be available if the app is providing an app defaults. See `GroundSdkConfig.defaultDevices`.
    public var defaultModelUid: String {
        return "default-\(description)"
    }

    /// All known device models.
    public static var allDevices: Set<DeviceModel> {
        var allDevices: Set<DeviceModel> = []
        for drone in Drone.Model.allCases {
            allDevices.insert(.drone(drone))
        }
        for rc in RemoteControl.Model.allCases {
            allDevices.insert(.rc(rc))
        }

        return allDevices
    }

    /// Map of device models, by their associated name.
    private static var modelsByName: [String: DeviceModel] {
        var modelsByName: [String: DeviceModel] = [:]
        for drone in Drone.Model.allCases {
            modelsByName[drone.description] = .drone(drone)
        }
        for rc in RemoteControl.Model.allCases {
            modelsByName[rc.description] = .rc(rc)
        }

        return modelsByName
    }

    /// Map of device models, by their associated internal id.
    private static var modelsByInternalId: [Int: DeviceModel] {
        var modelsByInternalId: [Int: DeviceModel] = [:]
        for drone in Drone.Model.allCases {
            modelsByInternalId[drone.internalId] = .drone(drone)
        }
        for rc in RemoteControl.Model.allCases {
            modelsByInternalId[rc.internalId] = .rc(rc)
        }

        return modelsByInternalId
    }

    /// List of devices that can be connectable through usb.
    private static var usbDevices: Set<DeviceModel> = [.rc(.skyCtrl3)]

    /// List of devices that can be connectable through wifi.
    private static var wifiDevices: Set<DeviceModel> = [.drone(.anafi4k), .drone(.anafiThermal)]

    /// List of devices that can be connectable through BLE.
    private static var bleDevices: Set<DeviceModel> = []

    /// Filters device models that support a given technology.
    ///
    /// - Parameters:
    ///   - models: set of device models to filter
    ///   - technology: technology that must be supported
    /// - Returns: a subset of the given device models that support this technology
    public static func supportingTechnology(
        models: Set<DeviceModel>, technology: DeviceConnectorTechnology) -> Set<DeviceModel> {

        switch technology {
        case .usb:
            return usbDevices.intersection(models)
        case .wifi:
            return wifiDevices.intersection(models)
        case .ble:
            return bleDevices.intersection(models)
        }
    }

    /// Retrieves a device model by its name.
    ///
    /// - Parameter name: name of the device model to retrieve
    /// - Returns: the corresponding `DeviceModel`, or `nil` if no model with such a name exists
    public static func from(name: String) -> DeviceModel? {
        return modelsByName[name]
    }

    /// Retrieves a device model by its internal id.
    ///
    /// - Parameter internalId: internal id of the device model to retrieve
    /// - Returns: the corresponding `DeviceModel`, or `nil` if no model with such internal id exists
    public static func from(internalId: Int) -> DeviceModel? {
        return modelsByInternalId[internalId]
    }

    /// Retrieves a device model by its internal id as hex string.
    ///
    /// - Parameter internalIdHexStr: internal id of the device model to retrieve
    /// - Returns: the corresponding `DeviceModel`, or `nil` if no model with such internal id exists
    public static func from(internalIdHexStr: String) -> DeviceModel? {
        if let internalId = Int(internalIdHexStr, radix: 16) {
            return from(internalId: internalId)
        }
        return nil
    }
}

/// Extension of DeviceModel that implements the Hashable protocol.
extension DeviceModel: Hashable {

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .drone(let model):
            hasher.combine(model.rawValue)
        case .rc(let model):
            hasher.combine(model.rawValue)
        }
    }

    public static func == (lhs: DeviceModel, rhs: DeviceModel) -> Bool {
        switch (lhs, rhs) {
        case (.drone(let lhsModel), .drone(let rhsModel)):
            return lhsModel == rhsModel
        case (.rc(let lhsModel), .rc(let rhsModel)):
            return lhsModel == rhsModel
        default:
            return false
        }
    }
}

/// Model of a device.
/// - Note: This class is only intended to be used in ObjC. In Swift, use `DeviceModel`.
@objcMembers
public class GSDeviceModel: NSObject {
    /// The device model.
    let deviceModel: DeviceModel

    /// Internal unique identifier.
    public var internalId: Int {
        return deviceModel.internalId
    }

    /// Internal unique identifier.
    public override var description: String {
        return deviceModel.description
    }

    /// Constructor.
    ///
    /// - Parameter deviceModel: device model
    init(deviceModel: DeviceModel) {
        self.deviceModel = deviceModel
        super.init()
    }

    /// Thells whether this device model is a drone.
    ///
    /// - Returns: `true` if the device model is a drone
    public func isDrone() -> Bool {
        if case DeviceModel.drone = deviceModel {
            return true
        }
        return false
    }

    /// Tells whether this device model is a remote control
    ///
    /// - Returns: `true` if the device model is a remote control
    public func isRemoteControl() -> Bool {
        if case DeviceModel.rc = deviceModel {
            return true
        }
        return false
    }

    /// Gets the drone raw value of this device model.
    /// To use the returned value, you can create a drone model with:
    /// `Drone.Model(rawValue: self.droneValue())`
    ///
    /// - Returns: the raw value of the drone if `isDrone()` returns `true`, negative value otherwise.
    public func droneValue() -> Int {
        if case let DeviceModel.drone(drone) = deviceModel {
            return drone.rawValue
        }
        return -1
    }

    /// Gets the remote control raw value of this device model
    /// To use the returned value, you can create a remote control model with:
    /// `RemoteControl.Model(rawValue: self.remoteControlValueValue())`
    ///
    /// - Returns: the raw value of the remote control if `isRemoteControl()` returns `true`, negative value otherwise.
    public func remoteControlValue() -> Int {
        if case let DeviceModel.rc(rc) = deviceModel {
            return rc.rawValue
        }
        return -1
    }

    /// All known device models.
    public static var allDevices: Set<GSDeviceModel> {
        return Set(DeviceModel.allDevices.map { GSDeviceModel(deviceModel: $0) })
    }

    /// Filters device models that support a given technology.
    ///
    /// - Parameters:
    ///   - models: set of device models to filter
    ///   - technology: technology that must be supported
    /// - Returns: a subset of the given device models that support this technology
    public static func supportingTechnology(
        models: Set<GSDeviceModel>, technology: DeviceConnectorTechnology) -> Set<GSDeviceModel> {

        let extractedModels = Set(models.map { $0.deviceModel })
        let supporting = DeviceModel.supportingTechnology(models: extractedModels, technology: technology)
        return Set(supporting.map { GSDeviceModel(deviceModel: $0) })
    }

    /// Retrieves a device model by its name.
    ///
    /// - Parameter name: name of the device model to retrieve
    /// - Returns: the corresponding `GSDeviceModel`, or `nil` if no model with such a name exists
    public static func fromName(_ name: String) -> GSDeviceModel? {
        if let deviceModel = DeviceModel.from(name: name) {
            return GSDeviceModel(deviceModel: deviceModel)
        }
        return nil
    }

    /// Retrieves the internal id of a drone model.
    ///
    /// - Parameter droneModel: drone model
    /// - Returns: internal id of the drone model
    public static func internalIdOf(droneModel: Drone.Model) -> Int {
        return droneModel.internalId
    }

    /// Retrieves the internal id of a remote control model.
    ///
    /// - Parameter remoteControlModel: remote control model
    /// - Returns: internal id of the remote control model
    public static func internalIdOf(remoteControlModel: RemoteControl.Model) -> Int {
        return remoteControlModel.internalId
    }

    /// Retrieves the description of a drone model.
    ///
    /// - Parameter droneModel: drone model
    /// - Returns: description of the drone model
    public static func descriptionOf(droneModel: Drone.Model) -> String {
        return droneModel.description
    }

    /// Retrieves the description of a remote control model.
    ///
    /// - Parameter remoteControlModel: remote control model
    /// - Returns: description of the remote control model
    public static func descriptionOf(remoteControlModel: RemoteControl.Model) -> String {
        return remoteControlModel.description
    }
}
