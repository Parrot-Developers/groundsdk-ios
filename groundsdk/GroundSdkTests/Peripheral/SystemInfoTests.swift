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

/// Test SystemInfo peripheral
class SystemInfoTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: SystemInfoCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = SystemInfoCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.systemInfo), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.systemInfo), nilValue())
    }

    func testFirmwareVersion() {
        impl.publish()
        var cnt = 0
        let systemInfo = store.get(Peripherals.systemInfo)!
        _ = store.register(desc: Peripherals.systemInfo) {
            cnt += 1
        }

        // test initial value
        assertThat(systemInfo.firmwareVersion, `is`(""))
        assertThat(cnt, `is`(0))

        // change firmware version from a string
        impl.update(firmwareVersion: "1.0.2-rc4").notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(systemInfo.firmwareVersion, `is`("1.0.2-rc4"))

        // setting the same firmware version should not change anything
        impl.update(firmwareVersion: "1.0.2-rc4").notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(systemInfo.firmwareVersion, `is`("1.0.2-rc4"))
    }

    func testIsBlacklisted() {
        impl.publish()
        var cnt = 0
        let systemInfo = store.get(Peripherals.systemInfo)!
        _ = store.register(desc: Peripherals.systemInfo) {
            cnt += 1
        }

        // test initial value
        assertThat(systemInfo.isFirmwareBlacklisted, `is`(false))
        assertThat(cnt, `is`(0))

        // change blacklisted information
        impl.update(isBlacklisted: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(systemInfo.isFirmwareBlacklisted, `is`(true))

        // setting the same should not change anything
        impl.update(isBlacklisted: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(systemInfo.isFirmwareBlacklisted, `is`(true))
    }

    func testHardwareVersion() {
        impl.publish()
        var cnt = 0
        let systemInfo = store.get(Peripherals.systemInfo)!
        _ = store.register(desc: Peripherals.systemInfo) {
            cnt += 1
        }

        // test initial value
        assertThat(systemInfo.hardwareVersion, `is`(""))
        assertThat(cnt, `is`(0))

        // change hardware version
        impl.update(hardwareVersion: "HW03").notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(systemInfo.hardwareVersion, `is`("HW03"))

        // setting the same hardware version should not change anything
        impl.update(hardwareVersion: "HW03").notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(systemInfo.hardwareVersion, `is`("HW03"))
    }

    func testSerial() {
        impl.publish()
        var cnt = 0
        let systemInfo = store.get(Peripherals.systemInfo)!
        _ = store.register(desc: Peripherals.systemInfo) {
            cnt += 1
        }

        // test initial value
        assertThat(systemInfo.serial, `is`(""))
        assertThat(cnt, `is`(0))

        // change hardware version
        impl.update(serial: "SERIAL_00").notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(systemInfo.serial, `is`("SERIAL_00"))

        // setting the same serial should not change anything
        impl.update(serial: "SERIAL_00").notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(systemInfo.serial, `is`("SERIAL_00"))
    }

    func testBoardId() {
        impl.publish()
        var cnt = 0
        let systemInfo = store.get(Peripherals.systemInfo)!
        _ = store.register(desc: Peripherals.systemInfo) {
            cnt += 1
        }

        // test initial value
        assertThat(systemInfo.boardId, `is`(""))
        assertThat(cnt, `is`(0))

        // change board id from a string
        impl.update(boardId: "board id").notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(systemInfo.boardId, `is`("board id"))

        // setting the same board id should not change anything
        impl.update(boardId: "board id").notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(systemInfo.boardId, `is`("board id"))
    }

    func testResetSettings() {
        impl.publish()
        var cnt = 0
        let systemInfo = store.get(Peripherals.systemInfo)!
        _ = store.register(desc: Peripherals.systemInfo) {
            cnt += 1
        }

        // test initial value
        assertThat(backend.resetSettingsCnt, `is`(0))
        assertThat(systemInfo.isResetSettingsInProgress, `is`(false))
        assertThat(cnt, `is`(0))

        _ = systemInfo.resetSettings()
        assertThat(backend.resetSettingsCnt, `is`(1))
        assertThat(systemInfo.isResetSettingsInProgress, `is`(true))
        assertThat(cnt, `is`(1))
    }

    func testFactoryReset() {
        impl.publish()
        var cnt = 0
        let systemInfo = store.get(Peripherals.systemInfo)!
        _ = store.register(desc: Peripherals.systemInfo) {
            cnt += 1
        }

        // test initial value
        assertThat(backend.factoryResetCnt, `is`(0))
        assertThat(systemInfo.isFactoryResetInProgress, `is`(false))
        assertThat(cnt, `is`(0))

        _ = systemInfo.factoryReset()
        assertThat(backend.factoryResetCnt, `is`(1))
        assertThat(systemInfo.isFactoryResetInProgress, `is`(true))
        assertThat(cnt, `is`(1))
    }
}

private class Backend: SystemInfoBackend {
    var factoryResetCnt = 0
    var resetSettingsCnt = 0

    func resetSettings() -> Bool {
        resetSettingsCnt += 1
        return true
    }

    func factoryReset() -> Bool {
        factoryResetCnt += 1
        return true
    }
}
