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

class AnafiGpsTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var gps: Gps?
    var gpsRef: Ref<Gps>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    private func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!
        gpsRef = drone.getInstrument(Instruments.gps) { [unowned self] gps in
            self.gps = gps
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(gps, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(gps, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(gps, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpDrone()
    }

    func testPublishUnpublishWithPersistentDataReceived() {
        // should be unavailable when the drone is not connected
        assertThat(gps, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(gps, present())
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePositionchangedEncoder(
                latitude: 1.2, longitude: 3.4, altitude: 56))
        var date = gps?.lastKnownLocation?.timestamp
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 1.2, longitude: 3.4, altitude: 56, hAcc: -1, vAcc: -1)))
        assertThat(changeCnt, `is`(2))

        disconnect(drone: drone, handle: 1)
        assertThat(gps, present())
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 1.2, longitude: 3.4, altitude: 56, hAcc: -1, vAcc: -1, date: date)))
        assertThat(changeCnt, `is`(2))

        // restart engine
        resetArsdkEngine()

        assertThat(gps, present())
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 1.2, longitude: 3.4, altitude: 56, hAcc: -1, vAcc: -1, date: date)))
        assertThat(changeCnt, `is`(0))

        connect(drone: drone, handle: 1)
        assertThat(gps, present())
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 1.2, longitude: 3.4, altitude: 56, hAcc: -1, vAcc: -1, date: date)))
        assertThat(changeCnt, `is`(0))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateGpslocationchangedEncoder(
                latitude: 2.3, longitude: 4.5, altitude: 67, latitudeAccuracy: 10, longitudeAccuracy: 20,
                altitudeAccuracy: 30))
        date = gps?.lastKnownLocation?.timestamp
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 2.3, longitude: 4.5, altitude: 67, hAcc: 20, vAcc: 30)))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(gps, present())
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 2.3, longitude: 4.5, altitude: 67, hAcc: 20, vAcc: 30, date: date)))
        assertThat(changeCnt, `is`(1))

        // forget the drone
        _ = drone.forget()
        assertThat(gps, nilValue())
        assertThat(changeCnt, `is`(2))
    }

    func testGpsValuesWithPositionChanged() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(gps!.fixed, `is`(false))
        assertThat(gps!.lastKnownLocation, nilValue())
        assertThat(gps!.satelliteCount, `is`(0))
        assertThat(changeCnt, `is`(1))

        // Receive gps position without having fixed should set the location anyway
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePositionchangedEncoder(
                latitude: 1.2, longitude: 3.4, altitude: 56))
        assertThat(gps!.fixed, `is`(false))
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 1.2, longitude: 3.4, altitude: 56, hAcc: -1, vAcc: -1)))
        assertThat(gps!.satelliteCount, `is`(0))
        assertThat(changeCnt, `is`(2))

        // Fix changed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateGpsfixstatechangedEncoder(fixed: 1))
        assertThat(gps!.fixed, `is`(true))
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 1.2, longitude: 3.4, altitude: 56, hAcc: -1, vAcc: -1)))
        assertThat(gps!.satelliteCount, `is`(0))
        assertThat(changeCnt, `is`(3))

        // nb satellite changed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpsstateNumberofsatellitechangedEncoder(numberofsatellite: 2))
        assertThat(gps!.fixed, `is`(true))
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 1.2, longitude: 3.4, altitude: 56, hAcc: -1, vAcc: -1)))
        assertThat(gps!.satelliteCount, `is`(2))
        assertThat(changeCnt, `is`(4))

        // Not fixed should not erase the location values but modify the satellite number value
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateGpsfixstatechangedEncoder(fixed: 0))
        assertThat(gps!.fixed, `is`(false))
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 1.2, longitude: 3.4, altitude: 56, hAcc: -1, vAcc: -1)))
        assertThat(gps!.satelliteCount, `is`(0))
        assertThat(changeCnt, `is`(5))
    }

    func testGpsValuesWithGpsChanged() {
        connect(drone: drone, handle: 1)

        // Receive gps position from old event (PositionChanged) should set the position
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePositionchangedEncoder(
                latitude: 1.2, longitude: 3.4, altitude: 56))
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 1.2, longitude: 3.4, altitude: 56, hAcc: -1, vAcc: -1)))
        assertThat(changeCnt, `is`(2))

        // Receive gps position from the new event (GpsChanged) should set the position
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateGpslocationchangedEncoder(
                latitude: 2.3, longitude: 4.5, altitude: 67, latitudeAccuracy: 10, longitudeAccuracy: 20,
                altitudeAccuracy: 30))
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 2.3, longitude: 4.5, altitude: 67, hAcc: 20, vAcc: 30)))
        assertThat(changeCnt, `is`(3))

        // Receive gps position from old event (PositionChanged) should not set the position
        // once the newer event has been received
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePositionchangedEncoder(latitude: 1.2, longitude: 3.4,
                                                                               altitude: 56))
        assertThat(gps!.lastKnownLocation, presentAnd(
            `is`(latitude: 2.3, longitude: 4.5, altitude: 67, hAcc: 20, vAcc: 30)))
        assertThat(changeCnt, `is`(3))
    }
}
