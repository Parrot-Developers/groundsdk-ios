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

/// Test StorableUserStorage peripheral
class StorableUserStorageTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: RemovableUserStorageCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = RemovableUserStorageCore(store: store!, backend: backend)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.removableUserStorage), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.removableUserStorage), nilValue())
    }

    func testState() {
        impl.publish()
        var cnt = 0
        let storage = store.get(Peripherals.removableUserStorage)!
        _ = store.register(desc: Peripherals.removableUserStorage) {
            cnt += 1
        }

        // test initial value
        assertThat(storage.state, `is`(.noMedia))
        assertThat(cnt, `is`(0))

        // update the state
        impl.update(state: .mediaTooSlow).notifyUpdated()
        assertThat(storage.state, `is`(.mediaTooSlow))
        assertThat(cnt, `is`(1))

        // update with the same state should not change anything
        impl.update(state: .mediaTooSlow).notifyUpdated()
        assertThat(storage.state, `is`(.mediaTooSlow))
        assertThat(cnt, `is`(1))

        // update the state
        impl.update(state: .ready).notifyUpdated()
        assertThat(storage.state, `is`(.ready))
        assertThat(cnt, `is`(2))
    }

    func testAvailableSpace() {
        impl.publish()
        var cnt = 0
        let storage = store.get(Peripherals.removableUserStorage)!
        _ = store.register(desc: Peripherals.removableUserStorage) {
            cnt += 1
        }

        // test initial value
        assertThat(storage.availableSpace, lessThan(0))
        assertThat(cnt, `is`(0))

        // update the available space
        impl.update(availableSpace: 100).notifyUpdated()
        assertThat(storage.availableSpace, `is`(100))
        assertThat(cnt, `is`(1))

        // update with the same value should not change anything
        impl.update(availableSpace: 100).notifyUpdated()
        assertThat(storage.availableSpace, `is`(100))
        assertThat(cnt, `is`(1))

        // update the available space
        impl.update(availableSpace: 10).notifyUpdated()
        assertThat(storage.availableSpace, `is`(10))
        assertThat(cnt, `is`(2))
    }

    func testMediaInfo() {
        impl.publish()
        var cnt = 0
        let storage = store.get(Peripherals.removableUserStorage)!
        _ = store.register(desc: Peripherals.removableUserStorage) {
            cnt += 1
        }

        // test initial value
        assertThat(storage.mediaInfo, nilValue())
        assertThat(cnt, `is`(0))

        // update the media info
        impl.update(name: "MediaInfo", capacity: 100).notifyUpdated()
        assertThat(storage.mediaInfo, presentAnd(`is`(name: "MediaInfo", capacity: 100)))
        assertThat(cnt, `is`(1))

        // update with the same value should not change anything
        impl.update(name: "MediaInfo", capacity: 100).notifyUpdated()
        assertThat(storage.mediaInfo, presentAnd(`is`(name: "MediaInfo", capacity: 100)))
        assertThat(cnt, `is`(1))

        // update the media info name
        impl.update(name: "NewMediaInfo", capacity: 100).notifyUpdated()
        assertThat(storage.mediaInfo, presentAnd(`is`(name: "NewMediaInfo", capacity: 100)))
        assertThat(cnt, `is`(2))

        // update the media info capacity
        impl.update(name: "NewMediaInfo", capacity: 50).notifyUpdated()
        assertThat(storage.mediaInfo, presentAnd(`is`(name: "NewMediaInfo", capacity: 50)))
        assertThat(cnt, `is`(3))

        // update the media info
        impl.update(name: "NewNewMediaInfo", capacity: 200).notifyUpdated()
        assertThat(storage.mediaInfo, presentAnd(`is`(name: "NewNewMediaInfo", capacity: 200)))
        assertThat(cnt, `is`(4))
    }

    func testCanFormat() {
        impl.publish()
        var cnt = 0
        let storage = store.get(Peripherals.removableUserStorage)!
        _ = store.register(desc: Peripherals.removableUserStorage) {
            cnt += 1
        }

        // test initial value
        assertThat(storage.canFormat, `is`(false))
        assertThat(cnt, `is`(0))

        impl.update(canFormat: true).notifyUpdated()
        assertThat(storage.canFormat, `is`(true))
        assertThat(cnt, `is`(1))

        // Check same value does not trigger a change
        impl.update(canFormat: true).notifyUpdated()
        assertThat(storage.canFormat, `is`(true))
        assertThat(cnt, `is`(1))
    }

    func testFormattingType() {
        impl.publish()
        var cnt = 0
        let storage = store.get(Peripherals.removableUserStorage)!
        _ = store.register(desc: Peripherals.removableUserStorage) {
            cnt += 1
        }
        // test initial value
        assertThat(storage.supportedFormattingTypes, `is`([.full]))

        impl.update(supportedFormattingTypes: [.full, .quick]).notifyUpdated()
        assertThat(storage.supportedFormattingTypes, `is`([.full, .quick]))
        assertThat(cnt, `is`(1))

        // Check same value does not trigger a change
        impl.update(supportedFormattingTypes: [.full, .quick]).notifyUpdated()
        assertThat(storage.supportedFormattingTypes, `is`([.full, .quick]))
        assertThat(cnt, `is`(1))
    }

    func testFormat() {
        impl.publish()
        var cnt = 0
        let storage = store.get(Peripherals.removableUserStorage)!
        _ = store.register(desc: Peripherals.removableUserStorage) {
            cnt += 1
        }

        // test initial value
        assertThat(storage.state, `is`(.noMedia))
        assertThat(backend.formatCnt, `is`(0))
        assertThat(cnt, `is`(0))

        // calling format while being in noMedia should return false
        var res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(res, `is`(false))
        assertThat(backend.formatCnt, `is`(0))
        assertThat(backend.formatName, nilValue())
        assertThat(cnt, `is`(0))

        // update canFormat to true
        impl.update(canFormat: true).notifyUpdated()
        assertThat(storage.state, `is`(.noMedia))
        assertThat(cnt, `is`(1))

        // calling format while being in canFormat true should return true
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(res, `is`(true))
        assertThat(backend.formatCnt, `is`(1))
        assertThat(backend.formatName, presentAnd(`is`("newName")))
        assertThat(cnt, `is`(1))

        // calling format while being in needFormat and canFormat true should return true
        res = storage.format(formattingType: .quick)
        assertThat(res, `is`(true))
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(cnt, `is`(1))

        // test that is canFormat is `false`, the returned value is false and backend is not called
        impl.update(canFormat: false).notifyUpdated()
        assertThat(cnt, `is`(2))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

        impl.update(state: .needFormat).notifyUpdated()
        assertThat(cnt, `is`(3))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))
        res = storage.format(formattingType: .quick)
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

        impl.update(state: .mediaTooSmall).notifyUpdated()
        assertThat(cnt, `is`(4))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))
        res = storage.format(formattingType: .quick)
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

        impl.update(state: .mounting).notifyUpdated()
        assertThat(cnt, `is`(5))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))
        res = storage.format(formattingType: .quick)
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

        impl.update(state: .formatting).notifyUpdated()
        assertThat(cnt, `is`(6))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))
        res = storage.format(formattingType: .quick)
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

        impl.update(state: .formattingSucceeded).notifyUpdated()
        assertThat(cnt, `is`(7))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))
        res = storage.format(formattingType: .quick)
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

        impl.update(state: .formattingFailed).notifyUpdated()
        assertThat(cnt, `is`(8))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))
        res = storage.format(formattingType: .quick)
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

        impl.update(state: .formattingDenied).notifyUpdated()
        assertThat(cnt, `is`(9))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))
        res = storage.format(formattingType: .quick)
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

        impl.update(state: .error).notifyUpdated()
        assertThat(cnt, `is`(10))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))
        res = storage.format(formattingType: .quick)
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

        impl.update(state: .needFormat).notifyUpdated()
        assertThat(cnt, `is`(11))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))
        res = storage.format(formattingType: .quick)
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

        impl.update(state: .ready).notifyUpdated()
        assertThat(cnt, `is`(12))
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))
        res = storage.format(formattingType: .quick)
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formatName, nilValue())
        assertThat(res, `is`(false))

    }

    func testSupportedFormattingTypes() {
        impl.publish()
        var cnt = 0
        let storage = store.get(Peripherals.removableUserStorage)!
        _ = store.register(desc: Peripherals.removableUserStorage) {
            cnt += 1
        }

        // test initial value
        assertThat(storage.state, `is`(.noMedia))
        assertThat(backend.formatCnt, `is`(0))
        assertThat(cnt, `is`(0))
        assertThat(backend.formattingType, nilValue())

        // calling format while being in noMedia should return false
        var res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(res, `is`(false))
        assertThat(backend.formatCnt, `is`(0))
        assertThat(backend.formatName, nilValue())
        assertThat(backend.formattingType, nilValue())

        assertThat(cnt, `is`(0))

        // update canFormat to true
        impl.update(canFormat: true).notifyUpdated()
        assertThat(storage.state, `is`(.noMedia))
        assertThat(cnt, `is`(1))

        // calling format while being in canFormat true should return true
        res = storage.format(formattingType: .full, newMediaName: "newName")
        assertThat(res, `is`(true))
        assertThat(backend.formatCnt, `is`(1))
        assertThat(backend.formattingType, `is`(.full))
        assertThat(backend.formatName, presentAnd(`is`("newName")))
        assertThat(cnt, `is`(1))

        // calling format while being in canFormat true should return true
        res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(res, `is`(true))
        assertThat(backend.formatCnt, `is`(2))
        assertThat(backend.formattingType, `is`(.quick))
        assertThat(backend.formatName, presentAnd(`is`("newName")))
        assertThat(cnt, `is`(1))

        impl.update(canFormat: false).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(backend.formattingType, `is`(.quick))
    }
    func testFormattingTypeAndProgress() {
        impl.publish()
        var cnt = 0
        let storage = store.get(Peripherals.removableUserStorage)!
        _ = store.register(desc: Peripherals.removableUserStorage) {
            cnt += 1
        }
        // test initial value
        assertThat(storage.state, `is`(.noMedia))
        assertThat(backend.formatCnt, `is`(0))
        assertThat(cnt, `is`(0))

        // update canFormat to true
        impl.update(canFormat: true).notifyUpdated()
        assertThat(storage.state, `is`(.noMedia))
        assertThat(cnt, `is`(1))

        // calling format while being in canFormat true should return true
        let res = storage.format(formattingType: .quick, newMediaName: "newName")
        assertThat(res, `is`(true))
        assertThat(backend.formatCnt, `is`(1))
        assertThat(backend.formatName, presentAnd(`is`("newName")))
        assertThat(cnt, `is`(1))

        impl.update(state: .formatting).notifyUpdated()
        assertThat(cnt, `is`(2))

        assertThat(impl.formattingState, nilValue())

        impl.update(formattingStep: .partitioning, formattingProgress: 0).notifyUpdated()
        assertThat(impl.formattingState?.step, `is`(.partitioning))
        assertThat(impl.formattingState?.progress, `is`(0))
        assertThat(cnt, `is`(3))
        impl.update(formattingStep: .clearingData, formattingProgress: 10).notifyUpdated()
        assertThat(impl.formattingState?.step, `is`(.clearingData))
        assertThat(impl.formattingState?.progress, `is`(10))
        assertThat(cnt, `is`(4))
        impl.update(formattingStep: .clearingData, formattingProgress: 25).notifyUpdated()
        assertThat(impl.formattingState?.step, `is`(.clearingData))
        assertThat(impl.formattingState?.progress, `is`(25))
        assertThat(cnt, `is`(5))
        impl.update(formattingStep: .creatingFs, formattingProgress: 25).notifyUpdated()
        assertThat(impl.formattingState?.step, `is`(.creatingFs))
        assertThat(impl.formattingState?.progress, `is`(25))
        assertThat(cnt, `is`(6))
        // should not change count with same values
        impl.update(formattingStep: .creatingFs, formattingProgress: 25).notifyUpdated()
        assertThat(cnt, `is`(6))

    }
}

private class Backend: RemovableUserStorageCoreBackend {
    var formatCnt = 0
    var formatName: String?
    var formattingType: FormattingType?

    func format(formattingType: FormattingType, newMediaName: String?) -> Bool {
        formatCnt += 1
        formatName = newMediaName
        self.formattingType = formattingType
        return true
    }
    func format(formattingType: FormattingType) -> Bool {
        formatCnt += 1
        self.formattingType = formattingType
        return true
    }
}
