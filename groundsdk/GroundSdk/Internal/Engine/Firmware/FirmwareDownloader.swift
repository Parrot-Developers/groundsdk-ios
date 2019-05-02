//    Copyright (C) 2019 Parrot Drones SAS
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

/// Manages download of firmware update files.
class FirmwareDownloader {

    /// State of the firmware downloader
    enum State: CustomStringConvertible {
        /// No download ongoing currently
        case idle
        /// Queued firmwares are being downloaded
        case downloading

        /// Debug description
        var description: String {
            switch self {
            case .idle:         return "idle"
            case .downloading:  return "downloading"
            }
        }
    }

    /// Latest download error
    enum Error: CustomStringConvertible {
        /// No error occurred
        case none
        /// Download was aborted
        case aborted
        /// Download failed due to some server error
        case serverError

        /// Debug description
        var description: String {
            switch self {
            case .none:         return "none"
            case .aborted:      return "aborted"
            case .serverError:  return "serverError"
            }
        }
    }

    /// Provides firmware downloader change notification
    class Observer: NSObject {

        /// The firmware downloader owning this observer.
        private unowned let observable: FirmwareDownloader

        /// Block that should be called when the firmware downloader changes
        fileprivate var didChange: () -> Void

        /// Constructor
        ///
        /// - Parameters:
        ///   - observable: firmware downloader owning this observer
        ///   - didChange: block that should be called when the firmware downloader changes
        init(observable: FirmwareDownloader, didChange: @escaping () -> Void) {
            self.observable = observable
            self.didChange = didChange
        }

        /// Unregister this observer
        func unregister() {
            observable.unregister(observer: self)
        }
    }

    /// Engine owning this downloader
    private unowned let engine: FirmwareEngine

    /// Update REST Api
    private let downloader: UpdateRestApi

    /// Root folder to store the firmwares
    private let firmwareFolder: URL

    /// Queue of firmwares to be downloaded
    private var downloadQueue: [FirmwareIdentifier] = []

    /// Current request
    private var currentRequest: CancelableCore?

    /// Set of registered observers
    private var observers: Set<Observer> = []

    /// Current state
    private(set) var state = State.idle
    /// Latest download error.
    private(set) var latestError = Error.none

    /// Identifies currently downloaded firmware.
    var currentDownload: FirmwareIdentifier? {
        return downloadQueue.first
    }

    /// Current firmware download progress.
    private(set) var progress = 0
    /// Whether this downloader has changed
    private var changed = false

    /// Constructor
    ///
    /// - Parameters:
    ///   - engine: the engine owning this object
    ///   - downloader: the downloader
    ///   - destinationFolder: root folder where downloaded firmwares should be stored
    init(engine: FirmwareEngine, downloader: UpdateRestApi, destinationFolder: URL) {
        self.engine = engine
        self.downloader = downloader
        self.firmwareFolder = destinationFolder
    }

    /// Queues a firmware for download.
    ///
    /// The given firmware will be downloaded after all previously queued firmware download have successfully completed.
    /// In case some queued download fails, then the downloader stops and all remaining queued downloads are discarded.
    ///
    /// - Parameter firmwareIdentifier: identifier of the firmware to be downloaded
    func queueForDownload(firmwareIdentifier: FirmwareIdentifier) {
        if !downloadQueue.contains(firmwareIdentifier) {
            downloadQueue.append(firmwareIdentifier)
        }

        processNextFirmware()
    }

    /// Registers an observer that will receive firmware downloader state change notifications.
    ///
    /// - Parameter didChange: block that will be called when the downloader changes
    /// - Returns: the observer.
    ///
    /// - Note: `unregister()` should be called on the returned observer when not needed anymore.
    func registerObserver(didChange: @escaping () -> Void) -> Observer {
        let observer = Observer(observable: self, didChange: didChange)
        observers.insert(observer)
        return observer
    }

    /// Unregisters an observer
    ///
    /// - Parameter observer: observer to unregister
    private func unregister(observer: Observer) {
        observers.remove(observer)
    }

    /// Downloads next firmware in queue.
    private func processNextFirmware() {
        guard currentRequest == nil else {
            return
        }

        update(progress: 0)

        var nextEntry: FirmwareStoreEntry?
        while nextEntry == nil && !downloadQueue.isEmpty {
            update(state: .downloading)
            update(latestError: .none)
            notifyUpdated()

            nextEntry = engine.firmwareStore.getEntry(for: downloadQueue.first!)
            if nextEntry == nil || nextEntry!.isLocal || nextEntry!.remoteUrl == nil {
                downloadQueue.removeFirst()
                nextEntry = nil
            }
        }

        if let nextEntry = nextEntry {
            let firmwareIdentifier = nextEntry.firmware.firmwareIdentifier
            let remoteUrl = nextEntry.remoteUrl!
            let destinationUrl = getDestinationUrl(for: firmwareIdentifier, name: remoteUrl.lastPathComponent)

            currentRequest = downloader.downloadFirmware(
                from: remoteUrl, to: destinationUrl,
                didProgress: { [weak self] progress in
                    self?.update(progress: progress)
                    self?.notifyUpdated()
                },
                didComplete: { [weak self] status, url in
                    self?.currentRequest = nil
                    self?.downloadQueue.removeFirst()

                    if status == .success {
                        self?.engine.firmwareStore.changeRemoteFirmwareToLocal(
                            identifier: firmwareIdentifier, localUrl: url!)
                    } else {
                        self?.downloadQueue.removeAll()
                        self?.update(latestError: status == .canceled ? .aborted : .serverError)
                    }
                    self?.processNextFirmware()
            })
        } else {
            update(state: .idle)
        }

        notifyUpdated()
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

    /// Updates current downloaded update file progress.
    ///
    /// - Parameter newValue: new progress value
    private func update(progress newValue: Int) {
        if progress != newValue {
            progress = newValue
            changed = true
        }
    }

    /// Updates current downloader state.
    ///
    /// - Parameter newValue: new state
    private func update(state newValue: State) {
        if state != newValue {
            state = newValue
            changed = true
        }
    }

    /// Updates latest download error.
    ///
    /// - Parameter newValue: new latest error
    private func update(latestError newValue: Error) {
        if latestError != newValue {
            latestError = newValue
            changed = true
        }
    }

    /// Notifies all observers of download state change, iff state did change since last call to this method
    private func notifyUpdated() {
        if changed {
            changed = false
            observers.forEach { $0.didChange() }
        }
    }
}
