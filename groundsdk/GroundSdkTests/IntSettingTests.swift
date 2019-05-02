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

class IntSettingTests: XCTestCase, SettingChangeDelegate {

    var changeCnt = 0

    func userDidChangeSetting() {
        changeCnt+=1
    }

    override func setUp() {
        changeCnt = 0
    }

    func testSetSuccess() {
        var newValue = 0
        let setting = IntSettingCore(didChangeDelegate: self) { value in
            newValue = value
            return true
        }
        _ = setting.update(min: -1, value: 2, max: 5)

        setting.value = 3
        assertThat(changeCnt, `is`(1))
        assertThat(newValue, `is`(3))
        assertThat(setting.updating, `is`(true))

        _ = setting.update(min: -1, value: 3, max: 5)
        assertThat(newValue, `is`(3))
        assertThat(setting.value, `is`(3))
        assertThat(setting.updating, `is`(false))
    }

    func testSetFail() {
        let setting = IntSettingCore(didChangeDelegate: self) { _ in
            return false
        }
        _ = setting.update(min: -1, value: 2, max: 5)

        setting.value = 12
        assertThat(changeCnt, `is`(0))

        assertThat(setting.value, `is`(2))
        assertThat(setting.updating, `is`(false))
    }

    func testUpdateSameValue() {
        let setting = IntSettingCore(didChangeDelegate: self) { _ in
            return true
        }
        _ = setting.update(min: -1, value: 2, max: 5)

        // update with same values, should not be changed
        var changed = setting.update(min: -1, value: 2, max: 5)
        assertThat(changed, `is`(false))

        // set value, should be upading
        setting.value = 12
        assertThat(changeCnt, `is`(1))
        assertThat(setting.updating, `is`(true))
        // update with same value again, shoud change updating to false
        changed = setting.update(min: -1, value: 2, max: 5)
        assertThat(changed, `is`(true))
        assertThat(setting.updating, `is`(false))

        // check updating individial values
        changed = setting.update(min: -2, value: nil, max: nil)
        assertThat(changed, `is`(true))

        changed = setting.update(min: nil, value: 3, max: nil)
        assertThat(changed, `is`(true))

        changed = setting.update(min: nil, value: nil, max: 6)
        assertThat(changed, `is`(true))

        changed = setting.update(min: -3, value: nil, max: 6)
        assertThat(changed, `is`(true))

        changed = setting.update(min: -3, value: nil, max: 7)
        assertThat(changed, `is`(true))

    }

    func testUpdateBackendReject() {
        let setting = IntSettingCore(didChangeDelegate: self) { _ in
            return false
        }
        _ = setting.update(min: -10, value: 1, max: 50)
        // set value, should be rejected
        setting.value = 12
        assertThat(setting.updating, `is`(false))
        assertThat(setting.value, `is`(1))
    }

    func testClamp() {
        let setting = IntSettingCore(didChangeDelegate: self) { _ in
            return true
        }
        _ = setting.update(min: -1, value: 2, max: 5)

        setting.value = -10
        assertThat(setting.value, `is`(-1))

        setting.value = 10
        assertThat(setting.value, `is`(5))
    }

    func testTimeout() {
        let setting = IntSettingCore(didChangeDelegate: self) { _ in
            return true
        }
        _ = setting.update(min: -1, value: 2, max: 5)

        // change setting
        setting.value = 5
        assertThat(changeCnt, `is`(1))
        assertThat(setting.value, `is`(5))
        assertThat(setting.updating, `is`(true))

        // mock timeout
        setting.mockTimeout()
        assertThat(changeCnt, `is`(2))
        assertThat(setting.value, `is`(2))
        assertThat(setting.updating, `is`(false))
    }
}
