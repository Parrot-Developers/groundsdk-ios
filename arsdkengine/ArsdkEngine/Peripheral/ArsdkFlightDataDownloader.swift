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

/// flightData downloader delegate
protocol ArsdkFlightDataDownloaderDelegate: class {
    /// Configure the delegate
    ///
    /// - Parameter downloader: the downloader in charge
    func configure(downloader: ArsdkFlightDataDownloader)
    /// Reset the delegate
    ///
    /// - Parameter downloader: the downloader in charge
    func reset(downloader: ArsdkFlightDataDownloader)
    /// Download all existing flightData files
    ///
    /// - Parameters:
    ///   - directory: the local directory to store the reports
    ///   - downloader: the downloader in charge
    func download(toDirectory directory: URL, downloader: ArsdkFlightDataDownloader)

    /// Cancel current request and all following ones.
    func cancel()
}

/// flightData downloader component controller subclass that does the download through http
class HttpFlightDataDownloader: ArsdkFlightDataDownloader {
    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - flightDataStorage: utility used for storage operations
    init(deviceController: DeviceController, flightDataStorage: FlightDataStorageCore) {
        super.init(deviceController: deviceController, flightDataStorage: flightDataStorage,
                   delegate: HttpFlightDataDownloaderDelegate())
    }
}

/// Generic flightData downloader component controller
class ArsdkFlightDataDownloader: DeviceComponentController {

    /// CrashReportDownloader component.
    let flightDataDownloader: FlightDataDownloaderCore
    /// FlightDataStorageCore component (utility for storage)
    let flightDataStorage: FlightDataStorageCore

    // swiftlint:disable weak_delegate
    /// Delegate to actually download the reports
    let delegate: ArsdkFlightDataDownloaderDelegate
    // swiftlint:enable weak_delegate

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - flightDataStorage: utility used for storage operations
    fileprivate init(deviceController: DeviceController, flightDataStorage: FlightDataStorageCore,
                     delegate: ArsdkFlightDataDownloaderDelegate) {
        self.delegate = delegate
        self.flightDataStorage = flightDataStorage
        self.flightDataDownloader = FlightDataDownloaderCore(store: deviceController.device.peripheralStore)
        super.init(deviceController: deviceController)
    }

    /// Device is connected
    override func didConnect() {
        delegate.configure(downloader: self)
        // note that it is safe to call `dataSyncAllowanceChanged` even if it has not changed.
        dataSyncAllowanceChanged(allowed: deviceController.dataSyncAllowed)
        flightDataDownloader.publish()
    }

    /// Device is disconnected
    override func didDisconnect() {
        flightDataDownloader.unpublish()
        delegate.reset(downloader: self)
    }

    override func dataSyncAllowanceChanged(allowed: Bool) {
        if allowed {
            download()
        } else {
            cancelDownload()
        }
    }

    /// Downloads PUDs from the controlled device
    private func download() {
        delegate.download(toDirectory: flightDataStorage.workDir, downloader: self)
    }

    /// Cancels current download
    ///
    /// - Returns: true if the cancel succeeded to start otherwise false
    private func cancelDownload() {
        delegate.cancel()
    }
}
