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

class AnafiFlightMeterTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var flightMeter: FlightMeter?
    var FlightMeterRef: Ref<FlightMeter>?
    var changeCnt: Int = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    private func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        FlightMeterRef = drone.getInstrument(Instruments.flightMeter) { [unowned self] flightMeter in
            self.flightMeter = flightMeter
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpDrone()
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(flightMeter, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(flightMeter, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(flightMeter, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testPublishUnpublishWithPersistentDataReceived() {
        // should be unavailable when the drone is not connected
        assertThat(flightMeter, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(flightMeter, present())
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorflightsstatuschangedEncoder(
                nbflights: 123, lastflightduration: 456, totalflightduration: 789))

        assertThat(flightMeter, presentAnd(`is`(totalFlights: 123, lastFlightDuration: 456, totalFlightDuration: 789)))
        assertThat(changeCnt, `is`(2))

        disconnect(drone: drone, handle: 1)
        assertThat(flightMeter, presentAnd(`is`(totalFlights: 123, lastFlightDuration: 456, totalFlightDuration: 789)))
        assertThat(changeCnt, `is`(2))

        // restart engine
        resetArsdkEngine()

        assertThat(flightMeter, presentAnd(`is`(totalFlights: 123, lastFlightDuration: 456, totalFlightDuration: 789)))
        assertThat(changeCnt, `is`(0))

        connect(drone: drone, handle: 1)
        assertThat(flightMeter, presentAnd(`is`(totalFlights: 123, lastFlightDuration: 456, totalFlightDuration: 789)))
        assertThat(changeCnt, `is`(0))

        mockArsdkCore.onCommandReceived(
        1, encoder: CmdEncoder.ardrone3SettingsstateMotorflightsstatuschangedEncoder(
        nbflights: 555, lastflightduration: 66, totalflightduration: 9999))
        assertThat(flightMeter, presentAnd(`is`(totalFlights: 555, lastFlightDuration: 66, totalFlightDuration: 9999)))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(flightMeter, presentAnd(`is`(totalFlights: 555, lastFlightDuration: 66, totalFlightDuration: 9999)))
        assertThat(changeCnt, `is`(1))

        // forget the drone
        _ = drone.forget()
        assertThat(flightMeter, nilValue())
        assertThat(changeCnt, `is`(2))
    }
}
