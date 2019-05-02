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
import SdkCore
import SdkCoreTesting

class GimbalFeatureGimbalTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var gimbal: Gimbal?
    var gimbalRef: Ref<Gimbal>?
    var changeCnt = 0
    var transiantStateTester: (() -> Void)?

    override func setUp() {
        super.setUp()
        setUpDrone()
        changeCnt = 0
    }

    private func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net,
                                name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!
        gimbalRef = drone.getPeripheral(Peripherals.gimbal) { [unowned self] camera in
            self.gimbal = camera
            self.changeCnt += 1
            if let transiantStateTester = self.transiantStateTester {
                transiantStateTester()
                self.transiantStateTester = nil
            }
        }
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpDrone()
    }

    private func mockSupportedAxes(_ axes: GimbalAxis...) {
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalGimbalCapabilitiesEncoder(
                gimbalId: 0, model: .main, axesBitField: Bitfield.of(axes)))
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(gimbal, `is`(nilValue()))

        connect(drone: drone, handle: 1) {
            //self.mockSupportedAxes(.yaw, .pitch)
        }
        assertThat(gimbal, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(gimbal, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // forget the drone
        _ = drone.forget()
        assertThat(gimbal, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testAxisCapabilities() {
        connect(drone: drone, handle: 1)

        // Check initial value
        assertThat(gimbal!.supportedAxes, empty())
        assertThat(changeCnt, `is`(1))

        mockSupportedAxes(.yaw, .pitch)

        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(changeCnt, `is`(2))

        mockSupportedAxes(.roll)
        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.roll))
        assertThat(changeCnt, `is`(3))

        // disconnect
        disconnect(drone: drone, handle: 1)

        // check that supported axes have been kept
        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.roll))
    }

    func testCurrentErros() {
        connect(drone: drone, handle: 1)

        // Check initial value
        assertThat(gimbal!.currentErrors, empty())
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.gimbalAlertEncoder(
            gimbalId: 0, errorBitField: Bitfield<ArsdkFeatureGimbalError>.of(.commError, .criticalError)))
        assertThat(gimbal!.currentErrors, containsInAnyOrder(.communication, .critical))
        assertThat(changeCnt, `is`(2))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.gimbalAlertEncoder(
            gimbalId: 0, errorBitField: 0))
        assertThat(gimbal!.currentErrors, empty())
        assertThat(changeCnt, `is`(3))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.gimbalAlertEncoder(
            gimbalId: 0, errorBitField: Bitfield<ArsdkFeatureGimbalError>.of(.calibrationError, .overloadError)))
        assertThat(gimbal!.currentErrors, containsInAnyOrder(.calibration, .overload))
        assertThat(changeCnt, `is`(4))

        // disconnect
        disconnect(drone: drone, handle: 1)

        // check that supported axes have been kept
        assertThat(gimbal!.currentErrors, empty())
        assertThat(changeCnt, `is`(5))
    }

    func testStabilization() {
        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.yaw, .pitch)
            // mock reception of bounds
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalRelativeAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: 2, maxYaw: 10, minPitch: 3, maxPitch: 10, minRoll: 4, maxRoll: 10))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAbsoluteAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: -100, maxYaw: 100, minPitch: -100, maxPitch: 100, minRoll: -100, maxRoll: 100))
        }

        // Check initial value
        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(gimbal!.stabilizationSettings, empty())
        assertThat(changeCnt, `is`(1))

        // mock stabilization info
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0, yawFrameOfReference: .absolute, pitchFrameOfReference: .relative,
                rollFrameOfReference: .absolute, yawRelative: -10, pitchRelative: 5, rollRelative: 30,
                yawAbsolute: 20, pitchAbsolute: 80, rollAbsolute: 200))

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(2))

        // change stab on the yaw axis
        gimbal!.stabilizationSettings[.yaw]!.value = false
        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpdating())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        // check in the gimbal non-ack command encoder that the stab has been set
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .relative, yaw: 2,
            pitchFrameOfReference: .none, pitch: 0,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
        assertThat(changeCnt, `is`(3))

        // mock stabilization info has not applied stabilization change yet. stabilized axes should not change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0, yawFrameOfReference: .absolute, pitchFrameOfReference: .relative,
                rollFrameOfReference: .absolute, yawRelative: -10, pitchRelative: 5, rollRelative: 30,
                yawAbsolute: 20, pitchAbsolute: 80, rollAbsolute: 200))

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpdating())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(3))

        // mock stabilization info
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0, yawFrameOfReference: .relative, pitchFrameOfReference: .relative,
                rollFrameOfReference: .absolute, yawRelative: -10, pitchRelative: 5, rollRelative: 30,
                yawAbsolute: 20, pitchAbsolute: 80, rollAbsolute: 200))

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(4))

        // assert that a stab change that has not been requested by the component does notify the component
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0, yawFrameOfReference: .relative, pitchFrameOfReference: .absolute,
                rollFrameOfReference: .absolute, yawRelative: -10, pitchRelative: 5, rollRelative: 30,
                yawAbsolute: 20, pitchAbsolute: 80, rollAbsolute: 200))

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(5))
        // should send an empty command
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .none, pitch: 0,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // change stab on the yaw axis
        gimbal!.stabilizationSettings[.yaw]!.value = true
        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(true), isUpdating())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        // check in the gimbal non-ack command encoder that the stab has been set
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .absolute, yaw: 20,
            pitchFrameOfReference: .none, pitch: 0,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
        assertThat(changeCnt, `is`(6))

        // mock stabilization info
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0, yawFrameOfReference: .absolute, pitchFrameOfReference: .absolute,
                rollFrameOfReference: .absolute, yawRelative: -10, pitchRelative: 5, rollRelative: 30,
                yawAbsolute: 20, pitchAbsolute: 80, rollAbsolute: 200))

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(7))

        // disconnect
        disconnect(drone: drone, handle: 1)

        // check that stabilized axes have been kept
        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(8)) // + 1 because attitude has been reset.

        // change stab offline
        gimbal!.stabilizationSettings[.yaw]!.value = false
        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(9))

        // restart engine
        resetArsdkEngine()
        changeCnt = 0

        // reconnect
        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.yaw, .pitch)
            // mock reception of stabilization infos
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                    gimbalId: 0, yawFrameOfReference: .absolute, pitchFrameOfReference: .absolute,
                    rollFrameOfReference: .none, yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                    yawAbsolute: 4, pitchAbsolute: 5, rollAbsolute: 6))
            // mock reception of bounds
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAbsoluteAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: -100, maxYaw: 100, minPitch: -100, maxPitch: 100, minRoll: -100, maxRoll: 100))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalRelativeAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: -10, maxYaw: 10, minPitch: -10, maxPitch: 10, minRoll: -10, maxRoll: 10))
        }

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpToDate())))
        //assertThat(gimbal!.currentAttitude[.yaw], presentAnd(`is`(1))) TODO fix this test
        assertThat(gimbal!.attitudeBounds[.yaw], presentAnd(`is`(-10..<10)))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.currentAttitude[.pitch], presentAnd(`is`(5)))
        assertThat(gimbal!.attitudeBounds[.pitch], presentAnd(`is`(-100..<100)))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(4))  // + 1 for the supported axes, +1 for absolute bounds, +1 for relative bounds

        // The control command should reflect what the user wants
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .relative, yaw: 1,
            pitchFrameOfReference: .none, pitch: 0,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0, yawFrameOfReference: .relative, pitchFrameOfReference: .absolute,
                rollFrameOfReference: .none, yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 4, pitchAbsolute: 5, rollAbsolute: 6))

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.currentAttitude[.yaw], presentAnd(`is`(1)))
        assertThat(gimbal!.attitudeBounds[.yaw], presentAnd(`is`(-10..<10)))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.currentAttitude[.pitch], presentAnd(`is`(5)))
        assertThat(gimbal!.attitudeBounds[.pitch], presentAnd(`is`(-100..<100)))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(5))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .none, pitch: 0,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // mock unexpected stab change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0, yawFrameOfReference: .relative, pitchFrameOfReference: .relative,
                rollFrameOfReference: .absolute, yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 4, pitchAbsolute: 5, rollAbsolute: 6))

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(6))
    }

    func testMaxSpeed() {
        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.yaw, .pitch)
        }

        // Check initial value
        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(gimbal!.maxSpeedSettings, empty())
        assertThat(changeCnt, `is`(1))

        // mock current max speed received
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalMaxSpeedEncoder(
                gimbalId: 0,
                minBoundYaw: -1, maxBoundYaw: 1, currentYaw: 0,
                minBoundPitch: -2, maxBoundPitch: 2, currentPitch: 1,
                minBoundRoll: -3, maxBoundRoll: 3, currentRoll: 3))

        assertThat(gimbal!.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(-1, 0, 1), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(-2, 1, 2), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(2))

        // change max speed on the yaw axis
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetMaxSpeed(gimbalId: 0, yaw: 1, pitch: 1, roll: 0))
        gimbal?.maxSpeedSettings[.yaw]?.value = 1
        assertThat(gimbal!.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(-1, 1, 1), isUpdating())))
        assertThat(gimbal!.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(-2, 1, 2), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(3))

        // mock current max speed received
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalMaxSpeedEncoder(
                gimbalId: 0,
                minBoundYaw: -1, maxBoundYaw: 1, currentYaw: 0.5,
                minBoundPitch: -2, maxBoundPitch: 2, currentPitch: 1,
                minBoundRoll: -3, maxBoundRoll: 3, currentRoll: 3))

        assertThat(gimbal!.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(-1, 0.5, 1), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(-2, 1, 2), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(4))

        // assert that a max speed change that has not been requested by the component does notify the component
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalMaxSpeedEncoder(
                gimbalId: 0,
                minBoundYaw: -1, maxBoundYaw: 1, currentYaw: -1,
                minBoundPitch: -2, maxBoundPitch: 2, currentPitch: 1,
                minBoundRoll: -3, maxBoundRoll: 3, currentRoll: 3))

        assertThat(gimbal!.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(-1, -1, 1), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(-2, 1, 2), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(5))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(6)) // +1 currentAttitude is put to nil

        // check that max speeds have been kept
        assertThat(gimbal!.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(-1, -1, 1), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(-2, 1, 2), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(6))

        // change max speed offline
        gimbal?.maxSpeedSettings[.yaw]?.value = -0.5
        assertThat(gimbal!.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(-1, -0.5, 1), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(-2, 1, 2), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(7))

        // restart engine
        resetArsdkEngine()
        changeCnt = 0

        // reconnect
        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.yaw, .pitch)
        }

        assertThat(gimbal!.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(-1, -0.5, 1), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(-2, 1, 2), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.roll], nilValue())
        assertThat(changeCnt, `is`(1))
    }

    func testAttitudeBounds() {
        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.yaw, .pitch)
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                    gimbalId: 0,
                    yawFrameOfReference: .absolute, pitchFrameOfReference: .relative, rollFrameOfReference: .absolute,
                    yawRelative: 0, pitchRelative: 0, rollRelative: 0,
                    yawAbsolute: 0, pitchAbsolute: 0, rollAbsolute: 0))
        }

        // Check initial value
        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(gimbal!.attitudeBounds[.yaw], nilValue())
        assertThat(gimbal!.attitudeBounds[.pitch], nilValue())
        assertThat(gimbal!.attitudeBounds[.roll], nilValue())
        assertThat(changeCnt, `is`(1))

        // mock relative attitude bounds change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalRelativeAttitudeBoundsEncoder(
                gimbalId: 0,
                minYaw: 0, maxYaw: 180,
                minPitch: 0, maxPitch: 90,
                minRoll: -180, maxRoll: 180))

        assertThat(gimbal!.attitudeBounds[.yaw], nilValue())
        assertThat(gimbal!.attitudeBounds[.pitch], presentAnd(`is`(0..<90)))
        assertThat(gimbal!.attitudeBounds[.roll], nilValue())
        assertThat(changeCnt, `is`(2))

        // mock absolute attitude bounds change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAbsoluteAttitudeBoundsEncoder(
                gimbalId: 0,
                minYaw: 0, maxYaw: 360,
                minPitch: 20, maxPitch: 45,
                minRoll: -90, maxRoll: 90))

        assertThat(gimbal!.attitudeBounds[.yaw], presentAnd(`is`(0..<360)))
        assertThat(gimbal!.attitudeBounds[.pitch], presentAnd(`is`(0..<90)))
        assertThat(gimbal!.attitudeBounds[.roll], nilValue())
        assertThat(changeCnt, `is`(3))

        // check that changing the stabilization automatically changes the bounds
        gimbal?.stabilizationSettings[.yaw]?.value = false
        assertThat(gimbal!.attitudeBounds[.yaw], presentAnd(`is`(0..<180)))
        assertThat(gimbal!.attitudeBounds[.pitch], presentAnd(`is`(0..<90)))
        assertThat(gimbal!.attitudeBounds[.roll], nilValue())
        assertThat(changeCnt, `is`(4))

        // check that changing the stabilization automatically changes the bounds
        gimbal?.stabilizationSettings[.pitch]?.value = true
        assertThat(gimbal!.attitudeBounds[.yaw], presentAnd(`is`(0..<180)))
        assertThat(gimbal!.attitudeBounds[.pitch], presentAnd(`is`(20..<45)))
        assertThat(gimbal!.attitudeBounds[.roll], nilValue())
        assertThat(changeCnt, `is`(5))

        // check that bounds are nil when disconnected
        disconnect(drone: drone, handle: 1)

        assertThat(gimbal!.attitudeBounds[.yaw], nilValue())
        assertThat(gimbal!.attitudeBounds[.pitch], nilValue())
        assertThat(gimbal!.attitudeBounds[.roll], nilValue())
        assertThat(changeCnt, `is`(6))
    }

    func testLockedAxes() {
        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.yaw, .pitch)
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAxisLockStateEncoder(
                    gimbalId: 0, lockedBitField: Bitfield<ArsdkFeatureGimbalAxis>.of(.pitch)))
        }

        // Check initial value
        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(gimbal!.lockedAxes, containsInAnyOrder(.pitch))
        assertThat(changeCnt, `is`(1))

        // mock relative attitude bounds change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAxisLockStateEncoder(
                gimbalId: 0, lockedBitField: Bitfield<ArsdkFeatureGimbalAxis>.of(.yaw)))

        assertThat(gimbal!.lockedAxes, containsInAnyOrder(.yaw))
        assertThat(changeCnt, `is`(2))

        // mock relative attitude bounds change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAxisLockStateEncoder(
                gimbalId: 0, lockedBitField: Bitfield<ArsdkFeatureGimbalAxis>.of(.yaw, .roll)))

        assertThat(gimbal!.lockedAxes, containsInAnyOrder(.yaw))
        assertThat(changeCnt, `is`(2))

        // mock relative attitude bounds change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAxisLockStateEncoder(
                gimbalId: 0, lockedBitField: Bitfield<ArsdkFeatureGimbalAxis>.of(.pitch)))

        assertThat(gimbal!.lockedAxes, containsInAnyOrder(.pitch))
        assertThat(changeCnt, `is`(3))

        // check that all supported axes are locked when disconnected
        disconnect(drone: drone, handle: 1)

        assertThat(gimbal!.lockedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(changeCnt, `is`(4))
    }

    func testCurrentAttitude() {
        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.yaw, .pitch)
        }

        // Check initial value
        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(gimbal!.currentAttitude, empty())
        assertThat(changeCnt, `is`(1))

        // mock attitude info
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0,
                yawFrameOfReference: .absolute, pitchFrameOfReference: .relative, rollFrameOfReference: .absolute,
                yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 10, pitchAbsolute: 20, rollAbsolute: 30))

        assertThat(gimbal!.currentAttitude[.yaw], presentAnd(`is`(10)))
        assertThat(gimbal!.currentAttitude[.pitch], presentAnd(`is`(2)))
        assertThat(gimbal!.currentAttitude[.roll], nilValue())
        assertThat(changeCnt, `is`(2))

        // if a stabilization change is asked, attitude should automatically match the asked frame of reference
        gimbal?.stabilizationSettings[.yaw]?.value = false

        assertThat(gimbal!.currentAttitude[.yaw], presentAnd(`is`(1)))
        assertThat(gimbal!.currentAttitude[.pitch], presentAnd(`is`(2)))
        assertThat(gimbal!.currentAttitude[.roll], nilValue())
        assertThat(changeCnt, `is`(3))

        // yaw attitude frame of reference should stay "relative" even if the change is not applied yet
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0,
                yawFrameOfReference: .absolute, pitchFrameOfReference: .relative, rollFrameOfReference: .absolute,
                yawRelative: 4, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 40, pitchAbsolute: 20, rollAbsolute: 30))

        assertThat(gimbal!.currentAttitude[.yaw], presentAnd(`is`(4)))
        assertThat(gimbal!.currentAttitude[.pitch], presentAnd(`is`(2)))
        assertThat(gimbal!.currentAttitude[.roll], nilValue())
        assertThat(changeCnt, `is`(4))

        // mock stab change applied
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0,
                yawFrameOfReference: .relative, pitchFrameOfReference: .relative, rollFrameOfReference: .absolute,
                yawRelative: 4, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 40, pitchAbsolute: 20, rollAbsolute: 30))

        assertThat(gimbal!.currentAttitude[.yaw], presentAnd(`is`(4)))
        assertThat(gimbal!.currentAttitude[.pitch], presentAnd(`is`(2)))
        assertThat(gimbal!.currentAttitude[.roll], nilValue())
        assertThat(changeCnt, `is`(5)) // +1 for the stabilization setting change

        // mock attitude change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0,
                yawFrameOfReference: .relative, pitchFrameOfReference: .relative, rollFrameOfReference: .absolute,
                yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 10, pitchAbsolute: 20, rollAbsolute: 30))

        assertThat(gimbal!.currentAttitude[.yaw], presentAnd(`is`(1)))
        assertThat(gimbal!.currentAttitude[.pitch], presentAnd(`is`(2)))
        assertThat(gimbal!.currentAttitude[.roll], nilValue())
        assertThat(changeCnt, `is`(6))

        // check that all attitudes are nil when disconnected
        disconnect(drone: drone, handle: 1)

        assertThat(gimbal!.currentAttitude, empty())
        assertThat(changeCnt, `is`(7))
    }

    func testControl() {
        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.yaw, .pitch)
            // mock reception of bounds
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAbsoluteAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: -100, maxYaw: 100, minPitch: -100, maxPitch: 100, minRoll: -100, maxRoll: 100))
        }

        // Check that, at the beginning, no setTarget command is sent
        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(gimbal!.stabilizationSettings, empty())
        assertNoExpectation()
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // check that receiving an attitude event does not send any setTarget command
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0,
                yawFrameOfReference: .relative, pitchFrameOfReference: .absolute, rollFrameOfReference: .absolute,
                yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 10, pitchAbsolute: 20, rollAbsolute: 30))

        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(`is`(false)))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(`is`(true)))
        assertNoExpectation()
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        gimbal?.control(mode: .velocity, yaw: nil, pitch: 1.0, roll: nil)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .velocity,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .absolute, pitch: 1.0,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // check that setting the stabilization does send the setTarget command with updated attitude according to the
        // frame of reference
        gimbal?.stabilizationSettings[.yaw]?.value = true

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(`is`(true)))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(`is`(true)))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .velocity,
            yawFrameOfReference: .absolute, yaw: 0,
            pitchFrameOfReference: .absolute, pitch: 1.0,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // control the gimbal
        gimbal?.control(mode: .position, yaw: nil, pitch: 15, roll: nil)

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(`is`(true)))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(`is`(true)))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .absolute, pitch: 15,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        gimbal?.control(mode: .position, yaw: 10, pitch: 15, roll: nil)

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(`is`(true)))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(`is`(true)))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .absolute, yaw: 10,
            pitchFrameOfReference: .absolute, pitch: 15,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // check that receiving an unrequested stabilization change while sending a control in velocity continue to send
        // the velocity in the correct frame of reference
        gimbal?.control(mode: .velocity, yaw: nil, pitch: 15, roll: nil)

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(`is`(true)))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(`is`(true)))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .velocity,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .absolute, pitch: 15,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // mock stabilization changed, on yaw drone has applied what we wanted, on pitch it has changed stab without
        // having requested this change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0,
                yawFrameOfReference: .absolute, pitchFrameOfReference: .relative, rollFrameOfReference: .absolute,
                yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 10, pitchAbsolute: 20, rollAbsolute: 30))

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(`is`(false)))
        // yaw is sent because we received a change on the stabilized axes and because we are controlling in velocity
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .velocity,
            yawFrameOfReference: .absolute, yaw: 0,
            pitchFrameOfReference: .relative, pitch: 15,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // check that receiving an unrequested stabilization change while sending a control in position sends none
        gimbal?.control(mode: .position, yaw: nil, pitch: 1, roll: nil)

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(`is`(true)))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(`is`(false)))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .relative, pitch: 1,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // mock stabilization changed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0,
                yawFrameOfReference: .absolute, pitchFrameOfReference: .absolute, rollFrameOfReference: .absolute,
                yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 10, pitchAbsolute: 20, rollAbsolute: 30))

        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(`is`(true)))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(`is`(true)))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .none, pitch: 0,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
    }

    func testControlSendingTimes() {
        let maxRepeatedSent = 10 // should be the same as GimbalControlCommandEncoder.maxRepeatedSent

        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.yaw, .pitch)
        }

        // Check that, at the beginning, no setTarget command is sent
        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(gimbal!.stabilizationSettings, empty())
        assertNoExpectation()
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0,
                yawFrameOfReference: .relative, pitchFrameOfReference: .absolute, rollFrameOfReference: .absolute,
                yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 10, pitchAbsolute: 20, rollAbsolute: 30))

        assertThat(gimbal!.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(gimbal!.stabilizationSettings[.yaw], presentAnd(`is`(false)))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(`is`(true)))
        assertNoExpectation()
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // control the gimbal
        gimbal?.control(mode: .position, yaw: nil, pitch: 15, roll: nil)

        for _ in 0..<maxRepeatedSent {
            expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
                gimbalId: 0, controlMode: .position,
                yawFrameOfReference: .none, yaw: 0,
                pitchFrameOfReference: .absolute, pitch: 15,
                rollFrameOfReference: .none, roll: 0))
            mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
        }
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // send the next command only twice, then change it
        gimbal?.control(mode: .position, yaw: 1, pitch: 15, roll: nil)

        for _ in 0..<2 {
            expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
                gimbalId: 0, controlMode: .position,
                yawFrameOfReference: .relative, yaw: 1,
                pitchFrameOfReference: .absolute, pitch: 15,
                rollFrameOfReference: .none, roll: 0))
            mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
        }

        gimbal?.control(mode: .position, yaw: 2, pitch: 15, roll: nil)
        for _ in 0..<maxRepeatedSent {
            expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
                gimbalId: 0, controlMode: .position,
                yawFrameOfReference: .relative, yaw: 2,
                pitchFrameOfReference: .absolute, pitch: 15,
                rollFrameOfReference: .none, roll: 0))
            mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
        }
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // check that command is sent forever (=> maxRepeatedSent + 1)
        // if at least one axis target is not 0 when controlling in velocity
        gimbal?.control(mode: .velocity, yaw: 1, pitch: nil, roll: nil)
        for _ in 0..<maxRepeatedSent+1 {
            expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
                gimbalId: 0, controlMode: .velocity,
                yawFrameOfReference: .relative, yaw: 1,
                pitchFrameOfReference: .none, pitch: 0,
                rollFrameOfReference: .none, roll: 0))
            mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
        }

        // however, if all values are nil or zero, it should be sent 10 times
        gimbal?.control(mode: .velocity, yaw: 0, pitch: nil, roll: nil)
        for _ in 0..<maxRepeatedSent {
            expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
                gimbalId: 0, controlMode: .velocity,
                yawFrameOfReference: .relative, yaw: 0,
                pitchFrameOfReference: .none, pitch: 0,
                rollFrameOfReference: .none, roll: 0))
            mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
        }
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        gimbal?.control(mode: .velocity, yaw: nil, pitch: nil, roll: nil)
        for _ in 0..<maxRepeatedSent {
            expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
                gimbalId: 0, controlMode: .velocity,
                yawFrameOfReference: .none, yaw: 0,
                pitchFrameOfReference: .none, pitch: 0,
                rollFrameOfReference: .none, roll: 0))
            mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
        }
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
    }

    func testControlWhenAttitudeReceivedBeforeCapabilities() {
        connect(drone: drone, handle: 1) {
            // mock stabilization info
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                    gimbalId: 0, yawFrameOfReference: .absolute, pitchFrameOfReference: .absolute,
                    rollFrameOfReference: .absolute, yawRelative: -10, pitchRelative: 5, rollRelative: 30,
                    yawAbsolute: 20, pitchAbsolute: 80, rollAbsolute: 200))

            self.mockSupportedAxes(.roll, .pitch)
            // mock reception of bounds
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalRelativeAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: 2, maxYaw: 10, minPitch: 3, maxPitch: 10, minRoll: 4, maxRoll: 10))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAbsoluteAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: -100, maxYaw: 100, minPitch: -100, maxPitch: 100, minRoll: -100, maxRoll: 100))
        }

        // Should not send anything since attitude has not been received from the drone and values have not been set
        // by gsdk/user
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // Should not send anything since attitude has not been received from the drone
        gimbal?.control(mode: .velocity, yaw: nil, pitch: 1.0, roll: nil)
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0, yawFrameOfReference: .absolute, pitchFrameOfReference: .absolute,
                rollFrameOfReference: .absolute, yawRelative: -10, pitchRelative: 5, rollRelative: 30,
                yawAbsolute: 20, pitchAbsolute: 80, rollAbsolute: 200))

        gimbal?.control(mode: .velocity, yaw: nil, pitch: 1.0, roll: nil)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .velocity,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .absolute, pitch: 1.0,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        disconnect(drone: drone, handle: 1)

        connect(drone: drone, handle: 1) {
            // mock stabilization info
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                    gimbalId: 0, yawFrameOfReference: .absolute, pitchFrameOfReference: .absolute,
                    rollFrameOfReference: .relative, yawRelative: -10, pitchRelative: 5, rollRelative: 30,
                    yawAbsolute: 20, pitchAbsolute: 80, rollAbsolute: 200))

            self.mockSupportedAxes(.roll, .pitch)
            // mock reception of bounds
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalRelativeAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: 2, maxYaw: 10, minPitch: 3, maxPitch: 10, minRoll: 4, maxRoll: 10))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAbsoluteAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: -100, maxYaw: 100, minPitch: -100, maxPitch: 100, minRoll: -100, maxRoll: 100))
        }

        // Should not send anything since attitude has not been received from the drone
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0, yawFrameOfReference: .absolute, pitchFrameOfReference: .absolute,
                rollFrameOfReference: .relative, yawRelative: -10, pitchRelative: 5, rollRelative: 30,
                yawAbsolute: 20, pitchAbsolute: 80, rollAbsolute: 200))
        // no cmd should be sent
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        // changing the control mode
        gimbal?.control(mode: .position, yaw: nil, pitch: nil, roll: 25)

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .none, pitch: 0,
            rollFrameOfReference: .relative, roll: 10)) // expected roll at 10 since upperBound for roll is 10
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        resetArsdkEngine()
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                    gimbalId: 0,
                    yawFrameOfReference: .absolute, pitchFrameOfReference: .absolute, rollFrameOfReference: .absolute,
                    yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                    yawAbsolute: 10, pitchAbsolute: 20, rollAbsolute: 30))

            self.mockSupportedAxes(.roll, .pitch)

            // mock reception of bounds
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalRelativeAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: 2, maxYaw: 10, minPitch: 3, maxPitch: 10, minRoll: 4, maxRoll: 10))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAbsoluteAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: -100, maxYaw: 100, minPitch: -100, maxPitch: 100, minRoll: -100, maxRoll: 100))
        }

        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0,
                yawFrameOfReference: .absolute, pitchFrameOfReference: .absolute, rollFrameOfReference: .absolute,
                yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 10, pitchAbsolute: 20, rollAbsolute: 30))

        gimbal?.control(mode: .velocity, yaw: nil, pitch: 1.0, roll: nil)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .velocity,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .absolute, pitch: 1.0,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
    }

    func testAxisValueWithAttitudeBounds() {
        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.roll, .pitch)

            // mock reception of bounds
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalRelativeAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: 2, maxYaw: 10, minPitch: 3, maxPitch: 10, minRoll: 4, maxRoll: 10))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAbsoluteAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: -100, maxYaw: 100, minPitch: -100, maxPitch: 100, minRoll: -100, maxRoll: 100))
        }
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0,
                yawFrameOfReference: .absolute, pitchFrameOfReference: .absolute, rollFrameOfReference: .absolute,
                yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                yawAbsolute: 10, pitchAbsolute: 20, rollAbsolute: 30))

        /// test lowerBound and upperBounds for relative attitude
        gimbal?.control(mode: .velocity, yaw: nil, pitch: 120, roll: nil)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .velocity,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .absolute, pitch: 100,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        gimbal?.control(mode: .position, yaw: nil, pitch: -110, roll: nil)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .absolute, pitch: -100,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                gimbalId: 0, yawFrameOfReference: .relative, pitchFrameOfReference: .relative,
                rollFrameOfReference: .absolute, yawRelative: -10, pitchRelative: 5, rollRelative: 30,
                yawAbsolute: 20, pitchAbsolute: 80, rollAbsolute: 200))

        gimbal?.control(mode: .position, yaw: nil, pitch: 2, roll: nil)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetTarget(
            gimbalId: 0, controlMode: .position,
            yawFrameOfReference: .none, yaw: 0,
            pitchFrameOfReference: .relative, pitch: 3,
            rollFrameOfReference: .none, roll: 0))
        mockNonAckLoop(handle: 1, noAckType: .gimbalControl)
    }

    func testCalibrationOffset() {
        connect(drone: drone, handle: 1)

        // Check initial value
        assertThat(gimbal!.offsetsCorrectionProcess, nilValue())
        assertThat(changeCnt, `is`(1))

        // Start correction process
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalStartOffsetsUpdate(gimbalId: 0))
        gimbal!.startOffsetsCorrectionProcess()

        assertThat(gimbal!.offsetsCorrectionProcess, nilValue())
        assertThat(changeCnt, `is`(1))

        // mock reception of offsets correction process started (only pitch should be correctable)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalOffsetsEncoder(
                gimbalId: 0, updateState: .active, minBoundYaw: 0, maxBoundYaw: 0, currentYaw: 0, minBoundPitch: -5,
                maxBoundPitch: 5, currentPitch: 1, minBoundRoll: 5, maxBoundRoll: 5, currentRoll: 0))

        assertThat(gimbal!.offsetsCorrectionProcess, present())
        assertThat(gimbal!.offsetsCorrectionProcess!.correctableAxes, contains(.pitch))
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.yaw], nilValue())
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(-5, 1, 5), isUpToDate())))
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(changeCnt, `is`(2))

        // change offset on the pitch axis (also check that it is clamped)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetOffsets(gimbalId: 0, yaw: 0, pitch: 5, roll: 0))
        gimbal?.offsetsCorrectionProcess?.offsetsCorrection[.pitch]?.value = 7
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.yaw], nilValue())
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(-5, 5, 5), isUpdating())))
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(changeCnt, `is`(3))

        // mock calibration offset received
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalOffsetsEncoder(
                gimbalId: 0, updateState: .active, minBoundYaw: -1, maxBoundYaw: 1, currentYaw: 0.5, minBoundPitch: -5,
                maxBoundPitch: 5, currentPitch: 5, minBoundRoll: 5, maxBoundRoll: 5, currentRoll: 0))

        assertThat(gimbal!.offsetsCorrectionProcess!.correctableAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(-1, 0.5, 1), isUpToDate())))
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(-5, 5, 5), isUpToDate())))
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(changeCnt, `is`(4))

        // assert that an offset change that has not been requested by the component does notify the component
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalOffsetsEncoder(
                gimbalId: 0, updateState: .active, minBoundYaw: -1, maxBoundYaw: 1, currentYaw: 1, minBoundPitch: 0,
                maxBoundPitch: 0, currentPitch: 0, minBoundRoll: 5, maxBoundRoll: 5, currentRoll: 0))

        assertThat(gimbal!.offsetsCorrectionProcess!.correctableAxes, containsInAnyOrder(.yaw))
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(-1, 1, 1), isUpToDate())))
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.pitch], nilValue())
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(changeCnt, `is`(5))

        // Mock reception of a process stopped without having asked
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalOffsetsEncoder(
                gimbalId: 0, updateState: .inactive, minBoundYaw: -1, maxBoundYaw: 1, currentYaw: 1, minBoundPitch: 0,
                maxBoundPitch: 0, currentPitch: 0, minBoundRoll: 5, maxBoundRoll: 5, currentRoll: 0))

        assertThat(gimbal!.offsetsCorrectionProcess, nilValue())
        assertThat(changeCnt, `is`(6))

        // Mock reception of a process started without having asked
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalOffsetsEncoder(
                gimbalId: 0, updateState: .active, minBoundYaw: -1, maxBoundYaw: 1, currentYaw: 1, minBoundPitch: 0,
                maxBoundPitch: 0, currentPitch: 0, minBoundRoll: 5, maxBoundRoll: 5, currentRoll: 0))

        assertThat(gimbal!.offsetsCorrectionProcess, present())
        assertThat(gimbal!.offsetsCorrectionProcess!.correctableAxes, containsInAnyOrder(.yaw))
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(-1, 1, 1), isUpToDate())))
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.pitch], nilValue())
        assertThat(gimbal!.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(changeCnt, `is`(7))

        // stop the process
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalStopOffsetsUpdate(gimbalId: 0))
        gimbal!.stopOffsetsCorrectionProcess()

        assertThat(gimbal!.offsetsCorrectionProcess, present())
        assertThat(changeCnt, `is`(7))

        // disconnect
        disconnect(drone: drone, handle: 1)

        // check that process is stopped
        assertThat(gimbal!.offsetsCorrectionProcess, nilValue())
        assertThat(changeCnt, `is`(8))
    }

    func testCalibration() {
        connect(drone: drone, handle: 1) {
            // mock calibration state
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalCalibrationStateEncoder(state: .ok, gimbalId: 0))
        }

        // Check initial values
        assertThat(gimbal!.calibrated, `is`(true))
        assertThat(gimbal!.calibrationProcessState, `is`(.none))
        assertThat(changeCnt, `is`(1))

        // mock reception of calibration state, need calibration
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalCalibrationStateEncoder(state: .required, gimbalId: 0))

        assertThat(gimbal!.calibrated, `is`(false))
        assertThat(gimbal!.calibrationProcessState, `is`(.none))
        assertThat(changeCnt, `is`(2))

        // start calibration
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalCalibrate(gimbalId: 0))
        gimbal!.startCalibration()

        assertThat(gimbal!.calibrated, `is`(false))
        assertThat(gimbal!.calibrationProcessState, `is`(.none))
        assertThat(changeCnt, `is`(2))

        // mock reception of calibration state, calibrating
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalCalibrationStateEncoder(state: .inProgress, gimbalId: 0))

        assertThat(gimbal!.calibrated, `is`(false))
        assertThat(gimbal!.calibrationProcessState, `is`(.calibrating))
        assertThat(changeCnt, `is`(3))

        // mock reception of calibration result, failure
        transiantStateTester = {
            assertThat(self.gimbal!.calibrated, `is`(false))
            assertThat(self.gimbal!.calibrationProcessState, `is`(.failure))
            assertThat(self.changeCnt, `is`(4))
        }
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalCalibrationResultEncoder(gimbalId: 0, result: .failure))

        assertThat(gimbal!.calibrated, `is`(false))
        assertThat(gimbal!.calibrationProcessState, `is`(.none))
        assertThat(changeCnt, `is`(5))

        // mock reception of calibration state, not calibrated, nothing should change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalCalibrationStateEncoder(state: .required, gimbalId: 0))

        assertThat(gimbal!.calibrated, `is`(false))
        assertThat(gimbal!.calibrationProcessState, `is`(.none))
        assertThat(changeCnt, `is`(5))

        // start calibration
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalCalibrate(gimbalId: 0))
        gimbal!.startCalibration()

        assertThat(gimbal!.calibrated, `is`(false))
        assertThat(gimbal!.calibrationProcessState, `is`(.none))
        assertThat(changeCnt, `is`(5))

        // mock reception of calibration state, calibrating
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalCalibrationStateEncoder(state: .inProgress, gimbalId: 0))

        assertThat(gimbal!.calibrated, `is`(false))
        assertThat(gimbal!.calibrationProcessState, `is`(.calibrating))
        assertThat(changeCnt, `is`(6))

        // mock reception of calibration state, calibrated
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalCalibrationStateEncoder(state: .ok, gimbalId: 0))

        assertThat(gimbal!.calibrated, `is`(true))
        assertThat(gimbal!.calibrationProcessState, `is`(.calibrating))
        assertThat(changeCnt, `is`(7))

        // mock reception of calibration result, success
        transiantStateTester = {
            assertThat(self.gimbal!.calibrated, `is`(true))
            assertThat(self.gimbal!.calibrationProcessState, `is`(.success))
            assertThat(self.changeCnt, `is`(8))
        }
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalCalibrationResultEncoder(gimbalId: 0, result: .success))

        assertThat(gimbal!.calibrated, `is`(true))
        assertThat(gimbal!.calibrationProcessState, `is`(.none))
        assertThat(changeCnt, `is`(9))

        // mock reception of calibration state, calibrating
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalCalibrationStateEncoder(state: .inProgress, gimbalId: 0))

        assertThat(gimbal!.calibrated, `is`(true))
        assertThat(gimbal!.calibrationProcessState, `is`(.calibrating))
        assertThat(changeCnt, `is`(10))

        // cancel calibration
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalCancelCalibration(gimbalId: 0))
        gimbal!.cancelCalibration()

        assertThat(gimbal!.calibrated, `is`(true))
        assertThat(gimbal!.calibrationProcessState, `is`(.calibrating))
        assertThat(changeCnt, `is`(10))

        // mock reception of calibration result, canceled
        transiantStateTester = {
            assertThat(self.gimbal!.calibrated, `is`(true))
            assertThat(self.gimbal!.calibrationProcessState, `is`(.canceled))
            assertThat(self.changeCnt, `is`(11))
        }
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalCalibrationResultEncoder(gimbalId: 0, result: .canceled))

        assertThat(gimbal!.calibrated, `is`(true))
        assertThat(gimbal!.calibrationProcessState, `is`(.none))
        assertThat(changeCnt, `is`(12))

        // mock reception of calibration state, not calibrated
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.gimbalCalibrationStateEncoder(state: .required, gimbalId: 0))

        assertThat(gimbal!.calibrated, `is`(false))
        assertThat(gimbal!.calibrationProcessState, `is`(.none))
        assertThat(changeCnt, `is`(13))
    }

    func testResetOnDisconnect() {
        connect(drone: drone, handle: 1) {
            self.mockSupportedAxes(.roll, .pitch)
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalMaxSpeedEncoder(
                    gimbalId: 0,
                    minBoundYaw: 0, maxBoundYaw: 1, currentYaw: 0,
                    minBoundPitch: 0, maxBoundPitch: 1, currentPitch: 0,
                    minBoundRoll: 0, maxBoundRoll: 1, currentRoll: 0))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAxisLockStateEncoder(
                    gimbalId: 0, lockedBitField: Bitfield<ArsdkFeatureGimbalAxis>.of(.pitch)))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalRelativeAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: 2, maxYaw: 10, minPitch: 3, maxPitch: 10, minRoll: 4, maxRoll: 10))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAbsoluteAttitudeBoundsEncoder(
                    gimbalId: 0, minYaw: -100, maxYaw: 100, minPitch: -100, maxPitch: 100, minRoll: -100, maxRoll: 100))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.gimbalAttitudeEncoder(
                    gimbalId: 0,
                    yawFrameOfReference: .absolute, pitchFrameOfReference: .relative, rollFrameOfReference: .relative,
                    yawRelative: 1, pitchRelative: 2, rollRelative: 3,
                    yawAbsolute: 10, pitchAbsolute: 20, rollAbsolute: 30))
        }

        assertThat(changeCnt, `is`(1))

        assertThat(gimbal!.lockedAxes, containsInAnyOrder(.pitch))
        assertThat(gimbal!.currentAttitude[.yaw], nilValue())
        assertThat(gimbal!.currentAttitude[.pitch], presentAnd(`is`(2.0)))
        assertThat(gimbal!.currentAttitude[.roll], presentAnd(`is`(3.0)))
        assertThat(gimbal!.attitudeBounds[.yaw], nilValue())
        assertThat(gimbal!.attitudeBounds[.pitch], presentAnd(`is`(3..<10)))
        assertThat(gimbal!.attitudeBounds[.roll], presentAnd(`is`(4..<10)))
        assertThat(gimbal!.offsetsCorrectionProcess, nilValue())

        assertThat(gimbal!.maxSpeedSettings[.yaw], nilValue())
        assertThat(gimbal!.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(0, 0, 1), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.roll], presentAnd(allOf(`is`(0, 0, 1), isUpToDate())))

        assertThat(gimbal!.stabilizationSettings[.yaw], nilValue())
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], presentAnd(allOf(`is`(false), isUpToDate())))

        // mock user modifies setting
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gimbalSetMaxSpeed(gimbalId: 0, yaw: 0, pitch: 1, roll: 0))
        gimbal?.maxSpeedSettings[.pitch]?.value = 1
        assertThat(changeCnt, `is`(2))
        assertThat(gimbal!.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(0, 1, 1), isUpdating())))

        gimbal!.stabilizationSettings[.pitch]!.value = true
        assertThat(changeCnt, `is`(3))
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpdating())))

        // disconnect
        disconnect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(4))
        // settings should be updated to user value
        assertThat(gimbal!.maxSpeedSettings[.yaw], nilValue())
        assertThat(gimbal!.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(0, 1, 1), isUpToDate())))
        assertThat(gimbal!.maxSpeedSettings[.roll], presentAnd(allOf(`is`(0, 0, 1), isUpToDate())))

        assertThat(gimbal!.stabilizationSettings[.yaw], nilValue())
        assertThat(gimbal!.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal!.stabilizationSettings[.roll], presentAnd(allOf(`is`(false), isUpToDate())))

        // test other values are reset as they should
        assertThat(gimbal!.lockedAxes, containsInAnyOrder(.pitch, .roll))
        assertThat(gimbal!.currentAttitude[.yaw], nilValue())
        assertThat(gimbal!.currentAttitude[.pitch], nilValue())
        assertThat(gimbal!.currentAttitude[.roll], nilValue())
        assertThat(gimbal!.attitudeBounds[.yaw], nilValue())
        assertThat(gimbal!.attitudeBounds[.pitch], nilValue())
        assertThat(gimbal!.attitudeBounds[.roll], nilValue())
        assertThat(gimbal!.offsetsCorrectionProcess, nilValue())
    }
}
