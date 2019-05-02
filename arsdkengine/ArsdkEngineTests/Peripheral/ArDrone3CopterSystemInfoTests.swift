// Copyright (C) 2016-2017 Parrot SA
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
//    * Neither the name of Parrot nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
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

class ArDrone3CopterSystemInfoTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var copterSystemInfo: CopterSystemInfo?
    var copterSystemInfoRef: Ref<CopterSystemInfo>?
    var changeCnt: Int = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: ArsdkDeviceType.bebop, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        copterSystemInfoRef = drone.getPeripheral(PeripheralDesc.copterSystemInfo) { [unowned self] copterSystemInfo in
            self.copterSystemInfo = copterSystemInfo
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    /// Tests the copter system info
    /// This function is huge because we test the matching between all messages enums and Api enums
    func testCopterSystemInfoValues() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        connect(drone: drone, handle: 1)
        // check default values
        assertThat(copterSystemInfo!, hasNoMotorError())
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(.errorcommlost))
        assertThat(changeCnt, `is`(2))
        assertThat(copterSystemInfo!, hasPastMotorError(.otherError, onMotors: CopterMotor.allValues))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                2,
                motorerror: .errorrcemergencystop))
        assertThat(changeCnt, `is`(3))
        assertThat(copterSystemInfo!, hasCurrentMotorError(.emergencyStop, onMotors: [.frontRight]))

        // receiving the current motor error to no error should set back the latest motor error
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                0,
                motorerror: .noerror))
        assertThat(changeCnt, `is`(4))
        assertThat(copterSystemInfo!, hasPastMotorError(.otherError, onMotors: CopterMotor.allValues))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                3,
                motorerror: .erroreeprom))
        assertThat(changeCnt, `is`(5))
        assertThat(copterSystemInfo!, hasCurrentMotorError(.otherError, onMotors: [.frontLeft, .frontRight]))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                4,
                motorerror: .errorpropellersecurity))
        assertThat(changeCnt, `is`(6))
        assertThat(copterSystemInfo!, hasCurrentMotorError(.securityMode, onMotors: [.backRight]))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                5,
                motorerror: .errorcommlost))
        assertThat(changeCnt, `is`(7))
        assertThat(copterSystemInfo!, hasCurrentMotorError(.otherError, onMotors: [.frontLeft, .backRight]))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                6,
                motorerror: .errorrealtime))
        assertThat(changeCnt, `is`(8))
        assertThat(copterSystemInfo!, hasCurrentMotorError(.otherError, onMotors: [.frontRight, .backRight]))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                7,
                motorerror: .errormotorsetting))
        assertThat(changeCnt, `is`(9))
        assertThat(copterSystemInfo!, hasCurrentMotorError(
            .otherError, onMotors: [.frontLeft, .frontRight, .backRight]))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                8,
                motorerror: .errortemperature))
        assertThat(changeCnt, `is`(10))
        assertThat(copterSystemInfo!, hasCurrentMotorError(.otherError, onMotors: [.backLeft]))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                9,
                motorerror: .errorbatteryvoltage))
        assertThat(changeCnt, `is`(11))
        assertThat(copterSystemInfo!, hasCurrentMotorError(.otherError, onMotors: [.frontLeft, .backLeft]))

        // check that receiving an error that don't change the api error will no call the listener
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                9,
                motorerror: .errorlipocells))
        assertThat(changeCnt, `is`(11))
        assertThat(copterSystemInfo!, hasCurrentMotorError(.otherError, onMotors: [.frontLeft, .backLeft]))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                9,
                motorerror: .noerror))
        assertThat(changeCnt, `is`(12))
        assertThat(copterSystemInfo!, hasPastMotorError(.otherError, onMotors: CopterMotor.allValues))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(.errormosfet))
        assertThat(changeCnt, `is`(12))
        assertThat(copterSystemInfo!, hasPastMotorError(.otherError, onMotors: CopterMotor.allValues))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(.errorbootloader))
        assertThat(changeCnt, `is`(12))
        assertThat(copterSystemInfo!, hasPastMotorError(.otherError, onMotors: CopterMotor.allValues))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(.errorassert))
        assertThat(changeCnt, `is`(12))
        assertThat(copterSystemInfo!, hasPastMotorError(.otherError, onMotors: CopterMotor.allValues))

    }
}
