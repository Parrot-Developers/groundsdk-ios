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

/// Test FlightLogDownloader peripheral
class FlightLogDownloaderTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: FlightLogDownloaderCore!

    private let anafi4kDeviceModel = DeviceModel.drone(.anafi4k)

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = FlightLogDownloaderCore(store: store!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.flightLogDownloader), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.flightLogDownloader), nilValue())
    }

    func testDownload() {
        impl.publish()
        var cnt = 0
        let flightLogDownloader = store.get(Peripherals.flightLogDownloader)!
        _ = store.register(desc: Peripherals.flightLogDownloader) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(flightLogDownloader, isIdle())

        // report download start
        impl.update(downloadingFlag: true).update(completionStatus: .none).update(downloadedCount: 0)
            .notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightLogDownloader, isDownloading(downloadedCount: 0))

        // check that changes are not reported for updating to the same values
        impl.update(downloadingFlag: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        impl.update(completionStatus: .none).notifyUpdated()
        assertThat(cnt, `is`(1))
        impl.update(downloadedCount: 0).notifyUpdated()
        assertThat(cnt, `is`(1))

        // report progress
        impl.update(downloadedCount: 1).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(flightLogDownloader, isDownloading(downloadedCount: 1))

        // report success
        impl.update(downloadingFlag: false).update(completionStatus: .success).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(flightLogDownloader, hasDownloaded(downloadedCount: 1))

        // report download start
        impl.update(downloadingFlag: true).update(completionStatus: .none).update(downloadedCount: 0)
            .notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(flightLogDownloader, isDownloading(downloadedCount: 0))

        // report failure
        impl.update(downloadingFlag: false).update(completionStatus: .interrupted).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(flightLogDownloader, hasFailedToDownload(downloadedCount: 0))
    }
}
