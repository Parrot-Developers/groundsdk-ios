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
import GroundSdk

/// Firmware updater specific uploader part
protocol UpdaterFirmwareUploader: class {
    /// Configure the delegate
    ///
    /// - Parameter updater: the updater in charge
    func configure(updater: UpdaterController)
    /// Reset the delegate
    ///
    /// - Parameter updater: the updater in charge
    func reset(updater: UpdaterController)
    /// Update the device with a given firmware
    ///
    /// - Parameters:
    ///   - firmwareVersion: version of the firmware to upload
    ///   - deviceController: the device controller that owns the firmware updater peripheral controller
    ///   - store: firmware store providing firmware data to upload
    ///   - uploadProgress: callback that will be called when the update progress changes
    ///   - progress: the current update progress
    ///   - updateEndStatus: callback that will be called when the update finishes
    ///   - status: the end status of the update
    /// - Returns:  the update request, nil if it could not start the update.
    func update(toVersion firmwareVersion: FirmwareVersion, deviceController: DeviceController,
                store: FirmwareStoreCore, uploadProgress: @escaping (_ progress: Int) -> Void,
                updateEndStatus: @escaping (_ status: UpdaterUpdateState) -> Void) -> CancelableCore?
}

/// Updater event receiver delegate
protocol UpdaterEventReceiver: class {
    /// Configure the delegate
    ///
    /// - Parameters:
    ///   - updateUnavailabilityReasonChanged: callback to know when the update unavailability has changed
    ///   - reason: the reason involved in the change
    ///   - isUnavailable: whether this reason appeared or disappeared
    func configure(
        updateUnavailabilityReasonChanged: @escaping (_ reason: UpdaterUpdateUnavailabilityReason,
        _ isUnavailable: Bool) -> Void)

    /// informs the event receiver that a command has been received
    ///
    /// - Parameter command: received command
    func didReceiveCommand(_ command: OpaquePointer)
}

/// Updater component controller
class UpdaterController: DeviceComponentController {
    /// A configuration to create a proper firmware updater
    struct Config {
        /// Type of the uploader
        enum UploaderType {
            /// Upload should be done through ftp
            case ftp
            /// Upload should be done through http
            case http
        }

        /// Device model
        let deviceModel: DeviceModel
        /// type of the uploader
        let uploaderType: UploaderType

        /// Instance of the uploader delegate
        var uploader: UpdaterFirmwareUploader {
            switch uploaderType {
            case .ftp:  return FtpFirmwareUploader()
            case .http: return HttpFirmwareUploader()
            }
        }

        /// Instance of the event receiver delegate
        var messageReceiver: UpdaterEventReceiver {
            switch deviceModel {
            case .rc:       return RcUpdaterEventReceiver()
            case .drone:    return DroneUpdaterEventReceiver()
            }
        }
    }

    /// FirmwareUpdater component.
    private(set) var firmwareUpdater: UpdaterCore!

    /// Firmware store utility
    private let firmwareStore: FirmwareStoreCore

    /// Firmware downloader utility
    private let downloader: FirmwareDownloaderCore

    /// Monitor on the connectivity
    private var connectivityMonitor: MonitorCore!

    /// Monitor on the firmware store
    private var firmwareStoreMonitor: MonitorCore!

    /// Delegate to upload the firmware file
    private let uploader: UpdaterFirmwareUploader

    /// Delegate to handle received events
    private let eventReceiver: UpdaterEventReceiver

    /// Queue of firmwares that must be applied. Maintained across device reboot/reconnection to allow automated
    /// updating with multiple firmware in sequence.
    private var updateQueue: [FirmwareInfoCore] = []

    /// Set of reasons that prevent to do an update
    private var updateUnavailabilityReasons: Set<UpdaterUpdateUnavailabilityReason> = [] {
        didSet {
            if updateUnavailabilityReasons != oldValue {
                firmwareUpdater.update(updateUnavailabilityReasons: updateUnavailabilityReasons)
                if !updateUnavailabilityReasons.isEmpty {
                    currentUpdate?.cancel()
                }
            }
        }
    }

    /// Set of reasons that prevent to do a download
    private var downloadUnavailabilityReasons: Set<UpdaterDownloadUnavailabilityReason> = [] {
        didSet {
            if downloadUnavailabilityReasons != oldValue {
                firmwareUpdater.update(downloadUnavailabilityReasons: downloadUnavailabilityReasons)
            }
        }
    }

    /// Current firmware update request. nil when no firmware update is being applied.
    var currentUpdate: CancelableCore?

    /// Constructor
    ///
    /// - Parameters:
    ///   - deviceController: device controller owning this component controller (weak)
    ///   - config: constructor configuration
    ///   - firmwareStore: firmware store utility
    ///   - firmwareDownloader: firmware downloader utility
    init(deviceController: DeviceController, config: Config, firmwareStore: FirmwareStoreCore,
         firmwareDownloader: FirmwareDownloaderCore) {
        uploader = config.uploader
        eventReceiver = config.messageReceiver
        self.firmwareStore = firmwareStore
        self.downloader = firmwareDownloader
        super.init(deviceController: deviceController)

        firmwareUpdater = UpdaterCore(store: deviceController.device.peripheralStore, backend: self)
        firmwareStoreMonitor = firmwareStore.startMonitoring { [weak self] in
            self?.processFirmwareInfos()
            self?.firmwareUpdater.notifyUpdated()
        }

        setInitialValues()

        eventReceiver.configure(updateUnavailabilityReasonChanged: { [unowned self] reason, isUnavailable in
            if isUnavailable {
                self.updateUnavailabilityReasons.insert(reason)
            } else {
                self.updateUnavailabilityReasons.remove(reason)
            }
            if self.connected {
                self.firmwareUpdater.notifyUpdated()
            }
        })

        connectivityMonitor = deviceController.engine.utilities.getUtility(Utilities.internetConnectivity)!
            .startMonitoring { [unowned self] isInternetAvailable in
                if isInternetAvailable {
                    self.downloadUnavailabilityReasons.remove(.internetUnavailable)
                } else {
                    self.downloadUnavailabilityReasons.insert(.internetUnavailable)
                }
                self.firmwareUpdater.notifyUpdated()
        }

        processFirmwareInfos()

        // if the device is known, publish the component
        if !deviceController.deviceStore.new {
            firmwareUpdater.publish()
        }
    }

    deinit {
        connectivityMonitor.stop()
        firmwareStoreMonitor.stop()
    }

    /// Set initial values.
    ///
    /// - Note: This function is needed because if these values are directly set in the init, the didSet block won't be
    ///   called.
    func setInitialValues() {
        updateUnavailabilityReasons.insert(.notConnected)
        downloadUnavailabilityReasons.insert(.internetUnavailable)
    }

    override func didConnect() {
        super.didConnect()

        uploader.configure(updater: self)

        updateUnavailabilityReasons.remove(.notConnected)
        // compute up-to-date update info (device firmware may have changed)
        processFirmwareInfos()

        if let expectedFirmware = updateQueue.first {
            updateQueue.removeFirst()
            if deviceController.device.firmwareVersionHolder.version != expectedFirmware.firmwareIdentifier.version {
                // inconsistent, mark update failed
                updateDidEnd(withState: .failed)
            } else if updateQueue.isEmpty {
                // all done, success
                updateDidEnd(withState: .success)
            } else if updateUnavailabilityReasons.isEmpty {
                // continue update
                firmwareUpdater.continueUpdate()
                updateFirmware(toVersion: updateQueue.first!.firmwareIdentifier.version)
            } else {
                // cannot continue, fail
                updateDidEnd(withState: .failed)
            }
        }

        firmwareUpdater.publish()
        firmwareUpdater.notifyUpdated()
    }

    override func didDisconnect() {
        updateUnavailabilityReasons = [.notConnected]

        if !updateQueue.isEmpty {
            // if the current update is in processing state, move to .waitingForReboot state,
            // otherwise consider the update as failed
            if let currentUpdate = firmwareUpdater.currentUpdate, currentUpdate.state == .processing {
                firmwareUpdater.update(updateState: .waitingForReboot)
            } else {
                updateDidEnd(withState: .failed)
            }
        }
        // call notifyUpdated before unpublishing the component to be sure that the waitingForReboot is received
        firmwareUpdater.notifyUpdated()

        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            firmwareUpdater.unpublish()
        }

        super.didDisconnect()
    }

    /// Drone is about to be forgotten
    override func willForget() {
        firmwareUpdater.unpublish()
        super.willForget()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        eventReceiver.didReceiveCommand(command)
    }

    /// Updates the device to the given version
    ///
    /// - Parameter version: the version to update the device to
    private func updateFirmware(toVersion version: FirmwareVersion) {
        currentUpdate = uploader.update(
            toVersion: version,
            deviceController: deviceController, store: firmwareStore,
            uploadProgress: { [weak self] progress in
                self?.firmwareUpdater.update(uploadProgress: progress)
                if progress == 100 {
                    self?.firmwareUpdater.update(updateState: .processing)
                }
                self?.firmwareUpdater.notifyUpdated()
        }, updateEndStatus: { [weak self] state in
            self?.currentUpdate = nil
            // if success, nothing to do, just wait for reboot.
            if state != .success {
                self?.updateDidEnd(withState: state)
            }
        })
    }

    /// Processes firmware store content and current device firmware version to update downloadable and applicable
    /// firmwares info.
    ///
    /// - Note: This method may update the component state, but does **not** call `notifyUpdated()`
    private func processFirmwareInfos() {
        let device = deviceController.device! // can force unwrap since device is a DeviceCore!
        let currentVersion = deviceController.device.firmwareVersionHolder.version
        let firmwareIdentifier = FirmwareIdentifier(deviceModel: device.deviceModel, version: currentVersion)
        firmwareUpdater
            .update(idealVersion: firmwareStore.getIdealFirmware(
                for: firmwareIdentifier)?.firmwareIdentifier.version)
            .update(downloadableFirmwares: firmwareStore.getDownloadableFirmwares(for: firmwareIdentifier))
            .update(applicableFirmwares: firmwareStore.getApplicableFirmwares(on: firmwareIdentifier))

    }

    /// Called when the update process ends.
    ///
    /// This method first notifies the final status transiently by updating the status and `notifyUpdated()` to notify
    /// the change, then it signals the end of the update by clearing the update state and sending a second change
    /// notification.
    ///
    /// - Parameter state: final update status, either `.success`, `.failed` or `.canceled`.
    private func updateDidEnd(withState state: UpdaterUpdateState) {
        firmwareUpdater.update(updateState: state).notifyUpdated()
        firmwareUpdater.endUpdate().notifyUpdated()
        updateQueue = []
    }
}

/// Implementation of the backend
extension UpdaterController: UpdaterBackend {
    func download(firmwares: [FirmwareInfoCore], observer: @escaping (FirmwareDownloaderCoreTask) -> Void) {
        downloader.download(firmwares: firmwares, observer: observer)
    }

    func update(withFirmwares firmwares: [FirmwareInfoCore]) {
        guard currentUpdate == nil && updateQueue.isEmpty else {
            ULog.w(.fwTag, "Trying to start an update while an update is already in progress, ignoring the request.")
            return
        }
        guard !firmwares.isEmpty else {
            ULog.w(.fwTag, "Trying to start an update without giving any firmwares, ignoring the request.")
            return
        }

        updateQueue = firmwares
        firmwareUpdater.beginUpdate(withFirmwares: updateQueue)
        updateFirmware(toVersion: updateQueue.first!.firmwareIdentifier.version)
        firmwareUpdater.notifyUpdated()
    }

    func cancelUpdate() {
        if let currentUpdate = currentUpdate {
            currentUpdate.cancel()
        } else {
            updateDidEnd(withState: .canceled)
        }
    }
}
