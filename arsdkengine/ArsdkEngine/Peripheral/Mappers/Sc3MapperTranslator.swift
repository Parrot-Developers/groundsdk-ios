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
import GroundSdk

/// Converts `SkyCtrl3Button` and/or `SkyCtrl3Axis` into `MapperButtonsMask` and/or `MapperAxesMask`
final class Sc3InputTranslator {
    typealias MapperMask = (buttonsMask: MapperButtonsMask, axesMask: MapperAxesMask)

    private typealias ButtonMapperType = (
        buttons: [MapperButtonsMask: SkyCtrl3Button],
        buttonMasks: [SkyCtrl3Button: MapperButtonsMask])

    /// Lazy var which maps each button mask to each physical button
    private static var buttonMapper: ButtonMapperType = {
        var mapper = (buttons: [MapperButtonsMask: SkyCtrl3Button](),
                      buttonMasks: [SkyCtrl3Button: MapperButtonsMask]())

        func map(mask: MapperButtonsMask, button: SkyCtrl3Button) {
            mapper.buttons[mask] = button
            mapper.buttonMasks[button] = mask
        }

        map(mask: MapperButtonsMask.from(.button0), button: .frontTopButton)
        map(mask: MapperButtonsMask.from(.button1), button: .frontBottomButton)
        map(mask: MapperButtonsMask.from(.button2), button: .rearLeftButton)
        map(mask: MapperButtonsMask.from(.button3), button: .rearRightButton)

        return mapper
    }()

    private typealias AxisMapperType = (
        axes: [MapperAxesMask: SkyCtrl3Axis],
        mapperMasks: [SkyCtrl3Axis: MapperMask])

    /// Lazy var which maps each axis mask to each physical axis
    private static var axisMapper: AxisMapperType = {
        var mapper = (axes: [MapperAxesMask: SkyCtrl3Axis](),
                      mapperMasks: [SkyCtrl3Axis: MapperMask]())

        func map(mask: MapperMask, axes: SkyCtrl3Axis) {
            mapper.axes[mask.axesMask] = axes
            mapper.mapperMasks[axes] = mask
        }

        map(mask: MapperMask(buttonsMask: MapperButtonsMask.from(.button4, .button5),
                             axesMask: MapperAxesMask.from(.axis0)),
            axes: .leftStickHorizontal)
        map(mask: MapperMask(buttonsMask: MapperButtonsMask.from(.button6, .button7),
                             axesMask: MapperAxesMask.from(.axis1)),
            axes: .leftStickVertical)
        map(mask: MapperMask(buttonsMask: MapperButtonsMask.from(.button8, .button9),
                             axesMask: MapperAxesMask.from(.axis2)),
            axes: .rightStickHorizontal)
        map(mask: MapperMask(buttonsMask: MapperButtonsMask.from(.button10, .button11),
                             axesMask: MapperAxesMask.from(.axis3)),
            axes: .rightStickVertical)
        map(mask: MapperMask(buttonsMask: MapperButtonsMask.from(.button12, .button13),
                             axesMask: MapperAxesMask.from(.axis4)),
            axes: .leftSlider)
        map(mask: MapperMask(buttonsMask: MapperButtonsMask.from(.button14, .button15),
                             axesMask: MapperAxesMask.from(.axis5)),
            axes: .rightSlider)

        return mapper
    }()

    /// Converts a SkyController 3 button into a buttons mask
    ///
    /// - Parameter button: the button to translate
    /// - Returns: a button mask
    static func convert(button: SkyCtrl3Button) -> MapperButtonsMask {
        return buttonMapper.buttonMasks[button]!
    }

    /// Converts a SkyController 3 axis into a buttons mask and an axis mask
    ///
    /// - Parameter axis: the axis to translate
    /// - Returns: a struct containing a buttons mask (key `buttonsMask`) and an axis mask (key `axesMask`)
    static func convert(axis: SkyCtrl3Axis) -> MapperMask {
        return axisMapper.mapperMasks[axis]!
    }

    /// Converts a SkyController 3 buttons and axes into a buttons mask and an axis mask
    ///
    /// - Parameters:
    ///     - buttons: the set of buttons to translate
    ///     - axes: the set of axes to translate
    /// - Returns: a struct containing a buttons mask (key `buttonsMask`) and an axis mask (key `axesMask`)
    static func convert(buttons: Set<SkyCtrl3Button>, axes: Set<SkyCtrl3Axis>)
        -> MapperMask {
            var buttonsMask = MapperButtonsMask.none
            var axesMask = MapperAxesMask.none
            for button in buttons {
                buttonsMask.insert(convert(button: button))
            }
            for axis in axes {
                let mask = convert(axis: axis)
                buttonsMask.insert(mask.buttonsMask)
                axesMask.insert(mask.axesMask)
            }
            return MapperMask(buttonsMask: buttonsMask, axesMask: axesMask)
    }
}

/// Converts mapper buttons to/from SkyController 3 ButtonEvent
final class Sc3Buttons {

    /// Map that associates a SkyController 3 button event to a mapper button
    static var buttonEvents: [MapperButton: SkyCtrl3ButtonEvent] = {
        return buttonMapper.buttonEvents
    }()

    /// Map that associates a mapper button to a SkyController 3 button event
    static var buttonMasks: [SkyCtrl3ButtonEvent: MapperButton] = {
        return buttonMapper.mapperButtons
    }()

    private typealias ButtonMapperType = (
        buttonEvents: [MapperButton: SkyCtrl3ButtonEvent],
        mapperButtons: [SkyCtrl3ButtonEvent: MapperButton])

    /// Lazy var which maps each button mask to each button event
    private static var buttonMapper: ButtonMapperType = {
        var mapper = (buttonEvents: [MapperButton: SkyCtrl3ButtonEvent](),
                      mapperButtons: [SkyCtrl3ButtonEvent: MapperButton]())

        func map(button: MapperButton, event: SkyCtrl3ButtonEvent) {
            mapper.buttonEvents[button] = event
            mapper.mapperButtons[event] = button
        }

        map(button: .button0, event: .frontTopButton)
        map(button: .button1, event: .frontBottomButton)
        map(button: .button2, event: .rearLeftButton)
        map(button: .button3, event: .rearRightButton)
        map(button: .button4, event: .leftStickLeft)
        map(button: .button5, event: .leftStickRight)
        map(button: .button6, event: .leftStickUp)
        map(button: .button7, event: .leftStickDown)
        map(button: .button8, event: .rightStickLeft)
        map(button: .button9, event: .rightStickRight)
        map(button: .button10, event: .rightStickUp)
        map(button: .button11, event: .rightStickDown)
        map(button: .button12, event: .leftSliderDown)
        map(button: .button13, event: .leftSliderUp)
        map(button: .button14, event: .rightSliderUp)
        map(button: .button15, event: .rightSliderDown)

        return mapper
    }()

    /// Converts a button mask of buttons into a dictionary of SkyController 3 buttons events state indexed by button
    /// events. For each button in the given mask, its button event translation will appear as a key in the returned
    /// dictionary.
    ///
    /// - Parameters:
    ///     - buttons: mask of all buttons that should be in the returned dictionary as button event
    ///     - pressedButtons: mask of all pressed buttons
    /// - Returns: a dictionary of button events indexed by button events.
    class func statesFrom(buttons: MapperButtonsMask, pressedButtons: MapperButtonsMask)
        -> [SkyCtrl3ButtonEvent: SkyCtrl3ButtonEventState] {
            var states = [SkyCtrl3ButtonEvent: SkyCtrl3ButtonEventState]()
            for button in MapperButton.allCases {
                let buttonMask = MapperButtonsMask.from(button)
                if buttons.contains(buttonMask), let buttonEvent = buttonEvents[button] {
                    states[buttonEvent] = (pressedButtons.contains(buttonMask)) ? .pressed : .released
                }
            }
            return states
    }

    /// Translates a buttons mask into a set of button events.
    ///
    /// - Parameter buttons: the buttons mask to translate
    /// - Returns: a set containing the button events
    class func eventsFrom(buttons: MapperButtonsMask) -> Set<SkyCtrl3ButtonEvent> {
        var buttonEventSet = Set<SkyCtrl3ButtonEvent>()
        for button in MapperButton.allCases {
            let buttonMask = MapperButtonsMask.from(button)
            if buttons.contains(buttonMask), let buttonEvent = buttonEvents[button] {
                buttonEventSet.insert(buttonEvent)
            }
        }
        return buttonEventSet
    }

    /// Translates a set of button events into a buttons mask
    ///
    /// - Parameter buttonEvents: the set of button events to translate
    /// - Returns: a buttons mask
    class func maskFrom(buttonEvents: Set<SkyCtrl3ButtonEvent>) -> MapperButtonsMask {
        var buttonMask = MapperButtonsMask.none
        for buttonEvent in buttonEvents {
            if let mask = buttonMasks[buttonEvent] {
                buttonMask.insert(MapperButtonsMask.from(mask))
            }
        }
        return buttonMask
    }
}

/// Converts mapper axis to/from SkyController 3 AxisEvent
final class Sc3Axes {

    private typealias AxisEventMapperType = (
        axisEvents: [MapperAxis: SkyCtrl3AxisEvent],
        mapperAxes: [SkyCtrl3AxisEvent: MapperAxis])

    /// Lazy var which maps each mapper axis to each axis event
    private static var axisEventMapper: AxisEventMapperType = {
        var mapper = (axisEvents: [MapperAxis: SkyCtrl3AxisEvent](),
                      mapperAxes: [SkyCtrl3AxisEvent: MapperAxis]())

        func map(mapperAxis: MapperAxis, event: SkyCtrl3AxisEvent) {
            mapper.axisEvents[mapperAxis] = event
            mapper.mapperAxes[event] = mapperAxis
        }

        map(mapperAxis: .axis0, event: .leftStickHorizontal)
        map(mapperAxis: .axis1, event: .leftStickVertical)
        map(mapperAxis: .axis2, event: .rightStickHorizontal)
        map(mapperAxis: .axis3, event: .rightStickVertical)
        map(mapperAxis: .axis4, event: .leftSlider)
        map(mapperAxis: .axis5, event: .rightSlider)

        return mapper
    }()

    private typealias AxisMapperType = (
        sc3Axes: [MapperAxis: SkyCtrl3Axis],
        mapperAxes: [SkyCtrl3Axis: MapperAxis])

    /// Lazy var which maps each mapper axis to each axis event
    private static var axisMapper: AxisMapperType = {
        var mapper = (sc3Axes: [MapperAxis: SkyCtrl3Axis](),
                      mapperAxes: [SkyCtrl3Axis: MapperAxis]())

        func map(mapperAxis: MapperAxis, sc3Axis: SkyCtrl3Axis) {
            mapper.sc3Axes[mapperAxis] = sc3Axis
            mapper.mapperAxes[sc3Axis] = mapperAxis
        }

        map(mapperAxis: .axis0, sc3Axis: .leftStickHorizontal)
        map(mapperAxis: .axis1, sc3Axis: .leftStickVertical)
        map(mapperAxis: .axis2, sc3Axis: .rightStickHorizontal)
        map(mapperAxis: .axis3, sc3Axis: .rightStickVertical)
        map(mapperAxis: .axis4, sc3Axis: .leftSlider)
        map(mapperAxis: .axis5, sc3Axis: .rightSlider)

        return mapper
    }()

    /// Converts a mapper axis into an axis event
    ///
    /// - Parameter mapperAxis: the mapper axis to translate
    /// - Returns: an axis event
    static func convert(_ mapperAxis: MapperAxis) -> SkyCtrl3AxisEvent? {
        return axisEventMapper.axisEvents[mapperAxis]
    }

    /// Converts an axis event into a mapper axis
    ///
    /// - Parameter axisEvent: the axis event to translate
    /// - Returns: a mapper axis
    static func convert(_ axisEvent: SkyCtrl3AxisEvent) -> MapperAxis? {
        return axisEventMapper.mapperAxes[axisEvent]
    }

    /// Converts a mapper axis into an axis
    ///
    /// - Parameter mapperAxis: the mapper axis to translate
    /// - Returns: an axis
    static func convert(_ mapperAxis: MapperAxis) -> SkyCtrl3Axis? {
        return axisMapper.sc3Axes[mapperAxis]
    }

    /// Converts an axis into a mapper axis
    ///
    /// - Parameter axis: the axis to translate
    /// - Returns: a mapper axis
    static func convert(_ axis: SkyCtrl3Axis) -> MapperAxis? {
        return axisMapper.mapperAxes[axis]
    }
}
