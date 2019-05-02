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

class AnafiReturnHomePilotingItfTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var returnHomePilotingItf: ReturnHomePilotingItf?
    var returnHomePilotingItfRef: Ref<ReturnHomePilotingItf>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    private func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        returnHomePilotingItfRef = drone.getPilotingItf(PilotingItfs.returnHome) { [unowned self] pilotingItf in
            self.returnHomePilotingItf = pilotingItf
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpDrone()
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected and not known
        assertThat(returnHomePilotingItf, `is`(nilValue()))

        // connect the drone, piloting interface should be published
        connect(drone: drone, handle: 1)
        assertThat(returnHomePilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(returnHomePilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // forget the drone
        _ = drone.forget()
        assertThat(returnHomePilotingItf, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testActivateDeactivate() {
        connect(drone: drone, handle: 1)
        // should be inactive
        assertThat(returnHomePilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(1))

        // return home available
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .available, reason: .enabled))
        assertThat(returnHomePilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        // activate return home
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingNavigatehome(start: 1))
        _ = returnHomePilotingItf?.activate()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .inprogress, reason: .userrequest))
        assertThat(returnHomePilotingItf!.state, `is`(.active))
        assertThat(changeCnt, `is`(3))

        // deactivate return home
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingNavigatehome(start: 0))
        _ = returnHomePilotingItf?.deactivate()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .available, reason: .userrequest))
        assertThat(returnHomePilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(4))

        // return home unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .unavailable, reason: .userrequest))
        assertThat(returnHomePilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(5))
    }

    func testReason() {
        connect(drone: drone, handle: 1)
        // reason should be none
        assertThat(returnHomePilotingItf!.reason, `is`(.none))
        assertThat(changeCnt, `is`(1))

        // make return home available
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .available, reason: .enabled))
        assertThat(returnHomePilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        // mock return home activation because user requested it
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .inprogress, reason: .userrequest))
        assertThat(returnHomePilotingItf!.state, `is`(.active))
        assertThat(returnHomePilotingItf!.reason, `is`(.userRequested))
        assertThat(changeCnt, `is`(3))

        // mock return home deactivation because it finished
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .available, reason: .finished))
        assertThat(returnHomePilotingItf!.state, `is`(.idle))
        assertThat(returnHomePilotingItf!.reason, `is`(.finished))
        assertThat(changeCnt, `is`(4))

        // mock return home activation because of low battery
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .inprogress, reason: .lowbattery))
        assertThat(returnHomePilotingItf!.state, `is`(.active))
        assertThat(returnHomePilotingItf!.reason, `is`(.powerLow))
        assertThat(changeCnt, `is`(5))

        // mock return home deactivation because user requested it
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .available, reason: .userrequest))
        assertThat(returnHomePilotingItf!.state, `is`(.idle))
        assertThat(returnHomePilotingItf!.reason, `is`(.userRequested))
        assertThat(changeCnt, `is`(6))

        // mock return home activation because of connection lost
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .inprogress, reason: .connectionlost))
        assertThat(returnHomePilotingItf!.state, `is`(.active))
        assertThat(returnHomePilotingItf!.reason, `is`(.connectionLost))
        assertThat(changeCnt, `is`(7))

        // mock return home deactivation because rth is disabled (should not happen)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .available, reason: .disabled))
        assertThat(returnHomePilotingItf!.state, `is`(.idle))
        assertThat(returnHomePilotingItf!.reason, `is`(.none))
        assertThat(changeCnt, `is`(8))

        // mock return home activation because it has been enabled (should not happen)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .inprogress, reason: .enabled))
        assertThat(returnHomePilotingItf!.state, `is`(.active))
        assertThat(returnHomePilotingItf!.reason, `is`(.none))
        assertThat(changeCnt, `is`(9))
    }

    func testCurrentTarget() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        // TakeOffPosition
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpsstateHometypechosenchangedEncoder(type: .takeoff))
        assertThat(changeCnt, `is`(2))
        assertThat(returnHomePilotingItf!.currentTarget, `is`(.takeOffPosition))
        assertThat(returnHomePilotingItf!.gpsWasFixedOnTakeOff, `is`(true))

        // FirstFix
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3GpsstateHometypechosenchangedEncoder(type: .firstFix))
        assertThat(changeCnt, `is`(3))
        assertThat(returnHomePilotingItf!.currentTarget, `is`(.takeOffPosition))
        assertThat(returnHomePilotingItf!.gpsWasFixedOnTakeOff, `is`(false))

        // Pilot
        mockArsdkCore.onCommandReceived(1,
                                        encoder: CmdEncoder.ardrone3GpsstateHometypechosenchangedEncoder(type: .pilot))
        assertThat(changeCnt, `is`(4))
        assertThat(returnHomePilotingItf!.currentTarget, `is`(.controllerPosition))
    }

    func testHomeLocation() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        assertThat(returnHomePilotingItf!.homeLocation, `is`(nilValue()))

        // Ensure that position 500,500 is ignored
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3GpssettingsstateHomechangedEncoder(latitude: 500, longitude: 500, altitude: 10))
        assertThat(returnHomePilotingItf!.homeLocation, `is`(nilValue()))

        // TakeOffPosition
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3GpssettingsstateHomechangedEncoder(
                latitude: 20.0, longitude: 30.0, altitude: 150.0))
        assertThat(changeCnt, `is`(2))
        assertThat(returnHomePilotingItf!.homeLocation, presentAnd(
            `is`(latitude: 20.0, longitude: 30.0, altitude: 150.0, hAcc: -1, vAcc: -1)))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(returnHomePilotingItf!.homeLocation, `is`(nilValue()))
    }

    func testPreferredTarget() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        // backend changed to ControllerPosition
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateHometypechangedEncoder(type: .pilot))
        assertThat(changeCnt, `is`(2))
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: false))

        // change to trackedTargetPosition
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3GpssettingsHometype(type: .followee))
        returnHomePilotingItf!.preferredTarget.target = .trackedTargetPosition
        assertThat(changeCnt, `is`(3))
        assertThat(returnHomePilotingItf!.preferredTarget,
                   `is`(preferredTarget: .trackedTargetPosition, updating: true))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateHometypechangedEncoder(type: .followee))
        assertThat(changeCnt, `is`(4))
        assertThat(returnHomePilotingItf!.preferredTarget,
                   `is`(preferredTarget: .trackedTargetPosition, updating: false))

        // change to takeOffPosition
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3GpssettingsHometype(type: .takeoff))
        returnHomePilotingItf!.preferredTarget.target = .takeOffPosition
        assertThat(changeCnt, `is`(5))
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .takeOffPosition, updating: true))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateHometypechangedEncoder(type: .takeoff))
        assertThat(changeCnt, `is`(6))
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .takeOffPosition, updating: false))

        // change to controller position
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3GpssettingsHometype(type: .pilot))
        returnHomePilotingItf!.preferredTarget.target = .controllerPosition
        assertThat(changeCnt, `is`(7))
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: true))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateHometypechangedEncoder(type: .pilot))
        assertThat(changeCnt, `is`(8))
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: false))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: false))

        // restart engine
        resetArsdkEngine()
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: false))
        assertThat(changeCnt, `is`(0))

        // change value while disconnected
        returnHomePilotingItf!.preferredTarget.target = .takeOffPosition
        assertThat(changeCnt, `is`(1))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3GpssettingsstateHometypechangedEncoder(type: .pilot))
            // connect should send the saved setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3GpssettingsHometype(type: .takeoff))
        }
        assertThat(changeCnt, `is`(1))

        // backend changed to TakeOffPosition
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateHometypechangedEncoder(type: .takeoff))
        assertThat(changeCnt, `is`(1))
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .takeOffPosition, updating: false))

        // setting same value while connected should not change anything
        returnHomePilotingItf!.preferredTarget.target = .takeOffPosition
        assertThat(changeCnt, `is`(1))

        // disconnect
        disconnect(drone: drone, handle: 1)
        // setting same value while disconnected should not change anything
        returnHomePilotingItf!.preferredTarget.target = .takeOffPosition
        assertThat(changeCnt, `is`(1))
    }

    func testHomeReachability() {
        connect(drone: drone, handle: 1)

        // initial value
        assertThat(changeCnt, `is`(1))
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.unknown))

        // Reachable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.rthHomeReachabilityEncoder(status: .reachable))
        assertThat(changeCnt, `is`(2))
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.reachable))

        // Not Reachable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.rthHomeReachabilityEncoder(status: .notReachable))
        assertThat(changeCnt, `is`(3))
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.notReachable))

        // Critical
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.rthHomeReachabilityEncoder(status: .critical))
        assertThat(changeCnt, `is`(4))
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.critical))
    }

    func testWarningPlannedReturn() {
        connect(drone: drone, handle: 1)

        // initial value
        assertThat(changeCnt, `is`(1))
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.unknown))

        // Auto trigger
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.rthRthAutoTriggerEncoder(reason: .batteryCriticalSoon, delay: 60))
        assertThat(changeCnt, `is`(2))
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.warning))
        assertThat(returnHomePilotingItf!.autoTriggerDelay, `is`(60))

        // A reachability value changed, but the drone is still in auto triggering
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.rthHomeReachabilityEncoder(status: .critical))
        assertThat(changeCnt, `is`(2))
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.warning))
        assertThat(returnHomePilotingItf!.autoTriggerDelay, `is`(60))

        // Stop Auto trigger
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.rthRthAutoTriggerEncoder(reason: .none, delay: 0))
        assertThat(changeCnt, `is`(3))
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.critical))
        assertThat(returnHomePilotingItf!.autoTriggerDelay, `is`(0))

         mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.rthRthAutoTriggerEncoder(reason: .batteryCriticalSoon, delay: 15))
        assertThat(changeCnt, `is`(4))
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.warning))
        assertThat(returnHomePilotingItf!.autoTriggerDelay, `is`(15))

        // start a RTH.
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateNavigatehomestatechangedEncoder(
                state: .inprogress, reason: .lowbattery))
        assertThat(returnHomePilotingItf!.state, `is`(.active))
        assertThat(changeCnt, `is`(5))
        // assert that the automatic trigger is 0
        assertThat(returnHomePilotingItf!.autoTriggerDelay, `is`(0))
        // assert that we remove the ".warning" reachability and back to the previous one
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.critical))
    }

    func testMinimumAltitude() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))
        assertThat(returnHomePilotingItf!.minAltitude, `is`(nilValue()))

        // initial state notification
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateReturnhomeminaltitudechangedEncoder(
                value: 20, min: 10, max: 50))
        assertThat(changeCnt, `is`(2))
        assertThat(returnHomePilotingItf!.minAltitude, presentAnd(allOf(`is`(10.0, 20.0, 50.0), isUpToDate())))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3GpssettingsReturnhomeminaltitude(value: 30))
        returnHomePilotingItf?.minAltitude?.value = 30
        assertThat(changeCnt, `is`(3))
        assertThat(returnHomePilotingItf!.minAltitude, presentAnd(allOf(`is`(10.0, 30.0, 50.0), isUpdating())))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateReturnhomeminaltitudechangedEncoder(
                value: 30, min: 10, max: 50))
        assertThat(changeCnt, `is`(4))
        assertThat(returnHomePilotingItf!.minAltitude, presentAnd(allOf(`is`(10.0, 30.0, 50.0), isUpToDate())))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(returnHomePilotingItf!.minAltitude, presentAnd(allOf(`is`(10.0, 30.0, 50.0), isUpToDate())))
        assertThat(changeCnt, `is`(4))

        // restart engine
        resetArsdkEngine()
        assertThat(returnHomePilotingItf!.minAltitude, presentAnd(allOf(`is`(10.0, 30.0, 50.0), isUpToDate())))
        assertThat(changeCnt, `is`(0))

        // change value while disconnected
        returnHomePilotingItf?.minAltitude?.value = 40
        assertThat(changeCnt, `is`(1))
        assertThat(returnHomePilotingItf!.minAltitude, presentAnd(allOf(`is`(10.0, 40.0, 50.0), isUpToDate())))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3GpssettingsstateReturnhomeminaltitudechangedEncoder(
                    value: 20, min: 10, max: 50))
            // connect should send the saved setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3GpssettingsReturnhomeminaltitude(value: 40))
        }

        assertThat(returnHomePilotingItf!.minAltitude, presentAnd(allOf(`is`(10.0, 40.0, 50.0), isUpToDate())))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateReturnhomeminaltitudechangedEncoder(
                value: 40, min: 10, max: 50))
        assertThat(returnHomePilotingItf!.minAltitude, presentAnd(allOf(`is`(10.0, 40.0, 50.0), isUpToDate())))
    }

    func testAutoStartOnDisconnectDelay() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        // initial state notification
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateReturnhomedelaychangedEncoder(delay: 30))
        assertThat(changeCnt, `is`(2))
        assertThat(returnHomePilotingItf!.autoStartOnDisconnectDelay, allOf(`is`(0, 30, 120), isUpToDate()))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3GpssettingsReturnhomedelay(delay: 92))
        returnHomePilotingItf?.autoStartOnDisconnectDelay.value = 92
        assertThat(changeCnt, `is`(3))
        assertThat(returnHomePilotingItf!.autoStartOnDisconnectDelay, allOf(`is`(0, 92, 120), isUpdating()))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(returnHomePilotingItf!.autoStartOnDisconnectDelay, allOf(`is`(0, 92, 120), isUpToDate()))
        assertThat(changeCnt, `is`(4))

        // restart engine
        resetArsdkEngine()
                assertThat(returnHomePilotingItf!.autoStartOnDisconnectDelay, allOf(`is`(0, 92, 120), isUpToDate()))
        assertThat(changeCnt, `is`(0))

        // change value while disconnected
        returnHomePilotingItf?.autoStartOnDisconnectDelay.value = 101
        assertThat(changeCnt, `is`(1))
        assertThat(returnHomePilotingItf!.autoStartOnDisconnectDelay, allOf(`is`(0, 101, 120), isUpToDate()))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3GpssettingsstateReturnhomedelaychangedEncoder(delay: 30))
            // connect should send the saved setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3GpssettingsReturnhomedelay(delay: 101))
        }

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3GpssettingsstateReturnhomedelaychangedEncoder(delay: 102))
        assertThat(returnHomePilotingItf!.autoStartOnDisconnectDelay, allOf(`is`(0, 102, 120), isUpToDate()))
    }

    func testCancelAutoTrigger() {
        connect(drone: drone, handle: 1)

        // initial home reachability value
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.unknown))

        // cancelling when no auto trigger is planned should not do anything
        returnHomePilotingItf!.cancelAutoTrigger()

        // Mock reception of home reachability warning (i.e. auto trigger is planned)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.rthRthAutoTriggerEncoder(reason: .batteryCriticalSoon, delay: 60))
        assertThat(returnHomePilotingItf!.homeReachability, `is`(.warning))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.rthCancelAutoTrigger())
        returnHomePilotingItf!.cancelAutoTrigger()
    }

    func testResetOnDisconnect() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3GpssettingsstateReturnhomedelaychangedEncoder(delay: 0))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3GpssettingsstateHometypechangedEncoder(type: .takeoff))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3GpsstateHometypechosenchangedEncoder(type: .followee))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3GpssettingsstateHomechangedEncoder(
                    latitude: 42, longitude: 42, altitude: 42))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(returnHomePilotingItf!.autoStartOnDisconnectDelay, allOf(`is`(0, 0, 120), isUpToDate()))
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .takeOffPosition, updating: false))

        // mock user modifies settings
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3GpssettingsReturnhomedelay(delay: 1))
        returnHomePilotingItf?.autoStartOnDisconnectDelay.value = 1
        assertThat(returnHomePilotingItf!.autoStartOnDisconnectDelay, allOf(`is`(0, 1, 120), isUpdating()))
        assertThat(changeCnt, `is`(2))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3GpssettingsHometype(type: .pilot))
        returnHomePilotingItf?.preferredTarget.target = .controllerPosition
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: true))
        assertThat(changeCnt, `is`(3))

        // disconnect
        disconnect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(4))
        assertThat(returnHomePilotingItf!.autoStartOnDisconnectDelay, allOf(`is`(0, 1, 120), isUpToDate()))
        assertThat(returnHomePilotingItf!.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: false))

        // test other values are reset as they should
        assertThat(returnHomePilotingItf!.currentTarget, `is`(.takeOffPosition))
        assertThat(returnHomePilotingItf!.gpsWasFixedOnTakeOff, `is`(false))
        assertThat(returnHomePilotingItf!.homeLocation, nilValue())
    }
}
