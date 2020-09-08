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

/// Generic class that stores devices
public class DeviceStoreUtilityCore<Device: DeviceCore>: NSObject {

    /// Monitor that calls back closures when the store changes, when a device is added or removed or when the device
    /// changes.
    private class Monitor: NSObject, MonitorCore {
        /// Closure called when a device is added in the store.
        fileprivate let didAddDevice: ((Device) -> Void)?
        /// Closure called when a device direct information is changed in the store.
        /// This closure is not called when a device component (instrument/pilotingItf/peripheral change).
        fileprivate let deviceInfoDidChange: ((Device) -> Void)?
        /// Closure called when a device is removed from the store.
        fileprivate let didRemoveDevice: ((Device) -> Void)?
        /// Closure called when the store changes.
        fileprivate let storeDidChange: (() -> Void)?

        /// Monitored store.
        private let store: DeviceStoreUtilityCore<Device>

        /// Constructor
        ///
        /// - Parameters:
        ///   - store: the monitored store
        ///   - didAddDevice: closure called when a device is added in the store
        ///   - deviceInfoDidChange: closure called when a device direct information is changed in the store
        ///   - didRemoveDevice: closure called when a device is removed from the store
        ///   - storeDidChange: closure called when the store changes
        fileprivate init(store: DeviceStoreUtilityCore<Device>,
                         didAddDevice: ((Device) -> Void)?,
                         deviceInfoDidChange: ((Device) -> Void)?,
                         didRemoveDevice: ((Device) -> Void)?,
                         storeDidChange: (() -> Void)?) {
            self.store = store
            self.didAddDevice = didAddDevice
            self.deviceInfoDidChange = deviceInfoDidChange
            self.didRemoveDevice = didRemoveDevice
            self.storeDidChange = storeDidChange
        }

        public func stop() {
            store.stopMonitoring(with: self)
        }
    }

    /// Map of devices, by uid
    private var devices: [String: Device] = [:]
    /// List of monitors
    private var monitors: Set<Monitor> = []

    /// Private constructor since this class should only be implemented by its concrete subclasses.
    fileprivate override init() { }

    /// Start monitoring the store.
    ///
    /// - Note: To avoid memory leaks, the returned monitor should be kept. When not needed anymore, the `stop()`
    /// function should be called on this monitor before releasing it.
    ///
    /// - Parameters:
    ///   - didAddDevice: closure called when a device is added in the store. Default is nil
    ///   - deviceInfoDidChange: closure called when a device direct information is changed in the store. Default is nil
    ///   - didRemoveDevice: closure called when a device is removed from the store. Default is nil
    ///   - storeDidChange: closure called when the store changes. Default is nil
    /// - Returns: a monitor. This monitor should be kept until calling `stop()` on it
    public func startMonitoring(didAddDevice: ((Device) -> Void)? = nil,
                                deviceInfoDidChange: ((Device) -> Void)? = nil,
                                didRemoveDevice: ((Device) -> Void)? = nil,
                                storeDidChange: (() -> Void)? = nil) -> MonitorCore {
        let monitor = Monitor(store: self, didAddDevice: didAddDevice,
                              deviceInfoDidChange: deviceInfoDidChange,
                              didRemoveDevice: didRemoveDevice,
                              storeDidChange: storeDidChange)
        monitors.insert(monitor)
        return monitor
    }

    /// Add a device to the device store
    ///
    /// All monitors will be notified that the device has been added and the store has changed.
    ///
    /// - Parameter device: the device to add
    public func add(_ device: Device) {
        if devices[device.uid] == nil {
            devices[device.uid] = device
            notifyDeviceAdded(device)
            // register ourself as device name, state, firmware version and board identifier change listener
            _ = device.nameHolder.register { [unowned self] _ in
                self.notifyDeviceInfoChanged(device)
            }
            _ = device.stateHolder.register { [unowned self] _ in
                self.notifyDeviceInfoChanged(device)
            }
            _ = device.firmwareVersionHolder.register { [unowned self] _ in
                self.notifyDeviceInfoChanged(device)
            }
            _ = device.boardIdHolder.register { [unowned self] _ in
                self.notifyDeviceInfoChanged(device)
            }
        }
    }

    /// Remove a device from the device store
    ///
    /// All monitors will be notified that the device has been removed and the store has changed.
    ///
    /// - Parameter device: the device to remove
    public func remove(_ device: Device) {
        if let device = devices.removeValue(forKey: device.uid) {
            notifyDeviceRemoved(device)
            device.clear()
        }
    }

    /// Gets a device by its uid
    ///
    /// - Parameter uid: requested device uid
    /// - Returns: a device with the requested uid, or nil if not found
    public func getDevice(uid: String) -> Device? {
        return devices[uid]
    }

    /// Gets a list containing all known devices.
    ///
    /// - Returns: a list of devices. Empty list if no known devices.
    public func getDevices() -> [Device] {
        return Array(devices.values)
    }

    /// Stops monitoring with a given monitor.
    ///
    /// - Parameter monitor: the monitor
    private func stopMonitoring(with monitor: Monitor) {
        monitors.remove(monitor)
    }

    /// Notifies all monitors that a device has been added to the store.
    ///
    /// - Note: this will also notifies all monitors that the store has changed.
    ///
    /// - Parameter device: the added device
    private func notifyDeviceAdded(_ device: Device) {
        monitors.forEach { monitor in
            // ensure monitor has not be removed while iterating
            if monitors.contains(monitor) {
                monitor.didAddDevice?(device)
                monitor.storeDidChange?()
            }
        }
    }

    /// Notifies all monitors that a device has been removed from the store.
    ///
    /// - Note: this will also notifies all monitors that the store has changed.
    ///
    /// - Parameter device: the removed device
    private func notifyDeviceRemoved(_ device: Device) {
        monitors.forEach { monitor in
            // ensure monitor has not be removed while iterating
            if monitors.contains(monitor) {
                monitor.didRemoveDevice?(device)
                monitor.storeDidChange?()
            }
        }
    }

    /// Notifies all monitors that a device info has changed.
    ///
    /// - Note: this will also notifies all monitors that the store has changed.
    ///
    /// - Parameter device: the device that has changed
    private func notifyDeviceInfoChanged(_ device: Device) {
        monitors.forEach { monitor in
            // ensure listener has not be removed while iterating
            if monitors.contains(monitor) {
                monitor.deviceInfoDidChange?(device)
                monitor.storeDidChange?()
            }
        }
    }
}

/// Drone store utility.
///
/// This utility is always available after that the engine has started. So when get from
/// `UtilityCoreRegistry.getUtility(desc:)` it can be forced unwrapped.
public class DroneStoreUtilityCore: DeviceStoreUtilityCore<DroneCore>, UtilityCore {
    public let desc: UtilityCoreDescriptor = Utilities.droneStore

    /// Constructor
    public override init() {
        super.init()
    }
}

/// Remote control store utility.
///
/// This utility is always available after that the engine has started. So when get from
/// `UtilityCoreRegistry.getUtility(desc:)` it can be forced unwrapped.
public class RemoteControlStoreUtilityCore: DeviceStoreUtilityCore<RemoteControlCore>, UtilityCore {
    public let desc: UtilityCoreDescriptor = Utilities.remoteControlStore

    /// Constructor
    public override init() {
        super.init()
    }
}

/// Description of the drone store utility
public class DroneStoreCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = DroneStoreUtilityCore
    public let uid = UtilityUid.droneStore.rawValue
}

/// Description of the remote control store utility
public class RemoteControlStoreCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = RemoteControlStoreUtilityCore
    public let uid = UtilityUid.remoteControlStore.rawValue
}
