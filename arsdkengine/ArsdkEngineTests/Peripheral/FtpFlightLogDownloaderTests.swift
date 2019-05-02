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

class FtpFlightLogDownloaderTests: ArsdkEngineTestBase {
    var drone: DroneCore!
    var droneFlightLogDownloader: FlightLogDownloader?
    var droneFlightLogDownloaderRef: Ref<FlightLogDownloader>?
    var remoteControl: RemoteControlCore!
    var remoteFlightLogDownloader: FlightLogDownloader?
    var remoteFlightLogDownloaderRef: Ref<FlightLogDownloader>?
    var changeCntDrone = 0
    var changeCntRemote = 0

    override func setGroundSdkConfig() {
        super.setGroundSdkConfig()
        GroundSdkConfig.sharedInstance.enableFlightLog = true
    }

    override func setUp() {
        super.setUp()

        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        mockArsdkCore.addDevice("456", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "Rc1",
                                handle: 2)
        drone = droneStore.getDevice(uid: "123")!
        remoteControl = rcStore.getDevice(uid: "456")

        droneFlightLogDownloaderRef =
            drone.getPeripheral(Peripherals.flightLogDownloader) { [unowned self] flightLogDownloader in
                self.droneFlightLogDownloader = flightLogDownloader
                self.changeCntDrone += 1
        }

        remoteFlightLogDownloaderRef =
            remoteControl.getPeripheral(Peripherals.flightLogDownloader) { [unowned self] flightLogDownloader in
                self.remoteFlightLogDownloader = flightLogDownloader
                self.changeCntRemote += 1
        }
        changeCntDrone = 0
        changeCntRemote = 0
    }
    override func tearDown() {
        GroundSdkConfig.sharedInstance.enableFlightLog = false
    }

    func authentificatedUser(_ setAuthentificated: Bool) {
        let dateUserString = "20180101T101112+0000"
        let dateUser = DateFormatter.iso8601Base.date(from: dateUserString)
        var userAccountInfo: UserAccountInfoCore?

        if setAuthentificated {
            userAccountInfo = UserAccountInfoCore(
                account: "user-auth", changeDate: dateUser!, anonymousDataPolicy: AnonymousDataPolicy.allow,
                accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.allowUpload)
            userAccountUtility.userAccountInfo = userAccountInfo
        } else {
            userAccountInfo = UserAccountInfoCore(account: nil, changeDate: dateUser!,
                                            anonymousDataPolicy: AnonymousDataPolicy.allow,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.allowUpload)
        }
    }

    // test with an unauthenticated user
    func testDownloadUnauthenticatedUser() {
        let connectBlock: () -> Void = {
            _ = self.expectFlightLogDownload(handle: 2)
        }

        connect(remoteControl: remoteControl, handle: 2, connectBlock: connectBlock)

        assertThat(changeCntRemote, `is`(1))
        assertThat(changeCntDrone, `is`(0))

        assertThat(droneFlightLogDownloader, nilValue())
        assertThat(remoteFlightLogDownloader!, isDownloading())
    }

    // test with an authenticated user
    func testDownloadAuthenticatedUser() {

        let connectBlock: () -> Void = {
            _ = self.expectFlightLogDownload(handle: 2)
        }

        authentificatedUser(true)
        connect(remoteControl: remoteControl, handle: 2, connectBlock: connectBlock)

        assertThat(changeCntRemote, `is`(1))
        assertThat(changeCntDrone, `is`(0))

        assertThat(droneFlightLogDownloader, nilValue())
        assertThat(remoteFlightLogDownloader!, isDownloading())
    }

    func testDownloadFromRc() {
        var flightLogDownloadExpectation: FlightLogDownloadExpectation?
        let connectBlock: () -> Void = {
            flightLogDownloadExpectation = self.expectFlightLogDownload(handle: 2)
        }

        authentificatedUser(true)
        connect(remoteControl: remoteControl, handle: 2, connectBlock: connectBlock)

        assertThat(changeCntRemote, `is`(1))
        assertThat(remoteFlightLogDownloader!, isDownloading(downloadedCount: 0))

        flightLogDownloadExpectation?.progress(MockFlightLogStorage.mockWorkDir.path+"/flightlog_1", .ok)
        assertThat(changeCntRemote, `is`(2))
        assertThat(remoteFlightLogDownloader!, isDownloading(downloadedCount: 1))

        flightLogDownloadExpectation?.progress(MockFlightLogStorage.mockWorkDir.path+"/flightlog_2", .ok)
        assertThat(changeCntRemote, `is`(3))
        assertThat(remoteFlightLogDownloader!, isDownloading(downloadedCount: 2))

        // mock answer from low-level
        flightLogDownloadExpectation?.completion(.ok)

        assertThat(changeCntRemote, `is`(4))
        assertThat(remoteFlightLogDownloader!, hasDownloaded(downloadedCount: 2))
    }
}
