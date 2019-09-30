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

import Foundation
import XCTest

@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

class Sc3GamepadTests: ArsdkEngineTestBase {

    var remoteControl: RemoteControlCore!
    var skyCtrl3Gamepad: SkyCtrl3Gamepad?
    var skyCtrl3GamepadRef: Ref<SkyCtrl3Gamepad>?
    var virtualGamepad: VirtualGamepad?
    var virtualGamepadRef: Ref<VirtualGamepad>?
    var sc3ChangeCnt = 0
    var virtualChangeCnt = 0

    let navButtonMask: MapperButtonsMask = MapperButtonsMask.from(.button2, .button3, .button4, .button5, .button6,
                                                                  .button7)
    let navAxisMask: MapperAxesMask = MapperAxesMask.from(.axis0, .axis1)

    let allButtonsMask = MapperButtonsMask.from(
        .button0, .button1, .button2, .button3,
        .button4, .button5, .button6, .button7, .button8, .button9, .button10, .button11,
        .button12, .button13, .button14, .button15)

    let allAxesMask: MapperAxesMask = MapperAxesMask.from(.axis0, .axis1, .axis2, .axis3, .axis4, .axis5)

    let allButtonEvents: Set<SkyCtrl3ButtonEvent> = [
        .frontTopButton, .frontBottomButton, .rearLeftButton, .rearRightButton, .leftSliderUp, .leftSliderDown,
        .rightSliderUp, .rightSliderDown, .leftStickLeft, .leftStickRight, .leftStickUp, .leftStickDown,
        .rightStickLeft, .rightStickRight, .rightStickUp, .rightStickDown]

    var navListenerCount = 0
    var buttonListenerCount = 0
    var axisListenerCount = 0

    var navEvent: VirtualGamepadEvent?
    var navState: VirtualGamepadEventState?

    var sc3ButtonEvent: SkyCtrl3ButtonEvent?
    var sc3ButtonState: SkyCtrl3ButtonEventState?

    var sc3AxisEvent: SkyCtrl3AxisEvent?
    var sc3AxisValue: Int?

    var appAction: ButtonsMappableAction?

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "RC1",
                                handle: 1)
        remoteControl = rcStore.getDevice(uid: "123")!

        skyCtrl3GamepadRef =
            remoteControl.getPeripheral(Peripherals.skyCtrl3Gamepad) { [unowned self] skyCtrl3Gamepad in
                self.skyCtrl3Gamepad = skyCtrl3Gamepad
                self.sc3ChangeCnt += 1
        }

        virtualGamepadRef =
            remoteControl.getPeripheral(Peripherals.virtualGamepad) { [unowned self] virtualGamepad in
                self.virtualGamepad = virtualGamepad
                self.virtualChangeCnt += 1
        }

        sc3ChangeCnt = 0
        virtualChangeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(skyCtrl3Gamepad, `is`(nilValue()))
        assertThat(virtualGamepad, `is`(nilValue()))

        connect(remoteControl: remoteControl, handle: 1)
        assertThat(skyCtrl3Gamepad, `is`(present()))
        assertThat(virtualGamepad, `is`(present()))
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(virtualChangeCnt, `is`(1))

        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(skyCtrl3Gamepad, `is`(nilValue()))
        assertThat(virtualGamepad, `is`(nilValue()))
        assertThat(sc3ChangeCnt, `is`(2))
        assertThat(virtualChangeCnt, `is`(2))
    }

    func testGrab() {
        connect(remoteControl: remoteControl, handle: 1)

        let navListener: (_ event: VirtualGamepadEvent, _ state: VirtualGamepadEventState) -> Void = { _, _ in }

        assertThat(virtualGamepad!.isGrabbed, `is`(false))
        assertThat(virtualGamepad!.isPreempted, `is`(false))
        assertThat(virtualGamepad!.canGrab, `is`(true))
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(virtualChangeCnt, `is`(1))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(
                buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue))
        let grabResult = virtualGamepad!.grab(listener: navListener)
        assertThat(grabResult, `is`(true))
        assertThat(virtualGamepad!.isGrabbed, `is`(false))
        assertThat(virtualGamepad!.isPreempted, `is`(false))
        assertThat(virtualGamepad!.canGrab, `is`(true))
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(virtualChangeCnt, `is`(1))

        // mock grab state so that we can release afterwards
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperGrabStateEncoder(
            buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue, buttonsState: 0))
        assertThat(virtualGamepad!.isGrabbed, `is`(true))
        assertThat(virtualGamepad!.isPreempted, `is`(false))
        assertThat(virtualGamepad!.canGrab, `is`(false))
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(virtualChangeCnt, `is`(2))

        // release virtual gamepad
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(buttons: 0, axes: 0))
        virtualGamepad?.ungrab()
        assertThat(virtualGamepad!.isGrabbed, `is`(false))
        assertThat(virtualGamepad!.isPreempted, `is`(false))
        assertThat(virtualGamepad!.canGrab, `is`(true))
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(virtualChangeCnt, `is`(3))

        // simulate rc's answer
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabStateEncoder(buttons: 0, axes: 0, buttonsState: 0))
        assertThat(virtualGamepad!.isGrabbed, `is`(false))
        assertThat(virtualGamepad!.isPreempted, `is`(false))
        assertThat(virtualGamepad!.canGrab, `is`(true))
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(virtualChangeCnt, `is`(3))

        // grab every inputs separately with the skyController3 gamepad
        grabAndTest(input: [.frontTopButton], mask: MapperButtonsMask.from(.button0))
        grabAndTest(input: [.frontBottomButton], mask: MapperButtonsMask.from(.button1))
        grabAndTest(input: [.rearLeftButton], mask: MapperButtonsMask.from(.button2))
        grabAndTest(input: [.rearRightButton], mask: MapperButtonsMask.from(.button3))

        grabAndTest(input: [.leftStickHorizontal], buttonsMask: MapperButtonsMask.from(.button4, .button5),
                    axesMask: MapperAxesMask.from(.axis0))
        grabAndTest(input: [.leftStickVertical], buttonsMask: MapperButtonsMask.from(.button6, .button7),
                    axesMask: MapperAxesMask.from(.axis1))
        grabAndTest(input: [.rightStickHorizontal], buttonsMask: MapperButtonsMask.from(.button8, .button9),
                    axesMask: MapperAxesMask.from(.axis2))
        grabAndTest(input: [.rightStickVertical], buttonsMask: MapperButtonsMask.from(.button10, .button11),
                    axesMask: MapperAxesMask.from(.axis3))
        grabAndTest(input: [.leftSlider], buttonsMask: MapperButtonsMask.from(.button12, .button13),
                    axesMask: MapperAxesMask.from(.axis4))
        grabAndTest(input: [.rightSlider], buttonsMask: MapperButtonsMask.from(.button14, .button15),
                    axesMask: MapperAxesMask.from(.axis5))

        // grab all inputs
        grabAndTest(buttons: SkyCtrl3Button.allCases, axes: SkyCtrl3Axis.allCases,
                    buttonsMask: allButtonsMask, axesMask: allAxesMask)

        // mock grab so that we can release afterwards
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperGrabStateEncoder(
            buttons: allButtonsMask.rawValue, axes: allAxesMask.rawValue, buttonsState: 0))
        grabAndTest(buttons: [], axes: [], buttonsMask: MapperButtonsMask.none, axesMask: MapperAxesMask.none)
    }

    func testNavigationEvents() {
        connect(remoteControl: remoteControl, handle: 1)

        let navListener: (_ event: VirtualGamepadEvent, _ state: VirtualGamepadEventState) -> Void = {
            [unowned self] newEvent, newState in
            self.navListenerCount += 1
            self.navEvent = newEvent
            self.navState = newState
        }

        expectCommand(handle: 1,
            expectedCmd: ExpectedCmd.mapperGrab(buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue))
        _ = virtualGamepad!.grab(listener: navListener)

        // mock grab state so that we can receive events
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperGrabStateEncoder(
            buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue, buttonsState: 0))

        // Test that non-navigation buttons never trigger an event
        testNavigationEvents(button: .button0, event: nil)
        testNavigationEvents(button: .button1, event: nil)
        testNavigationEvents(button: .button8, event: nil)
        testNavigationEvents(button: .button9, event: nil)
        testNavigationEvents(button: .button10, event: nil)
        testNavigationEvents(button: .button11, event: nil)
        testNavigationEvents(button: .button12, event: nil)
        testNavigationEvents(button: .button13, event: nil)
        testNavigationEvents(button: .button14, event: nil)
        testNavigationEvents(button: .button15, event: nil)

        // test navigation buttons
        testNavigationEvents(button: .button3, event: .cancel)
        testNavigationEvents(button: .button2, event: .ok)
        testNavigationEvents(button: .button4, event: .left)
        testNavigationEvents(button: .button5, event: .right)
        testNavigationEvents(button: .button6, event: .up)
        testNavigationEvents(button: .button7, event: .down)

        // release navigation
        expectCommand(handle: 1,
            expectedCmd: ExpectedCmd.mapperGrab(
                buttons: MapperButtonsMask.none.rawValue, axes: MapperAxesMask.none.rawValue))
        virtualGamepad!.ungrab()

        // send navigation buttons again, events should not be forwarded
        testNavigationEvents(button: .button3, event: nil)
        testNavigationEvents(button: .button2, event: nil)
        testNavigationEvents(button: .button4, event: nil)
        testNavigationEvents(button: .button5, event: nil)
        testNavigationEvents(button: .button6, event: nil)
        testNavigationEvents(button: .button7, event: nil)
    }

    func testButtonEvents() {
        connect(remoteControl: remoteControl, handle: 1)

        let buttonListener: (_ event: SkyCtrl3ButtonEvent, _ state: SkyCtrl3ButtonEventState) -> Void = {
            [unowned self] (newEvent, newState) in
            self.buttonListenerCount += 1
            self.sc3ButtonEvent = newEvent
            self.sc3ButtonState = newState
        }

        skyCtrl3Gamepad!.buttonEventListener = buttonListener
        // mock grab state so we receive all button events
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperGrabStateEncoder(
            buttons: allButtonsMask.rawValue, axes: allAxesMask.rawValue, buttonsState: 0))

        // ensure events are forwarded for all buttons
        testButtonEvents(button: .button0, event: .frontTopButton)
        testButtonEvents(button: .button1, event: .frontBottomButton)
        testButtonEvents(button: .button2, event: .rearLeftButton)
        testButtonEvents(button: .button3, event: .rearRightButton)
        testButtonEvents(button: .button4, event: .leftStickLeft)
        testButtonEvents(button: .button5, event: .leftStickRight)
        testButtonEvents(button: .button6, event: .leftStickUp)
        testButtonEvents(button: .button7, event: .leftStickDown)
        testButtonEvents(button: .button8, event: .rightStickLeft)
        testButtonEvents(button: .button9, event: .rightStickRight)
        testButtonEvents(button: .button10, event: .rightStickUp)
        testButtonEvents(button: .button11, event: .rightStickDown)
        testButtonEvents(button: .button12, event: .leftSliderDown)
        testButtonEvents(button: .button13, event: .leftSliderUp)
        testButtonEvents(button: .button14, event: .rightSliderUp)
        testButtonEvents(button: .button15, event: .rightSliderDown)

        // make sure that events are not forwarded when listener is null
        skyCtrl3Gamepad!.buttonEventListener = nil
        testButtonEvents(button: .button0, event: nil)
    }

    func testAxisEvents() {
        connect(remoteControl: remoteControl, handle: 1)

        let axisListener: (_ event: SkyCtrl3AxisEvent, _ value: Int) -> Void = {
            [unowned self] (newEvent, newValue) in
            self.axisListenerCount += 1
            self.sc3AxisEvent = newEvent
            self.sc3AxisValue = newValue
        }

        skyCtrl3Gamepad!.axisEventListener = axisListener

        // ensure events are forwarded for all axes
        testAxisEvents(axis: .axis0, event: .leftStickHorizontal)
        testAxisEvents(axis: .axis1, event: .leftStickVertical)
        testAxisEvents(axis: .axis2, event: .rightStickHorizontal)
        testAxisEvents(axis: .axis3, event: .rightStickVertical)
        testAxisEvents(axis: .axis4, event: .leftSlider)
        testAxisEvents(axis: .axis5, event: .rightSlider)

        // make sure that events are not forwarded when listener is null
        skyCtrl3Gamepad!.axisEventListener = nil
        testAxisEvents(axis: .axis0, event: nil)
    }

    func testAppButtonEvents() {
        connect(remoteControl: remoteControl, handle: 1)

        let oberserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GsdkActionGamepadAppAction, object: nil, queue: nil,
            using: { [unowned self] notification in
                self.appAction = notification.userInfo?[GsdkActionGamepadAppActionKey] as? ButtonsMappableAction
        })

        // ensure app actions are forwarded through notification
        testAppButtonEvents(buttonAction: .app0, appAction: .appActionSettings)
        testAppButtonEvents(buttonAction: .app1, appAction: .appAction1)
        testAppButtonEvents(buttonAction: .app2, appAction: .appAction2)
        testAppButtonEvents(buttonAction: .app3, appAction: .appAction3)
        testAppButtonEvents(buttonAction: .app4, appAction: .appAction4)
        testAppButtonEvents(buttonAction: .app5, appAction: .appAction5)
        testAppButtonEvents(buttonAction: .app6, appAction: .appAction6)
        testAppButtonEvents(buttonAction: .app7, appAction: .appAction7)
        testAppButtonEvents(buttonAction: .app8, appAction: .appAction8)
        testAppButtonEvents(buttonAction: .app9, appAction: .appAction9)
        testAppButtonEvents(buttonAction: .app10, appAction: .appAction10)
        testAppButtonEvents(buttonAction: .app11, appAction: .appAction11)
        testAppButtonEvents(buttonAction: .app12, appAction: .appAction12)
        testAppButtonEvents(buttonAction: .app13, appAction: .appAction13)
        testAppButtonEvents(buttonAction: .app14, appAction: .appAction14)
        testAppButtonEvents(buttonAction: .app15, appAction: .appAction15)

        NotificationCenter.default.removeObserver(oberserver)
    }

    func testNavigationGrabState() {
        var allEvents = [VirtualGamepadEvent]()
        var allStates = [VirtualGamepadEventState]()

        connect(remoteControl: remoteControl, handle: 1)

        let navListener: (_ event: VirtualGamepadEvent, _ state: VirtualGamepadEventState) -> Void = { event, state in
            allEvents.append(event)
            allStates.append(state)
        }

        assertThat(virtualChangeCnt, `is`(1))
        assertThat(virtualGamepad!.isGrabbed, `is`(false))
        assertThat(virtualGamepad!.isPreempted, `is`(false))
        assertThat(virtualGamepad!.canGrab, `is`(true))

        // order to grab so that virtual gamepad receives the state
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(
            buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue))
        let grabResult = virtualGamepad!.grab(listener: navListener)
        assertThat(grabResult, `is`(true))

        // ensure grabbing a non navigation button does not grab navigation
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.mapperGrabStateEncoder(
                buttons: UInt(MapperButton.button0.rawValue), axes: 0, buttonsState: 0))
        assertThat(virtualChangeCnt, `is`(1))
        assertThat(virtualGamepad!.isGrabbed, `is`(false))

        // ensure grabbing a non navigation axis does not grab navigation
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.mapperGrabStateEncoder(
                buttons: 0, axes: MapperAxesMask.from(.axis3).rawValue, buttonsState: 0))
        assertThat(virtualChangeCnt, `is`(1))
        assertThat(virtualGamepad!.isGrabbed, `is`(false))

        // ensure grabbing any of the nav buttons makes nav grabbed
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.mapperGrabStateEncoder(
                buttons: UInt(MapperButton.button12.rawValue), axes: 0, buttonsState: 0))
        assertThat(virtualChangeCnt, `is`(2))
        assertThat(virtualGamepad!.isGrabbed, `is`(true))

        // mock release all
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabStateEncoder(buttons: 0, axes: 0, buttonsState: 0))
        assertThat(virtualChangeCnt, `is`(3))
        assertThat(virtualGamepad!.isGrabbed, `is`(false))

        // ensure grabbing any of the navigation axes makes nav grabbed
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.mapperGrabStateEncoder(
                buttons: 0, axes: MapperAxesMask.from(.axis0).rawValue, buttonsState: 0))
        assertThat(virtualChangeCnt, `is`(4))
        assertThat(virtualGamepad!.isGrabbed, `is`(true))

        // mock release all
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabStateEncoder(buttons: 0, axes: 0, buttonsState: 0))
        assertThat(virtualChangeCnt, `is`(5))
        assertThat(virtualGamepad!.isGrabbed, `is`(false))

        // ensure grabbing all of navigation buttons/axes makes navigation grabbed (which is the expected use case)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabStateEncoder(
                buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue, buttonsState: 0))
        assertThat(virtualChangeCnt, `is`(6))
        assertThat(virtualGamepad!.isGrabbed, `is`(true))

        // ensure we receive events for pressed buttons from grab state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabStateEncoder(
                buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue, buttonsState: navButtonMask.rawValue))
        assertThat(virtualChangeCnt, `is`(6))
        assertThat(virtualGamepad!.isGrabbed, `is`(true))
        assertThat(allEvents, containsInAnyOrder(.ok, .cancel, .left, .right, .up, .down))
        assertThat(allStates, everyItem(`is`(.pressed)))
    }

    func testInputsGrabState() {
        connect(remoteControl: remoteControl, handle: 1)

        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(skyCtrl3Gamepad!.grabbedButtons, empty())
        assertThat(skyCtrl3Gamepad!.grabbedAxes, empty())
        assertThat(skyCtrl3Gamepad!.grabbedButtonsState, empty())

        // test each input separately
        testInputsGrabState(buttons: [.frontTopButton], axes: [], buttonEvents: [.frontTopButton],
                            buttonsMask: MapperButtonsMask.from(.button0), axesMask: .none)
        testInputsGrabState(buttons: [.frontBottomButton], axes: [], buttonEvents: [.frontBottomButton],
                            buttonsMask: MapperButtonsMask.from(.button1), axesMask: .none)
        testInputsGrabState(buttons: [.rearLeftButton], axes: [], buttonEvents: [.rearLeftButton],
                            buttonsMask: MapperButtonsMask.from(.button2), axesMask: .none)
        testInputsGrabState(buttons: [.rearRightButton], axes: [], buttonEvents: [.rearRightButton],
                            buttonsMask: MapperButtonsMask.from(.button3), axesMask: .none)

        testInputsGrabState(buttons: [], axes: [.leftStickHorizontal],
                            buttonEvents: [.leftStickLeft, .leftStickRight],
                            buttonsMask: MapperButtonsMask.from(.button4, .button5),
                            axesMask: MapperAxesMask.from(.axis0))
        testInputsGrabState(buttons: [], axes: [.leftStickVertical],
                            buttonEvents: [.leftStickUp, .leftStickDown],
                            buttonsMask: MapperButtonsMask.from(.button6, .button7),
                            axesMask: MapperAxesMask.from(.axis1))
        testInputsGrabState(buttons: [], axes: [.rightStickHorizontal],
                            buttonEvents: [.rightStickLeft, .rightStickRight],
                            buttonsMask: MapperButtonsMask.from(.button8, .button9),
                            axesMask: MapperAxesMask.from(.axis2))
        testInputsGrabState(buttons: [], axes: [.rightStickVertical],
                            buttonEvents: [.rightStickUp, .rightStickDown],
                            buttonsMask: MapperButtonsMask.from(.button10, .button11),
                            axesMask: MapperAxesMask.from(.axis3))
        testInputsGrabState(buttons: [], axes: [.leftSlider],
                            buttonEvents: [.leftSliderUp, .leftSliderDown],
                            buttonsMask: MapperButtonsMask.from(.button12, .button13),
                            axesMask: MapperAxesMask.from(.axis4))
        testInputsGrabState(buttons: [], axes: [.rightSlider],
                            buttonEvents: [.rightSliderUp, .rightSliderDown],
                            buttonsMask: MapperButtonsMask.from(.button14, .button15),
                            axesMask: MapperAxesMask.from(.axis5))

        // test all inputs simultaneously
        testInputsGrabState(buttons: SkyCtrl3Button.allCases, axes: SkyCtrl3Axis.allCases,
                            buttonEvents: allButtonEvents,
                            buttonsMask: allButtonsMask, axesMask: allAxesMask)

        // test no inputs (release all)
        testInputsGrabState(buttons: [], axes: [], buttonEvents: [], buttonsMask: .none, axesMask: .none)

    }

    func testPreemption() {

        let buttonListener: (_ event: SkyCtrl3ButtonEvent, _ state: SkyCtrl3ButtonEventState) -> Void = {
            [unowned self] (newEvent, newState) in
            self.buttonListenerCount += 1
            self.sc3ButtonEvent = newEvent
            self.sc3ButtonState = newState
        }

        let navListener: (_ event: VirtualGamepadEvent, _ state: VirtualGamepadEventState) -> Void = {
            newEvent, newState in
            self.navListenerCount += 1
            self.navEvent = newEvent
            self.navState = newState
        }

        connect(remoteControl: remoteControl, handle: 1)

        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(virtualChangeCnt, `is`(1))

        // virtual gamepad should be released
        assertThat(virtualGamepad!.isGrabbed, `is`(false))
        // no input should be grabbed on sc3 gamepad
        assertThat(skyCtrl3Gamepad!.grabbedButtons, empty())

        skyCtrl3Gamepad!.buttonEventListener = buttonListener

        // grab navigation using virtual gamepad
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(
                buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue))
        let grabResult = virtualGamepad!.grab(listener: navListener)
        assertThat(grabResult, `is`(true))
        assertThat(virtualGamepad!.isGrabbed, `is`(false))
        assertThat(virtualGamepad!.isPreempted, `is`(false))
        assertThat(virtualGamepad!.canGrab, `is`(true))
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(virtualChangeCnt, `is`(1))

        // mock grab state acknowledge
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperGrabStateEncoder(
            buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue, buttonsState: 0))
        assertThat(virtualGamepad!.isGrabbed, `is`(true))
        assertThat(virtualGamepad!.isPreempted, `is`(false))
        assertThat(virtualGamepad!.canGrab, `is`(false))
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(virtualChangeCnt, `is`(2))
        // no input should be grabbed on sc3 gamepad
        assertThat(skyCtrl3Gamepad!.grabbedButtons, empty())

        // ensure we receive navigation events
        testNavigationEvents(button: .button3, event: .cancel)
        // ensure we don't receive non-navigation events
        testNavigationEvents(button: .button0, event: nil)

        // grab some input with sc3 gamepad
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(
                buttons: MapperButtonsMask.from(.button0).rawValue, axes: 0))
        skyCtrl3Gamepad!.grab(buttons: [.frontTopButton], axes: [])

        // mock grab state acknowledge
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperGrabStateEncoder(
            buttons: MapperButtonsMask.from(.button0).rawValue, axes: 0, buttonsState: 0))
        assertThat(sc3ChangeCnt, `is`(2))

        // virtual gamepad should be preempted
        assertThat(virtualChangeCnt, `is`(3))
        assertThat(virtualGamepad!.isGrabbed, `is`(true))
        assertThat(virtualGamepad!.isPreempted, `is`(true))
        assertThat(virtualGamepad!.canGrab, `is`(false))

        // ensure virtual gamepad does not receive any event
        testNavigationEvents(button: .button3, event: nil)
        testNavigationEvents(button: .button2, event: nil)
        testNavigationEvents(button: .button4, event: nil)

        // ensure sc3 gamepad receives grabbed input events
        testButtonEvents(button: .button0, event: .frontTopButton)

        // release grabbed input from sc3 gamepad (we expect a grab request back on navigation masks)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(
            buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue))
        skyCtrl3Gamepad!.grab(buttons: [], axes: [])
        assertNoExpectation()

        // mock grab state acknowledge
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperGrabStateEncoder(
            buttons: navButtonMask.rawValue, axes: navAxisMask.rawValue, buttonsState: 0))
        assertThat(virtualGamepad!.isGrabbed, `is`(true))
        assertThat(virtualGamepad!.isPreempted, `is`(false))
        assertThat(virtualGamepad!.canGrab, `is`(false))
        assertThat(sc3ChangeCnt, `is`(5))
        assertThat(virtualChangeCnt, `is`(4))

        // ensure sc3 gamepad does not receives any event
        testButtonEvents(button: .button0, event: nil)

        // ensure we receive navigation events
        testNavigationEvents(button: .button4, event: .left)
        // ensure we don't receive non-navigation events
        testNavigationEvents(button: .button0, event: nil)

        // grab some input with sc3 gamepad again
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(
            buttons: MapperButtonsMask.from(.button1).rawValue, axes: 0))
        skyCtrl3Gamepad!.grab(buttons: [.frontBottomButton], axes: [])
        // mock grab state acknowledge
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperGrabStateEncoder(
            buttons: MapperButtonsMask.from(.button1).rawValue, axes: 0, buttonsState: 0))

        assertThat(sc3ChangeCnt, `is`(6))
        assertThat(virtualChangeCnt, `is`(5))
        assertThat(virtualGamepad!.isGrabbed, `is`(true))
        assertThat(virtualGamepad!.isPreempted, `is`(true))
        assertThat(virtualGamepad!.canGrab, `is`(false))

        // then ungrab virtual gamepad (we don't expect any grab command to be sent since it is preempted)
        virtualGamepad!.ungrab()

        // virtual gamepad should be released
        assertThat(sc3ChangeCnt, `is`(6))
        assertThat(virtualChangeCnt, `is`(6))
        assertThat(virtualGamepad!.isGrabbed, `is`(false))
        assertThat(virtualGamepad!.isPreempted, `is`(true))
        assertThat(virtualGamepad!.canGrab, `is`(false))

        // ensure sc3 gamepad still receives grabbed input events
        testButtonEvents(button: .button1, event: .frontBottomButton)

        // ensure virtual gamepad does not receive any event
        testNavigationEvents(button: .button2, event: nil)
        testNavigationEvents(button: .button3, event: nil)
        testNavigationEvents(button: .button0, event: nil)

        // ungrab grabbed input from sc3 gamepad (we expect a grab release since virtual gamepad is also released)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(buttons: 0, axes: 0))
        skyCtrl3Gamepad!.grab(buttons: [], axes: [])

        // mock grab state acknowledge
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabStateEncoder(buttons: 0, axes: 0, buttonsState: 0))
        assertThat(sc3ChangeCnt, `is`(9))
        assertThat(virtualChangeCnt, `is`(7))
        assertThat(virtualGamepad!.isGrabbed, `is`(false))
        assertThat(virtualGamepad!.isPreempted, `is`(false))
        assertThat(virtualGamepad!.canGrab, `is`(true))
        // sc3 gamepad inputs should be released too
        assertThat(skyCtrl3Gamepad!.grabbedButtons, empty())
        assertThat(skyCtrl3Gamepad!.grabbedAxes, empty())

        // finally ensure neither virtual nor sc3 gamepad receive events
        testNavigationEvents(button: .button2, event: nil)
        testNavigationEvents(button: .button1, event: nil)
        testNavigationEvents(button: .button0, event: nil)
        testButtonEvents(button: .button2, event: nil)
        testButtonEvents(button: .button1, event: nil)
        testButtonEvents(button: .button0, event: nil)
    }

    func testButtonsMappings() {
        connect(remoteControl: remoteControl, handle: 1)

        // initial state
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(skyCtrl3Gamepad!.supportedDroneModels, empty())
        Drone.Model.allCases.forEach { droneModel in
            assertThat(skyCtrl3Gamepad!.mapping(forModel: droneModel), nilValue())
            return
        }

        // receive supported drone models
        setSupportedDroneModels(.anafi4k, .anafiThermal)

        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(skyCtrl3Gamepad!.supportedDroneModels, containsInAnyOrder(.anafi4k, .anafiThermal))
        Drone.Model.allCases.forEach { droneModel in
            if [.anafi4k, .anafiThermal].contains(droneModel) {
                assertThat(skyCtrl3Gamepad!.mapping(forModel: droneModel), presentAnd(empty()))
            } else {
                assertThat(skyCtrl3Gamepad!.mapping(forModel: droneModel), nilValue())
            }
        }

        // add first
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), action: .cameraExpositionDec,
            buttons: MapperButtonsMask.from(.button3).rawValue,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        // should not be notified until last
        assertThat(sc3ChangeCnt, `is`(1))

        // add item (neither first nor last)
        var buttons = MapperButtonsMask.from(.button0, .button1)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 2, product: UInt(Drone.Model.anafi4k.internalId), action: .app0,
            buttons: buttons.rawValue, listFlagsBitField: 0))

        // add last
        buttons = MapperButtonsMask.from(.button2, .button3)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 3, product: UInt(Drone.Model.anafiThermal.internalId), action: .videoRecord,
            buttons: buttons.rawValue, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        assertThat(sc3ChangeCnt, `is`(2))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k),
                   presentAnd(containsInAnyOrder(
                    isButtonsMappingEntry(
                        forDrone: .anafi4k, action: .decreaseCameraExposition, buttons: [.rearRightButton]),
                    isButtonsMappingEntry(
                        forDrone: .anafi4k, action: .appActionSettings, buttons: [.frontTopButton, .frontBottomButton])
                   )))

        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal),
                   presentAnd(contains(
                    isButtonsMappingEntry(
                        forDrone: .anafiThermal, action: .recordVideo, buttons: [.rearRightButton, .rearLeftButton]))))

        // remove
        buttons = MapperButtonsMask.from(.button0, .button1)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 2, product: UInt(Drone.Model.anafi4k.internalId), action: .app0,
            buttons: buttons.rawValue, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove, .last)))

        assertThat(sc3ChangeCnt, `is`(3))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k),
                   presentAnd(contains(
                    isButtonsMappingEntry(
                        forDrone: .anafi4k, action: .decreaseCameraExposition, buttons: [.rearRightButton]))))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal),
                   presentAnd(contains(
                    isButtonsMappingEntry(
                        forDrone: .anafiThermal, action: .recordVideo, buttons: [.rearRightButton, .rearLeftButton]))))

        // remove with only giving the correct id of the mapping, correct product id, with false values
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 3, product: UInt(Drone.Model.anafi4k.internalId), action: .app1,
            buttons: MapperButtonsMask.from(.button3).rawValue,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove, .last)))

        assertThat(sc3ChangeCnt, `is`(4))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k),
                   presentAnd(contains(
                    isButtonsMappingEntry(
                        forDrone: .anafi4k, action: .decreaseCameraExposition, buttons: [.rearRightButton]))))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal), presentAnd(empty()))

        // empty
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 1, product: 0, action: .app0,
            buttons: buttons.rawValue, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)))
        assertThat(sc3ChangeCnt, `is`(5))
        Drone.Model.allCases.forEach { droneModel in
            if [.anafi4k, .anafiThermal].contains(droneModel) {
                assertThat(skyCtrl3Gamepad!.mapping(forModel: droneModel), presentAnd(empty()))
            } else {
                assertThat(skyCtrl3Gamepad!.mapping(forModel: droneModel), nilValue())
            }
        }

        // insert again
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), action: .cameraExpositionDec,
            buttons: MapperButtonsMask.from(.button3).rawValue,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(sc3ChangeCnt, `is`(6))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k),
                   presentAnd(containsInAnyOrder(
                    isButtonsMappingEntry(
                        forDrone: .anafi4k, action: .decreaseCameraExposition, buttons: [.rearRightButton]))))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal), presentAnd(empty()))

        // test register
        let entry = SkyCtrl3ButtonsMappingEntry(
            droneModel: .anafi4k, action: .appActionSettings, buttonEvents: [.frontTopButton, .frontBottomButton])
        buttons = MapperButtonsMask.from(.button0, .button1)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperMapButtonAction(
                product: UInt(Drone.Model.anafi4k.internalId), action: .app0, buttons: buttons.rawValue))
        skyCtrl3Gamepad!.register(mappingEntry: entry)
        assertNoExpectation()

        // mock answer
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 4, product: UInt(Drone.Model.anafi4k.internalId), action: .app0,
            buttons: buttons.rawValue, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(sc3ChangeCnt, `is`(7))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k),
                   presentAnd(containsInAnyOrder(
                    isButtonsMappingEntry(
                        forDrone: .anafi4k, action: .appActionSettings,
                        buttons: [.frontTopButton, .frontBottomButton]))))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal), presentAnd(empty()))

        // test unregister
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperMapButtonAction(
                product: UInt(Drone.Model.anafi4k.internalId), action: .app0, buttons: 0))
        skyCtrl3Gamepad!.unregister(mappingEntry: entry)
        assertNoExpectation()

        // mock answer
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 4, product: UInt(Drone.Model.anafi4k.internalId), action: .app0,
            buttons: buttons.rawValue, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove, .last)))

        assertThat(sc3ChangeCnt, `is`(8))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k), presentAnd(empty()))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal), presentAnd(empty()))
        assertNoExpectation()
    }

    func testButtonsMappingsTranslations() {
        connect(remoteControl: remoteControl, handle: 1)

        // receive supported drone models
        setSupportedDroneModels(.anafi4k)

        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(skyCtrl3Gamepad!.supportedDroneModels, contains(.anafi4k))

        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button0), event: .frontTopButton)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button1), event: .frontBottomButton)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button2), event: .rearLeftButton)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button3), event: .rearRightButton)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button4), event: .leftStickLeft)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button5), event: .leftStickRight)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button6), event: .leftStickUp)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button7), event: .leftStickDown)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button8), event: .rightStickLeft)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button9), event: .rightStickRight)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button10), event: .rightStickUp)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button11), event: .rightStickDown)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button12), event: .leftSliderDown)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button13), event: .leftSliderUp)
        testButtonsMappingsTranslations(buttonMask: MapperButtonsMask.from(.button14), event: .rightSliderUp)

        testButtonsMappingsTranslations(arsdkAction: .app0, gsdkAction: .appActionSettings)
        testButtonsMappingsTranslations(arsdkAction: .app1, gsdkAction: .appAction1)
        testButtonsMappingsTranslations(arsdkAction: .app2, gsdkAction: .appAction2)
        testButtonsMappingsTranslations(arsdkAction: .app3, gsdkAction: .appAction3)
        testButtonsMappingsTranslations(arsdkAction: .app4, gsdkAction: .appAction4)
        testButtonsMappingsTranslations(arsdkAction: .app5, gsdkAction: .appAction5)
        testButtonsMappingsTranslations(arsdkAction: .app6, gsdkAction: .appAction6)
        testButtonsMappingsTranslations(arsdkAction: .app7, gsdkAction: .appAction7)
        testButtonsMappingsTranslations(arsdkAction: .app8, gsdkAction: .appAction8)
        testButtonsMappingsTranslations(arsdkAction: .app9, gsdkAction: .appAction9)
        testButtonsMappingsTranslations(arsdkAction: .app10, gsdkAction: .appAction10)
        testButtonsMappingsTranslations(arsdkAction: .app11, gsdkAction: .appAction11)
        testButtonsMappingsTranslations(arsdkAction: .app12, gsdkAction: .appAction12)
        testButtonsMappingsTranslations(arsdkAction: .app13, gsdkAction: .appAction13)
        testButtonsMappingsTranslations(arsdkAction: .app14, gsdkAction: .appAction14)
        testButtonsMappingsTranslations(arsdkAction: .app15, gsdkAction: .appAction15)
        testButtonsMappingsTranslations(arsdkAction: .cameraExpositionDec, gsdkAction: .decreaseCameraExposition)
        testButtonsMappingsTranslations(arsdkAction: .cameraExpositionInc, gsdkAction: .increaseCameraExposition)
        testButtonsMappingsTranslations(arsdkAction: .centerCamera, gsdkAction: .centerCamera)
        testButtonsMappingsTranslations(arsdkAction: .emergency, gsdkAction: .emergencyCutOff)
        testButtonsMappingsTranslations(arsdkAction: .flipBack, gsdkAction: .flipBack)
        testButtonsMappingsTranslations(arsdkAction: .flipFront, gsdkAction: .flipFront)
        testButtonsMappingsTranslations(arsdkAction: .flipLeft, gsdkAction: .flipLeft)
        testButtonsMappingsTranslations(arsdkAction: .flipRight, gsdkAction: .flipRight)
        testButtonsMappingsTranslations(arsdkAction: .returnHome, gsdkAction: .returnHome)
        testButtonsMappingsTranslations(arsdkAction: .takePicture, gsdkAction: .takePicture)
        testButtonsMappingsTranslations(arsdkAction: .takeoffLand, gsdkAction: .takeOffOrLand)
        testButtonsMappingsTranslations(arsdkAction: .videoRecord, gsdkAction: .recordVideo)
        testButtonsMappingsTranslations(arsdkAction: .cameraAuto, gsdkAction: .photoOrVideo)
        testButtonsMappingsTranslations(arsdkAction: .cycleHud, gsdkAction: .cycleHud)
    }

    func testAxisMappings() {
        connect(remoteControl: remoteControl, handle: 1)

        // initial state
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(skyCtrl3Gamepad!.supportedDroneModels, empty())
        Drone.Model.allCases.forEach { droneModel in
            assertThat(skyCtrl3Gamepad!.mapping(forModel: droneModel), nilValue())
            return
        }

        // receive supported drone models
        setSupportedDroneModels(.anafi4k, .anafiThermal)

        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(skyCtrl3Gamepad!.supportedDroneModels, containsInAnyOrder(.anafi4k, .anafiThermal))
        Drone.Model.allCases.forEach { droneModel in
            if [.anafi4k, .anafiThermal].contains(droneModel) {
                assertThat(skyCtrl3Gamepad!.mapping(forModel: droneModel), presentAnd(empty()))
            } else {
                assertThat(skyCtrl3Gamepad!.mapping(forModel: droneModel), nilValue())
            }
        }

        // add first
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperAxisMappingItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), action: .roll,
            axis: MapperAxis.axis0.rawValue, buttons: MapperButtonsMask.from(.button3).rawValue,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        // should not be notified until last
        assertThat(sc3ChangeCnt, `is`(1))

        // add item (neither first nor last)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperAxisMappingItemEncoder(
            uid: 2, product: UInt(Drone.Model.anafi4k.internalId), action: .cameraPan,
            axis: MapperAxis.axis2.rawValue, buttons: MapperButtonsMask.none.rawValue,
            listFlagsBitField: 0))

        // add last
        var buttons = MapperButtonsMask.from(.button3, .button2)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperAxisMappingItemEncoder(
            uid: 3, product: UInt(Drone.Model.anafiThermal.internalId), action: .cameraTilt,
            axis: MapperAxis.axis3.rawValue, buttons: buttons.rawValue,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        assertThat(sc3ChangeCnt, `is`(2))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k),
                   presentAnd(containsInAnyOrder(
                    isAxisMappingEntry(
                        forDrone: .anafi4k, action: .controlRoll, axis: .leftStickHorizontal,
                        buttons: [.rearRightButton]),
                    isAxisMappingEntry(
                        forDrone: .anafi4k, action: .panCamera, axis: .rightStickHorizontal, buttons: []))))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal),
                   presentAnd(contains(
                    isAxisMappingEntry(
                        forDrone: .anafiThermal, action: .tiltCamera, axis: .rightStickVertical,
                        buttons: [.rearRightButton, .rearLeftButton]))))

        // remove
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperAxisMappingItemEncoder(
            uid: 3, product: UInt(Drone.Model.anafiThermal.internalId), action: .cameraTilt,
            axis: MapperAxis.axis3.rawValue, buttons: buttons.rawValue,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove, .last)))

        assertThat(sc3ChangeCnt, `is`(3))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k),
                   presentAnd(containsInAnyOrder(
                    isAxisMappingEntry(
                        forDrone: .anafi4k, action: .controlRoll, axis: .leftStickHorizontal,
                        buttons: [.rearRightButton]),
                    isAxisMappingEntry(
                        forDrone: .anafi4k, action: .panCamera, axis: .rightStickHorizontal, buttons: []))))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal), presentAnd(empty()))

        // empty
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperAxisMappingItemEncoder(
            uid: 0, product: UInt(Drone.Model.anafiThermal.internalId), action: .cameraTilt,
            axis: MapperAxis.axis3.rawValue, buttons: buttons.rawValue,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)))

        assertThat(sc3ChangeCnt, `is`(4))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k), presentAnd(empty()))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal), presentAnd(empty()))

        // insert again
        buttons = MapperButtonsMask.from(.button12, .button13)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperAxisMappingItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafiThermal.internalId), action: .yaw,
            axis: MapperAxis.axis4.rawValue, buttons: buttons.rawValue,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(sc3ChangeCnt, `is`(5))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal),
                   presentAnd(contains(
                    isAxisMappingEntry(
                        forDrone: .anafiThermal, action: .controlYawRotationSpeed, axis: .leftSlider,
                        buttons: [.leftSliderUp, .leftSliderDown]))))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k), presentAnd(empty()))

        // test register
        let entry = SkyCtrl3AxisMappingEntry(
            droneModel: .anafi4k, action: .controlRoll, axisEvent: .leftStickHorizontal,
            buttonEvents: [.rearRightButton, .rearLeftButton])
        buttons = MapperButtonsMask.from(.button2, .button3)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperMapAxisAction(
                product: UInt(Drone.Model.anafi4k.internalId), action: .roll, axis: MapperAxis.axis0.rawValue,
                buttons: buttons.rawValue))
        skyCtrl3Gamepad!.register(mappingEntry: entry)
        assertNoExpectation()

        // mock answer
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperAxisMappingItemEncoder(
            uid: 4, product: UInt(Drone.Model.anafi4k.internalId), action: .roll, axis: MapperAxis.axis0.rawValue,
            buttons: buttons.rawValue, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(sc3ChangeCnt, `is`(6))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k),
                   presentAnd(containsInAnyOrder(
                    isAxisMappingEntry(
                        forDrone: .anafi4k, action: .controlRoll, axis: .leftStickHorizontal,
                        buttons: [.rearLeftButton, .rearRightButton]))))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal), presentAnd(empty()))

        // test unregister
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperMapAxisAction(
                product: UInt(Drone.Model.anafi4k.internalId), action: .roll, axis: -1, buttons: 0))
        skyCtrl3Gamepad!.unregister(mappingEntry: entry)
        assertNoExpectation()

        // mock answer
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperAxisMappingItemEncoder(
            uid: 4, product: UInt(Drone.Model.anafi4k.internalId), action: .roll, axis: 0,
            buttons: buttons.rawValue, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove, .last)))

        assertThat(sc3ChangeCnt, `is`(7))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k), presentAnd(empty()))
        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafiThermal), presentAnd(empty()))
    }

    func testAxisMappingsTranslations() {
        connect(remoteControl: remoteControl, handle: 1)

        // receive supported drone models
        setSupportedDroneModels(.anafi4k)

        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(skyCtrl3Gamepad!.supportedDroneModels, contains(.anafi4k))

        testAxisMappingsTranslations(axis: .axis0, event: .leftStickHorizontal)
        testAxisMappingsTranslations(axis: .axis1, event: .leftStickVertical)
        testAxisMappingsTranslations(axis: .axis2, event: .rightStickHorizontal)
        testAxisMappingsTranslations(axis: .axis3, event: .rightStickVertical)
        testAxisMappingsTranslations(axis: .axis4, event: .leftSlider)
        testAxisMappingsTranslations(axis: .axis5, event: .rightSlider)

        testAxisMappingsTranslations(arsdkAction: .cameraPan, gsdkAction: .panCamera)
        testAxisMappingsTranslations(arsdkAction: .cameraTilt, gsdkAction: .tiltCamera)
        testAxisMappingsTranslations(arsdkAction: .gaz, gsdkAction: .controlThrottle)
        testAxisMappingsTranslations(arsdkAction: .pitch, gsdkAction: .controlPitch)
        testAxisMappingsTranslations(arsdkAction: .roll, gsdkAction: .controlRoll)
        testAxisMappingsTranslations(arsdkAction: .yaw, gsdkAction: .controlYawRotationSpeed)
    }

    func testResetMappings() {
        connect(remoteControl: remoteControl, handle: 1)

        // receive supported drone models
        setSupportedDroneModels(.anafiThermal, .anafi4k)

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperResetMapping(product: 0))
        skyCtrl3Gamepad!.resetAllMappings()

        testResetMappings(droneModel: .anafiThermal)
        testResetMappings(droneModel: .anafi4k)
    }

    func testActiveProduct() {
        connect(remoteControl: remoteControl, handle: 1)

        // ensure no active product until notified
        assertThat(skyCtrl3Gamepad!.activeDroneModel, nilValue())
        assertThat(sc3ChangeCnt, `is`(1))

        // notify new active product
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperActiveProductEncoder(product: UInt(Drone.Model.anafi4k.internalId)))
        assertThat(skyCtrl3Gamepad!.activeDroneModel, presentAnd(`is`(.anafi4k)))
        assertThat(sc3ChangeCnt, `is`(2))

        // receive already active product should do nothing
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperActiveProductEncoder(product: UInt(Drone.Model.anafi4k.internalId)))
        assertThat(skyCtrl3Gamepad!.activeDroneModel, presentAnd(`is`(.anafi4k)))
        assertThat(sc3ChangeCnt, `is`(2))
    }

    func testExpoMap() {
        connect(remoteControl: remoteControl, handle: 1)

        // ensure no supported products and no interpolators
        assertThat(skyCtrl3Gamepad!.supportedDroneModels, empty())
        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafi4k), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .rightStickHorizontal, droneModel: .anafi4k), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickVertical, droneModel: .anafiThermal), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftSlider, droneModel: .anafiThermal), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .rightSlider, droneModel: .anafiThermal), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafiThermal), nilValue())

        // add first
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperExpoMapItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), axis: MapperAxis.axis0.rawValue, expo: .linear,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        // should not be notified until 'last'
        assertThat(sc3ChangeCnt, `is`(1))

        // add item (neither first, nor last)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperExpoMapItemEncoder(
            uid: 2, product: UInt(Drone.Model.anafiThermal.internalId), axis: MapperAxis.axis1.rawValue, expo: .expo0,
            listFlagsBitField: 0))
        assertThat(sc3ChangeCnt, `is`(1))

        // add last
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperExpoMapItemEncoder(
            uid: 3, product: UInt(Drone.Model.anafiThermal.internalId), axis: MapperAxis.axis4.rawValue, expo: .expo4,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        assertThat(sc3ChangeCnt, `is`(2))
        // map expo item also set the supported drone models
        assertThat(skyCtrl3Gamepad!.supportedDroneModels, containsInAnyOrder(.anafi4k, .anafiThermal))
        assertThat(skyCtrl3Gamepad!.supportedDroneModels.count, `is`(2))

        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafi4k),
                   presentAnd(`is`(.linear)))
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .rightStickHorizontal, droneModel: .anafi4k), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickVertical, droneModel: .anafiThermal),
                   presentAnd(`is`(.lightExponential)))
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftSlider, droneModel: .anafiThermal),
                   presentAnd(`is`(.strongestExponential)))
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafiThermal), nilValue())

        // remove
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperExpoMapItemEncoder(
            uid: 1, product: 0, axis: 0, expo: .expo0,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove, .last)))
        assertThat(sc3ChangeCnt, `is`(3))

        assertThat(skyCtrl3Gamepad!.supportedDroneModels, contains(.anafiThermal))
        assertThat(skyCtrl3Gamepad!.supportedDroneModels.count, `is`(1))

        // interpolator should be removed
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafi4k), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .rightStickHorizontal, droneModel: .anafi4k), nilValue())

        // others should not have changed
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickVertical, droneModel: .anafiThermal),
                   presentAnd(`is`(.lightExponential)))
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftSlider, droneModel: .anafiThermal),
                   presentAnd(`is`(.strongestExponential)))
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafiThermal), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafi4k),
                   nilValue())

        // empty
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperExpoMapItemEncoder(
            uid: 0, product: 0, axis: 0, expo: .expo0,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)))
        assertThat(sc3ChangeCnt, `is`(4))
        assertThat(skyCtrl3Gamepad!.supportedDroneModels, empty())

        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafi4k), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .rightStickHorizontal, droneModel: .anafi4k), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickVertical, droneModel: .anafiThermal), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftSlider, droneModel: .anafiThermal), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .rightSlider, droneModel: .anafiThermal), nilValue())
        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftStickHorizontal, droneModel: .anafiThermal), nilValue())

        // test listFlags
        // first
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperExpoMapItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), axis: MapperAxis.axis0.rawValue, expo: .linear,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        // test axis values are mapped properly
        testExpoMap(mapperAxis: .axis0, axis: .leftStickHorizontal)
        testExpoMap(mapperAxis: .axis1, axis: .leftStickVertical)
        testExpoMap(mapperAxis: .axis2, axis: .rightStickHorizontal)
        testExpoMap(mapperAxis: .axis3, axis: .rightStickVertical)
        testExpoMap(mapperAxis: .axis4, axis: .leftSlider)
        testExpoMap(mapperAxis: .axis5, axis: .rightSlider)

        // test AxisInterpolator values are mapped properly
        testExpoMap(arsdkExpo: .linear, gsdkExpo: .linear)
        testExpoMap(arsdkExpo: .expo0, gsdkExpo: .lightExponential)
        testExpoMap(arsdkExpo: .expo1, gsdkExpo: .mediumExponential)
        testExpoMap(arsdkExpo: .expo2, gsdkExpo: .strongExponential)
        testExpoMap(arsdkExpo: .expo4, gsdkExpo: .strongestExponential)
    }

    func testSetExpo() {
        connect(remoteControl: remoteControl, handle: 1)

        setSupportedDroneModels(.anafi4k, .anafiThermal)

        // models test
        testSetExpo(model: .anafi4k)
        testSetExpo(model: .anafiThermal)

        // axes test
        testSetExpo(axis: .leftStickHorizontal, mapperAxis: .axis0)
        testSetExpo(axis: .leftStickVertical, mapperAxis: .axis1)
        testSetExpo(axis: .rightStickHorizontal, mapperAxis: .axis2)
        testSetExpo(axis: .rightStickVertical, mapperAxis: .axis3)
        testSetExpo(axis: .leftSlider, mapperAxis: .axis4)
        testSetExpo(axis: .rightSlider, mapperAxis: .axis5)

        // interpolators test
        testSetExpo(interpolator: .linear, expoType: .linear)
        testSetExpo(interpolator: .lightExponential, expoType: .expo0)
        testSetExpo(interpolator: .mediumExponential, expoType: .expo1)
        testSetExpo(interpolator: .strongExponential, expoType: .expo2)
        testSetExpo(interpolator: .strongestExponential, expoType: .expo4)
    }

    func testInvertedMap() {
        connect(remoteControl: remoteControl, handle: 1)

        assertThat(sc3ChangeCnt, `is`(1))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k), nilValue())
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafiThermal), nilValue())

        setSupportedDroneModels(.anafi4k, .anafiThermal)

        // when drones are supported, set should be empty
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k), presentAnd(empty()))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafiThermal), presentAnd(empty()))

        // add first
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), axis: MapperAxis.axis0.rawValue, inverted: 1,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        // should not be notified until 'last'
        assertThat(sc3ChangeCnt, `is`(1))

        // add last
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 2, product: UInt(Drone.Model.anafiThermal.internalId), axis: MapperAxis.axis0.rawValue, inverted: 0,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        assertThat(sc3ChangeCnt, `is`(2))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k),
                   presentAnd(contains(`is`(.leftStickHorizontal))))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafiThermal), presentAnd(empty()))

        // remove
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 3, product: 0, axis: 0, inverted: 1,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove, .last)))

        assertThat(sc3ChangeCnt, `is`(3))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k),
                   presentAnd(contains(`is`(.leftStickHorizontal))))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafiThermal), presentAnd(empty()))

        // change a non-reverted axis into a reverted
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 2, product: UInt(Drone.Model.anafiThermal.internalId), axis: MapperAxis.axis0.rawValue, inverted: 1,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        assertThat(sc3ChangeCnt, `is`(4))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k),
                   presentAnd(contains(`is`(.leftStickHorizontal))))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafiThermal),
                   presentAnd(contains(`is`(.leftStickHorizontal))))

        // change a reverted axis into a non-reverted
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), axis: MapperAxis.axis0.rawValue, inverted: 0,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        assertThat(sc3ChangeCnt, `is`(5))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k), presentAnd(empty()))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafiThermal),
                   presentAnd(contains(`is`(.leftStickHorizontal))))

        // empty
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 0, product: 0, axis: 0, inverted: 0,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)))

        assertThat(sc3ChangeCnt, `is`(6))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k), presentAnd(empty()))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafiThermal), presentAnd(empty()))

        // test listFlags
        // first
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), axis: MapperAxis.axis0.rawValue, inverted: 1,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
        // first and last
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 3, product: UInt(Drone.Model.anafiThermal.internalId), axis: MapperAxis.axis1.rawValue, inverted: 1,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(sc3ChangeCnt, `is`(7))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k), presentAnd(empty()))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafiThermal),
                   presentAnd(contains(`is`(.leftStickVertical))))

        // test axis values are mapped properly
        testInvertedMap(mapperAxis: .axis0, axis: .leftStickHorizontal)
        testInvertedMap(mapperAxis: .axis1, axis: .leftStickVertical)
        testInvertedMap(mapperAxis: .axis2, axis: .rightStickHorizontal)
        testInvertedMap(mapperAxis: .axis3, axis: .rightStickVertical)
        testInvertedMap(mapperAxis: .axis4, axis: .leftSlider)
        testInvertedMap(mapperAxis: .axis5, axis: .rightSlider)
    }

    func testSetInverted() {
        connect(remoteControl: remoteControl, handle: 1)

        setSupportedDroneModels(.anafi4k, .anafiThermal)
        setDefaultRevertedAxes(forDroneModels: .anafi4k, .anafiThermal)

        // models test
        testSetInverted(model: .anafi4k)
        testSetInverted(model: .anafiThermal)

        // axes test (also tests inverted flag)
        testSetInverted(mapperAxis: .axis0, axis: .leftStickHorizontal)
        testSetInverted(mapperAxis: .axis1, axis: .leftStickVertical)
        testSetInverted(mapperAxis: .axis2, axis: .rightStickHorizontal)
        testSetInverted(mapperAxis: .axis3, axis: .rightStickVertical)
        testSetInverted(mapperAxis: .axis4, axis: .leftSlider)
        testSetInverted(mapperAxis: .axis5, axis: .rightSlider)
    }
}

// Extension that provides functions called by test functions
extension Sc3GamepadTests {

    func setSupportedDroneModels(_ droneModels: Drone.Model...) {
        let previousChangeCount = sc3ChangeCnt

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperExpoMapItemEncoder(
            uid: 1, product: 0, axis: 0, expo: .expo2,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)))
        var uid: UInt = 1
        droneModels.forEach { droneModel in
            mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperExpoMapItemEncoder(
                uid: uid, product: UInt(droneModel.internalId), axis: MapperAxis.axis3.rawValue,
                expo: .expo2, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
            uid += 1
        }
        sc3ChangeCnt = previousChangeCount
    }

    func setDefaultRevertedAxes(forDroneModels droneModels: Drone.Model...) {
        let previousChangeCount = sc3ChangeCnt

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 1, product: 0, axis: 0, inverted: 0,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)))
        var uid: UInt = 1
        droneModels.forEach { droneModel in
            mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
                uid: uid, product: UInt(droneModel.internalId), axis: MapperAxis.axis3.rawValue,
                inverted: 0, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
            uid += 1
        }
        sc3ChangeCnt = previousChangeCount
    }

    func grabAndTest(input: Set<SkyCtrl3Button>, mask: MapperButtonsMask) {
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(buttons: mask.rawValue, axes: 0))
        skyCtrl3Gamepad!.grab(buttons: input, axes: [])
        assertNoExpectation()
    }

    func grabAndTest(input: Set<SkyCtrl3Axis>, buttonsMask: MapperButtonsMask, axesMask: MapperAxesMask) {
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(
            buttons: buttonsMask.rawValue, axes: axesMask.rawValue))
        skyCtrl3Gamepad!.grab(buttons: [], axes: input)
        assertNoExpectation()
    }

    func grabAndTest(buttons: Set<SkyCtrl3Button>, axes: Set<SkyCtrl3Axis>,
                     buttonsMask: MapperButtonsMask, axesMask: MapperAxesMask) {
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperGrab(
            buttons: buttonsMask.rawValue, axes: axesMask.rawValue))
        skyCtrl3Gamepad!.grab(buttons: buttons, axes: axes)
        assertNoExpectation()
    }

    func testNavigationEvents(button: MapperButton, event expectedEvent: VirtualGamepadEvent?) {
        resetListenersVars()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabButtonEventEncoder(button: UInt(button.rawValue), event: .press))
        assertThat(navListenerCount, `is`((expectedEvent == nil) ? 0 : 1))
        assertThat(navEvent, (expectedEvent == nil) ? nilValue() : presentAnd(`is`(expectedEvent!)))
        assertThat(navState, `is`((expectedEvent == nil) ? nilValue() : presentAnd(`is`(.pressed))))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabButtonEventEncoder(button: UInt(button.rawValue), event: .release))
        assertThat(navListenerCount, `is`((expectedEvent == nil) ? 0 : 2))
        assertThat(navEvent, (expectedEvent == nil) ? nilValue() : presentAnd(`is`(expectedEvent!)))
        assertThat(navState, `is`((expectedEvent == nil) ? nilValue() : presentAnd(`is`(.released))))
    }

    func testButtonEvents(button: MapperButton, event expectedEvent: SkyCtrl3ButtonEvent?) {
        resetListenersVars()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabButtonEventEncoder(button: UInt(button.rawValue), event: .press))
        assertThat(buttonListenerCount, `is`((expectedEvent == nil) ? 0 : 1))
        assertThat(sc3ButtonEvent, (expectedEvent == nil) ? nilValue() : presentAnd(`is`(expectedEvent!)))
        assertThat(sc3ButtonState, `is`((expectedEvent == nil) ? nilValue() : presentAnd(`is`(.pressed))))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabButtonEventEncoder(button: UInt(button.rawValue), event: .release))
        assertThat(buttonListenerCount, `is`((expectedEvent == nil) ? 0 : 2))
        assertThat(sc3ButtonEvent, (expectedEvent == nil) ? nilValue() : presentAnd(`is`(expectedEvent!)))
        assertThat(sc3ButtonState, `is`((expectedEvent == nil) ? nilValue() : presentAnd(`is`(.released))))
    }

    func testAxisEvents(axis: MapperAxis, event expectedEvent: SkyCtrl3AxisEvent?) {
        resetListenersVars()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabAxisEventEncoder(axis: UInt(axis.rawValue), value: 42))
        assertThat(axisListenerCount, `is`((expectedEvent == nil) ? 0 : 1))
        assertThat(sc3AxisEvent, (expectedEvent == nil) ? nilValue() : presentAnd(`is`(expectedEvent!)))
        assertThat(sc3AxisValue, `is`((expectedEvent == nil) ? nilValue() : presentAnd(`is`(42))))
    }

    func testAppButtonEvents(
        buttonAction: ArsdkFeatureMapperButtonAction, appAction expectedAppAction: ButtonsMappableAction) {
        resetListenersVars()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperApplicationButtonEventEncoder(action: buttonAction))
        assertThat(appAction, presentAnd(`is`(expectedAppAction)))
    }

    func testInputsGrabState(
        buttons: Set<SkyCtrl3Button>, axes: Set<SkyCtrl3Axis>,
        buttonEvents: Set<SkyCtrl3ButtonEvent>, buttonsMask: MapperButtonsMask, axesMask: MapperAxesMask) {

        let changeCnt = sc3ChangeCnt

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.mapperGrabStateEncoder(
                buttons: buttonsMask.rawValue, axes: axesMask.rawValue, buttonsState: 0))
        assertThat(sc3ChangeCnt, `is`(changeCnt + 1))
        assertThat(skyCtrl3Gamepad!.grabbedButtons, `is`(buttons))
        assertThat(skyCtrl3Gamepad!.grabbedAxes, `is`(axes))
        for (event, state) in skyCtrl3Gamepad!.grabbedButtonsState {
            assertThat(buttonEvents, hasItem(event))
            assertThat(state, `is`(.released))
        }

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperGrabStateEncoder(
                buttons: buttonsMask.rawValue, axes: axesMask.rawValue, buttonsState: buttonsMask.rawValue))
        // if ungrabbed, it should not call the listener again
        if buttons.isEmpty && axes.isEmpty {
            assertThat(sc3ChangeCnt, `is`(changeCnt + 1))
        } else {
            assertThat(sc3ChangeCnt, `is`(changeCnt + 2))
        }
        assertThat(skyCtrl3Gamepad!.grabbedButtons, `is`(buttons))
        assertThat(skyCtrl3Gamepad!.grabbedAxes, `is`(axes))
        for (event, state) in skyCtrl3Gamepad!.grabbedButtonsState {
            assertThat(buttonEvents, hasItem(event))
            assertThat(state, `is`(.pressed))
        }
    }

    // test that receiving a mapping using a given buttonMask does create a mapping entry with a given button event.
    // For this to work, `.anafi4k` drone model should be in the `supportedDroneModels`
    func testButtonsMappingsTranslations(buttonMask: MapperButtonsMask, event: SkyCtrl3ButtonEvent) {
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), action: .app0,
            buttons: buttonMask.rawValue,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k), presentAnd(contains(has(buttons: [event]))))
    }

    // test that receiving a mapping for a given arsdkAction does create a mapping entry for a given action.
    // For this to work, `.anafi4k` drone model should be in the `supportedDroneModels`
    func testButtonsMappingsTranslations(
        arsdkAction: ArsdkFeatureMapperButtonAction, gsdkAction: ButtonsMappableAction) {
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperButtonMappingItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), action: arsdkAction,
            buttons: MapperButtonsMask.from(.button0).rawValue,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k), presentAnd(contains(has(action: gsdkAction))))
    }

    // test that receiving a mapping using a given axisMask does create a mapping entry with a given axis event.
    // For this to work, `.anafi4k` drone model should be in the `supportedDroneModels`
    func testAxisMappingsTranslations(axis: MapperAxis, event: SkyCtrl3AxisEvent) {
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperAxisMappingItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), action: .roll, axis: axis.rawValue,
            buttons: 0, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k), presentAnd(contains(has(axis: event))))
    }

    // test that receiving a mapping for a given arsdkAction does create a mapping entry for a given action.
    // For this to work, `.anafi4k` drone model should be in the `supportedDroneModels`
    func testAxisMappingsTranslations(
        arsdkAction: ArsdkFeatureMapperAxisAction, gsdkAction: AxisMappableAction) {
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperAxisMappingItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), action: arsdkAction,
            axis: MapperAxis.axis0.rawValue, buttons: 0,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(skyCtrl3Gamepad!.mapping(forModel: .anafi4k), presentAnd(contains(has(action: gsdkAction))))
    }

    // for this to work, the given drone model should be in the `supportedDroneModels`
    func testResetMappings(droneModel: Drone.Model) {
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperResetMapping(
            product: UInt(droneModel.internalId)))
        skyCtrl3Gamepad!.resetMapping(forModel: droneModel)

        assertNoExpectation()
    }

    func testExpoMap(mapperAxis: MapperAxis, axis: SkyCtrl3Axis) {
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperExpoMapItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), axis: mapperAxis.rawValue, expo: .linear,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: axis, droneModel: .anafi4k), presentAnd(`is`(.linear)))
    }

    func testExpoMap(arsdkExpo: ArsdkFeatureMapperExpoType, gsdkExpo: AxisInterpolator) {
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperExpoMapItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), axis: MapperAxis.axis4.rawValue,
            expo: arsdkExpo, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(skyCtrl3Gamepad!.interpolator(forAxis: .leftSlider, droneModel: .anafi4k),
                   presentAnd(`is`(gsdkExpo)))
    }

    func testSetExpo(model: Drone.Model) {
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperSetExpo(
                product: UInt(model.internalId), axis: MapperAxis.axis4.rawValue, expo: .linear))
        skyCtrl3Gamepad!.set(interpolator: .linear, forAxis: .leftSlider, droneModel: model)

        assertNoExpectation()
    }

    func testSetExpo(axis: SkyCtrl3Axis, mapperAxis: MapperAxis) {
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperSetExpo(
                product: UInt(Drone.Model.anafi4k.internalId), axis: mapperAxis.rawValue, expo: .linear))
        skyCtrl3Gamepad!.set(interpolator: .linear, forAxis: axis, droneModel: .anafi4k)

        assertNoExpectation()
    }

    func testSetExpo(interpolator: AxisInterpolator, expoType: ArsdkFeatureMapperExpoType) {
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperSetExpo(
                product: UInt(Drone.Model.anafi4k.internalId), axis: MapperAxis.axis4.rawValue, expo: expoType))
        skyCtrl3Gamepad!.set(interpolator: interpolator, forAxis: .leftSlider, droneModel: .anafi4k)

        assertNoExpectation()
    }

    func testInvertedMap(mapperAxis: MapperAxis, axis: SkyCtrl3Axis) {
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), axis: mapperAxis.rawValue, inverted: 1,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k), presentAnd(contains(`is`(axis))))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
            uid: 1, product: UInt(Drone.Model.anafi4k.internalId), axis: mapperAxis.rawValue, inverted: 0,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))
        assertThat(skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k), presentAnd(empty()))
    }

    func testSetInverted(model: Drone.Model) {
        let reversed = skyCtrl3Gamepad!.reversedAxes(forDroneModel: model)!.contains(.leftSlider)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperSetInverted(
                product: UInt(model.internalId), axis: MapperAxis.axis4.rawValue, inverted: reversed ? 0 : 1))
        skyCtrl3Gamepad!.reverse(axis: .leftSlider, forDroneModel: model)

        assertNoExpectation()
    }

    func testSetInverted(mapperAxis: MapperAxis, axis: SkyCtrl3Axis) {
        let reversed = skyCtrl3Gamepad!.reversedAxes(forDroneModel: .anafi4k)!.contains(axis)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperSetInverted(
                product: UInt(Drone.Model.anafi4k.internalId), axis: mapperAxis.rawValue, inverted: reversed ? 0 : 1))
        skyCtrl3Gamepad!.reverse(axis: axis, forDroneModel: .anafi4k)

        assertNoExpectation()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mapperInvertedMapItemEncoder(
                uid: 1, product: UInt(Drone.Model.anafi4k.internalId), axis: mapperAxis.rawValue,
                inverted: reversed ? 0 : 1,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperSetInverted(
                product: UInt(Drone.Model.anafi4k.internalId), axis: mapperAxis.rawValue, inverted: reversed ? 1 : 0))
        skyCtrl3Gamepad!.reverse(axis: axis, forDroneModel: .anafi4k)

        assertNoExpectation()
    }

    func testVolatileMapping() {
        connect(remoteControl: remoteControl, handle: 1)
        assertThat(skyCtrl3Gamepad?.volatileMappingSetting, nilValue())
        assertThat(sc3ChangeCnt, `is`(1))
        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(sc3ChangeCnt, `is`(2))
        connect(remoteControl: remoteControl, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperVolatileMappingStateEncoder(active: 0))
        }
        assertThat(sc3ChangeCnt, `is`(3))
        assertThat(skyCtrl3Gamepad?.volatileMappingSetting!.value, `is`(false))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.mapperEnterVolatileMapping())
        skyCtrl3Gamepad?.volatileMappingSetting!.value = true
        assertThat(sc3ChangeCnt, `is`(4))
        assertThat(skyCtrl3Gamepad?.volatileMappingSetting!.value, `is`(true))
        assertThat(skyCtrl3Gamepad?.volatileMappingSetting!.updating, `is`(true))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mapperVolatileMappingStateEncoder(active: 1))

        assertThat(skyCtrl3Gamepad?.volatileMappingSetting!.value, `is`(true))
        assertThat(skyCtrl3Gamepad?.volatileMappingSetting!.updating, `is`(false))

        assertThat(sc3ChangeCnt, `is`(4))
        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(skyCtrl3Gamepad?.volatileMappingSetting, nilValue())
    }

    func resetListenersVars() {
        navEvent = nil
        navState = nil
        sc3ButtonEvent = nil
        sc3ButtonState = nil
        sc3AxisEvent = nil
        sc3AxisValue = nil
        navListenerCount = 0
        buttonListenerCount = 0
        axisListenerCount = 0
        appAction = nil
    }
}
