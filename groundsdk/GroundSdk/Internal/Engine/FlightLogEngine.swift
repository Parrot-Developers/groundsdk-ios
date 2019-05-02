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

/// FlightLog engine.
class FlightLogEngine: EngineBaseCore {

    /// flightLogReporter facility
    private let flightLogReporter: FlightLogReporterCore

    /// Url path of the root directory where flightLogs are stored on the user device's local file system.
    ///
    /// This directory is located in the cache folder of the phone/tablet.
    ///
    /// This directory may contain:
    /// - the current work directory (see `workDir`) , which may itself contain temporary flightLogs
    ///   (being currently downloaded from remote devices) and finalized flightLogs (that are ready to be uploaded)
    /// - previous work directories, that may themselves contain finalized flightLogs, or temporary flightLogs that
    ///   failed to be downloaded completely.
    ///
    /// When the engine starts, all finalized flightLogs from all work directories are listed and queued for upload;
    /// temporary flightLogs in previous work directories (other than the work directory) are deleted.
    /// Temporary flightLogs in the work directory are left untouched.
    let engineDir: URL

    /// Url path of the current work directory where flightLogs downloaded from remote devices get stored.
    /// This directory is located in `engineDir`.
    let workDir: URL

    /// Name of the directory in which the flightLogs should be stored
    private let flightLogsLocalDirName = "FlightLogs"

    /// Monitor of the connectivity changes
    private var connectivityMonitor: MonitorCore!

    /// Monitor of the userAccount changes
    private var userAccountMonitor: MonitorCore!

    /// User Account information
    private var userAccountInfo: UserAccountInfoCore?

    /// flightLogs file collector.
    private var collector: FlightLogCollector!

    /// List of flightLogs waiting for upload.
    ///
    /// This list is used as a queue: new flightLogs are added at the end, flightLog to upload is the first one.
    /// The flightLog to upload is removed from this list after it is fully and correctly uploaded.
    ///
    /// - Note: visibility is internal for testing purposes only.
    private(set) var pendingFlightLogUrls: [URL] = []

    /// The uploader.
    /// `nil` until engine is started.
    private var uploader: FlightLogUploader?

    /// Current upload request.
    /// Kept to allow cancellation.
    private var currentUploadRequest: CancelableCore?

    /// space quota in megabytes
    private var spaceQuotaInMb: Int = 0

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        ULog.d(.flightLogEngineTag, "Loading FlightLogEngine.")

        let cacheDirUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        engineDir = cacheDirUrl.appendingPathComponent(flightLogsLocalDirName, isDirectory: true)
        workDir = engineDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        spaceQuotaInMb = GroundSdkConfig.sharedInstance.flightLogQuotaMb ?? 0

        flightLogReporter = FlightLogReporterCore(store: enginesController.facilityStore)

        super.init(enginesController: enginesController)
        publishUtility(FlightLogStorageCoreImpl(engine: self))
        collector = createCollector()
    }

    public override func startEngine() {
        ULog.d(.flightLogEngineTag, "Starting FlightLogEngine.")

        // Get the UserAccount Utility in order to know if the user changes
        let userAccountUtility = utilities.getUtility(Utilities.userAccount)!
        // get userInfo and monitor changes
        userAccountInfo = userAccountUtility.userAccountInfo
        // monitor userAccount changes
        userAccountMonitor = userAccountUtility.startMonitoring(accountDidChange: { (newUserAccountInfo) in
            if newUserAccountInfo != self.userAccountInfo {
                // if the account property changes and if the previous account was not nil, we delete all files
                // (a new user was identified or a user has logout)
                if self.userAccountInfo?.account != newUserAccountInfo?.account &&
                    self.userAccountInfo?.account != nil {
                    self.dropFlightLogs()
                }
                self.userAccountInfo = newUserAccountInfo
            }
        })

        if spaceQuotaInMb != 0 {
            try? FileManager.cleanOldInDirectory(url: engineDir, fileExt: "bin",
                                                    totalMaxSizeMb: spaceQuotaInMb, includingSubfolders: true)
        }

        collector.collectFlightLogs { [weak self] flightLogs in
            if let `self` = self, self.started {
                self.pendingFlightLogUrls.append(contentsOf: flightLogs)
                self.startFlightLogUploadProcess()

            }
        }
        connectivityMonitor = utilities.getUtility(Utilities.internetConnectivity)!
            .startMonitoring { [unowned self] internetAvailable in
                if internetAvailable {
                    self.startFlightLogUploadProcess()
                } else {
                    self.cancelCurrentUpload()
                }
        }
        // can force unwrap because this utility is always published.
        let cloudServer = utilities.getUtility(Utilities.cloudServer)!
        uploader = FlightLogUploader(cloudServer: cloudServer)

        flightLogReporter.publish()
    }

    public override func stopEngine() {
        ULog.d(.flightLogEngineTag, "Stopping FlightLogEngine.")
        userAccountMonitor?.stop()
        userAccountMonitor = nil
        flightLogReporter.unpublish()
        cancelCurrentUpload()
        uploader = nil
        connectivityMonitor.stop()
    }

    /// Adds a flightLog to the flightLogs to be uploaded.
    ///
    /// If the upload was not started and the upload may start, it will start.
    /// - Parameter flightLogUrl: local url of the flightLog that have just been added
    func add(flightLogUrl: URL) {
        pendingFlightLogUrls.append(flightLogUrl)
        startFlightLogUploadProcess()

    }

    /// Creates a collector
    ///
    /// - Returns: a new collector
    /// - Note: Visibility is internal only for testing purposes.
    func createCollector() -> FlightLogCollector {
        return FlightLogCollector(rootDir: engineDir, flightLogsLocalWorkDir: workDir)
    }

    /// Start the uploading process of flight log files
    ///
    /// if an upload is already start we are only updating the pending count
    /// uploading process is only start when it is not already uploading files.
    private func startFlightLogUploadProcess() {
        guard !flightLogReporter.isUploading else {
            flightLogReporter.update(pendingCount: pendingFlightLogUrls.count)
            return
        }
        processNextFlightLog()
    }

    /// Try to upload the first flightLog of the list.
    ///
    /// It will only start the upload if the engine is not currently uploading a flightLog, if Internet connectivity
    /// is available, if user account is present, or if anonymous data is allowed.
    private func processNextFlightLog() {
        flightLogReporter.update(pendingCount: pendingFlightLogUrls.count)
        if self.userAccountInfo?.account == nil
            || utilities.getUtility(Utilities.internetConnectivity)?.internetAvailable == false {
            flightLogReporter.update(isUploading: false).notifyUpdated()
            return
        }

        if let uploader = uploader,
            currentUploadRequest == nil {
            if let flightLog = pendingFlightLogUrls.first {
                if self.userAccountInfo?.account != nil
                    && self.userAccountInfo!.accountlessPersonalDataPolicy == .denyUpload {
                    // check if the file is before the authentification date
                    // if yes, we remove the file because the user did not accept the download of the data collected
                    // before the authentication
                    let toRemove: Bool
                    if let attrs = try? FileManager.default.attributesOfItem(
                        atPath: flightLog.path), let creationDate = attrs[.creationDate] as? Date,
                        let userDate = userAccountInfo?.changeDate {
                        toRemove = creationDate < userDate
                    } else {
                        toRemove = true
                    }
                    if toRemove {
                        self.deleteFlightLog(at: flightLog)
                        self.processNextFlightLog()
                        return
                    }
                }

                flightLogReporter.update(isUploading: true)
                currentUploadRequest = uploader.upload(flightLogUrl: flightLog) { flightLogUrl, error in
                    self.currentUploadRequest = nil

                    if let error = error {
                        switch error {
                        case .badRequest:
                            ULog.w(.flightLogEngineTag, "Bad request sent to the server. This should be a dev error.")
                            // delete file and stop uploading to avoid multiple errors
                            self.deleteFlightLog(at: flightLogUrl)
                            self.flightLogReporter.update(isUploading: false).notifyUpdated()
                        case .badFlightLog:
                            self.deleteFlightLog(at: flightLogUrl)
                            self.processNextFlightLog()
                        case .serverError,
                             .connectionError:
                            // Stop uploading if the server is not accessible
                            self.flightLogReporter.update(isUploading: false).notifyUpdated()
                        case .canceled:
                            self.flightLogReporter.update(isUploading: false).notifyUpdated()
                        }
                    } else {    // success
                        self.deleteFlightLog(at: flightLogUrl)
                        self.processNextFlightLog()
                    }
                }
            } else {
                flightLogReporter.update(isUploading: false)
            }
        }
        flightLogReporter.notifyUpdated()
    }

    /// Remove the given flightLog from the pending ones and delete it from the file system.
    ///
    /// - Parameter flightLog: the flightLog to delete
    private func deleteFlightLog(at flightLogUrl: URL) {
        if self.pendingFlightLogUrls.first == flightLogUrl {
            self.pendingFlightLogUrls.remove(at: 0)
        } else {
            ULog.w(.flightLogEngineTag, "Uploaded flightLog is not the first one of the pending")
            // fallback
            if let index: Int = self.pendingFlightLogUrls.index(where: {$0 == flightLogUrl}) {
                self.pendingFlightLogUrls.remove(at: index)
            }
        }

        self.collector.deleteFlightLog(at: flightLogUrl)
    }

    /// Cancel the current upload if there is one.
    private func cancelCurrentUpload() {
        // stop current upload request
        self.currentUploadRequest?.cancel()
        self.currentUploadRequest = nil
    }

    /// Deletes all locally stored flightLogs waiting to be uploaded.
    ///
    /// This is called when the user account changes. All recorded flightLogs are dropped since there is no proper
    /// user account identifier to use for upload anymore.
    private func dropFlightLogs() {

        // stop the upload if any
        cancelCurrentUpload()

        pendingFlightLogUrls.forEach { (flightLogUrl) in
            collector.deleteFlightLog(at: flightLogUrl)
        }

        // clear all pending flightLogs
        pendingFlightLogUrls.removeAll()

        // update the facility
        flightLogReporter.update(isUploading: false).update(pendingCount: 0).notifyUpdated()
    }
}
