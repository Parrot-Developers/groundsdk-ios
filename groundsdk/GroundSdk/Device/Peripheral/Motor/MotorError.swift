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

/// Motor error.
@objc(GSMotorError)
public enum MotorError: Int {

    /// No error.
    case noError

    /// Motor is stalled.
    case stalled

    /// Motor has been put in security mode.
    case securityMode

    /// Motor has been stopped due to emergency.
    case emergencyStop

    /// Battery voltage out of bounds.
    case batteryVoltage

    /// Incorrect number of LIPO cells.
    case lipocells

    /// Too hot or too cold Cypress temperature.
    case temperature

    /// Defective MOSFET or broken motor phases.
    case mosfet

    /// Other error.
    case other

    /// Debug description.
    public var description: String {
        switch self {
        case .noError:
            return "noError"
        case .stalled:
            return "stalled"
        case .securityMode:
            return "securityMode"
        case .emergencyStop:
            return "emergencyStop"
        case .batteryVoltage:
            return "batteryVoltage"
        case .lipocells:
            return "lipocells"
        case .temperature:
            return "temperature"
        case .mosfet:
            return "mosfet"
        case .other:
            return "other"
        }
    }
}
