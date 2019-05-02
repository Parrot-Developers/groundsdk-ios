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

/// CrashML downloader delegate that does the download through http
class HttpCrashmlDownloaderDelegate: ArsdkCrashmlDownloaderDelegate {

    /// Report REST Api.
    /// Not nil when uploader has been configured. Nil after a reset.
    private var reportApi: ReportRestApi?

    /// List of pending downloads
    private var pendingDownloads: [ReportRestApi.Report] = []

    /// CrashML downloaded count.
    private var downloadCount = 0

    /// Whether or not the current overall task has been canceled
    private var isCanceled = false

    /// Current report download request
    /// - Note: this request can change during the overall download task (it can be the listing, downloading or deleting
    ///         request).
    private var currentRequest: CancelableCore?

    func configure(downloader: ArsdkCrashmlDownloader) {
        if let droneServer = downloader.deviceController.droneServer {
            reportApi = ReportRestApi(server: droneServer)
        }
    }

    func reset(downloader: ArsdkCrashmlDownloader) {
        reportApi = nil
    }

    func download(toDirectory directory: URL, downloader: ArsdkCrashmlDownloader) -> Bool {
        guard currentRequest == nil else {
            return false
        }

        isCanceled = false
        currentRequest = reportApi?.getReportList { reportList in
            if let reportList = reportList {
                self.pendingDownloads = reportList
                self.downloadNextReport(toDirectory: directory, downloader: downloader)
            } else {
                downloader.crashReportDownloader.update(completionStatus: .interrupted)
                    .update(downloadingFlag: false)
                    .notifyUpdated()
                self.currentRequest = nil
            }
        }

        return currentRequest != nil
    }

    func cancel() {
        isCanceled = true
        // empty the list of pending downloads
        pendingDownloads = []
        currentRequest?.cancel()

    }

    /// Download next report.
    ///
    /// - Parameters:
    ///    - directory: directory in which reports should be stored
    ///    - downloader: the downloader in charge
    private func downloadNextReport(toDirectory directory: URL, downloader: ArsdkCrashmlDownloader) {
        if let report = pendingDownloads.first {
            // download full report
            currentRequest = reportApi?.downloadReport(report, toDirectory: directory, type: .full) { fileUrl in
                if let fileUrl = fileUrl {
                    let notifyUrl = fileUrl
                    // download light report
                    self.currentRequest = self.reportApi?.downloadReport(
                    report, toDirectory: directory, type: .light) { fileUrl in
                        self.downloadCount += 1
                        downloader.crashReportDownloader.update(downloadedCount: self.downloadCount).notifyUpdated()
                        var arrayUrl = [URL]()
                        arrayUrl.append(notifyUrl)
                        if let fileUrl = fileUrl {
                            arrayUrl.append(fileUrl)
                        }
                        downloader.crashReportStorage.notifyReportReady(reportUrlCollection: arrayUrl)

                        // at last full report was download, remove distant report and download next one.
                        self.currentRequest = self.reportApi?.deleteReport(report) { _ in
                            self.removeFirstAndDownloadNextReport(toDirectory: directory, downloader: downloader)
                        }
                    }
                } else { // failed to download full report, trying to download light report
                    // download light report
                     if !self.isCanceled {
                    self.currentRequest = self.reportApi?.downloadReport(report, toDirectory: directory,
                                                                         type: .light) { fileUrl in
                        if let fileUrl = fileUrl {
                            self.downloadCount += 1

                            downloader.crashReportDownloader.update(downloadedCount: self.downloadCount).notifyUpdated()
                            downloader.crashReportStorage.notifyReportReady(
                                reportUrlCollection: [URL(fileURLWithPath: fileUrl.path)])

                            // delete the distant report even if we have only the light one.
                            self.currentRequest = self.reportApi?.deleteReport(report) { _ in
                                self.removeFirstAndDownloadNextReport(toDirectory: directory, downloader: downloader)
                            }
                        } else {
                            // failed to download full & light report notify and download next report.
                            // we do not delete distant report.
                            self.removeFirstAndDownloadNextReport(toDirectory: directory, downloader: downloader)
                        }
                        }
                     } else {
                        self.removeFirstAndDownloadNextReport(toDirectory: directory, downloader: downloader)
                    }
                }
            }
        } else {
            if isCanceled {
                downloader.crashReportDownloader.update(completionStatus: .interrupted)
            } else {
                downloader.crashReportDownloader.update(completionStatus: .success)
            }
            downloader.crashReportDownloader.update(downloadingFlag: false).notifyUpdated()
            currentRequest = nil
            isCanceled = false
        }
    }

    private func removeFirstAndDownloadNextReport(toDirectory directory: URL, downloader: ArsdkCrashmlDownloader) {
        // even if the download failed, process next report
        if !self.pendingDownloads.isEmpty {
            self.pendingDownloads.removeFirst()
        }
        self.downloadNextReport(toDirectory: directory, downloader: downloader)
    }
}
