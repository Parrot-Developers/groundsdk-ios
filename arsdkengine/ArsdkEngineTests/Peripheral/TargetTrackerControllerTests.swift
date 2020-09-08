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

class TargetTrackerControllerTests: ArsdkEngineTestBase {

    var drone: DroneCore!

    var targetTracker: TargetTracker?
    var targetTrackerRef: Ref<TargetTracker>?
    var targetTrackerCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        targetTrackerRef = drone.getPeripheral(Peripherals.targetTracker) { [unowned self] targetTracker in
            self.targetTracker = targetTracker
            self.targetTrackerCnt += 1
        }
        targetTrackerCnt = 0
    }

    func testPublishAndForget() {
        // should be unavailable when the drone is not connected
        assertThat(targetTracker, nilValue())

        connect(drone: drone, handle: 1)
        assertThat(targetTracker, present())
        assertThat(targetTrackerCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(targetTracker, present())
        assertThat(targetTrackerCnt, `is`(1))

        // forget the drone
        _ = drone.forget()
        assertThat(targetTracker, nilValue())
        assertThat(targetTrackerCnt, `is`(2))
    }

    func testFraming() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(targetTracker!.framing, allOf(`is`(0.5, 0.5), isUpToDate()))
        assertThat(targetTrackerCnt, `is`(1))

        // changes framing from interface
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeTargetFramingPosition(
            horizontal: 50, vertical: 75))
        targetTracker!.framing.value = (0.5, 0.75)
        assertThat(targetTracker!.framing, allOf(`is`(0.5, 0.75), isUpdating()))
        assertThat(targetTrackerCnt, `is`(2))

        // mock framing update from low-level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeTargetFramingPositionChangedEncoder(horizontal: 50, vertical: 75))
        assertThat(targetTracker!.framing, allOf(`is`(0.5, 0.75), isUpToDate()))
        assertThat(targetTrackerCnt, `is`(3))

        // mock framing update from low-level with the same value
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeTargetFramingPositionChangedEncoder(horizontal: 50, vertical: 75))
        assertThat(targetTracker!.framing, allOf(`is`(0.5, 0.75), isUpToDate()))
        assertThat(targetTrackerCnt, `is`(3))

        // mock framing update from low-level with a new value
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeTargetFramingPositionChangedEncoder(horizontal: 100, vertical: 75))
        assertThat(targetTracker!.framing, allOf(`is`(1.0, 0.75), isUpToDate()))
        assertThat(targetTrackerCnt, `is`(4))
    }

    func testAlwaysRunning() {
        connect(drone: drone, handle: 1)

        // check that barometer is always started
        let measureDate = Date()
        let testBarometerMeasure = BarometerMeasure(pressure: 101325, timestamp: measureDate)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.controllerInfoBarometer(
            pressure: 101325,
            timestamp: measureDate.timeIntervalSince1970 * 1000))
        var isStarted = systemeBarometer.mockBarometerMeasure(testBarometerMeasure)
        assertThat(isStarted, equalTo(true))

        // barometer is always started
        let measureDate2 = Date()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.controllerInfoBarometer(
            pressure: 101335,
            timestamp: measureDate2.timeIntervalSince1970 * 1000))

        let testBarometerMeasure2 = BarometerMeasure(pressure: 101335, timestamp: measureDate2)
        isStarted = systemeBarometer.mockBarometerMeasure(testBarometerMeasure2)
        assertThat(isStarted, equalTo(true))
    }

    func testUseOfControllerAsLocation() {
        connect(drone: drone, handle: 1)
        // start
        assertThat(targetTracker!.targetIsController, `is`(false))
        assertThat(targetTrackerCnt, `is`(1))

        // check that force location not used
        assertThat(systemePosition.forcedUpdates, `is`(false))

        // uses the controller as target
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeSetTargetIsController(targetIsController: 1))
        targetTracker!.enableControllerTracking()
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeTargetIsControllerEncoder(state: 1))
        assertThat(targetTracker!.targetIsController, `is`(true))
        assertThat(targetTrackerCnt, `is`(2))

        // force updating location is ON
        assertThat(systemePosition.forcedUpdates, `is`(true))

        // stop
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeSetTargetIsController(targetIsController: 0))
        targetTracker!.disableControllerTracking()
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeTargetIsControllerEncoder(state: 0))
        assertThat(systemePosition.forcedUpdates, `is`(false))
        assertThat(targetTracker!.targetIsController, `is`(false))
        assertThat(targetTrackerCnt, `is`(3))

        // multiple starts / stops
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeSetTargetIsController(targetIsController: 1))
        targetTracker!.enableControllerTracking()
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeTargetIsControllerEncoder(state: 1))
        targetTracker!.enableControllerTracking()
        targetTracker!.enableControllerTracking()
        assertThat(targetTracker!.targetIsController, `is`(true))
        assertThat(targetTrackerCnt, `is`(4))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeSetTargetIsController(targetIsController: 0))
        targetTracker!.disableControllerTracking()
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeTargetIsControllerEncoder(state: 0))
        targetTracker!.disableControllerTracking()
        targetTracker!.disableControllerTracking()
        assertThat(targetTracker!.targetIsController, `is`(false))
        assertThat(targetTrackerCnt, `is`(5))

        // location is not forced
        assertThat(systemePosition.forcedUpdates, `is`(false))

        disconnect(drone: drone, handle: 1)
        assertThat(targetTracker!.targetIsController, `is`(false))
        connect(drone: drone, handle: 1) {
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeSetTargetIsController(targetIsController: 0))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeTargetIsControllerEncoder(state: 1))
        }
        assertThat(targetTracker!.targetIsController, `is`(false))
        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeTargetIsControllerEncoder(state: 0))
        assertThat(targetTracker!.targetIsController, `is`(false))
    }

    func testUseOfControllerWhenReconnect() {
        connect(drone: drone, handle: 1)

        // start
        assertThat(targetTrackerCnt, `is`(1))
        // start
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeSetTargetIsController(targetIsController: 1))
        targetTracker!.enableControllerTracking()
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeTargetIsControllerEncoder(state: 1))
        assertThat(targetTracker!.targetIsController, `is`(true))
        assertThat(targetTrackerCnt, `is`(2))

        // disconnect the drone
        assertNoExpectation()
        disconnect(drone: drone, handle: 1)

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeTargetIsControllerEncoder(state: 0))
            // connect should send the "TargetIsController" as true
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeSetTargetIsController(targetIsController: 1))
        }

        // disconnect the drone
        assertNoExpectation()
        disconnect(drone: drone, handle: 1)

        // disable tracker off line
        targetTracker!.disableControllerTracking()

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeTargetIsControllerEncoder(state: 1))
            // connect should send the "TargetIsController" as false
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeSetTargetIsController(targetIsController: 0))
        }
    }

    func testFramingWhenReconnect() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(targetTracker!.framing, allOf(`is`(0.5, 0.5), isUpToDate()))
        assertThat(targetTrackerCnt, `is`(1))

        // changes framing from interface
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeTargetFramingPosition(horizontal: 50, vertical: 75))
        targetTracker!.framing.value = (0.5, 0.75)
        assertThat(targetTracker!.framing, allOf(`is`(0.5, 0.75), isUpdating()))
        assertThat(targetTrackerCnt, `is`(2))

        // mock framing update from low-level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeTargetFramingPositionChangedEncoder(horizontal: 50, vertical: 75))
        assertThat(targetTracker!.framing, allOf(`is`(0.5, 0.75), isUpToDate()))
        assertThat(targetTrackerCnt, `is`(3))

        // changes framing from interface
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeTargetFramingPosition(horizontal: 60, vertical: 0))
        targetTracker!.framing.value = (0.6, 0.0)
        assertThat(targetTracker!.framing, allOf(`is`(0.6, 0.0), isUpdating()))
        assertThat(targetTrackerCnt, `is`(4))

        // disconnect the drone
        assertNoExpectation()
        disconnect(drone: drone, handle: 1)

        // setting should be updated to user value
        assertThat(targetTracker!.framing, allOf(`is`(0.6, 0.0), isUpToDate()))
        assertThat(targetTrackerCnt, `is`(5))

        // change framing offline
        targetTracker!.framing.value = (0.6, 0.2)
        assertThat(targetTracker!.framing, allOf(`is`(0.6, 0.2), isUpToDate()))
        assertThat(targetTrackerCnt, `is`(6))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.followMeTargetFramingPositionChangedEncoder(horizontal: 50, vertical: 75))
            // connect should send the current setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeTargetFramingPosition(
                horizontal: 60, vertical: 20))
        }

    }

    func testSendTargetDetectionInfo() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(targetTrackerCnt, `is`(1))

        // send Detection Info framing
        let detectionInfo = TargetDetectionInfo(
            targetAzimuth: 1.1, targetElevation: 2.2, changeOfScale: 3.3, confidence: 0.4, isNewTarget: true,
            timestamp: 200866)

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeTargetImageDetection(
            targetAzimuth: 1.1, targetElevation: 2.2, changeOfScale: 3.3, confidenceIndex: 102, isNewSelection: 1,
            timestamp: 200866))
        targetTracker!.sendTargetDetectionInfo(detectionInfo)
        assertThat(targetTrackerCnt, `is`(1))
        disconnect(drone: drone, handle: 1)
    }

    func testTargetTrajectory () {
        connect(drone: drone, handle: 1)
        assertThat(targetTracker?.targetTrajectory, nilValue())
        assertThat(targetTrackerCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeTargetTrajectoryEncoder(
                latitude: 1, longitude: 2, altitude: 3, northSpeed: 4, eastSpeed: 5, downSpeed: 6))

        assertThat(targetTracker?.targetTrajectory, presentAnd(`is`(1, 2, 3, 4, 5, 6)))
        assertThat(targetTrackerCnt, `is`(2))

        // same value
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeTargetTrajectoryEncoder(
                latitude: 1, longitude: 2, altitude: 3, northSpeed: 4, eastSpeed: 5, downSpeed: 6))

        assertThat(targetTracker?.targetTrajectory, presentAnd(`is`(1, 2, 3, 4, 5, 6)))
        assertThat(targetTrackerCnt, `is`(2))

        // new value
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeTargetTrajectoryEncoder(
                latitude: 10, longitude: 20, altitude: 30, northSpeed: 40, eastSpeed: 50, downSpeed: 60))

        assertThat(targetTracker?.targetTrajectory, presentAnd(`is`(10, 20, 30, 40, 50, 60)))
        assertThat(targetTrackerCnt, `is`(3))

        disconnect(drone: drone, handle: 1)
        assertThat(targetTracker?.targetTrajectory, nilValue())
        assertThat(targetTrackerCnt, `is`(4))
    }

}
