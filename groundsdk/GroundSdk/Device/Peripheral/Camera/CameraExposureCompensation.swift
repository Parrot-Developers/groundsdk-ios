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

/// EV compensation.
@objc(GSCameraEvCompensation)
public enum CameraEvCompensation: Int, CustomStringConvertible, Comparable {
    /// -3.00 EV
    @objc(GSCameraEvMinus3_00)
    case evMinus3_00
    /// -2.67 EV
    @objc(GSCameraEvMinus2_67)
    case evMinus2_67
    /// -2.33 EV
    @objc(GSCameraEvMinus2_33)
    case evMinus2_33
    /// -2.00 EV
    @objc(GSCameraEvMinus2_00)
    case evMinus2_00
    /// -1.67 EV
    @objc(GSCameraEvMinus1_67)
    case evMinus1_67
    /// -1.33 EV
    @objc(GSCameraEvMinus1_33)
    case evMinus1_33
    /// -1.00 EV
    @objc(GSCameraEvMinus1_00)
    case evMinus1_00
    /// -0.67 EV
    @objc(GSCameraEvMinus0_67)
    case evMinus0_67
    /// -0.33 EV
    @objc(GSCameraEvMinus0_33)
    case evMinus0_33
    /// 0.00 EV
    @objc(GSCameraEv0_00)
    case ev0_00
    /// +0.33 EV
    @objc(GSCameraEv0_33)
    case ev0_33
    /// +0.67 EV
    @objc(GSCameraEv0_67)
    case ev0_67
    /// +1.00 EV
    @objc(GSCameraEv1_00)
    case ev1_00
    /// +1.33 EV
    @objc(GSCameraEv1_33)
    case ev1_33
    /// +1.67 EV
    @objc(GSCameraEv1_67)
    case ev1_67
    /// +2.00 EV
    @objc(GSCameraEv2_00)
    case ev2_00
    /// +2.33 EV
    @objc(GSCameraEv2_33)
    case ev2_33
    /// +2.67 EV
    @objc(GSCameraEv2_67)
    case ev2_67
    /// +3.00 EV
    @objc(GSCameraEv3_00)
    case ev3_00

    /// Comparator.
    public static func < (lhs: CameraEvCompensation, rhs: CameraEvCompensation) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Set containing all possible values of CameraEvCompensation.
    public static let allCases: Set<CameraEvCompensation> = [
        evMinus3_00, evMinus2_67, evMinus2_33, evMinus2_00, evMinus1_67, evMinus1_33, evMinus1_00, evMinus0_67,
        evMinus0_33, ev0_00, ev0_33, ev0_67, ev1_00, .ev1_33, .ev1_67, .ev2_00, .ev2_33, .ev2_67, .ev3_00]

    /// Debug description.
    public var description: String {
        switch self {
        case .evMinus3_00:   return "-3.00 ev"
        case .evMinus2_67:   return "-2.67 ev"
        case .evMinus2_33:   return "-2.33 ev"
        case .evMinus2_00:   return "-2.00 ev"
        case .evMinus1_67:   return "-1.67 ev"
        case .evMinus1_33:   return "-1.33 ev"
        case .evMinus1_00:   return "-1.00 ev"
        case .evMinus0_67:   return "-0.67 ev"
        case .evMinus0_33:   return "-0.33 ev"
        case .ev0_00:        return "0.00 ev"
        case .ev0_33:        return "+0.33 ev"
        case .ev0_67:        return "+0.67 ev"
        case .ev1_00:        return "+1.00 ev"
        case .ev1_33:        return "+1.33 ev"
        case .ev1_67:        return "+1.67 ev"
        case .ev2_00:        return "+2.00 ev"
        case .ev2_33:        return "+2.33 ev"
        case .ev2_67:        return "+2.67 ev"
        case .ev3_00:        return "+3.00 ev"
        }
    }
}

/// Setting to configure camera exposure compensation.
public protocol CameraExposureCompensationSetting: class {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported exposure compensation values.
    ///
    /// An empty set means that the whole setting is currently unsupported.
   var supportedValues: Set<CameraEvCompensation> { get }

    /// Exposure compensation value.
    /// Value should be considered meaningless in case the set of `supportedValues` is empty.
    /// Value can only be changed to one of the value `supportedValues`
    var value: CameraEvCompensation { get set }
}

// MARK: - objc compatibility

/// Setting to configure camera exposure compensation
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCameraExposureCompensationSetting {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Exposure compensation value.
    var value: CameraEvCompensation { get set }

    /// Checks if an exposure compensation value is supported.
    ///
    /// - Parameter value: exposure compensation value to check
    /// - Returns: `true` if the exposure compensation value is supported
    func isValueSupported(_ value: CameraEvCompensation) -> Bool
}
