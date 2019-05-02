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

/// Utility interface allowing to list all declared firmware blacklisted versions.
public protocol BlacklistedVersionStoreCore: UtilityCore {
    /// Tells whether a firmware version is blacklisted.
    ///
    /// - Parameter firmwareIdentifier: identifies the firmware version requested
    /// - Returns: `true` if the firmware version of the product is blacklisted
    func isBlacklisted(firmwareIdentifier: FirmwareIdentifier) -> Bool

    /// Start monitoring the store.
    ///
    /// - Note: To avoid memory leaks, the returned monitor should be kept. When not needed anymore, the `stop()`
    /// function should be called on this monitor before releasing it.
    ///
    /// - Parameter storeDidChange: closure called when the store changes.
    /// - Returns: returns a monitor. This monitor should be kept until calling `stop()` on it.
    func startMonitoring(storeDidChange: @escaping () -> Void) -> MonitorCore
}

/// Implementation of BlacklistedVersionStore utility.
class BlacklistedVersionStoreCoreImpl: BlacklistedVersionStoreCore {
    let desc: UtilityCoreDescriptor = Utilities.blacklistedVersionStore

    /// Monitor that calls back closures when the store changes
    fileprivate class Monitor: NSObject, MonitorCore {
        /// Closure called when the store changes.
        fileprivate let storeDidChange: () -> Void

        /// Monitored store.
        private let store: BlacklistedVersionStoreCoreImpl

        /// Constructor
        ///
        /// - Parameters:
        ///   - store: the monitored store
        ///   - storeDidChange: closure called when the store changes.
        fileprivate init(store: BlacklistedVersionStoreCoreImpl, storeDidChange: @escaping () -> Void) {
            self.store = store
            self.storeDidChange = storeDidChange
        }

        public func stop() {
            store.stopMonitoring(with: self)
        }
    }

    /// List of blacklisted entries indexed by device model
    private(set) var blacklist: [DeviceModel: BlacklistStoreEntry] = [:]

    /// List of monitors
    private var monitors: Set<Monitor> = []

    /// The json encoder used to archive data
    private let plistEncoder = PropertyListEncoder()

    /// Persistent store
    private let gsdkUserdefaults: GroundSdkUserDefaults

    /// Key of the version in the persistent store
    private let versionKey = "version"
    /// Key of the blacklisted version list in the persistent store
    private let blacklistKey = "blacklistedVersions"

    /// Constructor
    ///
    /// Stored data and embedded firmwares will automatically be loaded.
    /// - Parameter gsdkUserdefaults: persistent store. Should only be overriden by tests.
    init(gsdkUserdefaults: GroundSdkUserDefaults = GroundSdkUserDefaults("blacklistStore")) {
        self.gsdkUserdefaults = gsdkUserdefaults
        loadData()
    }

    /// Start monitoring the store.
    ///
    /// - Note:
    ///    - The store did change callback will be called directly in this function.
    ///    - To avoid memory leaks, the returned monitor should be kept. When not needed anymore, the `stop()`
    ///      function should be called on this monitor before releasing it.
    ///
    /// - Parameter storeDidChange: closure called when the store changes.
    /// - Returns: returns a monitor. This monitor should be kept until calling `stop()` on it
    func startMonitoring(storeDidChange: @escaping () -> Void) -> MonitorCore {
        let monitor = Monitor(store: self, storeDidChange: storeDidChange)
        monitors.insert(monitor)
        monitor.storeDidChange()
        return monitor
    }

    func isBlacklisted(firmwareIdentifier: FirmwareIdentifier) -> Bool {
        return blacklist[firmwareIdentifier.deviceModel]?.versions.contains(firmwareIdentifier.version) ?? false
    }

    /// Merges remote blacklist info to the store.
    ///
    /// - Parameter remoteBlacklistedVersions: remote entries to merge in the store
    func mergeRemoteBlacklistedVersions(_ remoteBlacklistedVersions: [DeviceModel: Set<FirmwareVersion>]) {
        var changed = false
        remoteBlacklistedVersions.forEach { model, versions in
            var entry = self.blacklist[model]
            if entry != nil {
                if entry!.add(versions: versions) {
                    changed = true
                }
            } else {
                entry = BlacklistStoreEntry(deviceModel: model, versions: versions, embedded: false)
                changed = true
            }
            self.blacklist[model] = entry
        }

        if changed {
            notifyStoreChanged()
        }
    }

    /// Stops monitoring with a given monitor.
    ///
    /// - Parameter monitor: the monitor
    private func stopMonitoring(with monitor: Monitor) {
        monitors.remove(monitor)
    }

    /// Notifies all monitors that the store has changed.
    private func notifyStoreChanged() {
        saveData()
        monitors.forEach { monitor in
            // ensure monitor has not be removed while iterating
            if monitors.contains(monitor) {
                monitor.storeDidChange()
            }
        }
    }

    /// Save data in persistent store.
    private func saveData() {
        do {
            var storedData: [String: Any] = ["version": 1]
            let plistData = try plistEncoder.encode(Array(blacklist.values.filter { !$0.embedded }))
            storedData[blacklistKey] = try PropertyListSerialization.propertyList(
                from: plistData, options: [], format: nil)
            gsdkUserdefaults.storeData(storedData)
        } catch let err {
            ULog.e(.fwEngineTag, "Failed to encode data: \(err)")
            return
        }
    }

    /// Load all known blacklisted version entries.
    ///
    /// This will load data from persistent store and from the embedded blacklisted firmwares.
    private func loadData() {
        getStoredBlacklist().forEach { blacklist[$0.deviceModel] = $0 }

        getEmbeddedBlacklist().forEach { blacklistEntry in
            var entry = self.blacklist[blacklistEntry.deviceModel]
            if entry != nil {
                entry!.add(versions: blacklistEntry.versions)
            } else {
                entry = blacklistEntry
            }
            self.blacklist[blacklistEntry.deviceModel] = entry
        }
    }

    /// Retrieves the stored firmwares in the persistent store.
    ///
    /// - Returns: a list of blacklist store entries.
    private func getStoredBlacklist() -> [BlacklistStoreEntry] {
        var blacklist: [BlacklistStoreEntry] = []
        var storedData: [String: Any] = gsdkUserdefaults.loadData() as? [String: Any] ?? [:]
        let version = storedData[versionKey] as? Int ?? 0
        if version == 0 {
            storedData[versionKey] = 1
        }
        if let blacklistDescription = storedData[blacklistKey] {
            do {
                let plistData = try PropertyListSerialization.data(
                    fromPropertyList: blacklistDescription, format: .binary, options: 0)
                blacklist = try PropertyListDecoder().decode([BlacklistStoreEntry].self, from: plistData)
            } catch let err {
                ULog.e(.fwEngineTag, "Failed to decode stored data: \(err)")
            }
        }
        return blacklist
    }

    /// Retrieves the embedded blacklisted versions.
    ///
    /// Embedded blacklisted firmware version file descriptors are given by the config
    /// `GroundSdkConfig.sharedInstance.embeddedBlacklistedVersionDescriptors`.
    ///
    /// - Returns: a list of blacklist store entries.
    private func getEmbeddedBlacklist() -> [BlacklistStoreEntry] {
        var blacklist: [BlacklistStoreEntry] = []
        GroundSdkConfig.sharedInstance.embeddedBlacklistedVersionDescriptors.forEach { descriptorName in
            guard let url = Bundle.main.url(forResource: descriptorName, withExtension: "plist") else {
                preconditionFailure("Embedded firmware descriptor \(descriptorName).plist file name does not exists " +
                    "in main bundle.")
            }
            do {
                let plistData = try Data(contentsOf: url)
                blacklist.append(
                    contentsOf: try PropertyListDecoder().decode([BlacklistStoreEntry].self, from: plistData))
            } catch let err {
                ULog.e(.fwEngineTag, "Failed to decode embedded data: \(err)")
            }
        }

        return blacklist
    }

    /// Reset blacklist by a new one.
    ///
    /// - Note: this function should only be called by tests.
    ///
    /// - Parameter newBlacklist: new blacklist
    func resetBlacklist(_ newBlacklist: [DeviceModel: BlacklistStoreEntry]) {
        blacklist = newBlacklist
        notifyStoreChanged()
    }
}

/// Description of the BlacklistedVersionStore utility
public class BlacklistedVersionStoreCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = BlacklistedVersionStoreCore
    public let uid = UtilityUid.blacklistedVersionStore.rawValue
}
