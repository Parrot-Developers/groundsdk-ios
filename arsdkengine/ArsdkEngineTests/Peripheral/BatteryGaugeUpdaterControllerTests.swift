// Copyright (C) 2020 Parrot Drones SAS
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

class BatteryGaugeUpdaterControllerTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var batteryGaugeUpdater: BatteryGaugeUpdater?
    var ledsRef: Ref<BatteryGaugeUpdater>?
    var changeCnt = 0
    let emptyBitfield: UInt = (Bitfield<ArsdkFeatureGaugeFwUpdaterRequirements>.of())

    override func setUp() {
        super.setUp()
        setUpDrone()
        changeCnt = 0
    }

    func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        ledsRef =
            drone.getPeripheral(Peripherals.batteryGaugeUpdater) { [unowned self] batteryGaugeFirmwareUpdater in
                self.batteryGaugeUpdater = batteryGaugeFirmwareUpdater
                self.changeCnt += 1
        }
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpDrone()
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(batteryGaugeUpdater, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(batteryGaugeUpdater, `is`(nilValue()))
        assertThat(changeCnt, `is`(0))

        disconnect(drone: drone, handle: 1)

        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
                missingRequirementsBitField: self.emptyBitfield, state: .preparationInProgress))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(batteryGaugeUpdater, `is`(present()))

        disconnect(drone: drone, handle: 1)

        connect(drone: drone, handle: 1)
        assertThat(batteryGaugeUpdater, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
        disconnect(drone: drone, handle: 1)

        assertThat(batteryGaugeUpdater, `is`(nilValue()))
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .cannotUpdate,
                missingRequirementsBitField: self.emptyBitfield, state: .preparationInProgress))
        }
        assertThat(batteryGaugeUpdater, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testState() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
                missingRequirementsBitField: self.emptyBitfield, state: .readyToPrepare))
        }
        assertThat(batteryGaugeUpdater, `is`(present()))
        assertThat(changeCnt, `is`(1))

        assertThat(batteryGaugeUpdater?.state, `is`(.readyToPrepare))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gaugeFwUpdaterPrepare())
        assertThat(batteryGaugeUpdater?.prepareUpdate(), `is`(true))

        self.mockArsdkCore.onCommandReceived(1,
                    encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
                    missingRequirementsBitField: emptyBitfield, state: .preparationInProgress))
        assertThat(batteryGaugeUpdater?.state, `is`(.preparingUpdate))
        assertThat(changeCnt, `is`(2))

        self.mockArsdkCore.onCommandReceived(1,
                    encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
                    missingRequirementsBitField: emptyBitfield, state: .readyToUpdate))
        assertThat(batteryGaugeUpdater?.state, `is`(.readyToUpdate))
        assertThat(changeCnt, `is`(3))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gaugeFwUpdaterUpdate())
        assertThat(batteryGaugeUpdater?.update(), `is`(true))

        self.mockArsdkCore.onCommandReceived(1,
                    encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
                    missingRequirementsBitField: emptyBitfield, state: .updateInProgress))
        assertThat(batteryGaugeUpdater?.state, `is`(.updating))
        assertThat(changeCnt, `is`(4))

        self.mockArsdkCore.onCommandReceived(1,
                    encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .upToDate,
                    missingRequirementsBitField: emptyBitfield, state: .readyToPrepare))

    }

    func testProgress() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
                missingRequirementsBitField: self.emptyBitfield, state: .readyToPrepare))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(batteryGaugeUpdater?.currentProgress, `is`(0))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gaugeFwUpdaterPrepare())
        assertThat(batteryGaugeUpdater?.prepareUpdate(), `is`(true))
        self.mockArsdkCore.onCommandReceived(1,
                encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
                missingRequirementsBitField: emptyBitfield, state: .preparationInProgress))
        assertThat(batteryGaugeUpdater?.state, `is`(.preparingUpdate))
        assertThat(changeCnt, `is`(2))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.gaugeFwUpdaterProgressEncoder(result: .inProgress,
                                                                                                  percent: 1))

        assertThat(changeCnt, `is`(3))
        assertThat(batteryGaugeUpdater?.currentProgress, `is`(1))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.gaugeFwUpdaterProgressEncoder(result: .inProgress,
                                                                                                  percent: 50))

        assertThat(changeCnt, `is`(4))
        assertThat(batteryGaugeUpdater?.currentProgress, `is`(50))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.gaugeFwUpdaterProgressEncoder(result: .inProgress,
                                                                                                  percent: 50))

        assertThat(changeCnt, `is`(4))
        assertThat(batteryGaugeUpdater?.currentProgress, `is`(50))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.gaugeFwUpdaterProgressEncoder(result: .inProgress,
                                                                                                  percent: 100))

        assertThat(changeCnt, `is`(5))
        assertThat(batteryGaugeUpdater?.currentProgress, `is`(100))

        self.mockArsdkCore.onCommandReceived(1,
                encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
                missingRequirementsBitField: emptyBitfield, state: .readyToUpdate))
        assertThat(batteryGaugeUpdater?.state, `is`(.readyToUpdate))
        assertThat(changeCnt, `is`(6))
        assertThat(batteryGaugeUpdater?.currentProgress, `is`(0))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.gaugeFwUpdaterUpdate())
        _ = batteryGaugeUpdater?.update()
        self.mockArsdkCore.onCommandReceived(1,
                encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
                missingRequirementsBitField: emptyBitfield, state: .updateInProgress))
        assertThat(changeCnt, `is`(7))
        // drone will be disconnect while updating so there will be no progress.
        disconnect(drone: drone, handle: 1)

        assertThat(batteryGaugeUpdater, `is`(nilValue()))

    }

    func testUnavailabilityReasons() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
                missingRequirementsBitField: (Bitfield<ArsdkFeatureGaugeFwUpdaterRequirements>.of(.droneState)),
                state: .readyToPrepare))
        }
        assertThat(changeCnt, `is`(1))
        assertThat(batteryGaugeUpdater?.unavailabilityReasons, `is`([.droneNotLanded]))

        assertThat(batteryGaugeUpdater?.prepareUpdate(), `is`(false))
        assertThat(changeCnt, `is`(1))

        assertThat(batteryGaugeUpdater?.update(), `is`(false))
        assertThat(changeCnt, `is`(1))

        self.mockArsdkCore.onCommandReceived(1,
            encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
            missingRequirementsBitField: self.emptyBitfield,
            state: .readyToPrepare))
        assertThat(batteryGaugeUpdater?.unavailabilityReasons, `is`([]))
        assertThat(changeCnt, `is`(2))

        self.mockArsdkCore.onCommandReceived(1,
            encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
            missingRequirementsBitField: self.emptyBitfield,
            state: .readyToPrepare))
        assertThat(batteryGaugeUpdater?.unavailabilityReasons, `is`([]))
        assertThat(changeCnt, `is`(2))

        self.mockArsdkCore.onCommandReceived(1,
            encoder: CmdEncoder.gaugeFwUpdaterStatusEncoder(diag: .updatable,
            missingRequirementsBitField:
                (Bitfield<ArsdkFeatureGaugeFwUpdaterRequirements>.of(.droneState, .usb, .rsoc)),
            state: .readyToPrepare))
        assertThat(batteryGaugeUpdater?.unavailabilityReasons, `is`([.droneNotLanded,
            .notUsbPowered, .insufficientCharge]))
        assertThat(changeCnt, `is`(3))
    }
}
