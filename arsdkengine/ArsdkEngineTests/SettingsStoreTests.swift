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

enum TestEnum: StorableEnum {
    case v1
    case v2
    case v3
    static var storableMapper = Mapper<TestEnum, String>([.v1: "v-1", .v2: "v-2", .v3: "v-3"])
}

class SettingsStoreTests: XCTestCase {

    var store: MockPersistentStore!
    var settingStore: SettingsStore!

    override func setUp() {
        store = MockPersistentStore()
        settingStore = SettingsStore(dictionary: store.getDevice(uid: "1"))
    }

    func testBasicTypes() {
        settingStore.write(key: "val", value: 12)
        assertThat(settingStore.read(key: "val"), presentAnd(`is`(12)))
        settingStore.writeIfNew(key: "val", value: UInt(17))
        assertThat(settingStore.read(key: "val"), presentAnd(`is`(12)))
    }

     func testEnum() {
        settingStore.write(key: "val", value: TestEnum.v1)
        assertThat(settingStore.read(key: "val"), presentAnd(`is`(TestEnum.v1)))
    }

    func testSimpleArray() {
        settingStore.write(key: "val", value: StorableArray([1, 2, 3]))
        let val: StorableArray<Int>? = settingStore.read(key: "val")
        assertThat(val?.storableValue, presentAnd(contains(1, 2, 3)))
    }

    func testEnumArray() {
        settingStore.write(key: "val", value: StorableArray([TestEnum.v1, TestEnum.v2]))
        let val: StorableArray<TestEnum>? = settingStore.read(key: "val")
        assertThat(val?.storableValue, presentAnd(contains(TestEnum.v1, TestEnum.v2)))
    }

    func testDict() {
        settingStore.write(key: "val", value: StorableDict(["k1": TestEnum.v1, "k2": TestEnum.v2]))
        let val: StorableDict<String, TestEnum>? = settingStore.read(key: "val")
        assertThat(val?.storableValue, presentAnd(allOf(hasEntry("k1", TestEnum.v1), hasEntry("k2", TestEnum.v2))))
    }

    func testComplexTypes() {
        let complexData = StorableDict<TestEnum, AnyStorable>([
            .v1: AnyStorable([1, 2, 3]),
            .v2: AnyStorable(["A", "B"]),
            .v3: AnyStorable(["X": TestEnum.v1, "Y": TestEnum.v2])
        ])
        settingStore.write(key: "val", value: complexData)
        let val: StorableDict<TestEnum, AnyStorable>? = settingStore.read(key: "val")

        assertThat(StorableArray<Int>(val?[.v1])?.storableValue, presentAnd(contains(1, 2, 3)))
        assertThat(StorableArray<String>(val?[.v2])?.storableValue, presentAnd(contains("A", "B")))
        let val3 = StorableDict<String, TestEnum>(val?[.v3])
        assertThat(val3?.storableValue["X"], presentAnd(`is`(.v1)))
        assertThat(val3?.storableValue["Y"], presentAnd(`is`(.v2)))
    }
}
