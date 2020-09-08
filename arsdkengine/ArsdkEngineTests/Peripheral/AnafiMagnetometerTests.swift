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

class AnafiMagnetometerTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var magnetometer: MagnetometerWith3StepCalibration?
    var magnetometerRef: Ref<MagnetometerWith3StepCalibration>?
    var changeCnt = 0
    var latestFailed = false

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        magnetometerRef =
            drone.getPeripheral(Peripherals.magnetometerWith3StepCalibration) { [unowned self] magnetometer in
                if let calibrationProcessState = magnetometer?.calibrationProcessState {
                    self.latestFailed = calibrationProcessState.failed
                }
                self.magnetometer = magnetometer
                self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(magnetometer, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(magnetometer, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(magnetometer, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testCalibrationState() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationrequiredstateEncoder(required: 0))
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.calibrated))
        assertThat(magnetometer!.calibrationProcessState, nilValue())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationrequiredstateEncoder(required: 2))
        assertThat(changeCnt, `is`(3))
        assertThat(magnetometer!.calibrationState, `is`(.recommended))
        assertThat(magnetometer!.calibrationProcessState, nilValue())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationrequiredstateEncoder(required: 1))
        assertThat(changeCnt, `is`(4))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())

        // Receive same event
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationrequiredstateEncoder(required: 1))
        assertThat(changeCnt, `is`(4))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())
    }

    func testCalibrationProcess() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        // start the calibration process
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonCalibrationMagnetocalibration(calibrate: 1))
        magnetometer?.startCalibrationProcess()
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.none, [], false)))

        // starting it again should not send a new command
        magnetometer?.startCalibrationProcess()
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.none, [], false)))

        // receiving this command should not change anything
        // as the creation of the calibrationProcessState obj is done on startCalibrationProcess()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstartedchangedEncoder(started: 1))
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.none, [], false)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationaxistocalibratechangedEncoder(axis: .xaxis))
        assertThat(changeCnt, `is`(3))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.roll, [], false)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationaxistocalibratechangedEncoder(axis: .yaxis))
        assertThat(changeCnt, `is`(4))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.pitch, [], false)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstatechangedEncoder(
                xaxiscalibration: 1, yaxiscalibration: 0, zaxiscalibration: 0, calibrationfailed: 0))
        assertThat(changeCnt, `is`(5))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.pitch, [.roll], false)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationaxistocalibratechangedEncoder(axis: .zaxis))
        assertThat(changeCnt, `is`(6))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.yaw, [.roll], false)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstatechangedEncoder(
                xaxiscalibration: 1, yaxiscalibration: 1, zaxiscalibration: 0, calibrationfailed: 0))
        assertThat(changeCnt, `is`(7))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.yaw, [.roll, .pitch], false)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationaxistocalibratechangedEncoder(axis: .none))
        assertThat(changeCnt, `is`(8))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.none, [.roll, .pitch], false)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstatechangedEncoder(
                xaxiscalibration: 1, yaxiscalibration: 1, zaxiscalibration: 1, calibrationfailed: 0))
        assertThat(changeCnt, `is`(9))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.none, [.roll, .pitch, .yaw], false)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstartedchangedEncoder(started: 0))
        assertThat(changeCnt, `is`(10))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())
    }

    func testCalibrationProcessFailed() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        // start the calibration process
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonCalibrationMagnetocalibration(calibrate: 1))
        magnetometer?.startCalibrationProcess()
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.none, [], false)))
        assertThat(latestFailed, `is`(false))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstatechangedEncoder(
                xaxiscalibration: 1, yaxiscalibration: 0, zaxiscalibration: 1, calibrationfailed: 1))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstartedchangedEncoder(started: 0))
        assertThat(changeCnt, `is`(4)) // 2 calls : currentProcess.failed, then currentProcess is nil
        assertThat(latestFailed, `is`(true))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())
    }

    func testCalibrationProcessCancel() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        // start the calibration process
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonCalibrationMagnetocalibration(calibrate: 1))
        magnetometer?.startCalibrationProcess()
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.none, [], false)))

        // cancel the calibration process
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonCalibrationMagnetocalibration(calibrate: 0))
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

    func testCalibrationProcessAxesOkButFinallyFailed() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        // start the calibration process
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonCalibrationMagnetocalibration(calibrate: 1))
        magnetometer?.startCalibrationProcess()
        assertThat(changeCnt, `is`(2))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.none, [], false)))

        // receive all axes ok
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstatechangedEncoder(
                xaxiscalibration: 1, yaxiscalibration: 1, zaxiscalibration: 1, calibrationfailed: 0))
        assertThat(changeCnt, `is`(3))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.none, [.pitch, .yaw, .roll], false)))

        // current axe is yaw
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationaxistocalibratechangedEncoder(axis: .zaxis))
        assertThat(changeCnt, `is`(4))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.yaw, [.pitch, .yaw, .roll], false)))

        // current yaw not calibrated
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstatechangedEncoder(
                xaxiscalibration: 1, yaxiscalibration: 1, zaxiscalibration: 0, calibrationfailed: 0))
        assertThat(changeCnt, `is`(5))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.yaw, [.roll, .pitch], false)))

        // receive "all axes are ok"
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstatechangedEncoder(
                xaxiscalibration: 1, yaxiscalibration: 1, zaxiscalibration: 1, calibrationfailed: 0))
        assertThat(changeCnt, `is`(6))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.yaw, [.pitch, .yaw, .roll], false)))

        // the receive "all axes are ok" but calibrationfailed is true (all axes must be considered as uncalibrated)
        // The failure state will be indicated at the interface only when the calibration process stops. At this step
        // failed is still false
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstatechangedEncoder(
                xaxiscalibration: 1, yaxiscalibration: 1, zaxiscalibration: 1, calibrationfailed: 1))
        assertThat(changeCnt, `is`(7))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, presentAnd(`is`(.yaw, [], false)))
        assertThat(latestFailed, `is`(false))

        // the end of the calibration process is notified (with failed == true)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCalibrationstateMagnetocalibrationstartedchangedEncoder(started: 0))
        assertThat(changeCnt, `is`(9)) // 2 calls: failed, then nil
        assertThat(latestFailed, `is`(true))
        assertThat(magnetometer!.calibrationState, `is`(.required))
        assertThat(magnetometer!.calibrationProcessState, nilValue())
    }

}
