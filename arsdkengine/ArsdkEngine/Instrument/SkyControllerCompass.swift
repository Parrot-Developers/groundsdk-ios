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

/// Compass component controller for SkyController messages based rc
class SkyControllerCompass: DeviceComponentController {

    /// Compass component
    private var compass: CompassCore!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        self.compass = CompassCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        compass.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        compass.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlSkycontrollerstateUid {
            ArsdkFeatureSkyctrlSkycontrollerstate.decode(command, callback: self)
        }
    }
}

/// SkyController state decode callback implementation
extension SkyControllerCompass: ArsdkFeatureSkyctrlSkycontrollerstateCallback {
    func onAttitudeChanged(q0: Float, q1: Float, q2: Float, q3: Float) {
        let w = Double(q0)
        let x = Double(q1)
        let y = Double(q2)
        let z = Double(q3)

        let siny = 2.0 * (w * z + x * y)
        let cosy = 1.0 - 2.0 * (y * y + z * z)
        let yaw = atan2(siny, cosy)

        compass.update(heading: yaw.toBoundedDegrees()).notifyUpdated()
    }
}
