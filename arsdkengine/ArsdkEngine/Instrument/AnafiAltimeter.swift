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

/// Altimeter component controller for Anafi messages based drones
class AnafiAltimeter: DeviceComponentController {

    /// Altimeter component
    private var altimeter: AltimeterCore!

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static var UnknownCoordinate: Double = 500

    /// Whether the onGpsLocationChanged callback was triggered once.
    private var useOnGpsLocationChanged = false

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        self.altimeter = AltimeterCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        altimeter.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        altimeter.unpublish()
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
extension AnafiAltimeter: ArsdkFeatureArdrone3PilotingstateCallback {
    func onAltitudeChanged(altitude: Double) {
        // this event informs about the altitude above take off
        altimeter.update(takeoffRelativeAltitude: altitude).notifyUpdated()
    }

    func onSpeedChanged(speedx: Float, speedy: Float, speedz: Float) {
        altimeter.update(verticalSpeed: Double(-speedz)).notifyUpdated()
    }

    func onPositionChanged(latitude: Double, longitude: Double, altitude: Double) {
        if useOnGpsLocationChanged {
            return
        }

        if (latitude != AnafiAltimeter.UnknownCoordinate) && (longitude != AnafiAltimeter.UnknownCoordinate) {
            altimeter.update(absoluteAltitude: altitude).notifyUpdated()
        } else {
            altimeter.update(absoluteAltitude: nil).notifyUpdated()
        }
    }

    func onGpsLocationChanged(latitude: Double, longitude: Double, altitude: Double,
                              latitudeAccuracy: Int, longitudeAccuracy: Int, altitudeAccuracy: Int) {
        useOnGpsLocationChanged = true
        if (latitude != AnafiAltimeter.UnknownCoordinate) && (longitude != AnafiAltimeter.UnknownCoordinate) {
            altimeter.update(absoluteAltitude: altitude).notifyUpdated()
        } else {
            altimeter.update(absoluteAltitude: nil).notifyUpdated()
        }
    }
}
