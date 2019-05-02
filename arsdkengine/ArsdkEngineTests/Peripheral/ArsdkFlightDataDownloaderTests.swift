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

class ArsdkFlightDataDownloaderTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var droneFlightDataDownloader: FlightDataDownloader?
    var droneFlightDataDownloaderRef: Ref<FlightDataDownloader>?
    var changeCnt = 0

    override func setGroundSdkConfig() {
        super.setGroundSdkConfig()
        GroundSdkConfig.sharedInstance.enableFlightData = true
    }

    override func setUp() {
        super.setUp()

        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        droneFlightDataDownloaderRef =
            drone.getPeripheral(Peripherals.flightDataDownloader) { [unowned self] flightDataDownloader in
            self.droneFlightDataDownloader = flightDataDownloader
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.enableFlightData = false
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(droneFlightDataDownloader, `is`(nilValue()))

        // since download is triggered by the connection state AND the flying state, as we don't change the flying state
        // yet, we should NOT expect a download at connection.
        connect(drone: drone, handle: 1)
        assertThat(droneFlightDataDownloader, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(droneFlightDataDownloader, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }
}
