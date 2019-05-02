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

/// Test FlightDataManager facility
class FlightDataManagerTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: FlightDataManagerCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = FlightDataManagerCore(store: store, backend: backend)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Facilities.flightDataManager), present())
        impl.unpublish()
        assertThat(store!.get(Facilities.flightDataManager), nilValue())
    }

    func testFiles() {
        impl.publish()
        var cnt = 0
        let flightDataManager = store.get(Facilities.flightDataManager)!
        _ = store.register(desc: Facilities.flightDataManager) {
            cnt += 1
        }

        // test initial value
        assertThat(flightDataManager.files, `is`(Set<URL>()))

        // update from mock
        let setOfFiles = Set([URL(fileURLWithPath: "path1"), URL(fileURLWithPath: "path2")])
        impl.update(files: setOfFiles).notifyUpdated()
        assertThat(flightDataManager.files, containsInAnyOrder(
            URL(fileURLWithPath: "path2"), URL(fileURLWithPath: "path1")))
        assertThat(cnt, `is`(1))

        // update with the same value
        impl.update(files: setOfFiles).notifyUpdated()
        assertThat(flightDataManager.files, containsInAnyOrder(
            URL(fileURLWithPath: "path2"), URL(fileURLWithPath: "path1")))
        assertThat(cnt, `is`(1))
    }

    func testDeleteAFile() {
        impl.publish()
        var cnt = 0
        let flightDataManager = store.get(Facilities.flightDataManager)!
        _ = store.register(desc: Facilities.flightDataManager) {
            cnt += 1
        }

        // test initial value
        assertThat(flightDataManager.files, `is`(Set<URL>()))

        let fileToDelete = URL(fileURLWithPath: "file_to_delete")
        let file1 = URL(fileURLWithPath: "file1")
        let file2 = URL(fileURLWithPath: "file2")
        let allFiles = Set([file1, fileToDelete, file2])

        assertThat(flightDataManager.delete(file: fileToDelete), `is`(false))
        assertThat(cnt, `is`(0))
        assertThat(backend.deleteCnt, `is`(0))
        assertThat(backend.latestDeletedUrl, nilValue())

        // add files
        impl.update(files: allFiles).notifyUpdated()
        assertThat(flightDataManager.files, `is`(allFiles))
        assertThat(cnt, `is`(1))
        assertThat(backend.deleteCnt, `is`(0))
        assertThat(backend.latestDeletedUrl, nilValue())

        assertThat(flightDataManager.delete(file: fileToDelete), `is`(true))
        assertThat(backend.deleteCnt, `is`(1))
        assertThat(backend.latestDeletedUrl, presentAnd(`is`(fileToDelete)))

    }
}

private class Backend: FlightDataManagerBackend {
    var deleteCnt = 0
    var latestDeletedUrl: URL?

    func delete(file: URL) -> Bool {
        latestDeletedUrl = file
        deleteCnt += 1
        return true
    }
}
