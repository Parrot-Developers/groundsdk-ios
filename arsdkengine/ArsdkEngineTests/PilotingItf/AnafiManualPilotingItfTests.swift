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

class AnafiManualPilotingItfTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var manualCopterPilotingItf: ManualCopterPilotingItf?
    var manualCopterPilotingItfRef: Ref<ManualCopterPilotingItf>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    private func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        manualCopterPilotingItfRef = drone.getPilotingItf(PilotingItfs.manualCopter) { [unowned self] pilotingItf in
            self.manualCopterPilotingItf = pilotingItf
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
        assertThat(manualCopterPilotingItf, `is`(nilValue()))

        // connect the drone, piloting interface should be published
        connect(drone: drone, handle: 1)
        assertThat(manualCopterPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(manualCopterPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(2)) // should have been deactivated

        // forget the drone
        _ = drone.forget()
        assertThat(manualCopterPilotingItf, `is`(nilValue()))
        assertThat(changeCnt, `is`(3))
    }

    func testPilotingCmd() {
        let seqNrGenerator = PilotingCommand.Encoder.AnafiCopter()
        let timeProvider = MockTimeProvider()
        TimeProvider.instance = timeProvider

        connect(drone: drone, handle: 1)

        // expect the piloting command loop to have started
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
                flag: 0, roll: 0, pitch: 0, yaw: 0, gaz: 0, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // update pcmd value
        manualCopterPilotingItf!.set(roll: 2)
        manualCopterPilotingItf!.set(pitch: 4)
        manualCopterPilotingItf!.set(yawRotationSpeed: 6)
        manualCopterPilotingItf!.set(verticalSpeed: 8)
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
                flag: 1, roll: 2, pitch: -4, yaw: 6, gaz: 8, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        manualCopterPilotingItf!.hover()
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
                flag: 0, roll: 0, pitch: 0, yaw: 6, gaz: 8, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)
    }

    func testTakeOff() {
        connect(drone: drone, handle: 1)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingTakeoff())
        manualCopterPilotingItf!.takeOff()
    }

    func testLand() {
        connect(drone: drone, handle: 1)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingLanding())
        manualCopterPilotingItf!.land()
    }

    func testCanTakeOffCanLand() {
        connect(drone: drone, handle: 1)
        assertThat(manualCopterPilotingItf!.canTakeOff, `is`(false))
        assertThat(manualCopterPilotingItf!.canLand, `is`(false))

        // Landed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(manualCopterPilotingItf!.canTakeOff, `is`(true))
        assertThat(manualCopterPilotingItf!.canLand, `is`(false))

        // Motor ramping
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .motorRamping))
        assertThat(manualCopterPilotingItf!.canTakeOff, `is`(false))
        assertThat(manualCopterPilotingItf!.canLand, `is`(true))

        // User takeoff
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .usertakeoff))
        assertThat(manualCopterPilotingItf!.canTakeOff, `is`(false))
        assertThat(manualCopterPilotingItf!.canLand, `is`(true))

        // Takingoff
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .takingoff))
        assertThat(manualCopterPilotingItf!.canTakeOff, `is`(false))
        assertThat(manualCopterPilotingItf!.canLand, `is`(true))

        // Hovering
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .hovering))
        assertThat(manualCopterPilotingItf!.canTakeOff, `is`(false))
        assertThat(manualCopterPilotingItf!.canLand, `is`(true))

        // Flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(manualCopterPilotingItf!.canTakeOff, `is`(false))
        assertThat(manualCopterPilotingItf!.canLand, `is`(true))

        // Landing
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landing))
        assertThat(manualCopterPilotingItf!.canTakeOff, `is`(true))
        assertThat(manualCopterPilotingItf!.canLand, `is`(false))

        // Emergency
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .emergency))
        assertThat(manualCopterPilotingItf!.canTakeOff, `is`(false))
        assertThat(manualCopterPilotingItf!.canLand, `is`(false))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(manualCopterPilotingItf!.canTakeOff, `is`(false))
        assertThat(manualCopterPilotingItf!.canLand, `is`(false))
    }

    func testSmartTakeOffLand() {
        connect(drone: drone, handle: 1)
        // move to landed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))

        // the result of a smartTakeOffLandAction should be TakeOff
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.takeOff))

        // takeoff
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingTakeoff())
        manualCopterPilotingItf!.smartTakeOffLand()
        // move to flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        // land
        //  the result of a smartTakeOffLandAction should be should be .land
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.land))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingLanding())
        manualCopterPilotingItf!.smartTakeOffLand()

        // move to landed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))

        // motion detection is active
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingsettingsstateMotiondetectionEncoder(enabled: 1))
        // move the drone (MotionDetection)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateMotionstateEncoder(state: .moving))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsSetmotiondetectionmode(enable: 0))
        manualCopterPilotingItf!.thrownTakeOffSettings!.value = false
        // the result of a smartTakeOffLandAction should be takeOff
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.takeOff))

        // active "useForSmartTakeOff"
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsSetmotiondetectionmode(enable: 1))
        manualCopterPilotingItf!.thrownTakeOffSettings!.value = true

        // the result of a smartTakeOffLandAction should be ThrownTakeOff
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.thrownTakeOff))

        // Hand takeOff
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingUsertakeoff(state: 1))
        manualCopterPilotingItf!.smartTakeOffLand()

        // change state to usertakeoff and try to cancel the usertakeoff
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .usertakeoff))
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.land))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingLanding())
        manualCopterPilotingItf!.smartTakeOffLand()

        // move to landed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))

        // if the drone is not moving -> normal takeOff
        // (no MotionDetection) and "useForSmartTakeOff" is active
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateMotionstateEncoder(state: .steady))
        manualCopterPilotingItf!.thrownTakeOffSettings!.value = true
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.takeOff))

        // takeoff
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingTakeoff())
        manualCopterPilotingItf!.smartTakeOffLand()

        // move to motor ramping
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .motorRamping))
        //  the result of a smartTakeOffLandAction should be should be .land
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.land))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingLanding())
        manualCopterPilotingItf!.smartTakeOffLand()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))

        // move the drone (MotionDetection)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateMotionstateEncoder(state: .moving))
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.thrownTakeOff))

        // move to usertakeoff
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .usertakeoff))
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.land))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .hovering))
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.land))

        // move to landing
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landing))
        assertThat(manualCopterPilotingItf!.smartTakeOffLandAction, `is`(.takeOff))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingTakeoff())
        manualCopterPilotingItf!.smartTakeOffLand()
    }

    func testMaxPitchRoll() {
        connect(drone: drone, handle: 1)

        // initial state notification
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxtiltchangedEncoder(current: 1.2, min: 0.5, max: 2.5))
        assertThat(manualCopterPilotingItf!.maxPitchRoll, presentAnd(
            `is`(Double(Float(0.5)), Double(Float(1.2)), Double(Float(2.5)))))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsMaxtilt(current: 2.1))
        manualCopterPilotingItf!.maxPitchRoll.value = 2.1
        assertThat(manualCopterPilotingItf!.maxPitchRoll, presentAnd(allOf(
            `is`(0.5, 2.1, 2.5), isUpdating())))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(manualCopterPilotingItf!.maxPitchRoll, presentAnd(allOf(
            `is`(0.5, 2.1, 2.5), isUpToDate())))

        // restart engine
        resetArsdkEngine()

        // check we have the original preset setting
        assertThat(manualCopterPilotingItf!.maxPitchRoll, presentAnd(allOf(`is`(0.5, 2.1, 2.5), isUpToDate())))

        // change value while disconnected
        manualCopterPilotingItf!.maxPitchRoll.value = 2.2
        assertThat(manualCopterPilotingItf!.maxPitchRoll, presentAnd(allOf(
            `is`(Double(Float(0.5)), 2.2, Double(Float(2.5))), isUpToDate())))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1,
                encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxtiltchangedEncoder(
                    current: 1.1, min: 1.2, max: 2.6))
            // connect should send the saved setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsMaxtilt(current: 2.2))
        }
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxtiltchangedEncoder(current: 2.2, min: 1.1, max: 2.6))
        assertThat(manualCopterPilotingItf!.maxPitchRoll, presentAnd(
            `is`(Double(Float(1.1)), Double(Float(2.2)), Double(Float(2.6)))))
    }

    func testMaxPitchVelocity() {
        connect(drone: drone, handle: 1)

        // initial state notification
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxpitchrollrotationspeedchangedEncoder(
                current: 5.2, min: 3.3, max: 9.9))
        assertThat(manualCopterPilotingItf!.maxPitchRollVelocity, presentAnd(
            `is`(Double(Float(3.3)), Double(Float(5.2)), Double(Float(9.9)))))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3SpeedsettingsMaxpitchrollrotationspeed(current: 6.6))
        // change value while disconnected
        manualCopterPilotingItf!.maxPitchRollVelocity!.value = 6.6
        assertThat(manualCopterPilotingItf!.maxPitchRollVelocity, presentAnd(allOf(
            `is`(Double(Float(3.3)), 6.6, Double(Float(9.9))), isUpdating())))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(manualCopterPilotingItf!.maxPitchRollVelocity, presentAnd(allOf(
            `is`(Double(Float(3.3)), 6.6, Double(Float(9.9))), isUpToDate())))

        // restart engine
        resetArsdkEngine()
        assertThat(manualCopterPilotingItf!.maxPitchRollVelocity, presentAnd(allOf(
            `is`(Double(Float(3.3)), 6.6, Double(Float(9.9))), isUpToDate())))

        // change value while disconnected
        manualCopterPilotingItf!.maxPitchRollVelocity!.value = 6.7
        assertThat(manualCopterPilotingItf!.maxPitchRollVelocity, presentAnd(allOf(
            `is`(Double(Float(3.3)), 6.7, Double(Float(9.9))), isUpToDate())))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxpitchrollrotationspeedchangedEncoder(
                    current: 6.7, min: 3.3, max: 9.9))
            // connect should send the saved setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3SpeedsettingsMaxpitchrollrotationspeed(
                current: 6.7))
        }
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxpitchrollrotationspeedchangedEncoder(
                current: 6.7, min: 3.4, max: 9.8))
        assertThat(manualCopterPilotingItf!.maxPitchRollVelocity, presentAnd(
            `is`(Double(Float(3.4)), Double(Float(6.7)), Double(Float(9.8)))))
    }

    func testMaxVerticalSpeed() {
        connect(drone: drone, handle: 1)

        // initial state notification
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxverticalspeedchangedEncoder(
                current: 3.4, min: 1.2, max: 5.6))
        assertThat(manualCopterPilotingItf!.maxVerticalSpeed, presentAnd(
            `is`(Double(Float(1.2)), Double(Float(3.4)), Double(Float(5.6)))))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3SpeedsettingsMaxverticalspeed(current: 4.3))
        manualCopterPilotingItf!.maxVerticalSpeed.value = 4.3
        assertThat(manualCopterPilotingItf!.maxVerticalSpeed, presentAnd(allOf(
            `is`(Double(Float(1.2)), 4.3, Double(Float(5.6))), isUpdating())))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(manualCopterPilotingItf!.maxVerticalSpeed, presentAnd(allOf(
            `is`(Double(Float(1.2)), 4.3, Double(Float(5.6))), isUpToDate())))

        // restart engine
        resetArsdkEngine()
        assertThat(manualCopterPilotingItf!.maxVerticalSpeed, presentAnd(allOf(
            `is`(Double(Float(1.2)), 4.3, Double(Float(5.6))), isUpToDate())))

        // change value while disconnected
        manualCopterPilotingItf!.maxVerticalSpeed.value = 4.5
        assertThat(manualCopterPilotingItf!.maxVerticalSpeed, presentAnd(allOf(
            `is`(Double(Float(1.2)), 4.5, Double(Float(5.6))), isUpToDate())))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxverticalspeedchangedEncoder(
                    current: 1.2, min: 1.1, max: 6.7))
            // connect should send the saved setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3SpeedsettingsMaxverticalspeed(current: 4.5))
        }
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxverticalspeedchangedEncoder(
                current: 4.5, min: 1.1, max: 5.6))
        assertThat(manualCopterPilotingItf!.maxVerticalSpeed, presentAnd(
            `is`(Double(Float(1.1)), Double(Float(4.5)), Double(Float(5.6)))))
    }

    func testMaxYawSpeed() {
        connect(drone: drone, handle: 1)

        // initial state notification
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxrotationspeedchangedEncoder(
                current: 2.2, min: 1.1, max: 4.4))
        assertThat(manualCopterPilotingItf!.maxYawRotationSpeed, presentAnd(
            `is`(Double(Float(1.1)), Double(Float(2.2)), Double(Float(4.4)))))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3SpeedsettingsMaxrotationspeed(current: 3.3))
        manualCopterPilotingItf!.maxYawRotationSpeed.value = 3.3
        assertThat(manualCopterPilotingItf!.maxYawRotationSpeed, presentAnd(allOf(
            `is`(Double(Float(1.1)), 3.3, Double(Float(4.4))), isUpdating())))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(manualCopterPilotingItf!.maxYawRotationSpeed, presentAnd(allOf(
            `is`(Double(Float(1.1)), 3.3, Double(Float(4.4))), isUpToDate())))

        // restart engine
        resetArsdkEngine()
        assertThat(manualCopterPilotingItf!.maxYawRotationSpeed, presentAnd(allOf(
            `is`(Double(Float(1.1)), 3.3, Double(Float(4.4))), isUpToDate())))

        // change value while disconnected
        manualCopterPilotingItf!.maxYawRotationSpeed.value = 3.4
        assertThat(manualCopterPilotingItf!.maxYawRotationSpeed, presentAnd(allOf(
            `is`(Double(Float(1.1)), 3.4, Double(Float(4.4))), isUpToDate())))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxrotationspeedchangedEncoder(
                    current: 2.2, min: 1.0, max: 4.5))
            // connect should send the saved setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3SpeedsettingsMaxrotationspeed(current: 3.4))
        }
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxrotationspeedchangedEncoder(
                current: 3.4, min: 1.0, max: 4.5))
        assertThat(manualCopterPilotingItf!.maxYawRotationSpeed, presentAnd(
            `is`(Double(Float(1.0)), Double(Float(3.4)), Double(Float(4.5)))))
    }

    func testBankedTurnMode() {
        connect(drone: drone, handle: 1)

        // initial state notification
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingsettingsstateBankedturnchangedEncoder(state: 0))
        assertThat(manualCopterPilotingItf!.bankedTurnMode, presentAnd(`is`(false)))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsBankedturn(value: 1))
        manualCopterPilotingItf!.bankedTurnMode?.value = true
        assertThat(manualCopterPilotingItf!.bankedTurnMode, presentAnd(allOf(`is`(true), isUpdating())))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(manualCopterPilotingItf!.bankedTurnMode, presentAnd(allOf(`is`(true), isUpToDate())))

        // restart engine
        resetArsdkEngine()
        assertThat(manualCopterPilotingItf!.bankedTurnMode, presentAnd(allOf(`is`(true), isUpToDate())))

        // change value while disconnected
        manualCopterPilotingItf!.bankedTurnMode?.value = false
        assertThat(manualCopterPilotingItf!.bankedTurnMode, presentAnd(allOf(`is`(false), isUpToDate())))

        // reconnect
        connect(drone: drone, handle: 1) {
            // receive current drone setting
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingsettingsstateBankedturnchangedEncoder(state: 1))
            // connect should send the saved setting
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsBankedturn(value: 0))
        }
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingsettingsstateBankedturnchangedEncoder(state: 0))
        assertThat(manualCopterPilotingItf!.bankedTurnMode, presentAnd(`is`(false)))
    }

    func testResetOnDisconnect() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingsettingsstateBankedturnchangedEncoder(state: 0))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingsettingsstateMotiondetectionEncoder(enabled: 0))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxpitchrollrotationspeedchangedEncoder(
                    current: 0, min: 0, max: 1))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingsettingsstateMaxtiltchangedEncoder(current: 0, min: 0, max: 1))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxverticalspeedchangedEncoder(
                    current: 0, min: 0, max: 1))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3SpeedsettingsstateMaxrotationspeedchangedEncoder(
                    current: 0, min: 0, max: 1))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(manualCopterPilotingItf!.bankedTurnMode, presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(manualCopterPilotingItf!.thrownTakeOffSettings, presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(manualCopterPilotingItf!.maxPitchRollVelocity, presentAnd(allOf(`is`(0, 0, 1), isUpToDate())))
        assertThat(manualCopterPilotingItf!.maxPitchRoll, presentAnd(allOf(`is`(0, 0, 1), isUpToDate())))
        assertThat(manualCopterPilotingItf!.maxVerticalSpeed, presentAnd(allOf(`is`(0, 0, 1), isUpToDate())))
        assertThat(manualCopterPilotingItf!.maxYawRotationSpeed, presentAnd(allOf(`is`(0, 0, 1), isUpToDate())))

        // mock user modifies settings
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsBankedturn(value: 1))
        manualCopterPilotingItf!.bankedTurnMode?.value = true
        assertThat(manualCopterPilotingItf!.bankedTurnMode, presentAnd(allOf(`is`(true), isUpdating())))
        assertThat(changeCnt, `is`(2))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsSetmotiondetectionmode(enable: 1))
        manualCopterPilotingItf!.thrownTakeOffSettings?.value = true
        assertThat(manualCopterPilotingItf!.thrownTakeOffSettings, presentAnd(allOf(`is`(true), isUpdating())))
        assertThat(changeCnt, `is`(3))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3SpeedsettingsMaxpitchrollrotationspeed(current: 1))
        manualCopterPilotingItf!.maxPitchRollVelocity?.value = 1
        assertThat(manualCopterPilotingItf!.maxPitchRollVelocity, presentAnd(allOf(`is`(0, 1, 1), isUpdating())))
        assertThat(changeCnt, `is`(4))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingsettingsMaxtilt(current: 1))
        manualCopterPilotingItf!.maxPitchRoll.value = 1
        assertThat(manualCopterPilotingItf!.maxPitchRoll, allOf(`is`(0, 1, 1), isUpdating()))
        assertThat(changeCnt, `is`(5))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3SpeedsettingsMaxverticalspeed(current: 1))
        manualCopterPilotingItf!.maxVerticalSpeed.value = 1
        assertThat(manualCopterPilotingItf!.maxVerticalSpeed, allOf(`is`(0, 1, 1), isUpdating()))
        assertThat(changeCnt, `is`(6))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3SpeedsettingsMaxrotationspeed(current: 1))
        manualCopterPilotingItf!.maxYawRotationSpeed.value = 1
        assertThat(manualCopterPilotingItf!.maxYawRotationSpeed, allOf(`is`(0, 1, 1), isUpdating()))
        assertThat(changeCnt, `is`(7))

        // disconnect
        disconnect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(8))
        // setting should be updated to user value
        assertThat(manualCopterPilotingItf!.bankedTurnMode, presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(manualCopterPilotingItf!.thrownTakeOffSettings, presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(manualCopterPilotingItf!.maxPitchRollVelocity, presentAnd(allOf(`is`(0, 1, 1), isUpToDate())))
        assertThat(manualCopterPilotingItf!.maxPitchRoll, presentAnd(allOf(`is`(0, 1, 1), isUpToDate())))
        assertThat(manualCopterPilotingItf!.maxVerticalSpeed, presentAnd(allOf(`is`(0, 1, 1), isUpToDate())))
        assertThat(manualCopterPilotingItf!.maxYawRotationSpeed, presentAnd(allOf(`is`(0, 1, 1), isUpToDate())))
    }
}
