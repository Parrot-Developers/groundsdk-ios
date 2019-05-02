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

class CommonRadioTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var radio: Radio?
    var radioRef: Ref<Radio>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        radioRef = drone.getInstrument(Instruments.radio) { [unowned self] radio in
            self.radio = radio
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(radio, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(radio, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(radio, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testRssi() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(radio!.rssi, `is`(0))
        assertThat(changeCnt, `is`(1))

        // check rssi
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiRssiChangedEncoder(rssi: -30))
        assertThat(radio!.rssi, `is`(-30))
        assertThat(changeCnt, `is`(2))
    }

    func testLinkSignalQuality() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(radio!.linkSignalQuality, nilValue())
        assertThat(radio!.isLinkPerturbed, `is`(false))
        assertThat(radio!.is4GInterfering, `is`(false))
        assertThat(changeCnt, `is`(1))

        // minimal link quality and signal not perturbed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCommonstateLinksignalqualityEncoder(value: 1))
        assertThat(radio!.linkSignalQuality, presentAnd(`is`(0)))
        assertThat(radio!.isLinkPerturbed, `is`(false))
        assertThat(radio!.is4GInterfering, `is`(false))
        assertThat(changeCnt, `is`(2))

        // maximal link quality and signal not perturbed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCommonstateLinksignalqualityEncoder(value: 5))
        assertThat(radio!.linkSignalQuality, presentAnd(`is`(4)))
        assertThat(radio!.isLinkPerturbed, `is`(false))
        assertThat(radio!.is4GInterfering, `is`(false))
        assertThat(changeCnt, `is`(3))

        // high link quality and signal perturbed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCommonstateLinksignalqualityEncoder(value: 4 | 1 << 7))
        assertThat(radio!.linkSignalQuality, presentAnd(`is`(3)))
        assertThat(radio!.isLinkPerturbed, `is`(true))
        assertThat(radio!.is4GInterfering, `is`(false))
        assertThat(changeCnt, `is`(4))

        // low link quality, signal perturbed and 4G interfering
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCommonstateLinksignalqualityEncoder(value: 2 | 1 << 7 | 1 << 6))
        assertThat(radio!.linkSignalQuality, presentAnd(`is`(1)))
        assertThat(radio!.isLinkPerturbed, `is`(true))
        assertThat(radio!.is4GInterfering, `is`(true))
        assertThat(changeCnt, `is`(5))

        // invalid link quality should not change anything
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCommonstateLinksignalqualityEncoder(value: 1 << 7 | 1 << 6))
        assertThat(radio!.linkSignalQuality, presentAnd(`is`(1)))
        assertThat(radio!.isLinkPerturbed, `is`(true))
        assertThat(radio!.is4GInterfering, `is`(true))
        assertThat(changeCnt, `is`(5))

        // change signal perturbed and 4G interfering with invalid link quality
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCommonstateLinksignalqualityEncoder(value: 0))
        assertThat(radio!.linkSignalQuality, presentAnd(`is`(1)))
        assertThat(radio!.isLinkPerturbed, `is`(false))
        assertThat(radio!.is4GInterfering, `is`(false))
        assertThat(changeCnt, `is`(6))
    }
}
