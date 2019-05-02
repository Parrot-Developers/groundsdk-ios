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

class AnafiSpeedometerTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var speedometer: Speedometer?
    var speedometerRef: Ref<Speedometer>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        speedometerRef = drone.getInstrument(Instruments.speedometer) { [unowned self] speedometer in
            self.speedometer = speedometer
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(speedometer, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(speedometer, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(speedometer, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testValue() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(speedometer!.groundSpeed, `is`(0))
        assertThat(changeCnt, `is`(1))

        // check ground speed received
        let speedx = Float(1.2)
        let speedy = Float(3.4)
        let speedz = Float(2.3)
        let yaw = Float(0.2)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAttitudechangedEncoder(roll: 0.0, pitch: 0.0, yaw: yaw))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateSpeedchangedEncoder(
                speedx: speedx, speedy: speedy, speedz: speedz))
        assertThat(speedometer!.groundSpeed, `is`(sqrt(pow(Double(speedx), 2) + pow(Double(speedy), 2))))
        assertThat(speedometer!.northSpeed, `is`(Double(speedx)))
        assertThat(speedometer!.eastSpeed, `is`(Double(speedy)))
        assertThat(speedometer!.downSpeed, `is`(Double(speedz)))
        assertThat(speedometer!.forwardSpeed, `is`(
            cos(Double(yaw)) * Double(speedx) + sin(Double(yaw)) * Double(speedy)))
        assertThat(speedometer!.rightSpeed, `is`(
            -sin(Double(yaw)) * Double(speedx) + cos(Double(yaw)) * Double(speedy)))
        assertThat(changeCnt, `is`(2))
    }
}
