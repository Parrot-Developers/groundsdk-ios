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

/// Crash report engine.
class CrashReportEngine: EngineBaseCore {
    /// Crash reporter facility
    private let crashReporter: CrashReporterCore

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

    /// Name of the directory in which the crash reports should be stored
    private let crashReportsLocalDirName = "CrashReports"

    /// Monitor of the connectivity changes
    private var connectivityMonitor: MonitorCore!

    /// Monitor of the userAccount changes
    private var userAccountMonitor: MonitorCore!

    /// User Account information
    private var userAccountInfo: UserAccountInfoCore?

    /// Crash reports file collector.
    private var collector: CrashReportCollector!

    /// List of reports waiting for upload.
    ///
    /// This list is used as a queue: new reports are added at the end, report to upload is the first one.
    /// The report to upload is removed from this list after it is fully and correctly uploaded.
    ///
    /// - Note: visibility is internal for testing purposes only.
    private(set) var pendingReportUrls: [URL] = []

    /// The uploader.
    /// `nil` until engine is started.
    private var uploader: CrashReportUploader?

    /// Current upload request.
    /// Kept to allow cancellation.
    private var currentUploadRequest: CancelableCore?

    /// Space quota in megabytes
    private var spaceQuotaInMb: Int = 0

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        ULog.d(.crashReportEngineTag, "Loading CrashReportEngine.")

        let cacheDirUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        engineDir = cacheDirUrl.appendingPathComponent(crashReportsLocalDirName, isDirectory: true)
        workDir = engineDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        spaceQuotaInMb = GroundSdkConfig.sharedInstance.crashReportQuotaMb ?? 0

        crashReporter = CrashReporterCore(store: enginesController.facilityStore)

        super.init(enginesController: enginesController)
        publishUtility(CrashReportStorageCoreImpl(engine: self))
        collector = createCollector()
    }

    public override func startEngine() {
        ULog.d(.crashReportEngineTag, "Starting CrashReportEngine.")

        // Get the UserAccount Utility in order to know if the user changes :
        // - All existing reports, pending upload, are discarded whenever the user account chages.
        // - There is no proper user account identifier to use for upload anymore.
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
                    self.dropReports()
                }
                self.userAccountInfo = newUserAccountInfo
            }
        })

        if spaceQuotaInMb != 0 {
            try? FileManager.cleanOldInDirectory(url: engineDir, fileExt: nil,
                                                    totalMaxSizeMb: spaceQuotaInMb, includingSubfolders: true)
        }

        collector.collectCrashReports { [weak self] crashReports in
            if let `self` = self, self.started {
                self.pendingReportUrls.append(contentsOf: crashReports)
                self.startReportUploadProcess()
            }
        }
        connectivityMonitor = utilities.getUtility(Utilities.internetConnectivity)!
            .startMonitoring { [unowned self] internetAvailable in
                if internetAvailable {
                    self.startReportUploadProcess()
                } else {
                    self.cancelCurrentUpload()
                }
        }
        // can force unwrap because this utility is always published.
        let cloudServer = utilities.getUtility(Utilities.cloudServer)!
        uploader = CrashReportUploader(cloudServer: cloudServer)

        crashReporter.publish()
    }

    public override func stopEngine() {
        ULog.d(.crashReportEngineTag, "Stopping CrashReportEngine.")
        userAccountMonitor?.stop()
        userAccountMonitor = nil
        crashReporter.unpublish()
        cancelCurrentUpload()
        uploader = nil
        connectivityMonitor.stop()
    }

    /// Adds a crash report to the reports to be uploaded.
    ///
    /// If the upload was not started and the upload may start, it will start.
    /// - Parameter reportUrl: local url of the report that have just been added
    func add(reportUrl: URL) {
        pendingReportUrls.append(reportUrl)
        startReportUploadProcess()
    }

    /// Creates a collector
    ///
    /// - Returns: a new collector
    /// - Note: Visibility is internal only for testing purposes.
    func createCollector() -> CrashReportCollector {
        return CrashReportCollector(rootDir: engineDir, reportsLocalWorkDir: workDir)
    }

    /// Start the uploading process of crash report files
    ///
    /// if an upload is already start we are only updating the pending count
    /// uploading process is only start when it is not already uploading files.
    private func startReportUploadProcess() {
        guard !crashReporter.isUploading else {
            crashReporter.update(pendingCount: pendingReportUrls.count)
            return
        }
        processNextReport()
    }

    /// Try to upload the first report of the list.
    ///
    /// It will only start the upload if the engine is not currently uploading a report, if Internet connectivity
    /// is available, if user account is present, or if anonymous data is allowed.
    private func processNextReport() {
        crashReporter.update(pendingCount: pendingReportUrls.count)
        if (self.userAccountInfo?.account == nil
            && self.userAccountInfo?.anonymousDataPolicy != AnonymousDataPolicy.allow)
        || utilities.getUtility(Utilities.internetConnectivity)?.internetAvailable == false {
            crashReporter.update(isUploading: false).notifyUpdated()
            return
        }
        if let uploader = uploader,
            currentUploadRequest == nil {
            if let crashReport = pendingReportUrls.first {
                // don't upload full crash report if no account & only anonymousDataPolicy allow
                if self.userAccountInfo?.account == nil
                    && self.userAccountInfo?.anonymousDataPolicy == AnonymousDataPolicy.allow
                    && crashReport.pathExtension == "gz" {
                    pendingReportUrls.removeFirst()
                    self.processNextReport()
                    return
                }
                if self.userAccountInfo?.account != nil {
                    let toRemove: Bool
                    if self.userAccountInfo!.accountlessPersonalDataPolicy == .denyUpload {
                        // check if the file is before the authentification date
                        // if yes, we remove the file because the user did not accept the download of the data collected
                        // before the authentication
                        if let attrs = try? FileManager.default.attributesOfItem(
                            atPath: crashReport.path), let creationDate = attrs[.creationDate] as? Date,
                            let userDate = userAccountInfo?.changeDate {
                            toRemove = creationDate < userDate
                        } else {
                            toRemove = true
                        }
                    } else {
                        // remove light report since user account exist. only full report are uploaded
                        toRemove = crashReport.pathExtension != "gz"
                    }
                    if toRemove {
                        self.deleteCrashReport(at: crashReport)
                        self.processNextReport()
                        return
                    }
                }
                crashReporter.update(isUploading: true)
                currentUploadRequest = uploader.upload(reportUrl: crashReport) { reportUrl, error in
                    self.currentUploadRequest = nil

                    if let error = error {
                        switch error {
                        case .badRequest:
                            ULog.w(.crashReportEngineTag, "Bad request sent to the server. This should be a dev error.")
                            // delete file and stop uploading to avoid multiple errors
                            self.deleteCrashReport(at: reportUrl)
                            self.crashReporter.update(isUploading: false).notifyUpdated()
                        case .badReport:
                            self.deleteCrashReport(at: reportUrl)
                            self.processNextReport()
                        case .serverError,
                             .connectionError:
                            // Stop uploading if the server is not accessible
                            self.crashReporter.update(isUploading: false).notifyUpdated()
                        case .canceled:
                            self.crashReporter.update(isUploading: false).notifyUpdated()
                        }
                    } else {    // success
                        self.deleteCrashReport(at: reportUrl)
                        self.processNextReport()
                    }
                }
            } else {
                crashReporter.update(isUploading: false)
            }
        }
        crashReporter.notifyUpdated()
    }

    /// Remove the given report from the pending ones and delete it from the file system.
    ///
    /// - Parameter report: the crash report to delete
    private func deleteCrashReport(at reportUrl: URL) {
        if self.pendingReportUrls.first == reportUrl {
            self.pendingReportUrls.remove(at: 0)
        } else {
            ULog.w(.crashReportEngineTag, "Uploaded report is not the first one of the pending")
            // fallback
            if let index: Int = self.pendingReportUrls.index(where: {$0 == reportUrl}) {
                self.pendingReportUrls.remove(at: index)
            }
        }

        self.collector.deleteCrashReport(at: reportUrl)

        if reportUrl.pathExtension == "gz" {
            let urlLight = URL(fileURLWithPath: reportUrl.path + ".anon")
            if let index: Int = self.pendingReportUrls.index(where: {$0 == urlLight}) {
                self.pendingReportUrls.remove(at: index)
                self.collector.deleteCrashReport(at: urlLight)
            }
        }
    }

    /// Cancel the current upload if there is one.
    private func cancelCurrentUpload() {
        // stop current upload request
        self.currentUploadRequest?.cancel()
        self.currentUploadRequest = nil
    }

    /// Deletes all locally stored reports waiting to be uploaded.
    ///
    /// This is called when the user account changes. All recorded reports are dropped since there is no proper
    /// user account identifier to use for upload anymore.
    private func dropReports() {

        // stop the upload if any
        cancelCurrentUpload()

        pendingReportUrls.forEach { (reportUrl) in
            collector.deleteCrashReport(at: reportUrl)
        }

        // clear all pending reports
        pendingReportUrls.removeAll()

        // update the facility
        crashReporter.update(isUploading: false).update(pendingCount: 0).notifyUpdated()
    }
}
