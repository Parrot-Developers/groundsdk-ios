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

class AnafiCopterMotorsTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var copterMotors: CopterMotors?
    var copterMotorsRef: Ref<CopterMotors>?
    var changeCnt = 0
    var updateChangeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        copterMotorsRef = drone.getPeripheral(Peripherals.copterMotors) { [unowned self] copterMotors in
            self.copterMotors = copterMotors
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(copterMotors, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(copterMotors, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(copterMotors, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testMotorBitfieldTranslation() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(copterMotors!.motorsCurrentlyInError, empty())
        assertThat(changeCnt, `is`(1))

        // check motor bitfield translation for current error callback
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errormotorstalled))
        assertThat(copterMotors!.motorsCurrentlyInError, containsInAnyOrder(.frontLeft))
        assertThat(changeCnt, `is`(2))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 2, motorerror: .errormotorstalled))
        assertThat(copterMotors!.motorsCurrentlyInError, containsInAnyOrder(.frontLeft, .frontRight))
        assertThat(changeCnt, `is`(3))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 4, motorerror: .errormotorstalled))
        assertThat(copterMotors!.motorsCurrentlyInError, containsInAnyOrder(.frontLeft, .frontRight, .rearRight))
        assertThat(changeCnt, `is`(4))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 8, motorerror: .errormotorstalled))
        assertThat(copterMotors!.motorsCurrentlyInError,
                   containsInAnyOrder(.frontLeft, .frontRight, .rearLeft, .rearRight))
        assertThat(changeCnt, `is`(5))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(motorids: 15, motorerror: .noerror))
        assertThat(copterMotors!.motorsCurrentlyInError, empty())
        assertThat(changeCnt, `is`(6))
    }

    func testMotorErrorTranslation() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(copterMotors!, motorsHaveNoErrors([.frontLeft, .frontRight, .rearLeft, .rearRight]))
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .erroreeprom))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .other]))
        assertThat(changeCnt, `is`(2))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errormotorstalled))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .stalled]))
        assertThat(changeCnt, `is`(3))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errorcommlost))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .other]))
        assertThat(changeCnt, `is`(4))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errorrcemergencystop))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .emergencyStop]))
        assertThat(changeCnt, `is`(5))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errorrealtime))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .other]))
        assertThat(changeCnt, `is`(6))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errorpropellersecurity))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .securityMode]))
        assertThat(changeCnt, `is`(7))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errortemperature))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .temperature]))
        assertThat(changeCnt, `is`(8))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errormotorstalled))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .stalled]))
        assertThat(changeCnt, `is`(9))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errorbatteryvoltage))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .batteryVoltage]))
        assertThat(changeCnt, `is`(10))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errormotorstalled))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .stalled]))
        assertThat(changeCnt, `is`(11))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errorlipocells))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .lipocells]))
        assertThat(changeCnt, `is`(12))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errormotorstalled))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .stalled]))
        assertThat(changeCnt, `is`(13))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errorbootloader))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .other]))
        assertThat(changeCnt, `is`(14))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errormotorstalled))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .stalled]))
        assertThat(changeCnt, `is`(15))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errorassert))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .other]))
        assertThat(changeCnt, `is`(16))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(motorids: 1, motorerror: .noerror))
        assertThat(copterMotors!, motorsHaveNoErrors([.frontLeft]))
        assertThat(changeCnt, `is`(17))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(motorids: 1,
                                                                                   motorerror: .errormosfet))
        assertThat(copterMotors!, hasCurrentMotorErrors([.frontLeft: .mosfet]))
        assertThat(changeCnt, `is`(18))
    }

    func testLastMotorError() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(copterMotors!, motorsHaveNoErrors([.frontLeft, .frontRight, .rearLeft, .rearRight]))
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .erroreeprom))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.other))
        }
        assertThat(changeCnt, `is`(2))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errormotorstalled))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.stalled))
        }
        assertThat(changeCnt, `is`(3))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errorcommlost))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.other))
        }
        assertThat(changeCnt, `is`(4))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(
                motorerror: .errorrcemergencystop))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.emergencyStop))
        }
        assertThat(changeCnt, `is`(5))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errorrealtime))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.other))
        }
        assertThat(changeCnt, `is`(6))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(
                motorerror: .errorpropellersecurity))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.securityMode))
        }
        assertThat(changeCnt, `is`(7))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errortemperature))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.temperature))
        }
        assertThat(changeCnt, `is`(8))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errormotorstalled))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.stalled))
        }
        assertThat(changeCnt, `is`(9))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(
                motorerror: .errorbatteryvoltage))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.batteryVoltage))
        }
        assertThat(changeCnt, `is`(10))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errormotorstalled))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.stalled))
        }
        assertThat(changeCnt, `is`(11))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errorlipocells))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.lipocells))
        }
        assertThat(changeCnt, `is`(12))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errormotorstalled))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.stalled))
        }
        assertThat(changeCnt, `is`(13))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errorbootloader))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.other))
        }
        assertThat(changeCnt, `is`(14))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errormotorstalled))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.stalled))
        }
        assertThat(changeCnt, `is`(15))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errorassert))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.other))
        }
        assertThat(changeCnt, `is`(16))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .noerror))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.noError))
        }
        assertThat(changeCnt, `is`(17))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorlasterrorchangedEncoder(motorerror: .errormosfet))
        for motor in CopterMotor.allCases {
            assertThat(copterMotors!.latestError(onMotor: motor), `is`(.mosfet))
        }
        assertThat(changeCnt, `is`(18))
    }
}
