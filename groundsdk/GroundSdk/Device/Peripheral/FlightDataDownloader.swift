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

/// Completion status of a flight data (PUD) download.
@objc(GSFlightDataDownloadCompletionStatus)
public enum FlightDataDownloadCompletionStatus: Int, CustomStringConvertible {
    /// Download is not complete yet. Flight data (PUD) download may still be ongoing or not even started yet.
    case none

    /// Latest flight data download was successful.
    ///
    /// `latestDownloadCount` informs about the total count of downloaded flight data files.
    case success

    /// Latest flight data download was aborted before successful completion.
    ///
    /// `latestDownloadCount` informs about the total count of downloaded flight data files.
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

/// State of the flight data (PUD) downloader.
/// Informs about latest count of successfully downloaded flight data files, as well as the completion status of the
/// flight data files (PUDs) download.
@objcMembers
@objc(GSFlightDataDownloaderState)
public class FlightDataDownloaderState: NSObject {
    /// Current completion status of the flight data (PUD) downloader.
    ///
    /// The completion status changes to either `.interrupted` or `.success` when the download interrupted or
    /// completes successfully,
    /// then remains in this state until another flight data (PUD) download begins, where it switches back to `.none`.
    public internal(set) var status: FlightDataDownloadCompletionStatus

    /// Latest count of successfully downloaded flight data files.
    ///
    /// While downloading, this counter is incremented for each successfully downloaded flight data file. Once download
    /// is over (either `FlightDataDownloadCompletionStatus.success` or because
    /// `FlightDataDownloadCompletionStatus.interrupted`). Then it will keep its latest value, until flight data files
    /// download starts again, where it will be reset to 0.
    public internal(set) var latestDownloadCount: Int

    internal init(status: FlightDataDownloadCompletionStatus = .none, latestDownloadCount: Int = 0) {
        self.status = status
        self.latestDownloadCount = latestDownloadCount
        super.init()
    }
}

/// Flight data (PUD) downloader.
///
/// This peripheral informs about current flight data (PUD) download.
///
/// This peripheral is unavailable if flight data support is disabled in config.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.flightDataDownloader)
/// ```
@objc(GSFlightDataDownloader)
public protocol FlightDataDownloader: Peripheral {
    /// Current download state.
    var state: FlightDataDownloaderState { get }

    /// Whether a flight data (PUD) is currently being downloaded.
    var isDownloading: Bool { get }
}

/// :nodoc:
/// FlightDataDownloader description
@objc(GSFlightDataDownloaderDesc)
public class FlightDataDownloaderDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = FlightDataDownloader
    public let uid = PeripheralUid.flightDataDownloader.rawValue
    public let parent: ComponentDescriptor? = nil
}
