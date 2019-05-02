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

/// Test VirtualGamepad peripheral
class VirtualGamepadTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: VirtualGamepadCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = VirtualGamepadCore(
            store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.virtualGamepad), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.virtualGamepad), nilValue())
    }

    func testGrabUngrab() {
        impl.publish()
        var cnt = 0
        let virtualGamepad = store.get(Peripherals.virtualGamepad)!
        _ = store.register(desc: Peripherals.virtualGamepad) {
            cnt += 1
        }
        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(virtualGamepad.isGrabbed, `is`(false))
        assertThat(virtualGamepad.isPreempted, `is`(false))
        assertThat(virtualGamepad.canGrab, `is`(true))
        assertThat(backend.grabNavigationCalls, `is`(0))

        // ungrab should do nothing
        virtualGamepad.ungrab()
        assertThat(cnt, `is`(0))
        assertThat(virtualGamepad.isGrabbed, `is`(false))
        assertThat(virtualGamepad.isPreempted, `is`(false))
        assertThat(virtualGamepad.canGrab, `is`(true))
        assertThat(backend.grabNavigationCalls, `is`(0))

        // grab
        var grabResult = virtualGamepad.grab(listener: { _, _ in })
        assertThat(cnt, `is`(0))
        assertThat(virtualGamepad.isGrabbed, `is`(false))
        assertThat(virtualGamepad.isPreempted, `is`(false))
        assertThat(virtualGamepad.canGrab, `is`(true))
        assertThat(grabResult, `is`(true))
        assertThat(backend.grabNavigationCalls, `is`(1))

        // mock grabbed from the backend
        impl.update(isGrabbed: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(virtualGamepad.isGrabbed, `is`(true))
        assertThat(virtualGamepad.isPreempted, `is`(false))
        assertThat(virtualGamepad.canGrab, `is`(false))

        // grab should do nothing
        grabResult = virtualGamepad.grab(listener: { _, _ in })
        assertThat(cnt, `is`(1))
        assertThat(virtualGamepad.isGrabbed, `is`(true))
        assertThat(virtualGamepad.isPreempted, `is`(false))
        assertThat(virtualGamepad.canGrab, `is`(false))
        assertThat(grabResult, `is`(false))
        assertThat(backend.grabNavigationCalls, `is`(1))

        // set preempted from backend
        impl.update(isPreempted: true).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(virtualGamepad.isGrabbed, `is`(true))
        assertThat(virtualGamepad.isPreempted, `is`(true))
        assertThat(virtualGamepad.canGrab, `is`(false))

        // grab should do nothing
        grabResult = virtualGamepad.grab(listener: { _, _ in })
        assertThat(cnt, `is`(2))
        assertThat(virtualGamepad.isGrabbed, `is`(true))
        assertThat(virtualGamepad.isPreempted, `is`(true))
        assertThat(virtualGamepad.canGrab, `is`(false))
        assertThat(grabResult, `is`(false))
        assertThat(backend.grabNavigationCalls, `is`(1))

        // ungrab
        virtualGamepad.ungrab()
        assertThat(cnt, `is`(2))
        assertThat(virtualGamepad.isGrabbed, `is`(true))
        assertThat(virtualGamepad.isPreempted, `is`(true))
        assertThat(virtualGamepad.canGrab, `is`(false))
        assertThat(backend.grabNavigationCalls, `is`(0))

        // set end of grab from backend
        impl.update(isGrabbed: false).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(virtualGamepad.isGrabbed, `is`(false))
        assertThat(virtualGamepad.isPreempted, `is`(true))
        assertThat(virtualGamepad.canGrab, `is`(false))
        assertThat(backend.grabNavigationCalls, `is`(0))

        // set end of preemption from backend
        impl.update(isPreempted: false).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(virtualGamepad.isGrabbed, `is`(false))
        assertThat(virtualGamepad.isPreempted, `is`(false))
        assertThat(virtualGamepad.canGrab, `is`(true))
    }

    func testNavEvents() {
        impl.publish()
        var cnt = 0
        var event: VirtualGamepadEvent?
        var state: VirtualGamepadEventState?
        let virtualGamepad = store.get(Peripherals.virtualGamepad)!
        _ = store.register(desc: Peripherals.virtualGamepad) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(event, nilValue())
        assertThat(state, nilValue())

        // grab navigation (from API and from backend)
        _ = virtualGamepad.grab(listener: { newEvent, newState in
            event = newEvent
            state = newState
        })
        impl.update(isGrabbed: true)

        // ensure we receive events
        impl.notifyNavigationEvent(.cancel, state: .pressed)
        assertThat(cnt, `is`(0))
        assertThat(event, presentAnd(`is`(.cancel)))
        assertThat(state, presentAnd(`is`(.pressed)))

        // ungrab (from API and from backend)
        virtualGamepad.ungrab()
        impl.update(isGrabbed: false)

        // check that receiving a nav event won't be forwarded
        event = nil
        state = nil
        impl.notifyNavigationEvent(.ok, state: .released)
        assertThat(cnt, `is`(0))
        assertThat(event, nilValue())
        assertThat(state, nilValue())

        // grab again
        _ = virtualGamepad.grab(listener: { newEvent, newState in
            event = newEvent
            state = newState
        })
        impl.update(isGrabbed: true)

        // ensure we receive events
        impl.notifyNavigationEvent(.ok, state: .released)
        assertThat(cnt, `is`(0))
        assertThat(event, presentAnd(`is`(.ok)))
        assertThat(state, presentAnd(`is`(.released)))

        // check that receiving a nav event when unpublished won't be forwarded
        impl.resetNavListener()
        impl.unpublish()
        event = nil
        state = nil
        impl.notifyNavigationEvent(.cancel, state: .released)
        assertThat(cnt, `is`(1))
        assertThat(event, nilValue())
        assertThat(state, nilValue())
    }

    func testAppEvents() {
        impl.publish()
        var cnt = 0
        var appAction: ButtonsMappableAction?
        _ = store.register(desc: Peripherals.virtualGamepad) {
            cnt += 1
        }

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GsdkActionGamepadAppAction, object: nil, queue: nil, using: {  notification in
                appAction = notification.userInfo?[GsdkActionGamepadAppActionKey] as? ButtonsMappableAction
        })

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(appAction, nilValue())

        // receive an app event from the backend
        impl.notifyAppAction(.appAction1)
        assertThat(appAction, presentAnd(`is`(.appAction1)))

        NotificationCenter.default.removeObserver(observer)
    }

    private class Backend: VirtualGamepadBackend {
        var grabNavigationCalls = 0

        func grabNavigation() -> Bool {
            grabNavigationCalls += 1
            return true
        }

        func ungrabNavigation() {
            grabNavigationCalls -= 1
        }
    }
}
