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

/// Formatting type of the formatting process.
@objc(GSFormattingType)
public enum FormattingType: Int, CustomStringConvertible {
    /// Full formatting type, that includes low level format operation which can take a lot of time but optimizes
    /// performance.
    case full
    /// Quick formatting type, that just removes content of the media.
    case quick

    /// Debug description.
    public var description: String {
        switch self {
        case .full:     return "quick"
        case .quick:    return "full"
        }
    }
}

/// Formatting step of the formatting process.
@objc(GSFormattingStep)
public enum FormattingStep: Int, Codable {
    /// The drone is currently partitioning the media.
    case partitioning
    /// The drone is currently wiping data on the media in order to optimize performance.
    case clearingData
    /// The drone is creating a file system on the media.
    case creatingFs

    /// Debug description.
    public var description: String {
        switch self {
        case .partitioning: return "partitioning"
        case .clearingData: return "clearingData"
        case .creatingFs:   return "creatingFs"
        }
    }
}

/// Progress state of the formatting process.
@objcMembers
@objc(GSFormattingState)
public class FormattingState: NSObject {

    /// Retrieves the current formatting step.
    public var step: FormattingStep

    /// Retrieves the formatting progress of the current step, in percent.
    public var progress: Int

    /// Internal constructor.
    override init() {
        self.step = .partitioning
        self.progress = 0
    }
}

/// State of the removable storage.
@objc(GSRemovableUserStorageState)
public enum RemovableUserStorageState: Int, CustomStringConvertible {
    /// No media detected.
    case noMedia

    /// Media rejected because it is too small for operation.
    case mediaTooSmall

    /// Media rejected because it is too slow for operation.
    case mediaTooSlow

    /// Media cannot be mounted since the drone acts as a USB mass-storage device.
    case usbMassStorage

    /// Media is being mounted.
    case mounting

    /// Media has to be reformatted.
    ///
    /// This means that the file system is not supported or the partition is not formatted, or the capacity is too low.
    /// - Note: The media won't be usable until it is formatted.
    case needFormat

    /// Media is currently formatting.
    case formatting

    /// Media is ready to be used.
    case ready

    /// The latest try to format the media succeeded.
    ///
    /// This state indicates the result of formatting and is transient. The state will change to another state
    /// quickly after formatting result is notified.
    case formattingSucceeded

    /// The latest try to format the media failed.
    ///
    /// This state indicates the result of formatting and is transient. The state will change to another state
    /// quickly after formatting result is notified.
    case formattingFailed

    /// The latest try to format the media was denied.
    ///
    /// This state indicates the result of formatting and is transient. The state will change back to
    /// `.needFormat` or `.ready` immediately after formatting result is notified.
    case formattingDenied

    /// An error occurred, media cannot be used.
    case error

    /// Debug description.
    public var description: String {
        switch self {
        case .noMedia:              return "noMedia"
        case .mediaTooSmall:        return "mediaTooSmall"
        case .mediaTooSlow:         return "mediaTooSlow"
        case .usbMassStorage:       return "usbMassStorage"
        case .mounting:             return "mounting"
        case .needFormat:           return "needFormat"
        case .formatting:           return "formatting"
        case .ready:                return "ready"
        case .formattingSucceeded:  return "formattingSucceeded"
        case .formattingFailed:     return "formattingFailed"
        case .formattingDenied:     return "formattingDenied"
        case .error:                return "error"
        }
    }
}

/// Information about the media storage.
@objc(GSRemovableUserStorageMediaInfo)
public protocol RemovableUserStorageMediaInfo: class {
    /// The name of the media.
    var name: String { get }

    /// The capacity of the media, in Bytes.
    var capacity: Int64 { get }
}

/// Removable user storage.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.removableUserStorage)
/// ```
public protocol RemovableUserStorage: Peripheral {

    /// Current state of removable user storage.
    var state: RemovableUserStorageState { get }

    /// Information about the current media.
    ///
    /// `nil` if current media is not available.
    var mediaInfo: RemovableUserStorageMediaInfo? { get }

    /// Available free space on current media, in Bytes. Negative value if not known.
    var availableSpace: Int64 { get }

    /// Current ability to format the media.
    /// 'true' if the media can be formatted, otherwise 'false'
    var canFormat: Bool { get }

    /// Supported formatting types.
    var supportedFormattingTypes: Set<FormattingType> { get }

    /// Formatting state.
    var formattingState: FormattingState? { get }

    /// Requests a format of the media.
    ///
    /// Should be called only when `canFormat` is `true`.
    ///
    /// When formatting starts, the current state becomes `.formatting`.
    ///
    /// The formatting result is indicated with the transient state `.formattingSucceeded`,
    /// `.formattingFailed`, or `.formattingDenied`.
    ///
    /// - Parameters:
    ///     - formattingType: type of formatting
    ///     - newMediaName: the new name that should be given to the media. If you pass an empty string, the
    ///                           a default name will be assigned.
    /// - Returns: `true` if the format has been asked, `false` otherwise.
    func format(formattingType: FormattingType, newMediaName: String) -> Bool

    /// Requests a format of the media. The formatted media will get a default name.
    ///
    /// Should be called only when `canFormat` is `true`.
    /// - Note: If you want to set a name, use `format(newMediaName:)`.
    ///
    /// When formatting starts, the current state becomes `.formatting`.
    ///
    /// The formatting result is indicated with the transient state `.formattingSucceeded`,
    /// `.formattingFailed`, or `.formattingDenied`.
    ///
    /// - Parameter formattingType: type of formatting for the current media
    /// - Returns: `true` if the format has been asked, `false` otherwise
    func format(formattingType: FormattingType) -> Bool
}

/// :nodoc:
/// Removable user storage description
@objc(GSRemovableUserStorageDesc)
public class RemovableUserStorageDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = RemovableUserStorage
    public let uid = PeripheralUid.removableUserStorage.rawValue
    public let parent: ComponentDescriptor? = nil
}

// MARK: - objc compatibility

/// Removable user storage.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSRemovableUserStorage {
    /// Current state of removable user storage.
    var state: RemovableUserStorageState { get }

    /// Information about the current media.
    ///
    /// `nil` if current media is not available.
    var mediaInfo: RemovableUserStorageMediaInfo? { get }

    /// Available free space on current media, in Bytes. Negative value if not known.
    var availableSpace: Int64 { get }

    /// Current ability to format the media.
    /// 'true' if the media can be formatted, otherwise 'false'
    var canFormat: Bool { get }

    /// Formatting state.
    var formattingState: FormattingState? { get }

    /// Tells whether a formattingType is supported.
    ///
    /// - Parameter formattingType: mode to check
    /// - Returns: `true` if the formatting type is supported
    func isFormattingTypeSupported(_ formattingType: FormattingType) -> Bool

    /// Requests a format of the media.
    ///
    /// Should be called only when `canFormat` is `true`.
    ///
    /// When formatting starts, the current state becomes `.formatting`.
    ///
    /// The formatting result is indicated with the transient state `.formattingSucceeded`,
    /// `.formattingFailed`, or `.formattingDenied`.
    ///
    /// - Parameters:
    ///     - formattingType: type of formatting
    ///     - newMediaName: the new name that should be given to the media. If you pass an empty string, the
    ///                           a default name will be assigned.
    /// - Returns: `true` if the format has been asked, `false` otherwise
    func format(formattingType: FormattingType, newMediaName: String) -> Bool

    /// Requests a format of the media. The formatted media will get a default name.
    ///
    /// Should be called only when `canFormat` is `true`.
    /// - Note: If you want to set a name, use `format(newMediaName:)`.
    ///
    /// When formatting starts, the current state becomes `.formatting`.
    ///
    /// The formatting result is indicated with the transient state `.formattingSucceeded`,
    /// `.formattingFailed`, or `.formattingDenied`.
    ///
    /// - Parameter formattingType: type of formatting for the current media
    /// - Returns: `true` if the format has been asked, `false` otherwise
    func format(formattingType: FormattingType) -> Bool
}
