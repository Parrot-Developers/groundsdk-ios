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
import GroundSdk

/// Backend protocol to be implemented by subclasses
protocol AnafiMotorBackend {

    /// Processes a motors error state change.
    ///
    /// - Parameters:
    ///   - error: error that currently impacts motors
    ///   - motorMask: mask of motors that are currently impacted by the error
    func motorsErrorStateDidChange(error: MotorError, motorMask: UInt)

    /// Processes a change of the latest motor error.
    ///
    /// - Parameter error: latest motor error
    func latestMotorStateDidChange(error: MotorError)
}

/// Abstract base for Motor(s) peripheral controllers implementations based on Anafi messages
class AnafiMotor: DeviceComponentController {

    /// Backend that handles the motor error changes
    var backend: AnafiMotorBackend! // available after init

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        super.didReceiveCommand(command)
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3SettingsstateUid {
            ArsdkFeatureArdrone3Settingsstate.decode(command, callback: self)
        }
    }
}

/// Anafi settings state decode callback implementation
extension AnafiMotor: ArsdkFeatureArdrone3SettingsstateCallback {
    func onMotorErrorStateChanged(
        motorids: UInt, motorerror: ArsdkFeatureArdrone3SettingsstateMotorerrorstatechangedMotorerror) {
        let motorError: MotorError
        switch motorerror {
        case .noerror:
            motorError = .noError
        case .errormotorstalled:
            motorError = .stalled
        case .errorpropellersecurity:
            motorError = .securityMode
        case .errorrcemergencystop:
            motorError = .emergencyStop
        case .errorbatteryvoltage:
            motorError = .batteryVoltage
        case .errorlipocells:
            motorError = .lipocells
        case .errortemperature:
            motorError = .temperature
        case .errormosfet:
            motorError = .mosfet
        default:
            motorError = .other
        }
        backend.motorsErrorStateDidChange(error: motorError, motorMask: motorids)
    }

    func onMotorErrorLastErrorChanged(
        motorerror: ArsdkFeatureArdrone3SettingsstateMotorerrorlasterrorchangedMotorerror) {
        let motorError: MotorError

        switch motorerror {
        case .noerror:
            motorError = .noError
        case .errormotorstalled:
            motorError = .stalled
        case .errorpropellersecurity:
            motorError = .securityMode
        case .errorrcemergencystop:
            motorError = .emergencyStop
        case .errorbatteryvoltage:
            motorError = .batteryVoltage
        case .errorlipocells:
            motorError = .lipocells
        case .errortemperature:
            motorError = .temperature
        case .errormosfet:
            motorError = .mosfet
        default:
            motorError = .other
        }
        backend.latestMotorStateDidChange(error: motorError)
    }
}
