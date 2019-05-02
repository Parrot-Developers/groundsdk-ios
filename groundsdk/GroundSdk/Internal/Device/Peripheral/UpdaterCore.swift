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

/// Firmare updater backend
public protocol UpdaterBackend: class {
    /// Requests firmware download.
    ///
    /// - Parameters:
    ///   - firmwares: list of firmwares to be downloaded, in order
    ///   - observer: observer that will be notified when the download task changed
    ///   - task: the download task
    func download(firmwares: [FirmwareInfoCore], observer: @escaping (_ task: FirmwareDownloaderCoreTask) -> Void)

    /// Requests device firmware update.
    ///
    /// - Parameter withFirmwares: firmwares to be applied for update, in order
    func update(withFirmwares: [FirmwareInfoCore])

    /// Cancels ongoing firmware update, if any.
    func cancelUpdate()
}

/// Core implementation of the Updater
public class UpdaterCore: PeripheralCore, Updater {
    /// Implementation of `UpdaterDownload`.
    class Download: UpdaterDownload, CustomStringConvertible {
        /// Firmware(s) download task that this state wraps.
        private let task: FirmwareDownloaderCoreTask
        var currentFirmware: FirmwareInfo {
            return task.current
        }

        var currentProgress: Int {
            return task.currentProgress
        }

        var currentIndex: Int {
            return task.currentCount
        }

        var totalCount: Int {
            return task.totalCount
        }

        var totalProgress: Int {
            return task.totalProgress
        }

        var state: UpdaterDownloadState {
            switch task.state {
            case .queued,
                 .downloading:
                return .downloading
            case .success:
                return .success
            case .failed:
                return .failed
            case .canceled:
                return .canceled
            }
        }

        var description: String {
            return "state = \(state.description), currentFirmware = \(currentFirmware.firmwareIdentifier.description)" +
                ", currentProgress = \(currentProgress), currentIndex = \(currentIndex), " +
                "totalCount = \(totalCount), totalProgress = \(totalProgress)"
        }

        /// Constructor
        ///
        /// - Parameter task: task that informs about firmware(s) download state
        init(task: FirmwareDownloaderCoreTask) {
            self.task = task
        }

        /// Cancels the ongoing download.
        func cancel() {
            task.cancel()
        }
    }

    /// Implementation of `UpdaterUpdate`.
    class Update: UpdaterUpdate, CustomStringConvertible {
        /// Firmwares to be applied.
        private let firmwares: [FirmwareInfo]

        var currentFirmware: FirmwareInfo {
            return firmwares[currentIndex-1]
        }
        private(set) var currentProgress = 0

        private(set) var currentIndex = 1

        var totalCount: Int {
            return firmwares.count
        }

        var totalProgress: Int {
            var totalSize: UInt64 = 0
            var uploadedSize: UInt64 = 0
            var firmwareIndex = 1 // index begins at 1
            firmwares.forEach {
                let size = $0.size
                totalSize += size
                if currentIndex > firmwareIndex {
                    uploadedSize += size
                } else if currentIndex == firmwareIndex {
                    uploadedSize += UInt64(currentProgress) * size / 100
                }
                firmwareIndex += 1
            }
            return totalSize == 0 ? 0 : Int(round(Double(uploadedSize * 100) / Double(totalSize)))
        }

        private(set) var state = UpdaterUpdateState.uploading

        var description: String {
            return "state = \(state.description), currentFirmware = \(currentFirmware.firmwareIdentifier.description)" +
                ", currentProgress = \(currentProgress), currentIndex = \(currentIndex), " +
            "totalCount = \(totalCount), totalProgress = \(totalProgress)"
        }

        /// Constructor.
        ///
        /// - Parameter firmwares: firmwares that will be applied, in order
        init(firmwares: [FirmwareInfo]) {
            self.firmwares = firmwares
        }

        /// Increments current firmware index.
        ///
        /// In case the index did increment, then the update state is reset to `.uploading` and progress is reset to 0.
        ///
        /// - Returns: true if index did change
        func processNextFirmware() -> Bool {
            if currentIndex < firmwares.count {
                state = .uploading
                currentProgress = 0
                currentIndex += 1
                return true
            }
            return false
        }

        /// Updates the update state.
        ///
        /// - Parameter newValue: new update state
        /// - Returns: true if state did change
        fileprivate func update(state newValue: UpdaterUpdateState) -> Bool {
            if state != newValue {
                state = newValue
                return true
            }
            return false
        }

        /// Updates the current upload progress.
        ///
        /// - Parameter newValue: new upload progress
        /// - Returns: true if progress did change
        fileprivate func update(currentFirmwareProgress newValue: Int) -> Bool {
            if currentProgress != newValue {
                currentProgress = newValue
                return true
            }
            return false
        }
    }

    /// Implementation backend
    private unowned let backend: UpdaterBackend

    public var downloadableFirmwares: [FirmwareInfo] {
        return _downloadableFirmwares
    }
    private var _downloadableFirmwares: [FirmwareInfoCore] = []

    public var isUpToDate: Bool {
        return downloadableFirmwares.isEmpty && applicableFirmwares.isEmpty
    }

    private(set) public var downloadUnavailabilityReasons: Set<UpdaterDownloadUnavailabilityReason> = []

    public var currentDownload: UpdaterDownload? {
        return _currentDownload
    }
    private var _currentDownload: Download?

    public var applicableFirmwares: [FirmwareInfo] {
        return _applicableFirmwares
    }
    private var _applicableFirmwares: [FirmwareInfoCore] = []

    private(set) public var updateUnavailabilityReasons: Set<UpdaterUpdateUnavailabilityReason> = []

    public var currentUpdate: UpdaterUpdate? {
        return _currentUpdate
    }
    private var _currentUpdate: Update?

    private(set) public var idealVersion: FirmwareVersion?

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: updater backend
    public init(store: ComponentStoreCore, backend: UpdaterBackend) {
        self.backend = backend
        super.init(desc: Peripherals.updater, store: store)
    }

    public func downloadNextFirmware() -> Bool {
        return !_downloadableFirmwares.isEmpty && download(firmwares: [_downloadableFirmwares.first!])
    }

    public func downloadAllFirmwares() -> Bool {
        return !_downloadableFirmwares.isEmpty && download(firmwares: _downloadableFirmwares)
    }

    public func cancelDownload() -> Bool {
        if let _currentDownload = _currentDownload {
            _currentDownload.cancel()
            return true
        }
        return false
    }

    public func updateToNextFirmware() -> Bool {
        return !_applicableFirmwares.isEmpty && update(withFirmwares: [_applicableFirmwares.first!])
    }

    public func updateToLatestFirmware() -> Bool {
        return !_applicableFirmwares.isEmpty && update(withFirmwares: _applicableFirmwares)
    }

    public func cancelUpdate() -> Bool {
        if currentUpdate != nil {
            backend.cancelUpdate()
            return true
        }
        return false
    }

    /// Requests firmware(s) download.
    ///
    /// - Parameter firmwares: firmwares to be downloaded, in order
    /// - Returns: true if firmware download did start
    private func download(firmwares: [FirmwareInfoCore]) -> Bool {
        if downloadUnavailabilityReasons.isEmpty && currentDownload == nil {
            backend.download(firmwares: firmwares, observer: { [weak self] task in
                if let `self` = self {
                    if self._currentDownload == nil {
                        self._currentDownload = Download(task: task)
                    }
                    self.markChanged()
                    self.notifyUpdated()
                    switch task.state {
                    case .queued,
                         .downloading:
                        break
                    case .success,
                         .failed,
                         .canceled:
                        self._currentDownload = nil
                        self.markChanged()
                        self.notifyUpdated()
                    }
                }
            })
            return true
        }
        return false
    }

    /// Requests firmware(s) update.
    ///
    /// - Parameter firmwares: firmwares to be applied, in order
    /// - Returns: true if firmware update did start
    private func update(withFirmwares firmwares: [FirmwareInfoCore]) -> Bool {
        if updateUnavailabilityReasons.isEmpty && currentUpdate == nil {
            backend.update(withFirmwares: firmwares)
            return true
        }
        return false
    }
}

/// Backend callback methods
extension UpdaterCore {
    /// Updates the list of downloadable firmwares.
    ///
    /// - Parameter downloadableFirmwares: new downloadable firmwares, in application order
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(downloadableFirmwares newValue: [FirmwareInfoCore]) -> UpdaterCore {
        if _downloadableFirmwares != newValue {
            _downloadableFirmwares = newValue
            markChanged()
        }
        return self
    }

    /// Updates the applicable firmwares.
    ///
    /// - Parameter applicableFirmware: new applicable firmware, in application order
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(applicableFirmwares newValue: [FirmwareInfoCore]) -> UpdaterCore {
        if _applicableFirmwares != newValue {
            _applicableFirmwares = newValue
            markChanged()
        }
        return self
    }

    ///  Updates the set of unavailability reasons for firmware download.
    ///
    /// - Parameter downloadUnavailabilityReasons: new firmware download unavailability reasons
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        downloadUnavailabilityReasons newValue: Set<UpdaterDownloadUnavailabilityReason>) -> UpdaterCore {

        if downloadUnavailabilityReasons != newValue {
            downloadUnavailabilityReasons = newValue
            markChanged()
        }
        return self
    }

    ///  Updates the set of unavailability reasons for firmware update.
    ///
    /// - Parameter updateUnavailabilityReasons: new firmware update unavailability reasons
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        updateUnavailabilityReasons newValue: Set<UpdaterUpdateUnavailabilityReason>) -> UpdaterCore {

        if updateUnavailabilityReasons != newValue {
            updateUnavailabilityReasons = newValue
            markChanged()
        }
        return self
    }

    /// Creates a new update state.
    ///
    /// - Parameter firmwares: firmwares that will be applied for this update
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func beginUpdate(withFirmwares firmwares: [FirmwareInfoCore]) -> UpdaterCore {
        _currentUpdate = Update(firmwares: firmwares)
        markChanged()
        return self
    }

    /// Moves the update state to the next firmware to apply.
    ///
    /// This also resets the update state to `.uploading` and upload progress to 0.
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func continueUpdate() -> UpdaterCore {
        if let _currentUpdate = _currentUpdate, _currentUpdate.processNextFirmware() {
            markChanged()
        }
        return self
    }

    /// Clears the update state.
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func endUpdate() -> UpdaterCore {
        if _currentUpdate != nil {
            _currentUpdate = nil
            markChanged()
        }
        return self
    }

    ///  Updates the update state.
    ///
    /// - Parameter updateState: new update state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(updateState newValue: UpdaterUpdateState) -> UpdaterCore {
        if let _currentUpdate = _currentUpdate, _currentUpdate.update(state: newValue) {
            markChanged()
        }
        return self
    }

    ///  Updates the update progress.
    ///
    /// - Parameter uploadProgress: new update progress
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(uploadProgress newValue: Int) -> UpdaterCore {
        if let _currentUpdate = _currentUpdate, _currentUpdate.update(currentFirmwareProgress: newValue) {
            markChanged()
        }
        return self
    }

    ///  Updates the ideal version.
    ///
    /// - Parameter idealVersion: new ideal version
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(idealVersion newValue: FirmwareVersion?) -> UpdaterCore {
        if idealVersion != newValue {
            idealVersion = newValue
            markChanged()
        }
        return self
    }
}

/// Extension of UpdaterCore.Download to support Objective-C API
extension UpdaterCore.Download: GSUpdaterDownload {
    var gsCurrentFirmware: GSFirmwareInfo {
        // we allow us to force cast because we know that this firmware info is a FirmwareInfoCore and this class
        // implements the protocol GSFirmwareInfo.
        return currentFirmware as! GSFirmwareInfo
    }
}

/// Extension of UpdaterCore.Upload to support Objective-C API
extension UpdaterCore.Update: GSUpdaterUpdate {
    var gsCurrentFirmware: GSFirmwareInfo {
        // we allow us to force cast because we know that this firmware info is a FirmwareInfoCore and this class
        // implements the protocol GSFirmwareInfo.
        return currentFirmware as! GSFirmwareInfo
    }
}

/// Extension of UpdaterCore to support Objective-C API
extension UpdaterCore: GSUpdater {
    public var gsDownloadableFirmwares: [GSFirmwareInfo] {
        return _downloadableFirmwares
    }

    public var gsCurrentDownload: GSUpdaterDownload? {
        return _currentDownload
    }

    public var gsApplicableFirmwares: [GSFirmwareInfo] {
        return _applicableFirmwares
    }

    public var gsCurrentUpdate: GSUpdaterUpdate? {
        return _currentUpdate
    }

    public func isPreventingDownload(reason: UpdaterDownloadUnavailabilityReason) -> Bool {
        return downloadUnavailabilityReasons.contains(reason)
    }

    public func isPreventingUpdate(reason: UpdaterUpdateUnavailabilityReason) -> Bool {
        return updateUnavailabilityReasons.contains(reason)
    }
}
