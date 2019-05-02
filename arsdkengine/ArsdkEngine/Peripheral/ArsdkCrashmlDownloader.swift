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

/// CrashML downloader delegate
protocol ArsdkCrashmlDownloaderDelegate: class {
    /// Configure the delegate
    ///
    /// - Parameter downloader: the downloader in charge
    func configure(downloader: ArsdkCrashmlDownloader)
    /// Reset the delegate
    ///
    /// - Parameter downloader: the downloader in charge
    func reset(downloader: ArsdkCrashmlDownloader)
    /// Download all existing CrashML reports
    ///
    /// - Parameters:
    ///   - directory: the local directory to store the reports
    ///   - downloader: the downloader in charge
    /// - Returns: true if the download has been started, false otherwise
    func download(toDirectory directory: URL, downloader: ArsdkCrashmlDownloader) -> Bool

    /// Cancel current request and all following ones.
    func cancel()
}

/// CrashML downloader component controller subclass that does the download through http
class HttpCrashmlDownloader: ArsdkCrashmlDownloader {
    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - crashReportStorage: crash reporter storage
    init(deviceController: DeviceController, crashReportStorage: CrashReportStorageCore) {
        super.init(deviceController: deviceController, crashReportStorage: crashReportStorage,
                   delegate: HttpCrashmlDownloaderDelegate())
    }
}

/// CrashML downloader component controller subclass that does the download through ftp
class FtpCrashmlDownloader: ArsdkCrashmlDownloader {
    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - crashReportStorage: crash reporter storage
    init(deviceController: DeviceController, crashReportStorage: CrashReportStorageCore) {
        super.init(deviceController: deviceController, crashReportStorage: crashReportStorage,
                   delegate: FtpCrashmlDownloaderDelegate())
    }
}

/// Generic crashML downloader component controller
class ArsdkCrashmlDownloader: DeviceComponentController {

    /// CrashReportDownloader component.
    let crashReportDownloader: CrashReportDownloaderCore
    /// Crash report storage
    let crashReportStorage: CrashReportStorageCore

    // swiftlint:disable weak_delegate
    /// Delegate to actually download the reports
    let delegate: ArsdkCrashmlDownloaderDelegate
    // swiftlint:enable weak_delegate

    /// User Account Utility
    private var userAccountUtilityCore: UserAccountUtilityCore?

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - crashReportStorage: crash reporter storage
    fileprivate init(deviceController: DeviceController, crashReportStorage: CrashReportStorageCore,
                     delegate: ArsdkCrashmlDownloaderDelegate) {
        self.delegate = delegate
        self.crashReportStorage = crashReportStorage
        self.crashReportDownloader = CrashReportDownloaderCore(store: deviceController.device.peripheralStore)
        userAccountUtilityCore =  deviceController.engine.utilities.getUtility(Utilities.userAccount)
        super.init(deviceController: deviceController)
    }

    /// Device is connected
    override func didConnect() {
        delegate.configure(downloader: self)
        // note that it is safe to call `dataSyncAllowanceChanged` even if it has not changed.
        dataSyncAllowanceChanged(allowed: deviceController.dataSyncAllowed)
        crashReportDownloader.publish()
    }

    /// Device is disconnected
    override func didDisconnect() {
        crashReportDownloader.unpublish()
        delegate.reset(downloader: self)
    }

    override func dataSyncAllowanceChanged(allowed: Bool) {
        if allowed {
            download()
        } else {
            cancelDownload()
        }
    }

    /// Tells whether downloading a report containing user-related information is allowed.
    ///
    ///- Note: A report can contain user information, if a accountID has been set at a date earlier than the report
    /// date.
    ///
    /// - Parameter reportDate: date of the report
    /// - Returns: `true` if the report may contain user information, false otherwise
    public func reportMayContainUserInfo(reportDate: Date) -> Bool {

        if let userAccountInfo = userAccountUtilityCore?.userAccountInfo, userAccountInfo.account != nil {
            return userAccountInfo.changeDate < reportDate
        } else {
            return false
        }
    }

    /// Downloads crash reports from the controlled device
    private func download() {
        if delegate.download(toDirectory: crashReportStorage.workDir, downloader: self) {
            crashReportDownloader.update(downloadingFlag: true)
                .update(completionStatus: .none)
                .notifyUpdated()
        }
    }

    /// Cancels current download
    ///
    /// - Returns: true if the cancel succeeded to start otherwise false
    private func cancelDownload() {
        delegate.cancel()
    }
}
