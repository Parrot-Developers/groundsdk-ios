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

/// Speedometer component controller for Anafi messages based drone
class AnafiSpeedometer: DeviceComponentController {

    /// Speedometer component
    private var speedometer: SpeedometerCore!

    /// Current Yaw value (in radian)
    private var yaw = 0.0

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        self.speedometer = SpeedometerCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        speedometer.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        speedometer.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        }
    }
}

/// Anafi Piloting State decode callback implementation
extension AnafiSpeedometer: ArsdkFeatureArdrone3PilotingstateCallback {
    func onSpeedChanged(speedx: Float, speedy: Float, speedz: Float) {
        let sinYaw = sin(yaw)
        let cosYaw = cos(yaw)
        let northSpeed = Double(speedx)
        let eastSpeed = Double(speedy)
        let downSpeed = Double(speedz)
        let groundSpeed = sqrt(pow(northSpeed, 2) + pow(eastSpeed, 2))
        speedometer.update(groundSpeed: groundSpeed)
            .update(northSpeed: northSpeed)
            .update(eastSpeed: eastSpeed)
            .update(downSpeed: downSpeed)
            .update(forwardSpeed: cosYaw * northSpeed + sinYaw * eastSpeed)
            .update(rightSpeed: -sinYaw * northSpeed + cosYaw * eastSpeed)
            .notifyUpdated()
    }

    func onAttitudeChanged(roll: Float, pitch: Float, yaw: Float) {
        self.yaw = Double(yaw)
    }
}
