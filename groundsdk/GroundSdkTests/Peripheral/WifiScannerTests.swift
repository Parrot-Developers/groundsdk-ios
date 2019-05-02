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

/// Test WifiScanner peripheral
class WifiScannerTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: WifiScannerCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = WifiScannerCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.wifiScanner), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.wifiScanner), nilValue())
    }

    func testScanning() {
        impl.publish()
        var cnt = 0
        let wifiScanner = store.get(Peripherals.wifiScanner)!
        _ = store.register(desc: Peripherals.wifiScanner) {
            cnt += 1
        }

        // test initial value
        assertThat(wifiScanner.scanning, `is`(false))
        assertThat(cnt, `is`(0))

        impl.update(scanning: true).notifyUpdated()
        assertThat(wifiScanner.scanning, `is`(true))
        assertThat(cnt, `is`(1))

        impl.update(scanning: true).notifyUpdated()
        assertThat(wifiScanner.scanning, `is`(true))
        assertThat(cnt, `is`(1))

        impl.update(scanning: false).notifyUpdated()
        assertThat(wifiScanner.scanning, `is`(false))
        assertThat(cnt, `is`(2))

        impl.update(scanning: false).notifyUpdated()
        assertThat(wifiScanner.scanning, `is`(false))
        assertThat(cnt, `is`(2))
    }

    func testScanResults() {
        impl.publish()
        var cnt = 0
        let wifiScanner = store.get(Peripherals.wifiScanner)!
        _ = store.register(desc: Peripherals.wifiScanner) {
            cnt += 1
        }

        // test initial value
        WifiChannel.allCases.forEach {
            assertThat(wifiScanner.getOccupationRate(forChannel: $0), `is`(0))
        }
        assertThat(cnt, `is`(0))

        var scanResult = [WifiChannel.band_2_4_channel1: 1,
                          WifiChannel.band_2_4_channel2: 2,
                          WifiChannel.band_5_channel34: 3]
        impl.update(scannedChannels: scanResult).notifyUpdated()

        assertThat(wifiScanner.getOccupationRate(forChannel: .band_2_4_channel1), `is`(1))
        assertThat(wifiScanner.getOccupationRate(forChannel: .band_2_4_channel2), `is`(2))
        assertThat(wifiScanner.getOccupationRate(forChannel: .band_5_channel34), `is`(3))
        WifiChannel.allCases.forEach {
            if !scanResult.keys.contains($0) {
                assertThat(wifiScanner.getOccupationRate(forChannel: $0), `is`(0))
            }
        }
        assertThat(cnt, `is`(1))

        // update with no change
        impl.update(scannedChannels: scanResult).notifyUpdated()

        assertThat(wifiScanner.getOccupationRate(forChannel: .band_2_4_channel1), `is`(1))
        assertThat(wifiScanner.getOccupationRate(forChannel: .band_2_4_channel2), `is`(2))
        assertThat(wifiScanner.getOccupationRate(forChannel: .band_5_channel34), `is`(3))
        WifiChannel.allCases.forEach {
            if !scanResult.keys.contains($0) {
                assertThat(wifiScanner.getOccupationRate(forChannel: $0), `is`(0))
            }
        }
        assertThat(cnt, `is`(1))

        scanResult.removeValue(forKey: .band_2_4_channel2)
        impl.update(scannedChannels: scanResult).notifyUpdated()

        assertThat(wifiScanner.getOccupationRate(forChannel: .band_2_4_channel1), `is`(1))
        assertThat(wifiScanner.getOccupationRate(forChannel: .band_5_channel34), `is`(3))
        WifiChannel.allCases.forEach {
            if !scanResult.keys.contains($0) {
                assertThat(wifiScanner.getOccupationRate(forChannel: $0), `is`(0))
            }
        }
        assertThat(cnt, `is`(2))
    }

    func testStartStopScan() {
        impl.publish()
        var cnt = 0
        let wifiScanner = store.get(Peripherals.wifiScanner)!
        _ = store.register(desc: Peripherals.wifiScanner) {
            cnt += 1
        }

        // test initial value
        assertThat(backend.startScanCnt, `is`(0))
        assertThat(backend.stopScanCnt, `is`(0))
        assertThat(wifiScanner.scanning, `is`(false))
        assertThat(cnt, `is`(0))

        wifiScanner.startScan()
        assertThat(backend.startScanCnt, `is`(1))
        assertThat(backend.stopScanCnt, `is`(0))
        assertThat(wifiScanner.scanning, `is`(false))
        assertThat(cnt, `is`(0))

        impl.update(scanning: true).notifyUpdated()
        assertThat(backend.startScanCnt, `is`(1))
        assertThat(backend.stopScanCnt, `is`(0))
        assertThat(wifiScanner.scanning, `is`(true))
        assertThat(cnt, `is`(1))

        wifiScanner.startScan()
        assertThat(backend.startScanCnt, `is`(1))
        assertThat(backend.stopScanCnt, `is`(0))
        assertThat(wifiScanner.scanning, `is`(true))
        assertThat(cnt, `is`(1))

        wifiScanner.stopScan()
        assertThat(backend.startScanCnt, `is`(1))
        assertThat(backend.stopScanCnt, `is`(1))
        assertThat(wifiScanner.scanning, `is`(true))
        assertThat(cnt, `is`(1))

        impl.update(scanning: false).notifyUpdated()
        assertThat(backend.startScanCnt, `is`(1))
        assertThat(backend.stopScanCnt, `is`(1))
        assertThat(wifiScanner.scanning, `is`(false))
        assertThat(cnt, `is`(2))

        wifiScanner.stopScan()
        assertThat(backend.startScanCnt, `is`(1))
        assertThat(backend.stopScanCnt, `is`(1))
        assertThat(wifiScanner.scanning, `is`(false))
        assertThat(cnt, `is`(2))
    }
}

private class Backend: WifiScannerBackend {
    var startScanCnt = 0
    var stopScanCnt = 0

    func startScan() {
        startScanCnt += 1
    }

    func stopScan() {
        stopScanCnt += 1
    }
}
