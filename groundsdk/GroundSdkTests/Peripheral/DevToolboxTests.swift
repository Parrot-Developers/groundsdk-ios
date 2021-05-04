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

/// Test DevToolbox peripheral.
class DevToolboxTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: DevToolboxCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = DevToolboxCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.devToolbox), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.devToolbox), nilValue())
    }

    func testDebugSettings() {
        impl.publish()
        var cnt = 0
        let devToolbox = store.get(Peripherals.devToolbox)!
        _ = store.register(desc: Peripherals.devToolbox) {
            cnt += 1
        }

        // test initial values
        assertThat(cnt, `is`(0))
        assertThat(devToolbox.debugSettings, empty())

        // update debug settings list
        var debugSettings: [DebugSettingCore] = []
        debugSettings.append(impl.createDebugSetting(uid: 1, name: "1", readOnly: false, value: false))
        debugSettings.append(impl.createDebugSetting(uid: 2, name: "2", readOnly: false, value: "value2"))
        debugSettings.append(impl.createDebugSetting(uid: 3, name: "3", readOnly: false, range: 5...6, step: 7,
                                                     value: 5.5))
        impl.update(debugSettings: debugSettings).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(devToolbox.debugSettings, contains(
            allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: false), has(value: false)),
            allOf(has(name: "2"), `is`(readOnly: false), `is`(updating: false), has(value: "value2")),
            allOf(has(name: "3"), `is`(readOnly: false), `is`(updating: false), has(value: 5.5))
        ))

        // update with en empty list
        debugSettings.removeAll()
        impl.update(debugSettings: debugSettings).notifyUpdated()

        assertThat(cnt, `is`(2))
        assertThat(devToolbox.debugSettings, empty())
    }

    func testWritableBooleanDebugSetting() {
        impl.publish()
        var cnt = 0
        let devToolbox = store.get(Peripherals.devToolbox)!
        _ = store.register(desc: Peripherals.devToolbox) {
            cnt += 1
        }

        // test initial values
        assertThat(cnt, `is`(0))
        assertThat(devToolbox.debugSettings, empty())
        assertThat(backend.boolSetting, nilValue())

        // update debug settings list
        var debugSettings: [DebugSettingCore] = []
        debugSettings.append(impl.createDebugSetting(uid: 1, name: "1", readOnly: false, value: false))
        impl.update(debugSettings: debugSettings).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(devToolbox.debugSettings.count, `is`(1))
        assertThat(devToolbox.debugSettings, contains(
            allOf(has(name: "1"), `is`(readOnly: false), has(value: false))
        ))

        // get debug setting and change its value
        let debugSetting = devToolbox.debugSettings[0] as? BoolDebugSettingCore
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: false), has(value: false))))
        debugSetting?.value = true

        assertThat(cnt, `is`(2))
        assertThat(backend.boolSetting, equalTo(debugSetting))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: true), has(value: true))))

        // update value from low-level
        impl.update(debugSetting: debugSetting!, value: true).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: false), has(value: true))))

        // update to same value, nothing should change
        impl.update(debugSetting: debugSetting!, value: true).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: false), has(value: true))))
    }

    func testReadOnlyBooleanDebugSetting() {
        impl.publish()
        var cnt = 0
        let devToolbox = store.get(Peripherals.devToolbox)!
        _ = store.register(desc: Peripherals.devToolbox) {
            cnt += 1
        }

        // test initial values
        assertThat(cnt, `is`(0))
        assertThat(devToolbox.debugSettings, empty())
        assertThat(backend.boolSetting, nilValue())

        // update debug settings list
        var debugSettings: [DebugSettingCore] = []
        debugSettings.append(impl.createDebugSetting(uid: 1, name: "1", readOnly: true, value: false))
        impl.update(debugSettings: debugSettings).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(devToolbox.debugSettings.count, `is`(1))
        assertThat(devToolbox.debugSettings, contains(
            allOf(has(name: "1"), `is`(readOnly: true), has(value: false))
        ))

        // get debug setting and try to change its value
        let debugSetting = devToolbox.debugSettings[0] as? BoolDebugSettingCore
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: true), `is`(updating: false), has(value: false))))
        debugSetting?.value = true

        assertThat(cnt, `is`(1))
        assertThat(backend.boolSetting, nilValue())
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: true), `is`(updating: false), has(value: false))))
    }

    func testWritableTextDebugSetting() {
        impl.publish()
        var cnt = 0
        let devToolbox = store.get(Peripherals.devToolbox)!
        _ = store.register(desc: Peripherals.devToolbox) {
            cnt += 1
        }

        // test initial values
        assertThat(cnt, `is`(0))
        assertThat(devToolbox.debugSettings, empty())
        assertThat(backend.textSetting, nilValue())

        // update debug settings list
        var debugSettings: [DebugSettingCore] = []
        debugSettings.append(impl.createDebugSetting(uid: 1, name: "1", readOnly: false, value: "value"))
        impl.update(debugSettings: debugSettings).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(devToolbox.debugSettings.count, `is`(1))
        assertThat(devToolbox.debugSettings, contains(
            allOf(has(name: "1"), `is`(readOnly: false), has(value: "value"))
        ))

        // get debug setting and change its value
        let debugSetting = devToolbox.debugSettings[0] as? TextDebugSettingCore
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: false), has(value: "value"))))
        debugSetting?.value = "newValue"

        assertThat(cnt, `is`(2))
        assertThat(backend.textSetting, equalTo(debugSetting))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: true), has(value: "newValue"))))

        // update value from low-level
        impl.update(debugSetting: debugSetting!, value: "newValue").notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: false), has(value: "newValue"))))

        // update to same value, nothing should change
        impl.update(debugSetting: debugSetting!, value: "newValue").notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: false), has(value: "newValue"))))
    }

    func testReadOnlyTextDebugSetting() {
        impl.publish()
        var cnt = 0
        let devToolbox = store.get(Peripherals.devToolbox)!
        _ = store.register(desc: Peripherals.devToolbox) {
            cnt += 1
        }

        // test initial values
        assertThat(cnt, `is`(0))
        assertThat(devToolbox.debugSettings, empty())
        assertThat(backend.textSetting, nilValue())

        // update debug settings list
        var debugSettings: [DebugSettingCore] = []
        debugSettings.append(impl.createDebugSetting(uid: 1, name: "1", readOnly: true, value: "value"))
        impl.update(debugSettings: debugSettings).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(devToolbox.debugSettings.count, `is`(1))
        assertThat(devToolbox.debugSettings, contains(
            allOf(has(name: "1"), `is`(readOnly: true), has(value: "value"))
        ))

        // get debug setting and try to change its value
        let debugSetting = devToolbox.debugSettings[0] as? TextDebugSettingCore
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: true), `is`(updating: false), has(value: "value"))))
        debugSetting?.value = "newValue"

        assertThat(cnt, `is`(1))
        assertThat(backend.textSetting, nilValue())
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "1"), `is`(readOnly: true), `is`(updating: false), has(value: "value"))))
    }

    func testWritableNumericDebugSetting() {
        impl.publish()
        var cnt = 0
        let devToolbox = store.get(Peripherals.devToolbox)!
        _ = store.register(desc: Peripherals.devToolbox) {
            cnt += 1
        }

        // test initial values
        assertThat(cnt, `is`(0))
        assertThat(devToolbox.debugSettings, empty())
        assertThat(backend.numericSetting, nilValue())

        // update debug settings list
        var debugSettings: [DebugSettingCore] = []
        debugSettings.append(impl.createDebugSetting(uid: 1, name: "1", readOnly: false, range: 1...10, step: 0.2,
                                                     value: 1.1))
        impl.update(debugSettings: debugSettings).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(devToolbox.debugSettings.count, `is`(1))
        assertThat(devToolbox.debugSettings, contains(
            allOf(has(name: "1"), `is`(readOnly: false), has(value: 1.1))
        ))

        // get debug setting and change its value
        let debugSetting = devToolbox.debugSettings[0] as? NumericDebugSettingCore
        assertThat(debugSetting, presentAnd(allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: false),
                                                  has(value: 1.1), has(range: 1.0...10.0), has(step: 0.2))))
        debugSetting?.value = 2.2

        assertThat(cnt, `is`(2))
        assertThat(backend.numericSetting, equalTo(debugSetting))
        assertThat(debugSetting, presentAnd(allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: true),
                                                  has(value: 2.2), has(range: 1.0...10.0), has(step: 0.2))))

        // update value from low-level
        impl.update(debugSetting: debugSetting!, value: 2.2).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(debugSetting, presentAnd(allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: false),
                                                  has(value: 2.2), has(range: 1.0...10.0), has(step: 0.2))))

        // update to same value, nothing should change
        impl.update(debugSetting: debugSetting!, value: 2.2).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(debugSetting, presentAnd(allOf(has(name: "1"), `is`(readOnly: false), `is`(updating: false),
                                                  has(value: 2.2), has(range: 1.0...10.0), has(step: 0.2))))
    }

    func testReadOnlyNumericDebugSetting() {
        impl.publish()
        var cnt = 0
        let devToolbox = store.get(Peripherals.devToolbox)!
        _ = store.register(desc: Peripherals.devToolbox) {
            cnt += 1
        }

        // test initial values
        assertThat(cnt, `is`(0))
        assertThat(devToolbox.debugSettings, empty())
        assertThat(backend.numericSetting, nilValue())

        // update debug settings list
        var debugSettings: [DebugSettingCore] = []
        debugSettings.append(impl.createDebugSetting(uid: 1, name: "1", readOnly: true, range: 1...10, step: 0.2,
        value: 1.1))
        impl.update(debugSettings: debugSettings).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(devToolbox.debugSettings.count, `is`(1))
        assertThat(devToolbox.debugSettings, contains(
            allOf(has(name: "1"), `is`(readOnly: true), has(value: 1.1))
        ))

        // get debug setting and try to change its value
        let debugSetting = devToolbox.debugSettings[0] as? NumericDebugSettingCore
        assertThat(debugSetting, presentAnd(allOf(has(name: "1"), `is`(readOnly: true), `is`(updating: false),
                                                  has(value: 1.1), has(range: 1.0...10.0), has(step: 0.2))))
        debugSetting?.value = 2.2

        assertThat(cnt, `is`(1))
        assertThat(backend.textSetting, nilValue())
        assertThat(debugSetting, presentAnd(allOf(has(name: "1"), `is`(readOnly: true), `is`(updating: false),
                                                  has(value: 1.1), has(range: 1.0...10.0), has(step: 0.2))))
    }

    func testDebugTag() {
        impl.publish()
        var cnt = 0
        let devToolbox = store.get(Peripherals.devToolbox)!
        _ = store.register(desc: Peripherals.devToolbox) {
            cnt += 1
        }

        // test initial values
        assertThat(cnt, `is`(0))
        assertThat(devToolbox.latestDebugTagId, nilValue())
        assertThat(backend.debugTag, nilValue())

        // send a debug tag
        devToolbox.sendDebugTag(tag: "debug tag 1")

        assertThat(cnt, `is`(0))
        assertThat(backend.debugTag, `is`("debug tag 1"))

        // receive debug tag id from drone
        impl.update(debugTagId: "debugTagId1").notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(devToolbox.latestDebugTagId, `is`("debugTagId1"))

        // update with same debug tag id, nothing should change
        impl.update(debugTagId: "debugTagId1").notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(devToolbox.latestDebugTagId, `is`("debugTagId1"))
    }
}

private class Backend: DevToolboxBackend {

    var boolSetting: BoolDebugSettingCore?
    var textSetting: TextDebugSettingCore?
    var numericSetting: NumericDebugSettingCore?
    var debugTag: String?

    func set(setting: BoolDebugSettingCore) {
        boolSetting = setting
    }

    func set(setting: TextDebugSettingCore) {
        textSetting = setting
    }

    func set(setting: NumericDebugSettingCore) {
        numericSetting = setting
    }

    func sendDebugTag(tag: String) {
        debugTag = tag
    }
}
