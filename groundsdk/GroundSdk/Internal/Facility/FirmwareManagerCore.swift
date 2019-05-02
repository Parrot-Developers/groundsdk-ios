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

/// Firmware manager backend
protocol FirmwareManagerBackend: class {
    /// Requests fresh update information from remote servers.
    ///
    /// - Returns: true if a request was sent, false otherwise
    func queryRemoteUpdateInfos() -> Bool

    /// Request download of a remote firmware file
    ///
    /// - Parameters:
    ///   - firmware: identifies the firmware to download the update file of
    ///   - observer: observer that will be notified when the download task state changes
    ///   - task: the task that has changed
    func download(firmware: FirmwareInfoCore, observer: @escaping (_ task: FirmwareDownloaderCoreTask) -> Void)

    /// Requests deletion of a firmware local file
    ///
    /// - Parameter firmware: identifies the firmware whose local file must be deleted
    /// - Returns: `true` if any local firmware file was deleted for the identified firmware
    func delete(firmware: FirmwareInfoCore) -> Bool
}

protocol FirmwareManagerEntryBackend: class {
    /// Gets an existing task that is handling a given firmware
    ///
    /// - Parameter firmware: the firmware info
    /// - Returns: a task if the backend has one matching the requirement
    func getTask(firmware: FirmwareInfo) -> FirmwareDownloaderCoreTask?
    /// Request download of a remote firmware file
    ///
    /// - Parameter firmware: the firmware to download the update file of
    func download(firmware: FirmwareInfoCore)
    /// Requests deletion of a firmware local file
    ///
    /// - Parameter firmware: the firmware whose local file must be deleted
    /// - Returns: `true` if any local firmware file was deleted for the given firmware
    func delete(firmware: FirmwareInfoCore) -> Bool
}

/// Core implementation of the update manager facility
class FirmwareManagerCore: FacilityCore, FirmwareManager {
    private(set) var isQueryingRemoteUpdates = false
    private(set) var firmwares: [FirmwareManagerEntry] = []

    /// Implementation backend
    private unowned let backend: FirmwareManagerBackend
    /// Ongoing download tasks, indexed by firmware identifier
    private(set) var tasks: [FirmwareIdentifier: FirmwareDownloaderCoreTask] = [:]

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: component store owning this component
    ///   - backend: FirmwareManagerBackend backend
    init(store: ComponentStoreCore, backend: FirmwareManagerBackend) {
        self.backend = backend
        super.init(desc: Facilities.firmwareManager, store: store)
    }

    func queryRemoteUpdates() -> Bool {
        if !isQueryingRemoteUpdates {
            return backend.queryRemoteUpdateInfos()
        }
        return false
    }
}

/// Backend callback methods
extension FirmwareManagerCore {
    /// Updates current remote query status.
    ///
    /// - Parameter newValue: `true` when a remote query is ongoing, otherwise `false`
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(remoteQueryFlag newValue: Bool) -> FirmwareManagerCore {
        if isQueryingRemoteUpdates != newValue {
            isQueryingRemoteUpdates = newValue
            markChanged()
        }
        return self
    }

    /// Updates list of firmwares.
    ///
    /// - Parameter newEntries: new firmware store entries
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(entries newEntries: [FirmwareStoreEntry]) -> FirmwareManagerCore {
        let newValues = newEntries.map {
            FirmwareManagerEntry(
                info: $0.firmware, isLocal: $0.isLocal, canDelete: !$0.embedded && $0.isLocal, backend: self)
        }
        if firmwares != newValues {
            firmwares = newValues
            markChanged()
        }
        return self
    }
}

/// Extension of firmware manager that implements the FirmwareManagerEntryBackend
extension FirmwareManagerCore: FirmwareManagerEntryBackend {
    func getTask(firmware: FirmwareInfo) -> FirmwareDownloaderCoreTask? {
        return tasks[firmware.firmwareIdentifier]
    }

    func download(firmware: FirmwareInfoCore) {
        backend.download(firmware: firmware) { [weak self] task in
            if task.state != .downloading && task.state != .queued {
                self?.tasks[firmware.firmwareIdentifier] = nil
            } else {
                self?.tasks[firmware.firmwareIdentifier] = task
            }
            self?.markChanged()
            self?.notifyUpdated()
        }
    }

    func delete(firmware: FirmwareInfoCore) -> Bool {
        return backend.delete(firmware: firmware)
    }
}
