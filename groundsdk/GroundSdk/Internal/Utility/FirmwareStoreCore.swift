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

/// Utility interface allowing to list available device firmwares.
public protocol FirmwareStoreCore: UtilityCore {
    /// Gets the ideal firmware that might be used to update the device with.
    ///
    /// This firmware might not be local nor be directly applicable.
    /// If the returned value is nil, the device is up to date.
    ///
    /// - Parameter firmwareIdentifier: firmware to know the ideal version for
    /// - Returns: the ideal firmware if any
    func getIdealFirmware(for firmwareIdentifier: FirmwareIdentifier) -> FirmwareInfoCore?

    /// Gets the best directly applicable firmware to update the device with.
    ///
    /// - Parameter firmwareIdentifier: firmware to list applicable updates for
    /// - Returns: the greatest local firmware that can be directly uploaded,
    ///            `nil` if the current version is greater than any local firmware for this device or if no local
    ///             version can be directly used for an update (case of the "trampoline" firmwares).
    func getApplicableFirmwares(on firmwareIdentifier: FirmwareIdentifier) -> [FirmwareInfoCore]

    /// Gets all firmwares that must be downloaded in order to update a given firmware.
    ///
    /// This method returns a list containing infos about all firmwares that would need to be applied to update the
    /// specified firmware to the latest known version, **AND** that have not already been downloaded yet.
    ///
    /// Firmwares in the returned list are sorted by application order, i.e. first firmwares, once downloaded, must be
    /// applied to the device before subsequent ones.
    ///
    /// - Parameter firmwareIdentifier: firmware to list downloadable updates for
    /// - Returns: list of firmwares that have to be downloaded in order to update the specified firmware
    func getDownloadableFirmwares(for firmwareIdentifier: FirmwareIdentifier) -> [FirmwareInfoCore]

    /// Retrieves the update file for a given firmware.
    ///
    /// - Parameter firmwareIdentifier: identifies the firmware whose update file is requested
    /// - Returns: the firmware file local url or nil if no update file for the specified firmware is available locally
    func getFirmwareFile(firmwareIdentifier: FirmwareIdentifier) -> URL?

    /// Start monitoring the store.
    ///
    /// - Note: To avoid memory leaks, the returned monitor should be kept. When not needed anymore, the `stop()`
    /// function should be called on this monitor before releasing it.
    ///
    /// - Parameter storeDidChange: closure called when the store changes.
    /// - Returns: a monitor. This monitor should be kept until calling `stop()` on it.
    func startMonitoring(storeDidChange: @escaping () -> Void) -> MonitorCore
}

/// Implementation of FirmwareStore utility.
class FirmwareStoreCoreImpl: FirmwareStoreCore {
    let desc: UtilityCoreDescriptor = Utilities.firmwareStore

    /// Monitor that calls back closures when the store changes
    fileprivate class Monitor: NSObject, MonitorCore {
        /// Closure called when the store changes.
        fileprivate let storeDidChange: () -> Void

        /// Monitored store.
        private let store: FirmwareStoreCoreImpl

        /// Constructor
        ///
        /// - Parameters:
        ///   - store: the monitored store
        ///   - storeDidChange: closure called when the store changes.
        fileprivate init(store: FirmwareStoreCoreImpl, storeDidChange: @escaping () -> Void) {
            self.store = store
            self.storeDidChange = storeDidChange
        }

        public func stop() {
            store.stopMonitoring(with: self)
        }
    }

    /// Block that sorts two firmware store entry with the recent version first
    private let recentVersionFirst: (FirmwareStoreEntry, FirmwareStoreEntry) -> Bool = {
        $0.firmware.firmwareIdentifier.version > $1.firmware.firmwareIdentifier.version
    }

    /// Block that sorts two firmware store entry with the recent version last
    private let lowestVersionFirst: (FirmwareStoreEntry, FirmwareStoreEntry) -> Bool = {
        $0.firmware.firmwareIdentifier.version < $1.firmware.firmwareIdentifier.version
    }

    /// Drone store.
    ///
    /// Should be set as soon as available in order to remove unnecessary firmwares
    var droneStore: DroneStoreUtilityCore?

    /// Remote control store.
    ///
    /// Should be set as soon as available in order to remove unnecessary firmwares
    var rcStore: RemoteControlStoreUtilityCore?

    /// List of firmware entries indexed by identifier
    private(set) var firmwares: [FirmwareIdentifier: FirmwareStoreEntry] = [:]

    /// List of monitors
    private var monitors: Set<Monitor> = []

    /// The json encoder used to archive data
    private let plistEncoder = PropertyListEncoder()

    /// Persistent store
    private let gsdkUserdefaults: GroundSdkUserDefaults

    /// Key of the version in the persistent store
    private let versionKey = "version"
    /// Key of the firmware list in the persistent store
    private let firmwaresKey = "firmwares"

    /// Minimum time on the file system to be allowed to be deleted
    private static let MIN_TIME_TO_BE_DELETE: TimeInterval = 60 * 60 * 24   // One day

    /// Constructor
    ///
    /// Stored data and embedded firmwares will automatically be loaded.
    ///
    /// - Parameter gsdkUserdefaults: persistent store. Should only be overriden by tests.
    init(gsdkUserdefaults: GroundSdkUserDefaults = GroundSdkUserDefaults("firmwareStore")) {
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

    func getIdealFirmware(for firmwareIdentifier: FirmwareIdentifier) -> FirmwareInfoCore? {
        return getLatestFirmwareEntries(from: firmwareIdentifier).last?.firmware
    }

    func getApplicableFirmwares(on firmwareIdentifier: FirmwareIdentifier) -> [FirmwareInfoCore] {
        var applicableFirmwares: [FirmwareInfoCore] = []
        for firmwareStoreEntry in getLatestLocalFirmwareEntries(from: firmwareIdentifier) {
            applicableFirmwares.append(firmwareStoreEntry.firmware)
        }
        return applicableFirmwares
    }

    func getDownloadableFirmwares(for firmwareIdentifier: FirmwareIdentifier) -> [FirmwareInfoCore] {
        return getLatestFirmwareEntries(from: firmwareIdentifier).filter { !$0.isLocal }.map { $0.firmware }
    }

    func getFirmwareFile(firmwareIdentifier: FirmwareIdentifier) -> URL? {
        return firmwares[firmwareIdentifier]?.localUrl
    }

    /// Retrieves all update entries that may be applied to update a given device firmware to the latest known version.
    ///
    /// The returned array contains the latest firmware entry that is available to update the given firmware, plus all
    /// entries that are required to be applied before.
    ///
    /// Entries in the array are sorted by application order, first entries should be applied before subsequent entries.
    ///
    /// Entries in the array might be only remotely available and corresponding firmware update files should be
    /// downloaded before application.
    ///
    /// - Parameter firmwareIdentifier: identifier of the firmware to update
    /// - Returns: an array of all update entries that should be applied to update the firmware to the latest known
    ///   version. Possibly empty.
    func getLatestFirmwareEntries(from firmwareIdentifier: FirmwareIdentifier) -> [FirmwareStoreEntry] {
        var entries: [FirmwareStoreEntry] = []
        var applicableEntries = listSuitableEntries(from: firmwareIdentifier)
        while !applicableEntries.isEmpty {
            let entry = applicableEntries.first!
            entries.append(entry)
            applicableEntries = listSuitableEntries(from: entry.firmware.firmwareIdentifier)
        }
        entries.sort(by: lowestVersionFirst)
        return entries
    }

    /// Retrieves all local update entries that may be applied to update a given device firmware to the latest known
    /// version.
    ///
    /// The returned array contains the latest firmware entry that is available to update the given firmware, plus all
    /// entries that are required to be applied before.
    ///
    /// Entries in the array are sorted by application order, first entries should be applied before subsequent entries.
    ///
    /// Entries in the array might be only remotely available and corresponding firmware update files should be
    /// downloaded before application.
    ///
    /// - Parameter firmwareIdentifier: identifier of the firmware to update
    /// - Returns: an array of all update entries that should be applied to update the firmware to the latest known
    ///   version. Possibly empty.
    func getLatestLocalFirmwareEntries(from firmwareIdentifier: FirmwareIdentifier) -> [FirmwareStoreEntry] {
        var entries: [FirmwareStoreEntry] = []
        var applicableEntries = listSuitableEntries(from: firmwareIdentifier).filter { $0.isLocal }
        while !applicableEntries.isEmpty {
            let entry = applicableEntries.first!
            entries.append(entry)
            applicableEntries = listSuitableEntries(from: entry.firmware.firmwareIdentifier).filter {
                $0.isLocal
            }
        }
        entries.sort(by: lowestVersionFirst)
        return entries
    }

    /// Merges remote firmware info to the store.
    ///
    /// - Parameter remoteFirmwares: remote entries to merge in the store
    func mergeRemoteFirmwares(_ remoteFirmwares: [FirmwareIdentifier: FirmwareStoreEntry]) {
        // List of the firmwares that are not stored at all for the moment
        var notStoredRemoteFirmwares = remoteFirmwares
        var changed = false
        firmwares.forEach { identifier, entry in
            // if there is a matching firmware in the remote list
            if let matchingRemote = notStoredRemoteFirmwares.removeValue(forKey: identifier) {
                var entry = entry // make it mutable
                if entry.remoteUrl != matchingRemote.remoteUrl {
                    entry.remoteUrl = matchingRemote.remoteUrl
                    firmwares[identifier] = entry
                    changed = true
                }
            } else if !entry.isLocal {
                // there is no remote info entry for this firmware and no local uri, delete it
                firmwares[identifier] = nil
                changed = true
            }
        }

        // what remains in remoteEntries is only new entries to be added
        if !notStoredRemoteFirmwares.isEmpty {
            firmwares.merge(notStoredRemoteFirmwares) { firmware, _ in
                // this closure should not be called since we are only adding firmwares that aren't in `firmwares`
                return firmware
            }
            changed = true
        }

        if changed {
            notifyStoreChanged()
        }
    }

    /// Notifies to the store that a given firmware is local now.
    ///
    /// - Note: Calling this function will automatically delete from the file system all older local firmware files that
    ///   are not embedded.
    ///
    /// - Parameters:
    ///   - identifier: identifier of the firmware entry to update
    ///   - localUrl: local url to attach to the entry
    func changeRemoteFirmwareToLocal(identifier: FirmwareIdentifier, localUrl: URL) {
        if var entry = firmwares[identifier] {
            entry.localUrl = localUrl
            firmwares[identifier] = entry

            removeAllUnnecessaryFirmwares()

            notifyStoreChanged()
        } else {
            ULog.w(.fwEngineTag, "Cannot change remote firmware \(identifier) to a local one because it is not known")
        }
    }

    /// Retrieves an entry from the store.
    ///
    /// - Parameter firmwareIdentifier: identifier of the firmware to get the corresponding entry of
    /// - Returns: the firmware entry if exists, otherwise nil
    func getEntry(for firmwareIdentifier: FirmwareIdentifier) -> FirmwareStoreEntry? {
        return firmwares[firmwareIdentifier]
    }

    /// Removes from the file system all not embedded local firmware files that are not necessary
    func removeAllUnnecessaryFirmwares() {
        // get all current firmware versions the known devices
        var versions: Set<FirmwareIdentifier> = []
        rcStore?.getDevices().forEach {
            versions.insert(FirmwareIdentifier(deviceModel: .rc($0.model), version: $0.firmwareVersionHolder.version))
        }
        droneStore?.getDevices().forEach {
            versions.insert(FirmwareIdentifier(deviceModel: .drone($0.model),
                                               version: $0.firmwareVersionHolder.version))
        }

        // for each FirmwareIdentifier known, find all the local firmware entries that are needed to update to the
        // latest version
        var firmwaresToKeep = [FirmwareStoreEntry]()
        versions.forEach {
            firmwaresToKeep.append(contentsOf: getLatestLocalFirmwareEntries(from: $0))
        }

        // now that we have a list of all firmwares to keep, remove all local firmwares that are not in this list
        var hasChanged = false
        firmwares.forEach { (identifier, entry) in
            let shouldBeKept = firmwaresToKeep.contains {
                $0.firmware.firmwareIdentifier == identifier
            }
            if !shouldBeKept && canRemoveUnecessaryEntry(entry) && self.delete(firmware: identifier) {
                hasChanged = true
            }
        }

        if hasChanged {
            notifyStoreChanged()
        }
    }

    private func canRemoveUnecessaryEntry(_ entry: FirmwareStoreEntry) -> Bool {
        if let localUrl = entry.localUrl {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: localUrl.path) as NSDictionary,
                let modificationDate = attributes.fileModificationDate() {
                // only allow to remove the file if it is at least `MIN_TIME_TO_BE_DELETE` old
                return Date().timeIntervalSince(modificationDate) > FirmwareStoreCoreImpl.MIN_TIME_TO_BE_DELETE
            }
            // if we could not read creation date, allow the file to be removed
            return true
        }
        return false
    }

    /// Lists all entries which are suitable for updating a given firmware.
    ///
    /// - Parameter firmwareIdentifier: identifier of the firmware to test
    /// - Returns: an array of all update entries that should be applied to update the firmware. Possibly empty.
    private func listSuitableEntries(from firmwareIdentifier: FirmwareIdentifier) -> [FirmwareStoreEntry] {
        let baseVersion = firmwareIdentifier.version
        let model = firmwareIdentifier.deviceModel
        return firmwares.values.filter { firmwareEntry in
            let identifier = firmwareEntry.firmware.firmwareIdentifier

            if identifier.deviceModel == model && identifier.version > baseVersion {
                // check if this version is ok for 'requiredVersion' (minVersion)
                let matchMinVersion: Bool
                if let requiredVersion = firmwareEntry.requiredVersion {
                    matchMinVersion = baseVersion >= requiredVersion
                } else {
                    // no 'min' requirement
                    matchMinVersion = true
                }
                // check if this version is ok for 'maxVersion'
                let matchMaxVersion: Bool
                if let maxVersion = firmwareEntry.maxVersion {
                    matchMaxVersion = baseVersion <= maxVersion
                } else {
                    // no 'max' requirement
                    matchMaxVersion = true
                }
                return matchMinVersion && matchMaxVersion
            } else {
                return false
            }
            }.sorted(by: recentVersionFirst)
    }

    /// Deletes a given local firmware and update the entry in the store.
    ///
    /// - Parameter firmware: identifier of the firmware to delete.
    /// - Returns: `true` if the firmware has been deleted (i.e. entry exists in store, is local and is not embedded),
    ///   `false` otherwise.
    func delete(firmware: FirmwareIdentifier) -> Bool {
        if var entry = firmwares[firmware] {
            // can not delete presets and remote firmwares
            if let localUrl = entry.localUrl, !entry.embedded {
                do {
                    ULog.d(.fwEngineTag, "Try to delete local firmware: \(entry.description)")
                    // delete the file and its parent if it is empty
                    try FileManager.default.removeItem(at: localUrl)
                    let parentFolder = localUrl.deletingLastPathComponent()
                    if try FileManager.default.contentsOfDirectory(
                        at: parentFolder, includingPropertiesForKeys: []).isEmpty {
                        try FileManager.default.removeItem(at: parentFolder)
                    }
                    // if the entry is still referenced by the server, only remove the local url from it
                    if entry.remoteUrl != nil {
                        entry.localUrl = nil
                        firmwares[firmware] = entry
                    } else {
                        // if entry is no more referenced by the server, removes it from the store
                        firmwares[firmware] = nil
                    }
                    return true
                } catch let err {
                    ULog.w(.fwEngineTag, "Error while deleting \(firmware) at \(localUrl): \(err).")
                }
            }
        } else {
            ULog.w(.fwEngineTag, "Firmware \(firmware) to delete has not been found.")
        }
        return false
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
            let plistData = try plistEncoder.encode(Array(firmwares.values.filter { !$0.embedded }))
            storedData[firmwaresKey] = try PropertyListSerialization.propertyList(
                from: plistData, options: [], format: nil)
            gsdkUserdefaults.storeData(storedData)
        } catch let err {
            ULog.e(.fwEngineTag, "Failed to encode data: \(err)")
            return
        }
    }

    /// Load all known firmware store entries.
    ///
    /// This will load data from persistent store and from the embedded firmwares.
    private func loadData() {
        getStoredFirmwares().forEach { firmwares[$0.firmware.firmwareIdentifier] = $0 }

        // presets always override existing data
        getEmbeddedFirmwares().forEach { firmwares[$0.firmware.firmwareIdentifier] = $0 }
    }

    /// Retrieves the stored firmwares in the persistent store.
    ///
    /// - Returns: a list of firmware store entries.
    private func getStoredFirmwares() -> [FirmwareStoreEntry] {
        var firmwares: [FirmwareStoreEntry] = []
        var storedData: [String: Any] = gsdkUserdefaults.loadData() as? [String: Any] ?? [:]
        let version = storedData[versionKey] as? Int ?? 0
        if version == 0 {
            storedData[versionKey] = 1
        }
        if let firmwareDescriptions = storedData[firmwaresKey] {
            do {
                let plistData = try PropertyListSerialization.data(
                    fromPropertyList: firmwareDescriptions, format: .binary, options: 0)
                firmwares = try PropertyListDecoder().decode([FirmwareStoreEntry].self, from: plistData)
            } catch let err {
                ULog.e(.fwEngineTag, "Failed to decode stored data: \(err)")
            }
        }
        return firmwares
    }

    /// Retrieves the embedded firmwares.
    ///
    /// Embedded firmwares file descriptors are given by the config
    /// `GroundSdkConfig.sharedInstance.embeddedFirmwareDescriptors`.
    ///
    /// - Returns: a list of firmware store entries.
    private func getEmbeddedFirmwares() -> [FirmwareStoreEntry] {
        var firmwares: [FirmwareStoreEntry] = []
        GroundSdkConfig.sharedInstance.embeddedFirmwareDescriptors.forEach { descriptorName in
            guard let url = Bundle.main.url(forResource: descriptorName, withExtension: "plist") else {
                preconditionFailure("Embedded firmware descriptor \(descriptorName).plist file name does not exists " +
                    "in main bundle.")
            }
            do {
                let plistData = try Data(contentsOf: url)
                firmwares.append(
                    contentsOf: try PropertyListDecoder().decode([FirmwareStoreEntry].self, from: plistData))
            } catch let err {
                ULog.e(.fwEngineTag, "Failed to decode embedded data: \(err)")
            }
        }

        return firmwares
    }

    /// Reset firmware list by a new one.
    ///
    /// - Note: this function should only be called by tests.
    ///
    /// - Parameter newFirmwares: new firmwares
    func resetFirmwares(_ newFirmwares: [FirmwareIdentifier: FirmwareStoreEntry]) {
        firmwares = newFirmwares
        notifyStoreChanged()
    }
}

/// Description of the FirmwareStore utility
public class FirmwareStoreCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = FirmwareStoreCore
    public let uid = UtilityUid.firmwareStore.rawValue
}
