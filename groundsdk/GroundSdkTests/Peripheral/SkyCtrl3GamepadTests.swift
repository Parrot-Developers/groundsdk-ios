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

/// Test SkyCtrl3Gamepad peripheral
class SkyCtrl3GamepadTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: SkyCtrl3GamepadCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = SkyCtrl3GamepadCore(
            store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.skyCtrl3Gamepad), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.skyCtrl3Gamepad), nilValue())
    }

    func testGrabInputs() {
        impl.publish()
        var cnt = 0
        let sc3Gamepad = store.get(Peripherals.skyCtrl3Gamepad)!
        _ = store.register(desc: Peripherals.skyCtrl3Gamepad) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(sc3Gamepad.grabbedButtons, `is`(empty()))
        assertThat(sc3Gamepad.grabbedAxes, `is`(empty()))
        assertThat(backend.buttons, nilValue())
        assertThat(backend.axes, nilValue())

        // grab an input
        sc3Gamepad.grab(buttons: [.frontTopButton, .rearLeftButton], axes: [.leftSlider])
        assertThat(cnt, `is`(0))
        assertThat(backend.grabCalls, `is`(1))
        assertThat(backend.buttons, presentAnd(`is`([.rearLeftButton, .frontTopButton])))
        assertThat(backend.axes, presentAnd(`is`([.leftSlider])))

        // simulate grabbed inputs update from backend
        impl.updateGrabbedButtons([.frontTopButton, .rearLeftButton])
            .updateGrabbedAxes([.leftSlider])
            .notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(sc3Gamepad.grabbedButtons, `is`([.frontTopButton, .rearLeftButton]))
        assertThat(sc3Gamepad.grabbedAxes, `is`([.leftSlider]))

        // grabbing same inputs should do nothing
        sc3Gamepad.grab(buttons: [.frontTopButton, .rearLeftButton], axes: [.leftSlider])
        assertThat(cnt, `is`(1))
        assertThat(backend.grabCalls, `is`(1))

        // grab all buttons and none of axis
        sc3Gamepad.grab(buttons: SkyCtrl3Button.allCases, axes: [])
        assertThat(cnt, `is`(1))
        assertThat(backend.grabCalls, `is`(2))
        assertThat(backend.buttons, presentAnd(`is`(SkyCtrl3Button.allCases)))
        assertThat(backend.axes, presentAnd(`is`(empty())))

        // simulate grabbed inputs update from backend
        impl.updateGrabbedButtons([.rearLeftButton, .frontTopButton])
            .updateGrabbedAxes([])
            .notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(sc3Gamepad.grabbedButtons, `is`([.rearLeftButton, .frontTopButton]))
        assertThat(sc3Gamepad.grabbedAxes, `is`(empty()))

        // ungrab all
        sc3Gamepad.grab(buttons: [], axes: [])
        assertThat(cnt, `is`(2))
        assertThat(backend.grabCalls, `is`(3))
        assertThat(backend.buttons, presentAnd(`is`(empty())))
        assertThat(backend.axes, presentAnd(`is`(empty())))

        // simulate grabbed inputs update from backend
        impl.updateGrabbedButtons([])
            .updateGrabbedAxes([])
            .notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(sc3Gamepad.grabbedButtons, `is`(empty()))
        assertThat(sc3Gamepad.grabbedAxes, `is`(empty()))
    }

    func testGrabbedButtonEvents() {
        impl.publish()
        var cnt = 0
        var allEvents = [SkyCtrl3ButtonEvent]()
        var allStates = [SkyCtrl3ButtonEventState]()
        let sc3Gamepad = store.get(Peripherals.skyCtrl3Gamepad)!
        _ = store.register(desc: Peripherals.skyCtrl3Gamepad) {
            cnt += 1
        }

        sc3Gamepad.buttonEventListener = {
            newEvent, newState in
            allEvents.append(newEvent)
            allStates.append(newState)
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(sc3Gamepad.grabbedButtonsState, `is`(empty()))
        assertThat(allEvents, `is`(empty()))
        assertThat(allStates, `is`(empty()))

        // simulate grab state update from backend
        var grabState = [SkyCtrl3ButtonEvent: SkyCtrl3ButtonEventState]()
        grabState[.frontTopButton] = .pressed
        grabState[.frontBottomButton] = .released
        grabState[.rearLeftButton] = .released
        grabState[.rearRightButton] = .pressed
        impl.updateButtonEventStates(grabState).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(sc3Gamepad.grabbedButtonsState, allOf(
            hasCount(4),
            hasEntry(.frontTopButton, .pressed),
            hasEntry(.frontBottomButton, .released),
            hasEntry(.rearLeftButton, .released),
            hasEntry(.rearRightButton, .pressed)
        ))

        // ensure listener gets called for pressed buttons
        assertThat(allEvents, allOf(hasCount(2), containsInAnyOrder(`is`(.frontTopButton), `is`(.rearRightButton))))
        assertThat(allStates, everyItem(`is`(.pressed)))
    }

    func testButtonEvents() {
        impl.publish()
        var cnt = 0
        var event: SkyCtrl3ButtonEvent?
        var state: SkyCtrl3ButtonEventState?
        let sc3Gamepad = store.get(Peripherals.skyCtrl3Gamepad)!
        _ = store.register(desc: Peripherals.skyCtrl3Gamepad) {
            cnt += 1
        }

        let buttonEventListener: (_ event: SkyCtrl3ButtonEvent, _ state: SkyCtrl3ButtonEventState) -> Void = {
            newEvent, newState in
            event = newEvent
            state = newState
        }

        sc3Gamepad.buttonEventListener = buttonEventListener

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(sc3Gamepad.grabbedButtonsState, `is`(empty()))
        assertThat(event, nilValue())
        assertThat(state, nilValue())

        // ensure we don't receive any events for buttons that are not in the grabbed state
        impl.updateButtonEventState(.rearRightButton, state: .pressed).notifyUpdated()
        assertThat(cnt, `is`(0))
        assertThat(event, nilValue())
        assertThat(state, nilValue())

        // simulate grab state update
        var grabState = [SkyCtrl3ButtonEvent: SkyCtrl3ButtonEventState]()
        grabState[.rearRightButton] = .released
        impl.updateButtonEventStates(grabState).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(sc3Gamepad.grabbedButtonsState, allOf(
            hasCount(1),
            hasEntry(.rearRightButton, .released)
        ))
        assertThat(event, nilValue())
        assertThat(state, nilValue())

        // simulate grab state change
        impl.updateButtonEventState(.rearRightButton, state: .pressed).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(sc3Gamepad.grabbedButtonsState, allOf(
            hasCount(1),
            hasEntry(.rearRightButton, .pressed)
        ))
        assertThat(event, presentAnd(`is`(.rearRightButton)))
        assertThat(state, presentAnd(`is`(.pressed)))

        // repeat the exact same event
        event = nil
        state = nil
        impl.updateButtonEventState(.rearRightButton, state: .pressed).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(sc3Gamepad.grabbedButtonsState, allOf(
            hasCount(1),
            hasEntry(.rearRightButton, .pressed)
        ))
        assertThat(event, nilValue())
        assertThat(state, nilValue())

        // notify button release
        impl.updateButtonEventState(.rearRightButton, state: .released).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(sc3Gamepad.grabbedButtonsState, allOf(
            hasCount(1),
            hasEntry(.rearRightButton, .released)
        ))
        assertThat(event, presentAnd(`is`(.rearRightButton)))
        assertThat(state, presentAnd(`is`(.released)))

        // unregister listener
        sc3Gamepad.buttonEventListener = nil
        event = nil
        state = nil
        // notify button press from low level
        impl.updateButtonEventState(.rearRightButton, state: .pressed).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(sc3Gamepad.grabbedButtonsState, allOf(
            hasCount(1),
            hasEntry(.rearRightButton, .pressed)
        ))

        // put back the listener and notify button event
        sc3Gamepad.buttonEventListener = buttonEventListener
        impl.updateButtonEventState(.rearRightButton, state: .released)
        assertThat(event, presentAnd(`is`(.rearRightButton)))
        assertThat(state, presentAnd(`is`(.released)))

        // check that receiving a button event when unpublished won't be forwarded
        impl.resetEventListeners()
        impl.unpublish()
        event = nil
        state = nil

        impl.updateButtonEventState(.rearRightButton, state: .pressed).notifyUpdated()
        assertThat(event, nilValue())
        assertThat(state, nilValue())
    }

    func testAxisEvents() {
        impl.publish()
        var cnt = 0
        var event: SkyCtrl3AxisEvent?
        var value: Int?
        let sc3Gamepad = store.get(Peripherals.skyCtrl3Gamepad)!
        _ = store.register(desc: Peripherals.skyCtrl3Gamepad) {
            cnt += 1
        }

        let axisEventListener: (_ event: SkyCtrl3AxisEvent, _ value: Int) -> Void = {
            newEvent, newValue in
            event = newEvent
            value = newValue
        }

        sc3Gamepad.axisEventListener = axisEventListener

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(event, nilValue())
        assertThat(value, nilValue())

        // simulate grab axis value change
        impl.updateAxisEventValue(.leftStickHorizontal, value: 42).notifyUpdated()
        assertThat(cnt, `is`(0))
        assertThat(event, presentAnd(`is`(.leftStickHorizontal)))
        assertThat(value, presentAnd(`is`(42)))

        // simulate grab other axis value change
        impl.updateAxisEventValue(.leftStickVertical, value: -42).notifyUpdated()
        assertThat(cnt, `is`(0))
        assertThat(event, presentAnd(`is`(.leftStickVertical)))
        assertThat(value, presentAnd(`is`(-42)))

        // check that receiving a button event when unpublished won't be forwarded
        impl.resetEventListeners()
        impl.unpublish()
        event = nil
        value = nil

        impl.updateAxisEventValue(.leftStickVertical, value: 42).notifyUpdated()
        assertThat(event, nilValue())
        assertThat(value, nilValue())
    }

    func testSkyCtrl3InputEnum() {
        assertThat(SkyCtrl3Button.allCases, containsInAnyOrder(
            .frontTopButton, .frontBottomButton, .rearLeftButton, .rearRightButton
        ))

        assertThat(SkyCtrl3Axis.allCases, containsInAnyOrder(
            .leftStickHorizontal, .leftStickVertical, .rightStickVertical, .rightStickHorizontal,
            .leftSlider, .rightSlider))
    }

    func testMappings() {
        impl.publish()
        var cnt = 0
        let sc3Gamepad = store.get(Peripherals.skyCtrl3Gamepad)!
        _ = store.register(desc: Peripherals.skyCtrl3Gamepad) {
            cnt += 1
        }

        // mock the supported models
        impl.supportedDroneModels = [.anafi4k, .anafiThermal]

        // at start, there should be no mapping
        assertThat(cnt, `is`(0))
        assertThat(sc3Gamepad.mapping(forModel: .anafi4k), presentAnd(empty()))

        // register a button mapping
        let entry1 = SkyCtrl3ButtonsMappingEntry(
            droneModel: .anafi4k, action: .flipLeft, buttonEvents: [.rightSliderDown, .leftStickLeft])
        sc3Gamepad.register(mappingEntry: entry1)
        assertThat(backend.setupMappingCalls, `is`(1))
        assertThat(backend.mappingEntry, presentAnd(`is`(entry1)))
        assertThat(backend.register, presentAnd(`is`(true)))

        // mock update from low-level
        impl.updateButtonsMappings([entry1]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(sc3Gamepad.mapping(forModel: .anafi4k), presentAnd(containsInAnyOrder(`is`(entry1))))

        // register an axis mapping
        let entry2 = SkyCtrl3AxisMappingEntry(
            droneModel: .anafi4k, action: .panCamera, axisEvent: .rightStickHorizontal,
            buttonEvents: [.frontBottomButton, .rightSliderUp])
        sc3Gamepad.register(mappingEntry: entry2)
        assertThat(backend.setupMappingCalls, `is`(2))
        assertThat(backend.mappingEntry, presentAnd(`is`(entry2)))
        assertThat(backend.register, presentAnd(`is`(true)))

        // mock update from low-level
        impl.updateAxisMappings([entry2]).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(sc3Gamepad.mapping(forModel: .anafi4k), presentAnd(containsInAnyOrder(`is`(entry1), `is`(entry2))))

        // mock update from low level that erase entry2 and replace it with entry3
        let entry3 = SkyCtrl3AxisMappingEntry(
            droneModel: .anafi4k, action: .tiltCamera, axisEvent: .rightStickVertical,
            buttonEvents: [.frontBottomButton, .leftSliderDown])
        impl.updateAxisMappings([entry3]).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(sc3Gamepad.mapping(forModel: .anafi4k), presentAnd(containsInAnyOrder(`is`(entry1), `is`(entry3))))

        // unregister button mapping
        sc3Gamepad.unregister(mappingEntry: entry1)
        assertThat(backend.setupMappingCalls, `is`(3))
        assertThat(backend.mappingEntry, presentAnd(`is`(entry1)))
        assertThat(backend.register, presentAnd(`is`(false)))

        // mock update from low-level
        impl.updateButtonsMappings([]).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(sc3Gamepad.mapping(forModel: .anafi4k), presentAnd(containsInAnyOrder(`is`(entry3))))

        // unregister non-registered axis mapping should do nothing
        sc3Gamepad.unregister(mappingEntry: entry2)
        // same as before
        assertThat(backend.setupMappingCalls, `is`(3))
        assertThat(backend.mappingEntry, presentAnd(`is`(entry1)))
        assertThat(backend.register, presentAnd(`is`(false)))

        // unregister axis mapping
        sc3Gamepad.unregister(mappingEntry: entry3)
        assertThat(backend.setupMappingCalls, `is`(4))
        assertThat(backend.mappingEntry, presentAnd(`is`(entry3)))
        assertThat(backend.register, presentAnd(`is`(false)))

        // mock update from low-level
        impl.updateAxisMappings([]).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(sc3Gamepad.mapping(forModel: .anafiThermal), presentAnd(empty()))
    }

    func testResetMappings() {
        impl.publish()
        var cnt = 0
        _ = store.register(desc: Peripherals.skyCtrl3Gamepad) {
            cnt += 1
        }

        // mock the supported models
        impl.supportedDroneModels = [.anafi4k, .anafiThermal]

        impl.resetMapping(forModel: .anafi4k)
        assertThat(backend.resetMappingCalls, `is`(1))
        assertThat(backend.resetMappingModel, presentAnd(`is`(.anafi4k)))

        impl.resetAllMappings()
        assertThat(backend.resetMappingCalls, `is`(2))
        assertThat(backend.resetMappingModel, nilValue())
    }

    func testActiveDrone() {
        impl.publish()
        var cnt = 0
        let sc3Gamepad = store.get(Peripherals.skyCtrl3Gamepad)!
        _ = store.register(desc: Peripherals.skyCtrl3Gamepad) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(sc3Gamepad.activeDroneModel, nilValue())

        impl.updateActiveDroneModel(.anafi4k).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(sc3Gamepad.activeDroneModel, presentAnd(`is`(.anafi4k)))

        // check that setting the same active drone does not call the listener
        impl.updateActiveDroneModel(.anafi4k).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(sc3Gamepad.activeDroneModel, presentAnd(`is`(.anafi4k)))

        // change active drone model
        impl.updateActiveDroneModel(.anafiThermal).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(sc3Gamepad.activeDroneModel, presentAnd(`is`(.anafiThermal)))
    }

    func testSupportedDrones() {
        impl.publish()
        var cnt = 0
        let sc3Gamepad = store.get(Peripherals.skyCtrl3Gamepad)!
        _ = store.register(desc: Peripherals.skyCtrl3Gamepad) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(sc3Gamepad.supportedDroneModels, empty())

        impl.updateSupportedDroneModels([.anafi4k, .anafiThermal]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(sc3Gamepad.supportedDroneModels, containsInAnyOrder(.anafi4k, .anafiThermal))

        impl.updateSupportedDroneModels([.anafi4k, .anafiThermal]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(sc3Gamepad.supportedDroneModels, containsInAnyOrder(.anafi4k, .anafiThermal))

        // check that setting the same set does not call the listener
        impl.updateSupportedDroneModels([.anafiThermal]).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(sc3Gamepad.supportedDroneModels, containsInAnyOrder(.anafiThermal))

    }

    func testReversedAxes() {
        impl.publish()
        var cnt = 0
        let sc3Gamepad = store.get(Peripherals.skyCtrl3Gamepad)!
        _ = store.register(desc: Peripherals.skyCtrl3Gamepad) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        // at first, should return nil since the list of supported drone models is not known
        assertThat(sc3Gamepad.reversedAxes(forDroneModel: .anafi4k), nilValue())

        // adding a reversed axis for an unsupported drone model should do nothing
        sc3Gamepad.reverse(axis: .leftStickHorizontal, forDroneModel: .anafi4k)
        assertThat(backend.reverseCalls, `is`(0))
        assertThat(backend.reverseModel, nilValue())
        assertThat(backend.reverseAxis, nilValue())
        assertThat(backend.reversed, nilValue())

        // now support the anafi4k
        impl.updateSupportedDroneModels([.anafi4k]).notifyUpdated()
        assertThat(cnt, `is`(1))
        // set should be empty (not null since the model is supported now)
        assertThat(sc3Gamepad.reversedAxes(forDroneModel: .anafi4k), presentAnd(empty()))

        // if no information about reversed axes is received, the backend should not be called
        sc3Gamepad.reverse(axis: .leftStickHorizontal, forDroneModel: .anafi4k)
        assertThat(backend.reverseCalls, `is`(0))
        assertThat(backend.reverseModel, nilValue())
        assertThat(backend.reverseAxis, nilValue())
        assertThat(backend.reversed, nilValue())

        // mock info from reversed axes
        var entry = SkyCtrl3GamepadCore.ReversedAxisEntry(
            droneModel: .anafi4k, axis: .leftStickHorizontal, reversed: false)
        impl.updateReversedAxes([entry]).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(sc3Gamepad.reversedAxes(forDroneModel: .anafi4k), presentAnd(empty()))

        // reverse axis
        sc3Gamepad.reverse(axis: .leftStickHorizontal, forDroneModel: .anafi4k)
        assertThat(backend.reverseCalls, `is`(1))
        assertThat(backend.reverseModel, presentAnd(`is`(.anafi4k)))
        assertThat(backend.reverseAxis, presentAnd(`is`(.leftStickHorizontal)))
        assertThat(backend.reversed, presentAnd(`is`(true)))

        // mock update from low level
        entry = SkyCtrl3GamepadCore.ReversedAxisEntry(
            droneModel: .anafi4k, axis: .leftStickHorizontal, reversed: true)
        impl.updateReversedAxes([entry]).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(sc3Gamepad.reversedAxes(forDroneModel: .anafi4k), presentAnd(contains(`is`(.leftStickHorizontal))))

        // reverse same axis back to normal
        sc3Gamepad.reverse(axis: .leftStickHorizontal, forDroneModel: .anafi4k)
        assertThat(backend.reverseCalls, `is`(2))
        assertThat(backend.reverseModel, presentAnd(`is`(.anafi4k)))
        assertThat(backend.reverseAxis, presentAnd(`is`(.leftStickHorizontal)))
        assertThat(backend.reversed, presentAnd(`is`(false)))

        // mock update from low level
        entry = SkyCtrl3GamepadCore.ReversedAxisEntry(
            droneModel: .anafi4k, axis: .leftStickHorizontal, reversed: false)
        impl.updateReversedAxes([entry]).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(sc3Gamepad.reversedAxes(forDroneModel: .anafi4k), presentAnd(empty()))
    }

    func testAxisInterpolator() {
        impl.publish()
        var cnt = 0
        let sc3Gamepad = store.get(Peripherals.skyCtrl3Gamepad)!
        _ = store.register(desc: Peripherals.skyCtrl3Gamepad) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        // at first, should return nil since the list of supported drone models is not known
        assertThat(sc3Gamepad.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafi4k), nilValue())

        // adding an interpolator for an unsupported drone model should do nothing
        sc3Gamepad.set(interpolator: .linear, forAxis: .leftStickHorizontal, droneModel: .anafi4k)
        assertThat(backend.interpolatorCalls, `is`(0))
        assertThat(backend.interpolatorModel, nilValue())
        assertThat(backend.interpolatorAxis, nilValue())
        assertThat(backend.interpolatorValue, nilValue())

        // now support the anafi4k
        impl.updateSupportedDroneModels([.anafi4k]).notifyUpdated()
        assertThat(cnt, `is`(1))
        // as we return a value, it is still nil, even if the drone is supported
        assertThat(sc3Gamepad.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafi4k), nilValue())

        // if no information about interpolators axes is received, the backend should not be called
        sc3Gamepad.set(interpolator: .linear, forAxis: .leftStickHorizontal, droneModel: .anafi4k)
        assertThat(backend.interpolatorCalls, `is`(0))
        assertThat(backend.interpolatorModel, nilValue())
        assertThat(backend.interpolatorAxis, nilValue())
        assertThat(backend.interpolatorValue, nilValue())

        // mock update from low level
        let entry0 = SkyCtrl3GamepadCore.AxisInterpolatorEntry(
            droneModel: .anafi4k, axis: .leftStickHorizontal, interpolator: .strongestExponential)
        impl.updateAxisInterpolators([entry0]).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(sc3Gamepad.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafi4k),
                   presentAnd(`is`(.strongestExponential)))
        assertThat(sc3Gamepad.interpolator(forAxis: .rightStickHorizontal, droneModel: .anafi4k),
                   nilValue())

        // add an interpolator
        sc3Gamepad.set(interpolator: .linear, forAxis: .leftStickHorizontal, droneModel: .anafi4k)
        assertThat(backend.interpolatorCalls, `is`(1))
        assertThat(backend.interpolatorModel, presentAnd(`is`(.anafi4k)))
        assertThat(backend.interpolatorAxis, presentAnd(`is`(.leftStickHorizontal)))
        assertThat(backend.interpolatorValue, presentAnd(`is`(.linear)))

        // mock update from low level
        let entry1 = SkyCtrl3GamepadCore.AxisInterpolatorEntry(
            droneModel: .anafi4k, axis: .leftStickHorizontal, interpolator: .linear)
        impl.updateAxisInterpolators([entry1]).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(sc3Gamepad.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafi4k),
                   presentAnd(`is`(.linear)))
        assertThat(sc3Gamepad.interpolator(forAxis: .rightStickHorizontal, droneModel: .anafi4k), nilValue())

        // add another interpolator on another axis
        sc3Gamepad.set(interpolator: .strongExponential, forAxis: .rightStickHorizontal, droneModel: .anafi4k)
        assertThat(backend.interpolatorCalls, `is`(2))
        assertThat(backend.interpolatorModel, presentAnd(`is`(.anafi4k)))
        assertThat(backend.interpolatorAxis, presentAnd(`is`(.rightStickHorizontal)))
        assertThat(backend.interpolatorValue, presentAnd(`is`(.strongExponential)))

        // mock update from low level
        let entry2 = SkyCtrl3GamepadCore.AxisInterpolatorEntry(
            droneModel: .anafi4k, axis: .rightStickHorizontal, interpolator: .strongExponential)
        impl.updateAxisInterpolators([entry1, entry2]).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(sc3Gamepad.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafi4k),
                   presentAnd(`is`(.linear)))
        assertThat(sc3Gamepad.interpolator(forAxis: .rightStickHorizontal, droneModel: .anafi4k),
                   presentAnd(`is`(.strongExponential)))
    }

    func testMappableActions() {
        // test that the enum values are all contained in allValues
        assertThat(ButtonsMappableAction.allCases, containsInAnyOrder(.appActionSettings, .appAction1,
                                                                       .appAction2, .appAction3, .appAction4,
                                                                       .appAction5, .appAction6, .appAction7,
                                                                       .appAction8, .appAction9, .appAction10,
                                                                       .appAction11, .appAction12, .appAction13,
                                                                       .appAction14, .appAction15, .returnHome,
                                                                       .takeOffOrLand, .recordVideo, .takePicture,
                                                                       .centerCamera, .increaseCameraExposition,
                                                                       .decreaseCameraExposition, .flipLeft, .flipRight,
                                                                       .flipFront, .flipBack, .emergencyCutOff,
                                                                       .cycleHud, .photoOrVideo))
        assertThat(ButtonsMappableAction.allCases.count, `is`(30))

        assertThat(AxisMappableAction.allCases, containsInAnyOrder(.controlRoll, .controlPitch,
                                                                    .controlYawRotationSpeed, .controlThrottle,
                                                                    .panCamera, .tiltCamera, .zoomCamera))
        assertThat(AxisMappableAction.allCases.count, `is`(7))
    }

    private class Backend: SkyCtrl3GamepadBackend {
        var grabCalls = 0
        var buttons: Set<SkyCtrl3Button>?
        var axes: Set<SkyCtrl3Axis>?

        var setupMappingCalls = 0
        var mappingEntry: SkyCtrl3MappingEntry?
        var register: Bool?

        var resetMappingCalls = 0
        var resetMappingModel: Drone.Model?

        var reverseCalls = 0
        var reverseModel: Drone.Model?
        var reverseAxis: SkyCtrl3Axis?
        var reversed: Bool?

        var interpolatorCalls = 0
        var interpolatorModel: Drone.Model?
        var interpolatorAxis: SkyCtrl3Axis?
        var interpolatorValue: AxisInterpolator?

        func grab(buttons: Set<SkyCtrl3Button>, axes: Set<SkyCtrl3Axis>) {
            self.buttons = buttons
            self.axes = axes
            grabCalls += 1
        }

        func setup(mappingEntry: SkyCtrl3MappingEntry, register: Bool) {
            setupMappingCalls += 1
            self.mappingEntry = mappingEntry
            self.register = register
        }

        func resetMapping(forModel model: Drone.Model?) {
            resetMappingCalls += 1
            resetMappingModel = model
        }

        public func set(
            interpolator: AxisInterpolator, forDroneModel droneModel: Drone.Model, onAxis axis: SkyCtrl3Axis) {
            interpolatorCalls += 1
            interpolatorModel = droneModel
            interpolatorAxis = axis
            interpolatorValue = interpolator
        }

        public func set(axis: SkyCtrl3Axis, forDroneModel droneModel: Drone.Model, reversed: Bool) {
            reverseCalls += 1
            reverseModel = droneModel
            reverseAxis = axis
            self.reversed = reversed
        }
    }
}
