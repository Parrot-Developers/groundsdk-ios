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

/// Completion status of a crash report download.
@objc(GSCrashReportDownloadCompletionStatus)
public enum CrashReportDownloadCompletionStatus: Int, CustomStringConvertible {
    /// Download is not complete yet. Crash report download may still be ongoing or not even started yet.
    case none

    /// Crash reports download has completed successfully.
    case success

    /// Crash reports download interrupted.
    case interrupted

    /// Debug description.
    public var description: String {
        switch self {
        case .none:
            return "none"
        case .success:
            return "success"
        case .interrupted:
            return "interrupted"
        }
    }
}

/// State of the crash report downloader.
/// Informs about any ongoing crash reports download progress, as well as the completion status of the crash reports
/// download.
@objcMembers
@objc(GSCrashReportDownloaderState)
public class CrashReportDownloaderState: NSObject {
    /// Current completion status of the crash report downloader.
    ///
    /// The completion status changes to either `.interrupted` or `.success` when the download interrupted or
    /// completes successfully,
    /// then remains in this state until another crash report download begins, where it switches back to `.none`.
    public internal(set) var status: CrashReportDownloadCompletionStatus

    /// The current progress of an ongoing crash report download, expressed as a percentage.
    public internal(set) var downloadedCount: Int

    internal init(status: CrashReportDownloadCompletionStatus = .none, downloadedCount: Int = 0) {
        self.status = status
        self.downloadedCount = downloadedCount
        super.init()
    }
}

/// Crash report downloader.
///
/// This peripheral informs about current crash report download.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.crashReportDownloader)
/// ```
@objc(GSCrashReportDownloader)
public protocol CrashReportDownloader: Peripheral {
    /// Current download state
    var state: CrashReportDownloaderState { get }

    /// Whether a crash report is currently being downloaded
    var isDownloading: Bool { get }
}

/// :nodoc:
/// CrashReportDownloader description
@objc(GSCrashReportDownloaderDesc)
public class CrashReportDownloaderDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = CrashReportDownloader
    public let uid = PeripheralUid.crashReportDownloader.rawValue
    public let parent: ComponentDescriptor? = nil
}
