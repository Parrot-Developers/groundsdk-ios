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

/// Test CrashReporter facility
class CrashReporterTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: CrashReporterCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = CrashReporterCore(store: store)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Facilities.crashReporter), present())
        impl.unpublish()
        assertThat(store!.get(Facilities.crashReporter), nilValue())
    }

    func testPendingCount() {
        impl.publish()
        var cnt = 0
        let crashReporter = store.get(Facilities.crashReporter)!
        _ = store.register(desc: Facilities.crashReporter) {
            cnt += 1
        }

        // test initial value
        assertThat(crashReporter.pendingCount, `is`(0))

        // Check that setting same pending count from low-level does not trigger the notification
        impl.update(pendingCount: 0).notifyUpdated()
        assertThat(crashReporter.pendingCount, `is`(0))
        assertThat(cnt, `is`(0))

        // mock pending count change from low-level
        impl.update(pendingCount: 2).notifyUpdated()
        assertThat(crashReporter.pendingCount, `is`(2))
        assertThat(cnt, `is`(1))
    }

    func testUploadingState() {
        impl.publish()
        var cnt = 0
        let crashReporter = store.get(Facilities.crashReporter)!
        _ = store.register(desc: Facilities.crashReporter) {
            cnt += 1
        }

        // test initial value
        assertThat(crashReporter.isUploading, `is`(false))

        // Check that setting same uploading state from low-level does not trigger the notification
        impl.update(isUploading: false).notifyUpdated()
        assertThat(crashReporter.isUploading, `is`(false))
        assertThat(cnt, `is`(0))

        // mock uploading flag change from low-level
        impl.update(isUploading: true).notifyUpdated()
        assertThat(crashReporter.isUploading, `is`(true))
        assertThat(cnt, `is`(1))

        // Check that setting same uploading state from low-level does not trigger the notification
        impl.update(isUploading: true).notifyUpdated()
        assertThat(crashReporter.isUploading, `is`(true))
        assertThat(cnt, `is`(1))

        // mock uploading flag change from low-level
        impl.update(isUploading: false).notifyUpdated()
        assertThat(crashReporter.isUploading, `is`(false))
        assertThat(cnt, `is`(2))
    }
}
