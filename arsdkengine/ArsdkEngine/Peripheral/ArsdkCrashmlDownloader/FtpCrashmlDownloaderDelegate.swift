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

/// CrashML downloader delegate that does the download through ftp
class FtpCrashmlDownloaderDelegate: ArsdkCrashmlDownloaderDelegate {
    /// CrashML downloaded count.
    private var downloadCount = 0

    /// Current report download request
    private var currentRequest: CancelableCore?

    func configure(downloader: ArsdkCrashmlDownloader) { }

    func reset(downloader: ArsdkCrashmlDownloader) { }

    func download(toDirectory directory: URL, downloader: ArsdkCrashmlDownloader) -> Bool {
        guard currentRequest == nil else {
            return false
        }

        // we don't have any report date; so we pretend the report has been generated now, which may not be true.
        // Result is that we download reports if there is an user account set, no matter when it was.
        // The issue is that we may upload reports containing user info that were generated at a time when the user
        // did not agree to upload personal info yet...
        guard downloader.reportMayContainUserInfo(reportDate: Date()) else {
            return false
        }

        currentRequest = downloader.deviceController.downloadCrashml(
            path: downloader.crashReportStorage.workDir.path,
            progress: { [weak self] file, status in
                if status == .ok, let `self` = self {
                    self.downloadCount += 1
                    downloader.crashReportDownloader.update(downloadedCount: self.downloadCount).notifyUpdated()
                    downloader.crashReportStorage.notifyReportReady(reportUrlCollection: [URL(fileURLWithPath: file)])
                }
            },
            completion: { status in
                let success = status == .ok
                downloader.crashReportDownloader.update(completionStatus: success ? .success : .interrupted)
                    .update(downloadingFlag: false)
                    .notifyUpdated()
                self.currentRequest = nil
        })

        return currentRequest != nil
    }

    func cancel() {
        currentRequest?.cancel()
    }
}
