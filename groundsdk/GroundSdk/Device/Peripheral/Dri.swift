// Copyright (C) 2020 Parrot Drones SAS
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

/// Identifier type.
public enum DriIdType: Int, CustomStringConvertible, CaseIterable {
    /// French 30 bytes format.
    case FR_30_Octets
    /// ANSI CTA 2063 format on 40 bytes.
    case ANSI_CTA_2063

    /// Debug description.
    public var description: String {
        switch self {
        case .FR_30_Octets: return "FR_30_Octets"
        case .ANSI_CTA_2063: return "ANSI_CTA_2063"
        }
    }
}

/// Dri peripheral interface.
///
/// This peripheral allows changing dri state.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.dri)
/// ```
public protocol Dri: Peripheral {
    /// Dri setting.
    var mode: BoolSetting? { get }

    /// Dri drone ID.
    var droneId: (type: DriIdType, id: String)? { get }
}

/// :nodoc:
/// Dri description
public class DriDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = Dri
    public let uid = PeripheralUid.dri.rawValue
    public let parent: ComponentDescriptor? = nil
}
