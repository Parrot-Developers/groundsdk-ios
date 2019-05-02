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

/// FlightLog downloader delegate that does the download through ftp
class FtpFlightLogDownloaderDelegate: ArsdkFlightLogDownloaderDelegate {
    /// FlightLog downloaded count.
    private var downloadCount = 0

    /// Current flightLog download request
    private var currentRequest: CancelableCore?

    func configure(downloader: ArsdkFlightLogDownloader) { }

    func reset(downloader: ArsdkFlightLogDownloader) { }

    func download(toDirectory directory: URL, downloader: ArsdkFlightLogDownloader) -> Bool {
        guard currentRequest == nil else {
            return false
        }

        currentRequest = downloader.deviceController.downloadFlightLog(
            path: downloader.flightLogStorage.workDir.path,
            progress: { [weak self] file, status in
                if status == .ok, let `self` = self {
                    self.downloadCount += 1
                    downloader.flightLogDownloader.update(downloadedCount: self.downloadCount).notifyUpdated()
                    downloader.flightLogStorage.notifyFlightLogReady(flightLogUrl: URL(fileURLWithPath: file))
                }
            },
            completion: { status in
                let success = status == .ok
                downloader.flightLogDownloader.update(completionStatus: success ? .success : .interrupted)
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
