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
import XCTest
@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

class AnafiAltimeterTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var altimeter: Altimeter?
    var altimeterRef: Ref<Altimeter>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        altimeterRef = drone.getInstrument(Instruments.altimeter) { [unowned self] altimeter in
            self.altimeter = altimeter
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(altimeter, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(altimeter, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(altimeter, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testValue() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(altimeter!.groundRelativeAltitude, nilValue())
        assertThat(altimeter!.takeoffRelativeAltitude, nilValue())
        assertThat(altimeter!.absoluteAltitude, nilValue())
        assertThat(altimeter!.verticalSpeed, nilValue())
        assertThat(changeCnt, `is`(1))

        // check altitude is set on the take off relative altitude
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAltitudechangedEncoder(altitude: 1.2))
        assertThat(altimeter!.groundRelativeAltitude, nilValue())
        assertThat(altimeter!.takeoffRelativeAltitude, presentAnd(`is`(1.2)))
        assertThat(altimeter!.absoluteAltitude, nilValue())
        assertThat(altimeter!.verticalSpeed, nilValue())
        assertThat(changeCnt, `is`(2))

        // check speed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateSpeedchangedEncoder(speedx: 0, speedy: 0, speedz: 1))
        assertThat(altimeter!.groundRelativeAltitude, nilValue())
        assertThat(altimeter!.takeoffRelativeAltitude, presentAnd(`is`(1.2)))
        assertThat(altimeter!.absoluteAltitude, nilValue())
        assertThat(altimeter!.verticalSpeed, presentAnd(`is`(-1)))
        assertThat(changeCnt, `is`(3))

        // Receive gps altitude should set the absolute altitude
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePositionchangedEncoder(
                latitude: 1.2, longitude: 3.4, altitude: 56))
        assertThat(altimeter!.groundRelativeAltitude, nilValue())
        assertThat(altimeter!.takeoffRelativeAltitude, presentAnd(`is`(1.2)))
        assertThat(altimeter!.absoluteAltitude, presentAnd(`is`(56)))
        assertThat(altimeter!.verticalSpeed, presentAnd(`is`(-1)))
        assertThat(changeCnt, `is`(4))

        // receiving new command should set absolute altitude
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateGpslocationchangedEncoder(
                latitude: 1.2, longitude: 3.4, altitude: 67, latitudeAccuracy: 10, longitudeAccuracy: 20,
                altitudeAccuracy: 30))
        assertThat(altimeter!.groundRelativeAltitude, nilValue())
        assertThat(altimeter!.takeoffRelativeAltitude, presentAnd(`is`(1.2)))
        assertThat(altimeter!.absoluteAltitude, presentAnd(`is`(67)))
        assertThat(altimeter!.verticalSpeed, presentAnd(`is`(-1)))
        assertThat(changeCnt, `is`(5))

        // receiving old command after the new one should not change anything
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePositionchangedEncoder(
                latitude: 1.2, longitude: 3.4, altitude: 56))
        assertThat(altimeter!.groundRelativeAltitude, nilValue())
        assertThat(altimeter!.takeoffRelativeAltitude, presentAnd(`is`(1.2)))
        assertThat(altimeter!.absoluteAltitude, presentAnd(`is`(67)))
        assertThat(altimeter!.verticalSpeed, presentAnd(`is`(-1)))
        assertThat(changeCnt, `is`(5))

        // receiving new command with unknown longitude values should set the absolute altitude to nil
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateGpslocationchangedEncoder(
                latitude: 0, longitude: 500, altitude: 67, latitudeAccuracy: 10, longitudeAccuracy: 20,
                altitudeAccuracy: 30))
        assertThat(altimeter!.groundRelativeAltitude, nilValue())
        assertThat(altimeter!.takeoffRelativeAltitude, presentAnd(`is`(1.2)))
        assertThat(altimeter!.absoluteAltitude, nilValue())
        assertThat(altimeter!.verticalSpeed, presentAnd(`is`(-1)))
        assertThat(changeCnt, `is`(6))
    }
}
