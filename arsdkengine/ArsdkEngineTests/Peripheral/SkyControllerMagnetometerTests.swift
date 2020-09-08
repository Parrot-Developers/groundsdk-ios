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

class SkyControllerMagnetometerTests: ArsdkEngineTestBase {

    var remoteControl: RemoteControlCore!
    var magnetometer: MagnetometerWith1StepCalibration?
    var magnetometerRef: Ref<MagnetometerWith1StepCalibration>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice(
            "123", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .net, name: "Rc1", handle: 1)
        remoteControl = rcStore.getDevice(uid: "123")!

        magnetometerRef =
            remoteControl.getPeripheral(Peripherals.magnetometerWith1StepCalibration) { [unowned self] magneto in
                self.magnetometer = magneto
                self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(magnetometer, `is`(nilValue()))

        connect(remoteControl: remoteControl, handle: 1)
        assertThat(magnetometer, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(magnetometer, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testCalibrationState() {
        connect(remoteControl: remoteControl, handle: 1)
        // check default values
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlCalibrationstateMagnetocalibrationstateEncoder(
                status: .calibrated, xQuality: 0, yQuality: 0, zQuality: 0))
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.calibrated))
        assertThat(magnetometer!.calibrationProcessState, nilValue())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlCalibrationstateMagnetocalibrationstateEncoder(
                status: .unreliable, xQuality: 0, yQuality: 0, zQuality: 0))
        assertThat(changeCnt, `is`(3))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlCalibrationstateMagnetocalibrationstateEncoder(
                status: .assessing, xQuality: 0, yQuality: 0, zQuality: 0))
        assertThat(changeCnt, `is`(3))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())
    }

    func testCalibrationProcess() {
        connect(remoteControl: remoteControl, handle: 1)
        assertThat(changeCnt, `is`(1))

        // start the calibration process
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.skyctrlCalibrationEnablemagnetocalibrationqualityupdates(enable: 1))
        magnetometer?.startCalibrationProcess()
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(
            rollProgress: 0, pitchProgress: 0, yawProgress: 0)))

        // starting it again should not send a new command
        magnetometer?.startCalibrationProcess()
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(
            rollProgress: 0, pitchProgress: 0, yawProgress: 0)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlCalibrationstateMagnetocalibrationstateEncoder(
                status: .assessing, xQuality: 128, yQuality: 0, zQuality: 0))
        assertThat(changeCnt, `is`(3))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(
            rollProgress: 50, pitchProgress: 0, yawProgress: 0)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlCalibrationstateMagnetocalibrationstateEncoder(
                status: .assessing, xQuality: 128, yQuality: 26, zQuality: 0))
        assertThat(changeCnt, `is`(4))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(
            rollProgress: 50, pitchProgress: 10, yawProgress: 0)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlCalibrationstateMagnetocalibrationstateEncoder(
                status: .assessing, xQuality: 255, yQuality: 255, zQuality: 255))
        assertThat(changeCnt, `is`(5))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(
            rollProgress: 100, pitchProgress: 100, yawProgress: 100)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlCalibrationstateMagnetocalibrationstateEncoder(
                status: .calibrated, xQuality: 255, yQuality: 255, zQuality: 255))
        assertThat(changeCnt, `is`(6))
        assertThat(magnetometer!.calibrationState, `is`(.calibrated))
        // calibrationProcessState is still here until we call cancelCalibrationProcess
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(
            rollProgress: 100, pitchProgress: 100, yawProgress: 100)))
    }

    func testCalibrationProcessCancel() {
        connect(remoteControl: remoteControl, handle: 1)
        assertThat(changeCnt, `is`(1))

        // start the calibration process
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.skyctrlCalibrationEnablemagnetocalibrationqualityupdates(enable: 1))
        magnetometer?.startCalibrationProcess()
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(
            rollProgress: 0, pitchProgress: 0, yawProgress: 0)))

        // cancel the calibration process
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.skyctrlCalibrationEnablemagnetocalibrationqualityupdates(enable: 0))
        magnetometer?.cancelCalibrationProcess()
        assertThat(changeCnt, `is`(3))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())

        // starting it again should not send a new command
        magnetometer?.cancelCalibrationProcess()
        assertThat(changeCnt, `is`(3))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())
    }
}
