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

/// Copter motors component controller for Anafi message based drones
class AnafiCopterMotors: AnafiMotor {
    /// CopterMotors component
    private var copterMotors: CopterMotorsCore!

    /// Last motor error indexed by motor
    private var latestMotorError: [CopterMotor: MotorError] = [:]

    /// Current motor error indexed by motor
    private var currentMotorError: [CopterMotor: MotorError] = [:]

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        copterMotors = CopterMotorsCore(store: deviceController.device.peripheralStore)
        backend = self
    }

    /// Drone is connected
    override func didConnect() {
        copterMotors.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        copterMotors.unpublish()
    }
}

// Extension of AnafiCopterMotors that implements the superclass backend
extension AnafiCopterMotors: AnafiMotorBackend {
    func motorsErrorStateDidChange(error: MotorError, motorMask: UInt) {
        // set the current errors on the component
        if motorMask & (1 << 0) != 0 {
            copterMotors.update(currentError: error, onMotor: .frontLeft)
        }
        if motorMask & (1 << 1) != 0 {
            copterMotors.update(currentError: error, onMotor: .frontRight)
        }
        if motorMask & (1 << 2) != 0 {
            copterMotors.update(currentError: error, onMotor: .rearRight)
        }
        if motorMask & (1 << 3) != 0 {
            copterMotors.update(currentError: error, onMotor: .rearLeft)
        }
        copterMotors.notifyUpdated()
    }

    func latestMotorStateDidChange(error: MotorError) {
        for motor in CopterMotor.allCases {
            copterMotors.update(pastError: error, onMotor: motor)
        }
        copterMotors.notifyUpdated()
    }
}
