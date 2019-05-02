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
import CoreLocation

class AnafiGeofenceTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var geofence: Geofence?
    var geofenceRef: Ref<Geofence>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    func setUpDrone() {
        mockArsdkCore.addDevice(
            "123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        geofenceRef =
            drone.getPeripheral(Peripherals.geofence) { [unowned self] geofence in
                self.geofence = geofence
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
        assertThat(geofence, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(geofence, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(geofence, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // forget the drone
        _ = drone.forget()
        assertThat(geofence, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testMode() {
        connect(drone: drone, handle: 1) {
            // send a max altitide setting at connection in order to have some range values in the deviceStore
            // Otherwise, the interface will not be published after the resetArsdkEngine
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxaltitudechangedEncoder(
                    current: 50, min: 0, max: 150))
        }
        assertThat(geofence, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // initial values
        assertThat(geofence!.mode, allOf(`is`(.altitude), isUpToDate()))

        // change value from api
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.ardrone3PilotingsettingsNoflyovermaxdistance(shouldnotflyover: 1))
        geofence!.mode.value = .cylinder
        assertThat(geofence!.mode, allOf(`is`(.cylinder), isUpdating()))
        assertThat(changeCnt, `is`(2))

        // update value from backend
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingsettingsstateNoflyovermaxdistancechangedEncoder(shouldnotflyover: 1))
        assertThat(geofence!.mode, allOf(`is`(.cylinder), isUpToDate()))
        assertThat(changeCnt, `is`(3))

        // user modifies settings
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.ardrone3PilotingsettingsNoflyovermaxdistance(shouldnotflyover: 0))
        geofence!.mode.value = .altitude
        assertThat(geofence!.mode, allOf(`is`(.altitude), isUpdating()))
        assertThat(changeCnt, `is`(4))

        // Disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(geofence!.mode, allOf(`is`(.altitude), isUpToDate()))
        assertThat(changeCnt, `is`(5))

        resetArsdkEngine()
        assertThat(geofence, `is`(present()))
        assertThat(changeCnt, `is`(0))

        // Check setting are loaded correctly
        assertThat(geofence!.mode, allOf(`is`(.altitude), isUpToDate()))

        // change to .altitude while disconneted
        geofence!.mode.value = .cylinder
        assertThat(geofence!.mode, allOf(`is`(.cylinder), isUpToDate()))
        assertThat(changeCnt, `is`(1))

        // connect
        connect(drone: drone, handle: 1) {
            // drone connect with an ".altitude" mode
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingsettingsstateNoflyovermaxdistancechangedEncoder(
                    shouldnotflyover: 0))
            // a ".cylinder mode" should be sent
            self.expectCommand(handle: 1, expectedCmd:
                ExpectedCmd.ardrone3PilotingsettingsNoflyovermaxdistance(shouldnotflyover: 1))
        }

        assertThat(geofence!.mode, allOf(`is`(.cylinder), isUpToDate()))
    }

    func testMaxAltitude() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxaltitudechangedEncoder(
                    current: 10, min: 5, max: 50))
        }
        // initial state notification
        assertThat(geofence!.maxAltitude, presentAnd(`is`(5, 10, 50)))
        assertThat(changeCnt, `is`(1))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsMaxaltitude(current: 6.0))
        geofence!.maxAltitude.value = 6.0
        assertThat(geofence!.maxAltitude, allOf(`is`(5, 6.0, 50), isUpdating()))
        assertThat(changeCnt, `is`(2))

        // update notification
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxaltitudechangedEncoder(current: 8.3, min: 5, max: 50))
        assertThat(geofence!.maxAltitude, allOf(`is`(5, Double(Float(8.3)), 50), isUpToDate()))
        assertThat(changeCnt, `is`(3))

        // disconnect
        disconnect(drone: drone, handle: 1)

        assertThat(geofence!.maxAltitude, allOf(`is`(5, Double(Float(8.3)), 50), isUpToDate()))

        // restart engine
        resetArsdkEngine()

        // check we have the original preset setting
        assertThat(geofence!.maxAltitude, allOf(`is`(5, 6.0, 50), isUpToDate()))

        // change value while disconnected
        geofence!.maxAltitude.value = 12.2
        assertThat(geofence!.maxAltitude, allOf(`is`(5, 12.2, 50), isUpToDate()))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1,
                encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxaltitudechangedEncoder(current: 1, min: 1, max: 20))
            // connect should send the saved setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsMaxaltitude(current: 12.2))
        }
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxaltitudechangedEncoder(current: 12.2, min: 1, max: 20))
        assertThat(geofence!.maxAltitude, presentAnd(`is`(1, Double(Float(12.2)), 20)))
    }

    func testMaxDistance() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxdistancechangedEncoder(
                    current: 100, min: 5, max: 2000))
        }
        // initial state notification
        assertThat(geofence!.maxDistance, presentAnd(`is`(5, 100, 2000)))
        assertThat(changeCnt, `is`(1))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsMaxdistance(value: 600.0))
        geofence!.maxDistance.value = 600.0
        assertThat(geofence!.maxDistance, allOf(`is`(5, 600, 2000), isUpdating()))
        assertThat(changeCnt, `is`(2))

        // update notification
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxdistancechangedEncoder(current: 40.5, min: 5, max: 900))
        assertThat(geofence!.maxDistance, allOf(`is`(5, Double(Float(40.5)), 900), isUpToDate()))
        assertThat(changeCnt, `is`(3))

        // disconnect
        disconnect(drone: drone, handle: 1)

        assertThat(geofence!.maxDistance, allOf(`is`(5, Double(Float(40.5)), 900), isUpToDate()))

        // restart engine
        resetArsdkEngine()

        // check we have the original preset setting
        assertThat(geofence!.maxDistance, allOf(`is`(5, 600, 900), isUpToDate()))

        // change value while disconnected
        geofence!.maxDistance.value = 650
        assertThat(geofence!.maxDistance, allOf(`is`(5, 650, 900), isUpToDate()))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1,
                encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxdistancechangedEncoder(
                    current: 50, min: 5, max: 2000))
            // connect should send the saved setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsMaxdistance(value: 650))
        }
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxdistancechangedEncoder(current: 600, min: 5, max: 2000))
        assertThat(geofence!.maxDistance, presentAnd(`is`(5, 600, 2000)))
    }

    func testCenter() {
        connect(drone: drone, handle: 1) {
            // send a max altitide setting at connection in order to have some range values in the deviceStore
            // Otherwise, the interface will not be published after the resetArsdkEngine
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxaltitudechangedEncoder(
                    current: 50, min: 0, max: 150))
        }
        assertThat(geofence, `is`(present()))
        assertThat(geofence?.center, nilValue())
        assertThat(changeCnt, `is`(1))

        // update center
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateHomechangedEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 3.3))

        assertThat(geofence?.center, presentAnd(`is`(latitude: 1.1, longitude: 2.2)))
        assertThat(changeCnt, `is`(2))

        // update same value
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateHomechangedEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 4.4))

        assertThat(geofence?.center, presentAnd(`is`(latitude: 1.1, longitude: 2.2)))
        assertThat(changeCnt, `is`(3)) // '3' because the CLLocation has a new timestamp
        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(geofence?.center, presentAnd(`is`(latitude: 1.1, longitude: 2.2)))
    }
}
