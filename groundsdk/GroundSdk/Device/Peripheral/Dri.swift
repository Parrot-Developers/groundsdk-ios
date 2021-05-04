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

/// DRI identifier type.
public enum DriIdType: Int, CustomStringConvertible, CaseIterable {
    /// French 30-byte format.
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

/// DRI type.
public enum DriType: String, CustomStringConvertible, CaseIterable {
    /// DRI wifi beacon respects the EN4709-002 european regulation.
    case en4709_002

    /// DRI wifi beacon respects the french regulation.
    case french

    /// Debug description.
    public var description: String { rawValue }
}

/// DRI type configuration.
public enum DriTypeConfig: Hashable, CustomStringConvertible {
    /// DRI wifi beacon respects the EN4709-002 european regulation
    /// - operatorId: operator identifier
    case en4709_002(operatorId: String = "")

    /// DRI wifi beacon respects the french regulation.
    case french

    /// DRI type associated to this configuration.
    public var type: DriType {
        switch self {
        case .en4709_002: return .en4709_002
        case .french: return .french
        }
    }

    /// Verifies that the configuration is valid.
    ///
    /// For `en4709_002`, the configuration is considered invalid if the operator identifier
    /// does not conform to EN4709-002 standard.
    public var isValid: Bool {
        switch self {
        case .en4709_002(let operatorId): return validateEn4709UasOperator(operatorId)
        case .french: return true
        }
    }

    /// Debug description.
    public var description: String {
        switch self {
        case .french: return "french"
        case .en4709_002(let operatorId): return "en4709_002 \(operatorId)"
        }
    }
}

/// DRI type configuration state.
public enum DriTypeState: Equatable, CustomStringConvertible {
    /// DRI type has been sent to the drone and change confirmation is awaited.
    case updating

    /// DRI type is configured on the drone.
    /// - type: current DRI type
    case configured(type: DriTypeConfig)

    /// DRI type configuration failed for an unknown reason.
    case failure

    /// DRI type configuration failed due to an invalid operator identifier.
    case invalid_operator_id

    /// Equatable concordance.
    public static func == (lhs: DriTypeState, rhs: DriTypeState) -> Bool {
        switch (lhs, rhs) {
        case (.failure, failure), (.updating, .updating), (.invalid_operator_id, .invalid_operator_id):
            return true
        case let (.configured(lt), .configured(rt)):
            return lt == rt
        default:
            return false
        }
    }

    /// Debug description.
    public var description: String {
        switch self {
        case .updating: return "updating"
        case .configured(let type): return "configured \(type)"
        case .failure: return "failure"
        case .invalid_operator_id: return "invalid_operator_id"
        }
    }
}

/// Setting to configure DRI type.
public protocol DriTypeSetting: class {
    /// DRI type configuration state, when available.
    var state: DriTypeState? { get }

    /// DRI types supported by the drone.
    var supportedTypes: Set<DriType> { get }

    /// DRI type configuration as defined by the user.
    ///
    /// Trying to set this value to an unsupported or invalid DRI type configuration will fail.
    /// See `DriTypeConfig.isValid` to verify that the configuration is valid.
    ///
    /// This configuration is sent to the drone when its changed by the user and at every connection to the drone.
    /// When `nil`, nothing is sent to the drone.
    var type: DriTypeConfig? { get set }
}

/// DRI peripheral interface.
///
/// The DRI or Drone Remote ID is a protocol that sends periodic broadcasts of some identification data
/// during the flight for safety, security, and compliance purposes.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.dri)
/// ```
public protocol Dri: Peripheral {
    /// DRI setting. This setting allows to enable or disable the drone DRI.
    var mode: BoolSetting? { get }

    /// DRI type setting. This setting allows to configue the DRI type.
    var type: DriTypeSetting { get }

    /// DRI drone ID.
    var droneId: (type: DriIdType, id: String)? { get }
}

/// :nodoc:
/// Dri description.
public class DriDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = Dri
    public let uid = PeripheralUid.dri.rawValue
    public let parent: ComponentDescriptor? = nil
}
