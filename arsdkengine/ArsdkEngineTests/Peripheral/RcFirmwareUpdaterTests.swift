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

class RcFirmwareUpdaterTests: ArsdkEngineTestBase {

    var remoteControl: RemoteControlCore!
    var firmwareUpdater: Updater?
    var firmwareUpdaterRef: Ref<Updater>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("456", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "Rc1",
                                handle: 1)
        remoteControl = rcStore.getDevice(uid: "456")!

        firmwareUpdaterRef = remoteControl
            .getPeripheral(Peripherals.updater) { [unowned self] firmwareUpdater in
                self.firmwareUpdater = firmwareUpdater
                self.changeCnt += 1
        }

        changeCnt = 0
    }

    func testNotEnoughBatteryUnavailability() {
        // mock drone connected, with 40% of battery
        connect(remoteControl: remoteControl, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.skyctrlSkycontrollerstateBatterychangedEncoder(percent: 40))
        }

        // check initial value
        assertThat(firmwareUpdater!.updateUnavailabilityReasons, empty())
        assertThat(changeCnt, `is`(1))

        // mock battery goes low
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlSkycontrollerstateBatterychangedEncoder(percent: 39))

        assertThat(firmwareUpdater!.updateUnavailabilityReasons, contains(.notEnoughBattery))
        assertThat(changeCnt, `is`(2))

        // mock disconnection
        disconnect(remoteControl: remoteControl, handle: 1)

        assertThat(firmwareUpdater!.updateUnavailabilityReasons, contains(.notConnected))
        assertThat(changeCnt, `is`(3))

        connect(remoteControl: remoteControl, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.skyctrlSkycontrollerstateBatterychangedEncoder(percent: 39))
        }

        assertThat(firmwareUpdater!.updateUnavailabilityReasons, contains(.notEnoughBattery))
        assertThat(changeCnt, `is`(4))
    }
}
