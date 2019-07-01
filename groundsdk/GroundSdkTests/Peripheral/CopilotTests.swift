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

/// Test Copilot peripheral
class CopilotTests: XCTestCase {
    private var store: ComponentStoreCore!
    private var impl: CopilotCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = CopilotCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.copilot), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.copilot), nilValue())
    }

    func testCopilotSource() {
        impl.publish()

        var cnt = 0
        let copilot = store.get(Peripherals.copilot)!
        _ = store.register(desc: Peripherals.copilot) {
            cnt += 1
        }

        assertThat(store!.get(Peripherals.copilot), present())

        // test initial value
        assertThat(copilot.setting.source, `is`(.remoteControl))
        assertThat(cnt, `is`(0))

        copilot.setting.source = .application
        assertThat(cnt, `is`(1))

        copilot.setting.source = .application
        assertThat(cnt, `is`(1))

        copilot.setting.source = .remoteControl
        assertThat(cnt, `is`(2))

        copilot.setting.source = .remoteControl
        assertThat(cnt, `is`(2))
    }
}

private class Backend: CopilotBackend {
    var source: CopilotSource = .remoteControl

    func set(source: CopilotSource) -> Bool {
        self.source = source
        return true
    }

}
