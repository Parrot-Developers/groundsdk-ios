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

import XCTest
@testable import GroundSdk
@testable import GroundSdkMock

/// Test device connector
class DeviceConnectorTests: XCTestCase {

    var connector1: DeviceConnector!
    var connector2: DeviceConnector!
    var connector3: DeviceConnector!
    var connector4: DeviceConnector!
    var connector5: DeviceConnector!
    var connector6: DeviceConnector!
    var connector7: DeviceConnector!

    override func setUp() {
        connector1 = LocalDeviceConnectorCore.wifi
        connector2 = LocalDeviceConnectorCore.wifi
        connector3 = LocalDeviceConnectorCore.ble
        connector4 = RemoteControlDeviceConnectorCore(uid: "2")
        connector5 = RemoteControlDeviceConnectorCore(uid: "2")
        connector6 = RemoteControlDeviceConnectorCore(uid: "3")
        connector7 = LocalDeviceConnectorCore.usb
    }

    func testEquality() {
        assertThat(connector1 == connector2, `is`(true))
        assertThat(connector1 != connector2, `is`(false))

        assertThat(connector2 == connector2, `is`(true))
        assertThat(connector2 != connector2, `is`(false))

        assertThat(connector1 == connector3, `is`(false))
        assertThat(connector1 != connector3, `is`(true))

        assertThat(connector1 == connector4, `is`(false))
        assertThat(connector1 != connector4, `is`(true))

        assertThat(connector4 == connector5, `is`(true))
        assertThat(connector4 != connector5, `is`(false))

        assertThat(connector4 == connector6, `is`(false))
        assertThat(connector4 != connector6, `is`(true))
    }

    func testBetterThan() {
        // Do not add connector6 because we don't sort RemoteControlConnectors.
        // This way, we can be sure of the order, and thus avoid using anyOf in the matcher, which is very time
        // consuming during compilation
        let unsortedConnectors: [DeviceConnector] = [connector1, connector2, connector3, connector4, connector5,
                                                     connector7]
        let sortedConnectors = unsortedConnectors.sorted { connector1, connector2 -> Bool in
            return connector1.betterThan(connector2)
        }
        let sortedConnectorsUid = sortedConnectors.map { $0.uid }

        assertThat(sortedConnectorsUid, contains(
            `is`("2"), `is`("2"),
            `is`(LocalDeviceConnectorCore.usb.uid),
            `is`(LocalDeviceConnectorCore.wifi.uid),
            `is`(LocalDeviceConnectorCore.wifi.uid),
            `is`(LocalDeviceConnectorCore.ble.uid)))
    }
}
