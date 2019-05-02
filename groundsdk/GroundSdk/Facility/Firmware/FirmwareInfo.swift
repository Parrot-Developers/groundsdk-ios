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

/// Special firmware attributes.
@objc(GSFirmwareAttribute)
public enum FirmwareAttribute: Int, CustomStringConvertible {
    /// Updating a device using this firmware will result in all user data being deleted.
    case deletesUserData

    /// Debug description.
    public var description: String {
        switch self {
        case .deletesUserData: return "deletesUserData"
        }
    }
}

/// Provides extraneous information on a firmware, such as the size of the firmware update file, or special outcomes
/// that updating a device using this firmware may produce.
public protocol FirmwareInfo {
    /// Identifies the firmware that this FirmwareInfo provides information upon.
    var firmwareIdentifier: FirmwareIdentifier { get }

    /// Set of special attributes.
    var attributes: Set<FirmwareAttribute> { get }

    /// Size of the associated update file, in bytes.
    var size: UInt64 { get }
}

/// Provides extraneous information on a firmware, such as the size of the firmware update file, or special outcomes
/// that updating a device using this firmware may produce.
///
/// - Note: this protocol is for Objective-C only. Swift must use the protocol `FirmwareInfo`
@objc
public protocol GSFirmwareInfo {
    /// Identifies the firmware that this FirmwareInfo provides information upon.
    var firmwareIdentifier: FirmwareIdentifier { get }

    /// Size of the associated update file, in bytes.
    var size: UInt64 { get }

    /// Tells whether this firmware has a given attribute.
    ///
    /// - Parameter attribute: the attribute
    /// - Returns: `true` if the firmware has the attribute, `false` otherwise
    func has(attribute: FirmwareAttribute) -> Bool
}
