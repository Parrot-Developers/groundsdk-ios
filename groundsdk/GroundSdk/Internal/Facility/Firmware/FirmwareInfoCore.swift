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

/// Internal implementation of FirmwareInfo
public class FirmwareInfoCore: FirmwareInfo, Hashable {

    public let firmwareIdentifier: FirmwareIdentifier

    public let attributes: Set<FirmwareAttribute>

    public let size: UInt64
    /// Firmware update file checksum
    let checksum: String

    /// Constructor
    ///
    /// - Parameters:
    ///   - firmwareIdentifier: firmware identifier
    ///   - attributes: firmware attributes
    ///   - size: update file size
    ///   - checksum: update file checksum
    init(firmwareIdentifier: FirmwareIdentifier, attributes: Set<FirmwareAttribute>, size: UInt64, checksum: String) {
        self.firmwareIdentifier = firmwareIdentifier
        self.attributes = attributes
        self.size = size
        self.checksum = checksum
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(firmwareIdentifier)
    }

    public static func == (lhs: FirmwareInfoCore, rhs: FirmwareInfoCore) -> Bool {
        return lhs.firmwareIdentifier == rhs.firmwareIdentifier
    }
}

/// Extension of FirmwareInfoCore that implements GSFirmwareInfo for objc compatibility
extension FirmwareInfoCore: GSFirmwareInfo {
    public func has(attribute: FirmwareAttribute) -> Bool {
        return attributes.contains(attribute)
    }
}
