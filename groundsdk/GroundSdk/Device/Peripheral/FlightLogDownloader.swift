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

/// Completion status of a flight log download.
@objc(GSFlightLogDownloadCompletionStatus)
public enum FlightLogDownloadCompletionStatus: Int, CustomStringConvertible {
    /// Download is not complete yet. Flight log download may still be ongoing or not even started yet.
    case none

    /// Flight logs download has completed successfully.
    case success

    /// Flight logs download interrupted.
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

/// State of the flight log downloader.
/// Informs about any ongoing flight logs download progress, as well as the completion status of the flight logs
/// download.
@objcMembers
@objc(GSFlightLogDownloaderState)
public class FlightLogDownloaderState: NSObject {
    /// Current completion status of the flight log downloader.
    ///
    /// The completion status changes to either `.interrupted` or `.success` when the download interrupted or
    /// completes successfully,
    /// then remains in this state until another flight log download begins, where it switches back to `.none`.
    public internal(set) var status: FlightLogDownloadCompletionStatus

    /// The current progress of an ongoing flight log download, expressed as a percentage.
    public internal(set) var downloadedCount: Int

    internal init(status: FlightLogDownloadCompletionStatus = .none, downloadedCount: Int = 0) {
        self.status = status
        self.downloadedCount = downloadedCount
        super.init()
    }
}

/// Flight log downloader.
///
/// This peripheral informs about current flight log download.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.flightLogDownloader)
/// ```
@objc(GSFlightLogDownloader)
public protocol FlightLogDownloader: Peripheral {
    /// Current download state.
    var state: FlightLogDownloaderState { get }

    /// Whether a flight log is currently being downloaded.
    var isDownloading: Bool { get }
}

/// :nodoc:
/// FlightLogDownloader description
@objc(GSFlightLogDownloaderDesc)
public class FlightLogDownloaderDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = FlightLogDownloader
    public let uid = PeripheralUid.flightLogDownloader.rawValue
    public let parent: ComponentDescriptor? = nil
}
