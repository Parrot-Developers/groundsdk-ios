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

/// Test FlightDataDownloader peripheral
class FlightDataDownloaderTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: FlightDataDownloaderCore!

    private let anafi4KDeviceModel = DeviceModel.drone(.anafi4k)

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = FlightDataDownloaderCore(store: store!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.flightDataDownloader), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.flightDataDownloader), nilValue())
    }

    func testDownload() {
        impl.publish()
        var cnt = 0
        let flightDataDownloader = store.get(Peripherals.flightDataDownloader)!
        _ = store.register(desc: Peripherals.flightDataDownloader) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(flightDataDownloader, isIdle())

        // report download start
        impl.update(isDownloading: true).update(status: .none).update(latestDownloadCount: 0)
            .notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightDataDownloader, isDownloading(latestDownloadCount: 0))

        // check that changes are not reported for updating to the same values
        impl.update(isDownloading: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        impl.update(status: .none).notifyUpdated()
        assertThat(cnt, `is`(1))
        impl.update(latestDownloadCount: 0).notifyUpdated()
        assertThat(cnt, `is`(1))

        // report progress
        impl.update(latestDownloadCount: 1).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(flightDataDownloader, isDownloading(latestDownloadCount: 1))

        // report success
        impl.update(isDownloading: false).update(status: .success).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(flightDataDownloader, hasDownloaded(latestDownloadCount: 1))

        // report download start
        impl.update(isDownloading: true).update(status: .none).update(latestDownloadCount: 0)
            .notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(flightDataDownloader, isDownloading(latestDownloadCount: 0))

        // report failure
        impl.update(isDownloading: false).update(status: .interrupted).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(flightDataDownloader, hasFailedToDownload(latestDownloadCount: 0))
    }
}
