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
@testable import GroundSdkMock
@testable import GroundSdk

class BlacklistedVersionStoreCoreTests: XCTestCase {

    let store = BlacklistedVersionStoreCoreImpl(gsdkUserdefaults: MockGroundSdkUserDefaults("mockBlackList"))

    var monitor: MonitorCore!
    var changeCnt = 0

    override func setUp() {
        super.setUp()

        monitor = store.startMonitoring { [unowned self] in
            self.changeCnt += 1
        }
    }

    func testMergeRemote() {
        // store should be initialy empty
        assertThat(store.blacklist, empty())
        assertThat(changeCnt, `is`(1))

        store.mergeRemoteBlacklistedVersions([
            .drone(.anafi4k):
                [FirmwareVersion.parse(versionStr: "0.1.2")!,
                 FirmwareVersion.parse(versionStr: "1.2.3")!],
            .rc(.skyCtrl3):
                [FirmwareVersion.parse(versionStr: "5.4.3")!]
            ])

        assertThat(isBlacklisted(model: .drone(.anafi4k), version: "0.1.2"), `is`(true))
        assertThat(isBlacklisted(model: .drone(.anafi4k), version: "1.2.3"), `is`(true))
        assertThat(isBlacklisted(model: .rc(.skyCtrl3), version: "5.4.3"), `is`(true))
        assertThat(changeCnt, `is`(2))

        // check that new blacklisted version are added and do not replace existing ones
        store.mergeRemoteBlacklistedVersions([
            .drone(.anafi4k):
                [FirmwareVersion.parse(versionStr: "3.4.5")!],
            .rc(.skyCtrl3):
                [FirmwareVersion.parse(versionStr: "5.4.3")!]])

        assertThat(isBlacklisted(model: .drone(.anafi4k), version: "0.1.2"), `is`(true))
        assertThat(isBlacklisted(model: .drone(.anafi4k), version: "1.2.3"), `is`(true))
        assertThat(isBlacklisted(model: .drone(.anafi4k), version: "3.4.5"), `is`(true))
        assertThat(isBlacklisted(model: .rc(.skyCtrl3), version: "5.4.3"), `is`(true))
        assertThat(changeCnt, `is`(3))

        // check that no new blacklisted version does not trigger the update
        store.mergeRemoteBlacklistedVersions([
            .drone(.anafi4k):
                [FirmwareVersion.parse(versionStr: "3.4.5")!],
            .rc(.skyCtrl3):
                [FirmwareVersion.parse(versionStr: "5.4.3")!]
            ])

        assertThat(isBlacklisted(model: .drone(.anafi4k), version: "0.1.2"), `is`(true))
        assertThat(isBlacklisted(model: .drone(.anafi4k), version: "1.2.3"), `is`(true))
        assertThat(isBlacklisted(model: .drone(.anafi4k), version: "3.4.5"), `is`(true))
        assertThat(isBlacklisted(model: .rc(.skyCtrl3), version: "5.4.3"), `is`(true))
        assertThat(changeCnt, `is`(3))
    }

    private func isBlacklisted(model: DeviceModel, version: String) -> Bool {
        return store.isBlacklisted(
            firmwareIdentifier: FirmwareIdentifier(
                deviceModel: model, version: FirmwareVersion.parse(versionStr: version)!))
    }
}
