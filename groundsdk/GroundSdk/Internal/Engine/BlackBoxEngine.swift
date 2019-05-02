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

/// Black box engine.
class BlackBoxEngine: EngineBaseCore {
    /// Black box reporter facility
    private let blackBoxReporter: BlackBoxReporterCore

    /// Url path of the root directory where reports are stored on the user device's local file system.
    ///
    /// This directory is located in the cache folder of the phone/tablet.
    ///
    /// This directory may contain:
    /// - the current work directory (see `workDir`) , which may itself contain temporary reports
    ///   (being currently downloaded from remote devices) and finalized reports (that are ready to be uploaded)
    /// - previous work directories, that may themselves contain finalized reports, or temporary reports that failed to
    ///   be downloaded completely.
    ///
    /// When the engine starts, all finalized reports from all work directories are listed and queued for upload;
    /// temporary reports in previous work directories (other than the work directory) are deleted.
    /// Temporary reports in the work directory are left untouched.
    let engineDir: URL

    /// Url path of the current work directory where reports downloaded from remote devices get stored.
    /// This directory is located in `engineDir`.
    let workDir: URL

    /// Name of the directory in which the black boxes should be stored
    private let reportsDirName = "BlackBoxes"

    /// Monitor of the connectivity changes
    private var connectivityMonitor: MonitorCore!

    /// Monitor of the userAccount changes
    private var userAccountMonitor: MonitorCore!

    /// User Account information
    private var userAccountInfo: UserAccountInfoCore?

    /// Black box reports collector
    private var collector: BlackBoxCollector!

    /// List of reports waiting for upload.
    ///
    /// This list is used as a queue: new reports are added at the end, report to upload is the first one.
    /// The report to upload is removed from this list after it is fully and correctly uploaded.
    ///
    /// - Note: visibility is internal for testing purposes only.
    private(set) var pendingReports: [BlackBox] = []

    /// The uploader.
    /// `nil` until engine is started.
    private var uploader: BlackBoxUploader?

    /// Current upload request.
    /// Kept to allow cancellation.
    private var currentUploadRequest: CancelableCore?

    /// space quota in megabytes
    private var spaceQuotaInMb: Int = 0

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        ULog.d(.blackBoxEngineTag, "Loading BlackBoxEngine.")

        let cacheDirUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        engineDir = cacheDirUrl.appendingPathComponent(reportsDirName, isDirectory: true)
        workDir = engineDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        spaceQuotaInMb = GroundSdkConfig.sharedInstance.blackBoxQuotaMb ?? 0

        blackBoxReporter = BlackBoxReporterCore(store: enginesController.facilityStore)

        super.init(enginesController: enginesController)
        publishUtility(BlackBoxStorageCoreImpl(engine: self))
        collector = createCollector()
    }

    public override func startEngine() {
        ULog.d(.blackBoxEngineTag, "Starting BlackBoxEngine.")

        // get the UserAccount Utility in order to know if BlackBoxes are allowed (if the UserAccount exists)
        let userAccountUtility = utilities.getUtility(Utilities.userAccount)!
        userAccountInfo = userAccountUtility.userAccountInfo
        userAccountMonitor = userAccountUtility.startMonitoring(accountDidChange: { (newUserAccountInfo) in
            if newUserAccountInfo != self.userAccountInfo {
                // if the account property changes and if the previous account was not nil, we delete all files
                // (a new user was identified or a user has logout)
                if self.userAccountInfo?.account != newUserAccountInfo?.account &&
                    self.userAccountInfo?.account != nil {
                    self.stopAndDropAllBlackBoxes()
                }
                self.userAccountInfo = newUserAccountInfo
            }
        })

        if spaceQuotaInMb != 0 {
            try? FileManager.cleanOldInDirectory(url: engineDir, fileExt: "gz",
                                                    totalMaxSizeMb: spaceQuotaInMb, includingSubfolders: true)
        }

        collector.collectBlackBoxes { [weak self] blackBoxes in
            if let `self` = self, self.started {
                self.pendingReports.append(contentsOf: blackBoxes)
                self.startBlackBoxUploadProcess()
            }
        }
        connectivityMonitor = utilities.getUtility(Utilities.internetConnectivity)!
            .startMonitoring { [unowned self] internetAvailable in
                if internetAvailable {
                    self.startBlackBoxUploadProcess()
                } else {
                    self.cancelCurrentUpload()
                }
        }

        // can force unwrap because this utility is always published.
        let cloudServer = utilities.getUtility(Utilities.cloudServer)!
        uploader = BlackBoxUploader(cloudServer: cloudServer)

        blackBoxReporter.publish()
    }

    public override func stopEngine() {
        ULog.d(.blackBoxEngineTag, "Stopping BlackBoxEngine.")
        userAccountMonitor?.stop()
        userAccountMonitor = nil
        blackBoxReporter.unpublish()
        cancelCurrentUpload()
        uploader = nil
        connectivityMonitor.stop()
    }

    /// Encode and store on the file system a black box encodable data.
    ///
    /// - Parameter blackBoxData: the encodable data to archive
    func archiveBlackBoxData<T: Encodable>(_ blackBoxData: T) {
        collector.archive(blackBoxData: blackBoxData) { [weak self] report in
            self?.pendingReports.append(report)
            self?.startBlackBoxUploadProcess()
        }
    }

    /// Creates a collector
    ///
    /// - Returns: a new collector
    /// - Note: Visibility is internal only for testing purposes.
    func createCollector() -> BlackBoxCollector {
        return BlackBoxCollector(rootDir: engineDir, workDir: workDir)
    }

    /// Start the uploading process of blackBox files
    ///
    /// if an upload is already start we are only updating the pending count
    /// uploading process is only start when it is not already uploading files.
    private func startBlackBoxUploadProcess() {
        guard !blackBoxReporter.isUploading else {
            blackBoxReporter.update(pendingCount: pendingReports.count)
            return
        }
        processNextBlackBox()
    }

    /// Try to upload the first black box of the list.
    ///
    /// It will only start the upload if the engine is not currently uploading a black box, if internet connectivity
    /// is available, and if userAccount is set. A filter will be done on creation date if user deny upload of old
    /// file created before the user account was present.
    private func processNextBlackBox() {
        blackBoxReporter.update(pendingCount: pendingReports.count)
        if self.userAccountInfo?.account == nil
        || utilities.getUtility(Utilities.internetConnectivity)?.internetAvailable == false {
            blackBoxReporter.update(isUploading: false).notifyUpdated()
            return
        }

        if let uploader = uploader,
            currentUploadRequest == nil {
            if let blackBox = pendingReports.first {
                if self.userAccountInfo!.accountlessPersonalDataPolicy == .denyUpload {
                    // check if the file is before the authentification date
                    // if yes, we remove the file because the user did not accept the download of the data collected
                    // before the authentication
                    let toRemove: Bool
                    if let attrs = try? FileManager.default.attributesOfItem(
                        atPath: blackBox.url.path), let creationDate = attrs[.creationDate] as? Date,
                        let userDate = userAccountInfo?.changeDate {
                        toRemove = creationDate < userDate
                    } else {
                        toRemove = true
                    }
                    if toRemove {
                        self.deleteBlackBox(blackBox)
                        self.processNextBlackBox()
                        return
                    }
                }

                blackBoxReporter.update(isUploading: true)
                currentUploadRequest = uploader.upload(blackBox: blackBox) { report, error in
                    self.currentUploadRequest = nil

                    if let error = error {
                        switch error {
                        case .badRequest:
                            ULog.w(.blackBoxEngineTag, "Bad request sent to the server. This should be a dev error.")
                            // delete file and stop uploading to avoid multiple errors
                            self.deleteBlackBox(report)
                            self.blackBoxReporter.update(isUploading: false).notifyUpdated()
                        case .badReport:
                            self.deleteBlackBox(report)
                            self.processNextBlackBox()
                        case .serverError,
                             .connectionError:
                            // Stop uploading if the server is not accessible
                            self.blackBoxReporter.update(isUploading: false).notifyUpdated()
                        case .canceled:
                            self.blackBoxReporter.update(isUploading: false).notifyUpdated()
                        }
                    } else {    // success
                        self.deleteBlackBox(report)
                        self.processNextBlackBox()
                    }
                }
            } else {
                blackBoxReporter.update(isUploading: false)
            }
        }
        blackBoxReporter.notifyUpdated()
    }

    /// Remove the given report from the pending ones and delete it from the file system.
    ///
    /// - Parameter blackBox: the black box report to delete
    private func deleteBlackBox(_ blackBox: BlackBox) {
        if self.pendingReports.first == blackBox {
            self.pendingReports.remove(at: 0)
        } else {
            ULog.w(.blackBoxEngineTag, "Uploaded report is not the first one of the pending")
            // fallback
            if let index: Int = self.pendingReports.index(where: {$0 == blackBox}) {
                self.pendingReports.remove(at: index)
            }
        }

        self.collector.deleteBlackBox(at: blackBox.url)
    }

    /// Cancel the current upload if there is one.
    private func cancelCurrentUpload() {
        // stop current upload request
        self.currentUploadRequest?.cancel()
        self.currentUploadRequest = nil
    }

    /// Stop and drop any BlackBox.
    ///
    /// Note: this function is called when a user is no more identified (and has not accepted the terms of use and
    /// confidentiality). Blackboxes are only recorded, archived, and sent when a authorized account is present
    private func stopAndDropAllBlackBoxes() {

        // stop the upload if any
        cancelCurrentUpload()

        pendingReports.forEach { (blackBox) in
            collector.deleteBlackBox(at: blackBox.url)
        }

        // clear all pending blackBoxes
        pendingReports.removeAll()

        // update the facility
        blackBoxReporter.update(isUploading: false).update(pendingCount: 0).notifyUpdated()
    }
}
