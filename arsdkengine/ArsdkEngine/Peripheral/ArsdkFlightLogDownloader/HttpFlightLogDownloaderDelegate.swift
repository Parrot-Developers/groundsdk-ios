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

/// FlightLog downloader delegate that does the download through http
class HttpFlightLogDownloaderDelegate: ArsdkFlightLogDownloaderDelegate {

    /// Flight Log REST Api.
    /// Not nil when uploader has been configured. Nil after a reset.
    private var flightLogApi: FlightLogRestApi?

    /// List of pending downloads
    private var pendingDownloads: [FlightLogRestApi.FlightLog] = []

    /// FlightLog downloaded count.
    private var downloadCount = 0

    /// Whether or not the current overall task has been canceled
    private var isCanceled = false

    /// Current report download request
    /// - Note: this request can change during the overall download task (it can be the listing, downloading or deleting
    ///         request).
    private var currentRequest: CancelableCore?

    /// Device uid
    private var deviceUid: String = ""

    func configure(downloader: ArsdkFlightLogDownloader) {
        if let droneServer = downloader.deviceController.droneServer {
            flightLogApi = FlightLogRestApi(server: droneServer)
        }
        deviceUid = downloader.deviceController.device.uid
    }

    func reset(downloader: ArsdkFlightLogDownloader) {
        flightLogApi = nil
    }

    func download(toDirectory directory: URL, downloader: ArsdkFlightLogDownloader) -> Bool {
        guard currentRequest == nil else {
            return false
        }

        isCanceled = false
        currentRequest = flightLogApi?.getFlightLogList { flightLogList in
            if let flightLogList = flightLogList {
                self.pendingDownloads = flightLogList
                self.downloadNextLog(toDirectory: directory, downloader: downloader)
            } else {
                downloader.flightLogDownloader.update(completionStatus: .interrupted)
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

    /// Download next log.
    ///
    /// - Parameters:
    ///   - directory: directory in which flight logs should be stored
    ///   - downloader: the downloader in charge
    private func downloadNextLog(toDirectory directory: URL, downloader: ArsdkFlightLogDownloader) {
        if let flightLog = pendingDownloads.first {
            currentRequest = flightLogApi?.downloadFlightLog(
            flightLog, toDirectory: directory, deviceUid: deviceUid) { fileUrl in
                if let fileUrl = fileUrl {
                    self.downloadCount += 1
                    downloader.flightLogDownloader.update(
                        downloadedCount: self.downloadCount).notifyUpdated()
                    downloader.flightLogStorage.notifyFlightLogReady(
                        flightLogUrl: URL(fileURLWithPath: fileUrl.path))

                    self.deleteFlightLogAndDownloadNext(toDirectory: directory,
                                                        downloader: downloader, flightLog: flightLog)
                } else {
                    // even if the download failed, process next report
                    if !self.pendingDownloads.isEmpty {
                        self.pendingDownloads.removeFirst()
                    }
                    self.downloadNextLog(toDirectory: directory, downloader: downloader)
                }
            }
        } else {
            if isCanceled {
                downloader.flightLogDownloader.update(completionStatus: .interrupted)
            } else {
                downloader.flightLogDownloader.update(completionStatus: .success)
            }
            downloader.flightLogDownloader.update(downloadingFlag: false).notifyUpdated()
            currentRequest = nil
            isCanceled = false
        }
    }

    /// Delete flight log and start download for the next one
    ///
    /// - Parameters:
    ///   - directory: directory in which flight logs should be stored
    ///   - downloader: the downloader in charge
    ///   - flightLog: flightlog to delete
    private func deleteFlightLogAndDownloadNext(
        toDirectory directory: URL, downloader: ArsdkFlightLogDownloader,
        flightLog: FlightLogRestApi.FlightLog) {
        // delete the distant report
        self.currentRequest = self.flightLogApi?.deleteFlightLog(flightLog) { _ in
            // even if the deletion failed, process next report
            if !self.pendingDownloads.isEmpty {
                self.pendingDownloads.removeFirst()
            }
            self.downloadNextLog(toDirectory: directory, downloader: downloader)
        }
    }
}
