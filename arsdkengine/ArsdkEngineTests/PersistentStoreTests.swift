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
@testable import ArsdkEngine
import SdkCore
import SdkCoreTesting

class PersistentStoreTests: XCTestCase {

    var store: MockPersistentStore!

    func testEmpty() {
        store = MockPersistentStore()
        let uuids = store.getDevicesUid()
        assertThat(uuids, empty())
    }

    func testGetDeviceNotFound() {
        store = MockPersistentStore()
        let dict = store.getDevice(uid: "123")
        assertThat(dict.exist, `is`(false))
    }

    func testCreateDevice() {
        store = MockPersistentStore()
        let dict = store.getDevice(uid: "123")
        dict[PersistentStore.deviceType] = StorableValue(123).content
        dict[PersistentStore.deviceName] = StorableValue("name").content
        // dict should still be new
        assertThat(dict.new, `is`(true))

        // check value access
        assertThat(dict[PersistentStore.deviceType] as? Int, presentAnd(`is`(123)))
        assertThat(dict[PersistentStore.deviceName] as? String, presentAnd(`is`("name")))

        // commit
        dict.commit()
        assertThat(dict.new, `is`(false))

        // check getDevicesUid
        let uuids = store.getDevicesUid()
        assertThat(uuids, contains("123"))

        // chec getDevice
        let dict2 = store.getDevice(uid: "123")
        assertThat(dict2.new, `is`(false))
        assertThat(dict2[PersistentStore.deviceType] as? Int, presentAnd(`is`(123)))
        assertThat(dict2[PersistentStore.deviceName] as? String, presentAnd(`is`("name")))
    }

    func testChildDictionary() {
        store = MockPersistentStore()
        let dict = store.getDevice(uid: "123")
        dict.commit()

        let subDict: PersistentDictionary = dict.getPersistentDictionary(key: "SUB")
        // dict should still be new
        assertThat(subDict.new, `is`(true))

        subDict["substr"] = StorableValue("sub string").content
        subDict.commit()

        let dict2: PersistentDictionary = store.getDevice(uid: "123").getPersistentDictionary(key: "SUB")

        assertThat(dict2.new, `is`(false))
        assertThat(dict2["substr"] as? String, presentAnd(`is`("sub string")))
    }
}
