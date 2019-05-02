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

class GroundSdkRemoteControlListTests: XCTestCase {

    var groundSdkCore: MockGroundSdkCore?
    var gsdk: GroundSdk?
    var rc1: RemoteControlCore?
    var rc2: RemoteControlCore?
    var rc3: RemoteControlCore?

    override func setUp() {
        super.setUp()
        groundSdkCore = MockGroundSdkCore()

        rc1 = RemoteControlCore(uid: "1", model: RemoteControl.Model.skyCtrl3, name: "SkyCtrl1", delegate: self)
        rc2 = RemoteControlCore(uid: "2", model: RemoteControl.Model.skyCtrl3, name: "SkyCtrl2", delegate: self)
        rc3 = RemoteControlCore(uid: "3", model: RemoteControl.Model.skyCtrl3, name: "SkyCtrl3", delegate: self)
        gsdk = GroundSdk()
    }

    override func tearDown() {
        gsdk = nil
    }

    /// Check that list empty is received when no rc have been added
    func testEmptyList() {
        var cnt = 0
        var remoteControlList: [RemoteControlListEntry]?
        var listRef = gsdk?.getRemoteControlList(
            observer: { newRemoteControlList in
                remoteControlList = newRemoteControlList
                cnt += 1
        })
        // remove unused variable warning
        _ = listRef

        assertThat(cnt, equalTo(1))
        assertThat(remoteControlList, presentAnd(empty()))

        listRef = nil
    }

    /// Check that getting the correct list when adding drones before creating the ref
    func testGetList() {
        groundSdkCore?.mockEngine?.add(remoteControl: rc1!)
        groundSdkCore?.mockEngine?.add(remoteControl: rc2!)
        var cnt = 0
        var remoteControlList: [RemoteControlListEntry]?
        var listRef = gsdk?.getRemoteControlList(
            observer: { newRemoteControlList in
                remoteControlList = newRemoteControlList
                cnt += 1
        })
        // remove unused variable warning
        _ = listRef

        assertThat(cnt, equalTo(1))
        assertThat(remoteControlList, presentAnd(hasCount(2)))
        assertThat(remoteControlList!, containsInAnyOrder(has(uid: rc1!.uid), has(uid: rc2!.uid)))

        listRef = nil
    }

    /// Check that getting the correct list when adding drones after creating the ref
    func testRcAdded() {
        groundSdkCore?.mockEngine?.add(remoteControl: rc1!)
        groundSdkCore?.mockEngine?.add(remoteControl: rc2!)
        var cnt = 0
        var remoteControlList: [RemoteControlListEntry]?
        var listRef = gsdk?.getRemoteControlList(
            observer: { newRemoteControlList in
                remoteControlList = newRemoteControlList
                cnt += 1
        })
        // remove unused variable warning
        _ = listRef

        assertThat(cnt, equalTo(1))
        assertThat(remoteControlList, presentAnd(hasCount(2)))
        assertThat(remoteControlList!, containsInAnyOrder(has(uid: "1"), has(uid: "2")))

        groundSdkCore?.mockEngine?.add(remoteControl: rc3!)
        assertThat(cnt, equalTo(2))
        assertThat(remoteControlList, presentAnd(hasCount(3)))
        assertThat(remoteControlList!, containsInAnyOrder(has(uid: "1"), has(uid: "2"), has(uid: "3")))

        listRef = nil
    }

    /// Check that getting the correct list when removing drones
    func testRcRemoved() {
        groundSdkCore?.mockEngine?.add(remoteControl: rc1!)
        groundSdkCore?.mockEngine?.add(remoteControl: rc2!)
        var cnt = 0
        var remoteControlList: [RemoteControlListEntry]?
        var listRef = gsdk?.getRemoteControlList(
            observer: { newRemoteControlList in
                remoteControlList = newRemoteControlList
                cnt += 1
        })
        // remove unused variable warning
        _ = listRef

        assertThat(cnt, equalTo(1))
        assertThat(remoteControlList, presentAnd(hasCount(2)))

        groundSdkCore?.mockEngine?.remove(remoteControl: rc2!)
        assertThat(cnt, equalTo(2))
        assertThat(remoteControlList, presentAnd(hasCount(1)))
        assertThat(remoteControlList!, containsInAnyOrder(has(uid: "1")))

        listRef = nil
    }

    /// Check the list entry data
    func testEntryData() {
        groundSdkCore?.mockEngine?.add(remoteControl: rc1!)
        var cnt = 0
        var remoteControlList: [RemoteControlListEntry]?
        var listRef = gsdk?.getRemoteControlList(
            observer: { newRemoteControlList in
                remoteControlList = newRemoteControlList
                cnt += 1
        })
        // remove unused variable warning
        _ = listRef

        let entry = remoteControlList![0]
        assertThat(entry, allOf(has(uid: "1"), has(name: "SkyCtrl1"), `is`(RemoteControl.Model.skyCtrl3)))

        listRef = nil
    }

    /// Check drone name changes are notified
    func testRcNameChanged() {
        groundSdkCore?.mockEngine?.add(remoteControl: rc1!)
        groundSdkCore?.mockEngine?.add(remoteControl: rc2!)
        var cnt = 0
        var remoteControlList: [RemoteControlListEntry]?
        var listRef = gsdk?.getRemoteControlList(
            observer: { newRemoteControlList in
                remoteControlList = newRemoteControlList
                cnt += 1
        })
        // remove unused variable warning
        _ = listRef

        assertThat(cnt, equalTo(1))
        assertThat(remoteControlList, presentAnd(hasCount(2)))

        rc2?.nameHolder.update(name: "newrc2")
        assertThat(cnt, equalTo(2))
        assertThat(remoteControlList, presentAnd(hasCount(2)))
        assertThat(remoteControlList!, hasItem(has(name: "newrc2")))

        listRef = nil
    }

    /// Check rc firmware version changes are notified
    /// This behavior is unwanted but for the moment we accept that changing the firmware version notifies a change
    /// even if this change won't be seen from the API.
    func testRcFirmwareVersionChanged() {
        groundSdkCore?.mockEngine?.add(remoteControl: rc1!)
        groundSdkCore?.mockEngine?.add(remoteControl: rc2!)
        var cnt = 0
        var remoteControlList: [RemoteControlListEntry]?
        var listRef = gsdk?.getRemoteControlList(
            observer: { newRemoteControlList in
                remoteControlList = newRemoteControlList
                cnt += 1
        })
        // remove unused variable warning
        _ = listRef

        assertThat(cnt, equalTo(1))
        assertThat(remoteControlList, presentAnd(hasCount(2)))

        rc2?.firmwareVersionHolder.update(version: FirmwareVersion.parse(versionStr: "1.2.3")!)
        assertThat(cnt, equalTo(2))
        assertThat(remoteControlList, presentAnd(hasCount(2)))

        listRef = nil
    }

    /// Check drone state changes are notified
    func testRcStateChanged() {
        groundSdkCore?.mockEngine?.add(remoteControl: rc1!)
        var cnt = 0
        var remoteControlList: [RemoteControlListEntry]?
        var listRef = gsdk?.getRemoteControlList(
            observer: { newRemoteControlList in
                remoteControlList = newRemoteControlList
                cnt += 1
        })
        // remove unused variable warning
        _ = listRef

        assertThat(cnt, equalTo(1))
        assertThat(remoteControlList, presentAnd(hasCount(1)))
        assertThat(remoteControlList![0].state, `is`(.disconnected))

        rc1?.stateHolder.state.update(connectionState: .connecting).notifyUpdated()
        assertThat(cnt, equalTo(2))
        assertThat(remoteControlList, presentAnd(hasCount(1)))
        assertThat(remoteControlList![0].state, `is`(.connecting))

        listRef = nil
    }

    /// Check that getting the correct list when adding drones before creating a ref with a custom filter
    func testGetListWithFilter() {
        groundSdkCore?.mockEngine?.add(remoteControl: rc1!)
        groundSdkCore?.mockEngine?.add(remoteControl: rc2!)
        groundSdkCore?.mockEngine?.add(remoteControl: rc3!)
        var cnt = 0
        var remoteControlList: [RemoteControlListEntry]?
        var listRef = gsdk?.getRemoteControlList(
            observer: { newRemoteControlList in
                remoteControlList = newRemoteControlList
                cnt += 1
        },
            filter: { remoteControl in
                return remoteControl.uid == "1"
        })
        // remove unused variable warning
        _ = listRef

        assertThat(cnt, equalTo(1))
        assertThat(remoteControlList, presentAnd(hasCount(1)))
        assertThat(remoteControlList!, containsInAnyOrder(has(uid: "1")))

        listRef = nil
    }

    /// Check that when a drone changes and pass the filter its added to the list and it's removed from the list when it
    /// doesn't pass the filter anymore
    func testFilterUpdate() {
        groundSdkCore?.mockEngine?.add(remoteControl: rc1!)
        groundSdkCore?.mockEngine?.add(remoteControl: rc2!)
        groundSdkCore?.mockEngine?.add(remoteControl: rc3!)

        var cnt = 0
        var remoteControlList: [RemoteControlListEntry]?
        var listRef = gsdk?.getRemoteControlList(
            observer: { newRemoteControlList in
                remoteControlList = newRemoteControlList
                cnt += 1
        },
            filter: { drone in
                return drone.state.connectionState == .disconnected
        })
        // remove unused variable warning
        _ = listRef
        // expect both drone
        assertThat(cnt, equalTo(1))
        assertThat(remoteControlList, presentAnd(hasCount(3)))
        assertThat(remoteControlList!, containsInAnyOrder(has(uid: "1"), has(uid: "2"), has(uid: "3")))

        // change state of rc2 to Connecting
        rc2?.stateHolder.state.update(connectionState: .connecting).notifyUpdated()
        // expect drone 2 has been removed from the list
        assertThat(cnt, equalTo(2))
        assertThat(remoteControlList, presentAnd(hasCount(2)))
        assertThat(remoteControlList!, containsInAnyOrder(has(uid: "1"), has(uid: "3")))

        // change state of rc2 back to Disconnected
        rc2?.stateHolder.state.update(connectionState: .disconnected).notifyUpdated()
        // expect drone 2 back in the list
        assertThat(cnt, equalTo(3))
        assertThat(remoteControlList, presentAnd(hasCount(3)))
        assertThat(remoteControlList!, containsInAnyOrder(has(uid: "1"), has(uid: "2"), has(uid: "3")))

        // change the name if rc2
        rc2?.nameHolder.update(name: "newName")
        // expect drone 2 still in the list
        assertThat(cnt, equalTo(4))
        assertThat(remoteControlList, presentAnd(hasCount(3)))
        assertThat(remoteControlList!, containsInAnyOrder(has(uid: "1"), has(uid: "2"), has(uid: "3")))

        listRef = nil
    }

}

extension GroundSdkRemoteControlListTests: DeviceCoreDelegate {
    func forget() -> Bool {
        return false
    }

    func connect(connector: DeviceConnector, password: String?) -> Bool {
        return false
    }

    func disconnect() -> Bool {
        return false
    }
}
