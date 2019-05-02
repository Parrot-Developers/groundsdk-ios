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

/// Local state of the firmware update.
@objc(GSFirmwareManagerEntryState)
public enum FirmwareManagerEntryState: Int, CustomStringConvertible {
    /// Firmware update is available on remote server, and may be downloaded to device's storage.
    case notDownloaded
    /// Firmware update file is currently being downloaded.
    case downloading
    /// Firmware update is available locally from device's storage.
    case downloaded

    /// Debug description.
    public var description: String {
        switch self {
        case .notDownloaded:    return "notDownloaded"
        case .downloading:      return "downloading"
        case .downloaded:       return "downloaded"
        }
    }
}

/// Represents an available firmware update.
@objc(GSFirmwareManagerEntry)
@objcMembers
public class FirmwareManagerEntry: NSObject {
    /// Information about the firmware update.
    public let info: FirmwareInfo

    /// Firmware update's local state.
    public var state: FirmwareManagerEntryState {
        if backend.getTask(firmware: info) != nil {
            return .downloading
        } else if isLocal {
            return .downloaded
        } else {
            return .notDownloaded
        }
    }

    /// Firmware file current download progress, as a percentage.
    ///
    /// - Note: this is only meaningful when state is `.downloading`, otherwise progress is 0.
    public var downloadProgress: Int {
        return backend.getTask(firmware: info)?.currentProgress ?? 0
    }
    /// Whether any local file for this firmware update can be deleted from device's storage.
    ///
    /// - Note:
    ///   - this is only meaningful when state is `.downloaded`, otherwise canDelete is false.
    ///   - Application preset firmwares cannot usually be deleted from device's storage, i.e. their state reports
    ///   `.downloaded` since they are locally available, but this method returns false.
    public let canDelete: Bool

    /// Debug description.
    public override var description: String {
        return "\(info.firmwareIdentifier.description): \(state.description), progress = \(downloadProgress), " +
            "canDelete = \(canDelete)"
    }

    /// Backend of this entry, unowned.
    private unowned let backend: FirmwareManagerEntryBackend

    /// Whether the entry is local.
    private let isLocal: Bool

    /// Constructor.
    ///
    /// - Parameters:
    ///   - info: firmware info
    ///   - isLocal: indicates whether a local firmware is available
    ///   - canDelete: indicates whether a local firmware is available and can be deleted
    ///   - backend: the backend
    internal init(info: FirmwareInfoCore, isLocal: Bool, canDelete: Bool,
                  backend: FirmwareManagerEntryBackend) {
        self.info = info
        self.isLocal = isLocal
        self.canDelete = canDelete
        self.backend = backend
    }

    /// Requests download of this firmware update file.
    ///
    /// This action is only available when state is `.notDownloaded`, otherwise this method returns false.
    ///
    /// - Returns: `true` if the download was successfully requested
    public func download() -> Bool {
        guard !isLocal && backend.getTask(firmware: info) == nil else {
            return false
        }
        backend.download(firmware: info as! FirmwareInfoCore)
        return true
    }

    /// Cancels an ongoing firmware update file download.
    ///
    /// This action is only available when state is `.downloading`, otherwise this method returns false.
    ///
    /// - Returns: `true` if the download was successfully canceled
    public func cancelDownload() -> Bool {
        if let task = backend.getTask(firmware: info) {
            task.cancel()
            return true
        }
        return false
    }

    /// Requests deletion of this firmware update file from device's storage.
    ///
    /// This action is only available when state is `.downloaded`, otherwise this method returns false.
    ///
    /// - Returns: `true` if the file was successfully deleted
    public func delete() -> Bool {
        return canDelete && backend.delete(firmware: info as! FirmwareInfoCore)
    }
}

/// Extension of FirmwareManagerEntry that customize the equality operator.
extension FirmwareManagerEntry {
    public static func == (lhs: FirmwareManagerEntry, rhs: FirmwareManagerEntry) -> Bool {
        return lhs.isLocal == rhs.isLocal &&
            lhs.canDelete == rhs.canDelete &&
            lhs.info.firmwareIdentifier == rhs.info.firmwareIdentifier
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? FirmwareManagerEntry {
            return self == object
        }
        return false
    }
}

/// Extension of FirmwareManagerEntry that adds Objective-C missing vars/functions.
extension FirmwareManagerEntry {
    /// Information about the firmware update
    @objc(info)
    public var gsInfo: GSFirmwareInfo {
        return info as! GSFirmwareInfo
    }
}

/// Facility that provides global management of firmware updates.
///
/// FirmwareManager allows to:
/// - Query up-to-date firmware information from remote update server; note that the application is only allowed
///   to query update once every hour.
/// - list firmware updates for all supported device models, both remotely available (that need to be downloaded from
///   remote update server) and locally available, that are present on the device's internal storage and are ready to be
///   used for device update.
/// - Download remote firmware update file from remote update server and archive them on device's internal storage for
///   later use.
/// - Delete locally downloaded firmware update files.
///
/// This facility can be obtained using:
/// ```
/// groundSdk.getFacility(Facilities.firmwareManager)
/// ```
@objc(GSFirmwareManager)
public protocol FirmwareManager: Facility {

    /// Whether a remote update information query is currently in progress.
    var isQueryingRemoteUpdates: Bool { get }

    /// All available firmware updates.
    var firmwares: [FirmwareManagerEntry] { get }

    /// Requests to update information from remote servers.
    ///
    /// - Returns: `true` if a request has been sent (or is already in progress), `false` otherwise. Note: This flag
    /// corresponds to the `isQueryingRemoteUpdates` flag.
    @discardableResult func queryRemoteUpdates() -> Bool
}

/// :nodoc:
/// UpdateManager facility descriptor
@objc(GSUpdateManagerDesc)
public class UpdateManagerDesc: NSObject, FacilityClassDesc {
    public typealias ApiProtocol = FirmwareManager
    public let uid = FacilityUid.firmwareManager.rawValue
    public let parent: ComponentDescriptor? = nil
}
