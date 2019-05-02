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

/// Update file download state.
@objc(GSUpdaterDownloadState)
public enum UpdaterDownloadState: Int, CustomStringConvertible {
    /// Update files are currently being downloaded.
    case downloading
    /// All requested update files have successfully been downloaded.
    case success
    /// Some requested update files failed to be downloaded.
    ///
    /// - Note: after this state is notified, another change will be notified and `currentDownload` will return nil.
    case failed
    /// Download operation was canceled by application request.
    ///
    /// - Note: after this state is notified, another change will be notified and `currentDownload` will return nil.
    case canceled

    /// Debug description.
    public var description: String {
        switch self {
        case .downloading:  return "downloading"
        case .success:      return "success"
        case .failed:       return "failed"
        case .canceled:     return "canceled"
        }
    }
}

/// Update state.
@objc(GSUpdaterUpdateState)
public enum UpdaterUpdateState: Int, CustomStringConvertible {
    /// Some update file is being uploaded to the device.
    case uploading
    /// Some update file has been uploaded to the device, which is currently processing it.
    ///
    /// - Note: Although the application may cancel an update operation in this state, the device will still apply the
    ///         uploaded firmware update.
    case processing
    /// The device has switched off. Waiting for its reboot to reconnect.
    case waitingForReboot
    /// All requested updates have successfully been applied.
    ///
    /// - Note: After this state is notified, another change will be notified and `currentUpdate` will return nil.
    case success
    /// Some requested updates failed to be applied.
    ///
    /// - Note: After this state is notified, another change will be notified and `currentUpdate` will return nil.
    case failed
    /// Update operation was canceled by application request.
    ///
    /// - Note: After this state is notified, another change will be notified and `currentUpdate` will return nil.
    case canceled

    /// Debug description.
    public var description: String {
        switch self {
        case .uploading:        return "uploading"
        case .processing:       return "processing"
        case .waitingForReboot: return "waitingForReboot"
        case .success:          return "success"
        case .failed:           return "failed"
        case .canceled:         return "canceled"
        }
    }
}

/// Reasons that make downloading update file(s) impossible.
@objc(GSUpdaterDownloadUnavailabilityReason)
public enum UpdaterDownloadUnavailabilityReason: Int, CustomStringConvertible {
    /// Update file cannot be downloaded since there is no available internet connection.
    case internetUnavailable

    /// Debug description.
    public var description: String {
        switch self {
        case .internetUnavailable:  return "internetUnavailable"
        }
    }
}

/// Reasons that make applying update(s) impossible.
@objc(GSUpdaterUpdateUnavailabilityReason)
public enum UpdaterUpdateUnavailabilityReason: Int, CustomStringConvertible {
    /// Updates cannot be applied because the device is currently not connected.
    case notConnected
    /// Updates cannot be applied because there is not enough battery left on the device.
    case notEnoughBattery
    /// Updates cannot be applied because the device is not landed. This applies only to drone devices.
    case notLanded

    /// Debug description.
    public var description: String {
        switch self {
        case .notConnected:     return "notConnected"
        case .notEnoughBattery: return "notEnoughBattery"
        case .notLanded:        return "notLanded"
        }
    }
}

/// Ongoing update download state and progress.
public protocol UpdaterDownload: CustomStringConvertible {
    /// Information on the current update being downloaded.
    var currentFirmware: FirmwareInfo { get }

    /// Current update file download progress, in percent.
    var currentProgress: Int { get }

    /// Index of the firmware update currently being downloaded.
    /// Index is in range 1...`totalProgress.count`
    var currentIndex: Int { get }

    /// Count of all firmware updates that will be downloaded.
    ///
    /// - Note: This accounts for multiple firmware files that may be downloaded using `downloadAllFirmwares()`.
    var totalCount: Int { get }

    /// Total download progress, in percent.
    ///
    /// - Note: This accounts for multiple firmware files that may be downloaded using `downloadAllFirmwares()`.
    var totalProgress: Int { get }

    /// Current download state.
    var state: UpdaterDownloadState { get }
}

extension UpdaterDownload {
    /// Debug description.
    public var description: String {
        return "\(currentFirmware.firmwareIdentifier.description): \(state.description) \(currentProgress)% " +
            "(\(currentIndex)/\(totalCount)"
    }
}

/// Ongoing update download state and progress.
///
/// - Note: This protocol is for Objective-C only. Swift must use `UpdaterDownload`.
@objc
public protocol GSUpdaterDownload {
    /// Information on the current update being downloaded.
    @objc(currentFirmware)
    var gsCurrentFirmware: GSFirmwareInfo { get }

    /// Current update file download progress, in percent.
    var currentProgress: Int { get }

    /// Index of the firmware update currently being downloaded.
    /// Index is in range 1...`totalProgress.count`.
    var currentIndex: Int { get }

    /// Count of all firmware updates that will be downloaded.
    ///
    /// - Note: This accounts for multiple firmware files that may be downloaded using `downloadAllFirmwares()`.
    var totalCount: Int { get }

    /// Total download progress, in percent.
    ///
    /// - Note: This accounts for multiple firmware files that may be downloaded using `downloadAllFirmwares()`.
    var totalProgress: Int { get }

    /// Current download state.
    var state: UpdaterDownloadState { get }
}

/// Ongoing update state and progress
public protocol UpdaterUpdate {
    /// Information on the current firmware update being applied.
    var currentFirmware: FirmwareInfo { get }

    /// Current firmware update upload progress, in percent.
    var currentProgress: Int { get }

    /// Index of the firmware update currently being applied.
    /// Index is in range 1...`totalProgress.count`.
    var currentIndex: Int { get }

    /// Count of all firmware updates that will be applied.
    ///
    /// - Note: This accounts for multiple firmware updates that may be applied using `updateToLatestFirmware()`.
    var totalCount: Int { get }

    /// Total update progress, in percent.
    ///
    /// - Note: This accounts for multiple firmware updates that may be applied using `updateToLatestFirmware()`.
    var totalProgress: Int { get }

    /// Current update state.
    var state: UpdaterUpdateState { get }
}

/// Ongoing update state and progress
///
/// - Note: This protocol is for Objective-C only. Swift must use `UpdaterUpdate`.
@objc
public protocol GSUpdaterUpdate {
    /// Information on the current firmware update being applied.
    @objc(currentFirmware)
    var gsCurrentFirmware: GSFirmwareInfo { get }

    /// Current firmware update upload progress, in percent.
    var currentProgress: Int { get }

    /// Index of the firmware update currently being applied.
    /// Index is in range 1...`totalProgress.count`.
    var currentIndex: Int { get }

    /// Count of all firmware updates that will be applied.
    ///
    /// - Note: This accounts for multiple firmware updates that may be applied using `updateToLatestFirmware()`.
    var totalCount: Int { get }

    /// Total update progress, in percent.
    ///
    /// - Note: This accounts for multiple firmware updates that may be applied using `updateToLatestFirmware()`.
    var totalProgress: Int { get }

    /// Current update state.
    var state: UpdaterUpdateState { get }
}

/// Updater peripheral interface for Drone and RemoteControl devices.
///
/// Allows to:
///   - list and download available updates for the device from remote server.
///   - list locally available updates and apply them to the connected device.
///
/// This peripheral is always available even when the device is not connected, so that remote firmware updates may be
/// downloaded at all times (unless internet connection is unavailable).
///
/// Updating requires the device to be connected; however, this peripheral provides the ability to apply several
/// firmware updates in a row (mainly used in the presence of trampoline updates), and will maintain proper state across
/// device reboot/reconnection after each update is applied.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.updater)
/// ```
public protocol Updater: Peripheral {
    /// All firmwares that are required to be downloaded to update the device to the latest available version.
    ///
    /// The array is ordered by firmware application order: first firmwares in the list must be downloaded and applied
    /// before subsequent ones in order to update the device.
    var downloadableFirmwares: [FirmwareInfo] { get }

    /// Whether the device is currently up-to-date.
    var isUpToDate: Bool { get }

    /// Tells why it is currently impossible to download remote firmwares.
    ///
    /// If the returned set is not empty, then all firmware download methods (`downloadNextFirmware()`,
    /// `downloadAllFirmwares`()) won't do anything but return `false`.
    var downloadUnavailabilityReasons: Set<UpdaterDownloadUnavailabilityReason> { get }

    /// Current firmware download operation state, if any is ongoing.
    var currentDownload: UpdaterDownload? { get }

    /// All firmwares that are required to be applied to update the device to the latest available version.
    ///
    /// The array is ordered by firmware application order: first firmwares in the list must be applied before
    /// subsequent ones in order to update the device.
    var applicableFirmwares: [FirmwareInfo] { get }

    /// Tells why it is currently impossible to apply firmware updates.
    ///
    /// If the returned set is not empty, then all update methods (`updateToNextFirmware()`,
    /// `updateToLatestFirmware`()) won't do anything but return `false`.
    ///
    /// In case updating becomes unavailable for some reason while an update operation is ongoing (`.uploading` or
    /// `.processing`), then the update will be forcefully canceled.
    var updateUnavailabilityReasons: Set<UpdaterUpdateUnavailabilityReason> { get }

    /// Current update operation state, if any is ongoing.
    var currentUpdate: UpdaterUpdate? { get }

    /// Ideal version.
    ///
    /// This version is not necessarily local. It is the version that the drone will reach if all downloadable firmwares
    /// are downloaded and if all applicable updates are applied.
    /// This version is `nil` if there is no downloadable firmwares and no applicable firmwares.
    ///
    /// - Note: This version might differ from the greater version of all downloadable and applicable firmwares if,
    ///   and only if, the ideal firmware is local but cannot be applied because an intermediate, not downloaded,
    ///   firmware is required first.
    var idealVersion: FirmwareVersion? { get }

    /// Requests download of the next downloadable firmware that should be applied to update the device towards the
    /// latest available version.
    ///
    /// This method does nothing but return `false` if `downloadUnavailabilityReasons` is not empty, or if there is no
    /// `downloadableFirmwares`.
    ///
    /// - Returns: `true` if the download started
    @discardableResult func downloadNextFirmware() -> Bool

    /// Requests download of all downloadable firmware that should be applied to update the device to the latest
    /// available version.
    ///
    /// This method does nothing but return `false` if `downloadUnavailabilityReasons` is not empty, or if there is no
    /// `downloadableFirmwares`.
    ///
    /// - Returns: `true` if the download started
    @discardableResult func downloadAllFirmwares() -> Bool

    /// Cancels an ongoing firmware(s) download operation.
    ///
    /// - Returns: `true` if an ongoing firmware download operation has been canceled
    @discardableResult func cancelDownload() -> Bool

    /// Requests device update to the next currently applicable firmware version.
    ///
    /// This method does nothing but return `false` if `updateUnavailabilityReasons` is not empty, or if there is no
    /// `applicableFirmwares`.
    ///
    /// - Returns: `true` if the update started
    @discardableResult func updateToNextFirmware() -> Bool

    /// Requests device update to the latest applicable firmware version.
    ///
    /// This method will update the device by applying all `applicableFirmwares` in order, until the device is
    /// up-to-date.
    /// After each firmware is applied, the device will reboot. The application has the responsibility to ensure to
    /// reconnect to the device after the update, so that this peripheral may proceed automatically with the next
    /// firmware update, if any.
    ///
    /// This method does nothing but return `false` if `updateUnavailabilityReasons` is not empty, or if there is no
    /// `applicableFirmwares`.
    ///
    /// - Returns: `true` if the update started
    @discardableResult func updateToLatestFirmware() -> Bool

    /// Cancels an ongoing firmware(s) update operation.
    ///
    /// - Returns: `true` if an ongoing firmware update operation has been canceled
    @discardableResult func cancelUpdate() -> Bool
}

/// Updater peripheral interface for Drone and RemoteControl devices.
///
/// Allows to:
///   - Know if there is a locally available firmware that is suitable to update the device.
///   - Request to update the device using such a firmware.
///
/// This peripheral can be retrieved by:
/// ```
/// id<GSUpdater> updater = (id<GSUpdater>)[drone getPeripheral:GSPeripherals.updater];
/// ```
///
/// - Note: This protocol is for Objective-C only. Swift must use the protocol `Updater`
@objc
public protocol GSUpdater: Peripheral {
    /// All firmwares that are required to be downloaded to update the device to the latest available version.
    ///
    /// The array is ordered by firmware application order: first firmwares in the list must be applied before
    /// subsequent ones in order to update the device.
    @objc(downloadableFirmwares)
    var gsDownloadableFirmwares: [GSFirmwareInfo] { get }

    /// Whether the device is currently up-to-date.
    var isUpToDate: Bool { get }

    /// Current firmware download operation state, if any is ongoing.
    @objc(currentDownload)
    var gsCurrentDownload: GSUpdaterDownload? { get }

    /// All firmwares that are required to be applied to update the device to the latest available version.
    ///
    /// The array is ordered by firmware application order: first firmwares in the list must be applied before
    /// subsequent ones in order to update the device.
    @objc(applicableFirmwares)
    var gsApplicableFirmwares: [GSFirmwareInfo] { get }

    /// Current update operation state, if any is ongoing.
    @objc(currentUpdate)
    var gsCurrentUpdate: GSUpdaterUpdate? { get }

    /// Ideal version.
    ///
    /// This version is not necessarily local. It is the version that the drone will reach if all downloadable firmwares
    /// are downloaded and if all applicable updates are applied.
    /// This version is `nil` if there is no downloadable firmwares and no applicable firmwares.
    ///
    /// - Note: This version might differ from the greater version of all downloadable and applicable firmwares if,
    ///   and only if, the ideal firmware is local but cannot be applied because an intermediate, not downloaded,
    ///   firmware is required first.
    var idealVersion: FirmwareVersion? { get }

    /// Requests download of the next downloadable firmware that should be applied to update the device towards the
    /// latest available version.
    ///
    /// This method does nothing but return `false` if `downloadUnavailabilityReasons` is not empty, or if there is no
    /// `downloadableFirmwares`.
    ///
    /// - Returns: `true` if the download started
    @discardableResult func downloadNextFirmware() -> Bool

    /// Requests download of all downloadable firmware that should be applied to update the device to the latest
    /// available version.
    ///
    /// This method does nothing but return `false` if `downloadUnavailabilityReasons` is not empty, or if there is no
    /// `downloadableFirmwares`.
    ///
    /// - Returns: `true` if the download started
    @discardableResult func downloadAllFirmwares() -> Bool

    /// Cancels an ongoing firmware(s) download operation.
    ///
    /// - Returns: `true` if an ongoing firmware download operation has been canceled
    @discardableResult func cancelDownload() -> Bool

    /// Requests device update to the next currently applicable firmware version.
    ///
    /// This method does nothing but return `false` if `updateUnavailabilityReasons` is not empty, or if there is no
    /// `applicableFirmwares`.
    ///
    /// - Returns: `true` if the update started
    @discardableResult func updateToNextFirmware() -> Bool

    /// Requests device update to the latest applicable firmware version.
    ///
    /// This method will update the device by applying all `applicableFirmwares` in order, until the device is
    /// up-to-date.
    /// After each firmware is applied, the device will reboot. The application has the responsibility to ensure to
    /// reconnect to the device after the update, so that this peripheral may proceed automatically with the next
    /// firmware update, if any.
    ///
    /// This method does nothing but return `false` if `updateUnavailabilityReasons` is not empty, or if there is no
    /// `applicableFirmwares`.
    ///
    /// - Returns: `true` if the update started
    @discardableResult func updateToLatestFirmware() -> Bool

    /// Cancels an ongoing firmware(s) update operation.
    ///
    /// - Returns: `true` if an ongoing firmware update operation has been canceled
    @discardableResult func cancelUpdate() -> Bool

    /// Tells whether download is not available (partly) due to the given reason.
    ///
    /// - Parameter reason: the reason to query
    /// - Returns: `true` if the reason is preventing any download to start
    func isPreventingDownload(reason: UpdaterDownloadUnavailabilityReason) -> Bool

    /// Tells whether update is not available (partly) due to the given reason.
    ///
    /// - Parameter reason: the reason to query
    /// - Returns: `true` if the reason is preventing any update to start
    func isPreventingUpdate(reason: UpdaterUpdateUnavailabilityReason) -> Bool
}

/// :nodoc:
/// Updater description
@objc(GSUpdaterDesc)
public class UpdaterDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = Updater
    public let uid = PeripheralUid.updater.rawValue
    public let parent: ComponentDescriptor? = nil
}
