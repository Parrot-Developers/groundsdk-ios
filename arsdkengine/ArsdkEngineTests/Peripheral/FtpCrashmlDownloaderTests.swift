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

class FtpCrashmlDownloaderTests: ArsdkEngineTestBase {

    var droneCrashReportDownloader: CrashReportDownloader?
    var droneCrashReportDownloaderRef: Ref<CrashReportDownloader>?
    var remoteControl: RemoteControlCore!
    var remoteCrashReportDownloader: CrashReportDownloader?
    var remoteCrashReportDownloaderRef: Ref<CrashReportDownloader>?
    var changeCnt = 0

    override func setGroundSdkConfig() {

     super.setGroundSdkConfig()
     GroundSdkConfig.sharedInstance.enableCrashReport = true
    }

    override func setUp() {
        super.setUp()

        mockArsdkCore.addDevice("456", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "Rc1",
                                handle: 2)
        remoteControl = rcStore.getDevice(uid: "456")

        remoteCrashReportDownloaderRef =
            remoteControl.getPeripheral(Peripherals.crashReportDownloader) { [unowned self] crashReportDownloader in
                self.remoteCrashReportDownloader = crashReportDownloader
                self.changeCnt += 1
        }

        changeCnt = 0
        authentificatedUser(true)
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.enableCrashReport = false
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
            userAccountInfo = UserAccountInfoCore(
                account: nil, changeDate: dateUser!, anonymousDataPolicy: AnonymousDataPolicy.allow,
                accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.allowUpload)
        }
    }

    func testDownloadFromRc() {
        var crashmlDownloadExpectation: CrashmlDownloadExpectation?
        let connectBlock: () -> Void = {
            crashmlDownloadExpectation = self.expectCrashmlDownload(handle: 2)
        }

        authentificatedUser(true)
        connect(remoteControl: remoteControl, handle: 2, connectBlock: connectBlock)

        assertThat(changeCnt, `is`(1))
        assertThat(remoteCrashReportDownloader!, isDownloading(downloadedCount: 0))

        crashmlDownloadExpectation?.progress(MockCrashReportStorage.mockWorkDir.path+"/crash_1", .ok)
        assertThat(changeCnt, `is`(2))
        assertThat(remoteCrashReportDownloader!, isDownloading(downloadedCount: 1))

        crashmlDownloadExpectation?.progress(MockCrashReportStorage.mockWorkDir.path+"/crash_2", .ok)
        assertThat(changeCnt, `is`(3))
        assertThat(remoteCrashReportDownloader!, isDownloading(downloadedCount: 2))

        // mock answer from low-level
        crashmlDownloadExpectation?.completion(.ok)

        assertThat(changeCnt, `is`(4))
        assertThat(remoteCrashReportDownloader!, hasDownloaded(downloadedCount: 2))
    }
}
