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

/// FlightData downloader delegate that does the download through http
class HttpFlightDataDownloaderDelegate: ArsdkFlightDataDownloaderDelegate {

    /// Report REST Api.
    /// Not nil when uploader has been configured. Nil after a reset.
    private var pudApi: PudRestApi?

    /// List of pending downloads
    private var pendingDownloads = [PudRestApi.Pud]()

    /// PUDs downloaded count.
    private var downloadCount = 0

    /// Whether or not the current overall task has been canceled
    private var isCanceled = false

    /// Current pud download request
    /// - Note: this request can change during the overall download task (it can be the listing, downloading or deleting
    ///         request).
    private var currentRequest: CancelableCore?

    func configure(downloader: ArsdkFlightDataDownloader) {
        if let droneServer = downloader.deviceController.droneServer {
            pudApi = PudRestApi(server: droneServer)
        }
    }

    func reset(downloader: ArsdkFlightDataDownloader) {
        pudApi = nil
    }

    func download(toDirectory directory: URL, downloader: ArsdkFlightDataDownloader) {
        guard currentRequest == nil else {
            return
        }

        isCanceled = false
        currentRequest = pudApi?.getPudList { pudList in
            if let pudList = pudList {
                self.pendingDownloads = pudList
                if !pudList.isEmpty {
                    self.downloadCount = 0
                    downloader.flightDataDownloader.update(isDownloading: true).update(status: .none)
                        .update(latestDownloadCount: 0).notifyUpdated()
                    self.downloadNextPud(toDirectory: directory, downloader: downloader)
                } else {
                    self.currentRequest = nil
                }
            } else {
                // list PUDs files error
                downloader.flightDataDownloader.update(
                    status: .interrupted).update(isDownloading: false).notifyUpdated()
                self.currentRequest = nil
            }
        }
    }

    func cancel() {
        isCanceled = true
        // empty the list of pending downloads
        pendingDownloads = []
        currentRequest?.cancel()
    }

    /// Download next Pud.
    ///
    /// - Parameters:
    ///   - directory: directory in which PUDs should be stored
    ///   - downloader: the downloader in charge
    private func downloadNextPud(toDirectory directory: URL, downloader: ArsdkFlightDataDownloader) {
        if let pud = pendingDownloads.first {
            currentRequest = pudApi?.downloadPud(pud, toDirectory: directory) { fileUrl in
                if let fileUrl = fileUrl {
                    self.downloadCount += 1
                    downloader.flightDataDownloader.update(latestDownloadCount: self.downloadCount).notifyUpdated()
                    downloader.flightDataStorage.notifyFlightDataReady(
                        flightDataUrl: URL(fileURLWithPath: fileUrl.path))

                    // delete the distant Pud
                    self.currentRequest = self.pudApi?.deletePud(pud) { _ in
                        // even if the deletion failed, process next Pud
                        if !self.pendingDownloads.isEmpty {
                            self.pendingDownloads.removeFirst()
                        }
                        self.downloadNextPud(toDirectory: directory, downloader: downloader)
                    }
                } else {
                    // even if the download failed, process next Pud
                    if !self.pendingDownloads.isEmpty {
                        self.pendingDownloads.removeFirst()
                    }
                    self.downloadNextPud(toDirectory: directory, downloader: downloader)
                }
            }
        } else {
            // empty list
            if isCanceled {
                downloader.flightDataDownloader.update(status: .interrupted)
            } else {
                downloader.flightDataDownloader.update(status: .success)
            }
            downloader.flightDataDownloader.update(isDownloading: false).notifyUpdated()
            currentRequest = nil
            isCanceled = false
        }
    }
}
