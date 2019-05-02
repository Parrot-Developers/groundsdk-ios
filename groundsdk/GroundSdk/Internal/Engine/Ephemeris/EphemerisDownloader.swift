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

/// protocol for generic ephemeris downloader
protocol EphemerisDownloader {

    // Name of the file for ephemeris
    var ephemerisName: String { get }

    // Download Ephemeris and save them at urlDestination
    func download(urlDestination: URL, completionListener: @escaping (URL?) -> Void)
}

/// Ephemeris downloader from server ublox
class UBloxEphemerisDownloader: EphemerisDownloader {

    let ephemerisName = "ublox"

    // Http session core
    let httpSession: HttpSessionCore

    init(httpSession: HttpSessionCore) {
        self.httpSession = httpSession
    }

    func download(urlDestination: URL, completionListener: @escaping (URL?) -> Void) {

        let token = "oVx4Rd6fVUeYzHfSWtSapA"
        let mainBaseURL = "https://offline-live1.services.u-blox.com"
        let params = "token=\(token);gnss=gps,glo;period=1;resolution=1"

        let mainServerURL = URL(string: "\(mainBaseURL)/GetOfflineData.ashx?\(params)")!

        let backupBaseURL = "https://offline-live2.services.u-blox.com"
        let backupServerURL = URL(string: "\(backupBaseURL)/GetOfflineData.ashx?\(params)")!

        let urlDestinationTemp: URL = urlDestination.appendingPathComponent("\(ephemerisName)temp")
        let urlDestinationDest: URL = urlDestination.appendingPathComponent(ephemerisName)

        do {
            if FileManager.default.fileExists(atPath: urlDestinationTemp.path) {
                try FileManager.default.removeItem(at: urlDestinationTemp)
            }
        } catch let err {
            ULog.e(.ephemerisEngineTag, "Failed to delete temporary file if exist \(urlDestinationTemp.path): \(err)")
            completionListener(nil)
            return
        }

        _ = httpSession.downloadFile(
            request: URLRequest(url: mainServerURL), destination: urlDestinationTemp,
            progress: { _ in },
            completion: { [weak self] _, url in
                if let url = url {
                    if self?.deleteAndReplaceEphemeris(
                         urlOrigin: urlDestinationTemp, urlDestination: urlDestinationDest) == true {
                        completionListener(url)
                    } else {
                        completionListener(nil)
                    }
                } else {
                    // fallback to backup if first request failed
                    _ = self?.httpSession.downloadFile(
                        request: URLRequest(url: backupServerURL),
                        destination: urlDestinationTemp, progress: {_ in },
                        completion: { _, url in
                            if self?.deleteAndReplaceEphemeris(
                                 urlOrigin: urlDestinationTemp, urlDestination: urlDestinationDest) == true {
                                completionListener(url)
                            } else {
                                completionListener(nil)
                            }
                    })
                }
        })
    }

    /// Delete old ephemeris if exist, and replace with new ephemeris.
    ///
    /// - Parameters:
    /// - urlOrigin : temporary ephemeris file url. we need to move it to url final destination
    /// - urlDestination : final ephemeris file url
    private func deleteAndReplaceEphemeris(urlOrigin: URL, urlDestination: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: urlDestination.path) {
                try FileManager.default.removeItem(at: urlDestination)
            }
            try FileManager.default.moveItem(
                 atPath: urlOrigin.path, toPath: urlDestination.path)
            return true
        } catch let err {
            ULog.e(.ephemerisEngineTag, "Failed to delete and replace Ephemeris \(urlOrigin.path): \(err)")
            return false
        }
    }
}
