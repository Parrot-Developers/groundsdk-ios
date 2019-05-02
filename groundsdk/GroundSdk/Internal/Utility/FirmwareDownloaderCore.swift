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

/// Firmware downloader task state.
public enum FirmwareDownloaderCoreTaskState: CustomStringConvertible {
    /// Task has pending firmwares to be downloaded, none of which are being downloaded currently.
    case queued
    /// Next firmware in task queue is being downloaded.
    case downloading
    ///  All firmwares for this task have been successfully downloaded.
    case success
    /// Task failed to download some firmware.
    case failed
    /// Task was canceled by client request.
    case canceled

    /// Debug description.
    public var description: String {
        switch self {
        case .queued:       return "queued"
        case .downloading:  return "downloading"
        case .success:      return "success"
        case .failed:       return "failed"
        case .canceled:     return "canceled"
        }
    }
}

/// A firmware download task.
public protocol FirmwareDownloaderCoreTask: CancelableCore {
    /// Current state.
    var state: FirmwareDownloaderCoreTaskState { get }
    /// List of firmwares that have been requested to be downloaded for this task.
    ///
    /// List is in the same order as what was requested by client upon `download` request.
    /// This list does never change.
    var requested: [FirmwareInfoCore] { get }
    /// List of firmwares that have not been completely downloaded for this task, so far.
    ///
    /// List is in the same order as what was requested by client upon `download` request.
    var remaining: [FirmwareInfoCore] { get }
    /// Current progress of the ongoing firmware download, in percent.
    ///
    /// This is `0` when the task is `.queued`, `100` when the task is in state `.success`. Otherwise this is the
    /// current progress of the ongoing download if the task is `.downloading`, or the latest reached progress when the
    /// task is `.failed` or `.canceled`.
    var currentProgress: Int { get }
    /// Firmwares that have been successfully downloaded for this task, so far.
    ///
    /// List is in the same order as what was requested by client upon `download` request.
    var downloaded: [FirmwareInfoCore] { get }
    /// Index of the latest firmware being or having been processed so far.
    ///
    /// This gives the index of the current firmware  being `.queued` or `.downloading`, or the firmware that was being
    /// downloaded when the task completed, either successfully, with error or because of cancelation.
    ///
    /// Value in in range 1...`totalCount`.
    var currentCount: Int { get }
    /// Latest firmware being or having been processed so far.
    ///
    /// This gives the current firmware being `.queued` or `.downloading`, or the firmware that was being downloaded
    /// when the task completed, either successfully, with error or because of cancelation.
    var current: FirmwareInfoCore { get }
    /// Total count of firmwares this task should download.
    var totalCount: Int { get }
    /// Overall task progress, in percent.
    var totalProgress: Int { get }
}

/// Extension of the download task that brings default implementations
extension FirmwareDownloaderCoreTask {
    public var downloaded: [FirmwareInfoCore] {
        return Array(requested.dropLast(requested.count - (currentCount - ((state == .success) ? 0 : 1))))
    }
    public var currentCount: Int {
        return (state == .success) ? totalCount : totalCount - remaining.count + 1
    }
    public var current: FirmwareInfoCore {
        return requested[currentCount - 1]
    }
    public var totalCount: Int {
        return requested.count
    }
    public var totalProgress: Int {
        let totalSize = requested.reduce(0) { $0 + $1.size }
        var downloadedSize = downloaded.reduce(0) { $0 + $1.size }
        if state != .success {
            downloadedSize += UInt64(currentProgress) * current.size / 100
        }
        return totalSize == 0 ? 0 : Int(round(Double(downloadedSize * 100) / Double(totalSize)))
    }
}

/// Private implementation of the firmware downloader task.
///
/// Visibility is internal for testing purpose.
class FirmwareDownloaderCoreTaskImpl: NSObject, FirmwareDownloaderCoreTask {
    fileprivate(set) public var state = FirmwareDownloaderCoreTaskState.failed
    public let requested: [FirmwareInfoCore]
    fileprivate(set) public var remaining: [FirmwareInfoCore]
    fileprivate(set) public var currentProgress = 0

    /// Downloader owning this task (unowned).
    private unowned let downloader: FirmwareDownloaderCoreImpl

    /// Observer notified when the task state changes.
    private let observer: (FirmwareDownloaderCoreTask) -> Void

    /// Whether the observer has not been notified of changes yet.
    private var changed = false

    /// Constructor
    ///
    /// - Parameters:
    ///   - firmwares: firmwares to download, in order
    ///   - downloader: downloader owning this task
    ///   - observer: observer notified when the task state changes
    init(firmwares: [FirmwareInfoCore], downloader: FirmwareDownloaderCoreImpl,
         observer: @escaping (FirmwareDownloaderCoreTask) -> Void) {
        requested = firmwares
        remaining = requested
        self.downloader = downloader
        self.observer = observer
    }

    /// Cancels the task.
    ///
    /// When canceled, all queued firmware download requests are discarded.
    /// In case some firmware is currently being downloaded for this task, then, provided no other existing task
    /// requested that particular firmware to be downloaded too, the download is canceled.
    ///
    /// This operation has no effect if the task is already `.canceled`, has `.failed`, or completed with `.success`.
    public func cancel() {
        guard state == .queued || state == .downloading else {
            return
        }

        if let current = remaining.first {
            downloader.unqueue(firmware: current.firmwareIdentifier, task: self)
        }
        update(state: .canceled)
        notifyUpdated()
    }

    /// Queues the task for download.
    fileprivate func queue() {
        queueNext()
    }

    /// Called back after queued firmware for this task has been successfully downloaded.
    func downloadDidSuccess() {
        update(currentProgress: 100)
        remaining.removeFirst()
        markChanged()
        queueNext()
    }

    /// Called back after some firmware download for this task failed.
    func downloadDidFail() {
        update(state: .failed)
        notifyUpdated()
    }

    /// Called back after some firmware download for this task is canceled.
    func downloadDidCancel() {
        update(state: .canceled)
        notifyUpdated()
    }

    /// Called back after queued firmware download progress for this task updates.
    ///
    /// - Parameter progress: firmware download progress
    func downloadDidProgress(_ progress: Int) {
        update(state: .downloading)
        update(currentProgress: progress)
        notifyUpdated()
    }

    /// Queues next firmware to download.
    private func queueNext() {
        if let next = remaining.first {
            update(state: .queued)
            update(currentProgress: 0)
            downloader.queue(firmware: next.firmwareIdentifier, task: self)
        } else {
            update(state: .success)
        }
        notifyUpdated()
    }

    /// Updates current task state.
    ///
    /// - Parameter newValue: new state
    private func update(state newValue: FirmwareDownloaderCoreTaskState) {
        if state != newValue {
            state = newValue
            markChanged()
        }
    }

    /// Updates current task progress.
    ///
    /// - Parameter newValue: new progress
    private func update(currentProgress newValue: Int) {
        if currentProgress != newValue {
            currentProgress = newValue
            markChanged()
        }
    }

    /// Mark this object as changed.
    private func markChanged() {
        changed = true
    }

    /// Notifies all observers of task state change, iff it did change since last call to this method.
    private func notifyUpdated() {
        if changed {
            changed = false
            observer(self)
        }
    }
}

/// Utility interface allowing to download firmwares.
public protocol FirmwareDownloaderCore: UtilityCore {
    /// Download a list of firmware files
    ///
    /// - Parameters:
    ///   - firmwares: list of firmware files to download
    ///   - observer: observer that will get called when the download task changes
    ///   - task: the download task
    func download(firmwares: [FirmwareInfoCore], observer: @escaping (_ task: FirmwareDownloaderCoreTask) -> Void)
}

/// Implementation of FirmwareDownloader utility.
class FirmwareDownloaderCoreImpl: FirmwareDownloaderCore {
    let desc: UtilityCoreDescriptor = Utilities.firmwareDownloader

    /// Engine owning this downloader
    private unowned let engine: FirmwareEngine

    /// Update REST Api
    ///
    /// Not nil after `start(downloader:)` has been called.
    private var downloader: UpdateRestApi!

    /// Root folder to store the firmwares
    private let firmwareFolder: URL

    /// Current download request
    private var currentDownload: CancelableCore?
    /// Current download progress
    private var currentProgress = 0

    /// Queue of firmwares to be downloaded (keys). Each mapping to the set of tasks that depends on it.
    private var downloadQueue: [FirmwareIdentifier: Set<FirmwareDownloaderCoreTaskImpl>] = [:]
    /// Queue of firmwares to be downloaded represented by their firmware identifiers. Sorted in download order.
    private var sortedDownloadQueue: [FirmwareIdentifier] = []

    init(engine: FirmwareEngine, destinationFolder: URL) {
        self.engine = engine
        self.firmwareFolder = destinationFolder
    }

    func start(downloader: UpdateRestApi) {
        self.downloader = downloader
    }

    func download(firmwares: [FirmwareInfoCore], observer: @escaping (FirmwareDownloaderCoreTask) -> Void) {
        FirmwareDownloaderCoreTaskImpl(firmwares: firmwares, downloader: self, observer: observer).queue()
    }

    /// Queues a firmware for download
    ///
    /// - Parameters:
    ///   - firmware: the firmware to be downloaded
    ///   - task: task that requests this firmware download
    fileprivate func queue(firmware: FirmwareIdentifier, task: FirmwareDownloaderCoreTaskImpl) {
        if let entry = engine.firmwareStore.getEntry(for: firmware), entry.isLocal {
            task.downloadDidSuccess()
        } else {
            if !sortedDownloadQueue.contains(firmware) {
                sortedDownloadQueue.append(firmware)
            }
            var tasks = downloadQueue[firmware] ?? []
            let (inserted, _) = tasks.insert(task)
            downloadQueue[firmware] = tasks
            if inserted && tasks.count == 1 {
                processQueue()
            } else if isCurrentlyDownloading(firmware: firmware) {
                task.downloadDidProgress(currentProgress)
            }
        }
    }

    /// Unqueues a firmware from download.
    ///
    /// - Parameters:
    ///   - firmware: the firmware to be unqueued
    ///   - task: the task that does not requests this firmware anymore
    fileprivate func unqueue(firmware: FirmwareIdentifier, task: FirmwareDownloaderCoreTaskImpl) {
        if var tasks = downloadQueue[firmware], tasks.remove(task) != nil {
            downloadQueue[firmware] = tasks
            if tasks.isEmpty {
                if isCurrentlyDownloading(firmware: firmware) {
                    currentDownload?.cancel()
                } else {
                    downloadQueue[firmware] = nil
                }
            }
        }
    }

    /// Processes the download queue.
    ///
    /// Starts to download next in queue, if any and no firmware is being downloaded currently.
    private func processQueue() {
        guard currentDownload == nil, !downloadQueue.isEmpty else {
            return
        }

        let firmware = sortedDownloadQueue.first!   // can force unwrap because downloadQueue is not empty
        if let entry = engine.firmwareStore.getEntry(for: firmware) {
            if entry.localUrl != nil {
                downloadDidSuccess(firmware: firmware)
            } else {
                if let remoteUrl = entry.remoteUrl {
                    let destinationUrl = getDestinationUrl(for: firmware, name: remoteUrl.lastPathComponent)

                    currentDownload = downloader.downloadFirmware(
                        from: remoteUrl, to: destinationUrl,
                        didProgress: { [weak self] progress in
                            self?.currentProgress = progress
                            self?.downloadDidProgress(firmware: firmware)
                        },
                        didComplete: { [weak self] status, url in
                            self?.currentDownload = nil
                            switch status {
                            case .success:
                                self?.engine.firmwareStore.changeRemoteFirmwareToLocal(
                                    identifier: firmware, localUrl: url!)
                                self?.downloadDidSuccess(firmware: firmware)
                            case .failed:
                                self?.downloadDidFail(firmware: firmware)
                            case .canceled:
                                self?.downloadDidCancel(firmware: firmware)
                            }
                    })
                    currentProgress = 0
                    downloadDidProgress(firmware: firmware)
                } else {
                    downloadDidFail(firmware: firmware)
                }
            }
        } else {
            downloadDidFail(firmware: firmware)
        }
    }

    /// Called back after some firmware has been successfully downloaded.
    ///
    /// - Parameter firmware: identifies the downloaded firmware
    private func downloadDidSuccess(firmware: FirmwareIdentifier) {
        if let index = sortedDownloadQueue.index(of: firmware) {
            sortedDownloadQueue.remove(at: index)
        }
        downloadQueue.removeValue(forKey: firmware)?.forEach {
            $0.downloadDidSuccess()
        }
        processQueue()
    }

    /// Called back after some firmware download failed.
    ///
    /// - Parameter firmware: identifies the firmware whose download did fail.
    private func downloadDidFail(firmware: FirmwareIdentifier) {
        if let index = sortedDownloadQueue.index(of: firmware) {
            sortedDownloadQueue.remove(at: index)
        }
        downloadQueue.removeValue(forKey: firmware)?.forEach {
            $0.downloadDidFail()
        }
        processQueue()
    }

    /// Called back after some firmware download is canceled.
    ///
    /// - Parameter firmware: identifies the firmware whose download was canceled.
    private func downloadDidCancel(firmware: FirmwareIdentifier) {
        if let index = sortedDownloadQueue.index(of: firmware) {
            sortedDownloadQueue.remove(at: index)
        }
        downloadQueue.removeValue(forKey: firmware)?.forEach {
            $0.downloadDidCancel()
        }
        processQueue()
    }

    /// Called back after some firmware download progress updates.
    ///
    /// - Parameter firmware: identifies the firmware whose download did progress.
    private func downloadDidProgress(firmware: FirmwareIdentifier) {
        downloadQueue[firmware]?.forEach {
            $0.downloadDidProgress(currentProgress)
        }
    }

    /// Tells whether some firmware is currently being downloaded.
    ///
    /// If this method returns `true`, then it is safe to assume that `currentDownload` is not `nil`.
    ///
    /// - Parameter firmware: identifies the firmware to test
    /// - Returns: true if the specified firmware is currently being downloaded
    private func isCurrentlyDownloading(firmware: FirmwareIdentifier) -> Bool {
        return currentDownload != nil && firmware == sortedDownloadQueue.first
    }

    /// Creates a destination url for a given firmware
    ///
    /// A firmware in version X.Y.Z for model A will be stored in `firmwareFolder/A/X.Y.Z/name`.
    ///
    /// - Parameters:
    ///   - identifier: the firmware identifier
    ///   - name: the name of the file
    /// - Returns: an url where the given firmware should be downloaded.
    private func getDestinationUrl(for identifier: FirmwareIdentifier, name: String) -> URL {
        return firmwareFolder.appendingPathComponent(identifier.deviceModel.description, isDirectory: true)
            .appendingPathComponent(identifier.version.description, isDirectory: true).appendingPathComponent(name)
    }
}

/// Description of the FirmwareDownloader utility
public class FirmwareDownloaderCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = FirmwareDownloaderCore
    public let uid = UtilityUid.firmwareDownloader.rawValue
}
