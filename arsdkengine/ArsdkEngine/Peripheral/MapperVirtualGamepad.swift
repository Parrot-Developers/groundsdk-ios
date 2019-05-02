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

/// Mapper buttons mask
struct MapperButtonsMask: OptionSet, Hashable {
    let rawValue: UInt

    /// Mask containing no button
    static let none: MapperButtonsMask = []

    /// Converts a `MapperButton` into a `MapperButtonsMask`
    ///
    /// - Parameter mapperAxis: the axis to convert
    /// - Returns: an axes mask
    static func from(_ mapperButton: MapperButton) -> MapperButtonsMask {
        return MapperButtonsMask(rawValue: 1 << UInt(mapperButton.rawValue))
    }

    /// Converts a list of `MapperAxis` into a `MapperAxesMask`
    ///
    /// - Parameter mapperAxes: the list of axes
    /// - Returns: an axes mask
    static func from(_ mapperButtons: MapperButton...) -> MapperButtonsMask {
        var mask = MapperButtonsMask.none
        mapperButtons.forEach { mask.insert(from($0)) }
        return mask
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

/// Mapper axes mask
struct MapperAxesMask: OptionSet, Hashable {
    let rawValue: UInt

    /// Mask containing no axis
    static let none: MapperAxesMask = []

    /// Converts a `MapperAxis` into a `MapperAxesMask`
    ///
    /// - Parameter mapperAxis: the axis to convert
    /// - Returns: an axes mask
    static func from(_ mapperAxis: MapperAxis) -> MapperAxesMask {
        return MapperAxesMask(rawValue: 1 << UInt(mapperAxis.rawValue))
    }

    /// Converts a list of `MapperAxis` into a `MapperAxesMask`
    ///
    /// - Parameter mapperAxes: the list of axes
    /// - Returns: an axes mask
    static func from(_ mapperAxes: MapperAxis...) -> MapperAxesMask {
        var mask = MapperAxesMask.none
        mapperAxes.forEach { mask.insert(from($0)) }
        return mask
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

enum MapperButton: Int {
    /// Generic button 0
    case button0

    /// Generic button 1
    case button1

    /// Generic button 2
    case button2

    /// Generic button 3
    case button3

    /// Generic button 4
    case button4

    /// Generic button 5
    case button5

    /// Generic button 6
    case button6

    /// Generic button 7
    case button7

    /// Generic button 8
    case button8

    /// Generic button 9
    case button9

    /// Generic button 10
    case button10

    /// Generic button 11
    case button11

    /// Generic button 12
    case button12

    /// Generic button 13
    case button13

    /// Generic button 14
    case button14

    /// Generic button 15
    case button15

    /// Generic button 16
    case button16

    /// Generic button 17
    case button17

    /// Generic button 18
    case button18

    /// Generic button 19
    case button19

    /// Generic button 20
    case button20

    /// Generic button 21
    case button21

    /// Set containing all generic buttons
    static let allCases: Set<MapperButton> = [.button0, .button1, .button2, .button3, .button4,
                                              .button5, .button6, .button7, .button8, .button9,
                                              .button10, .button11, .button12, .button13, .button14,
                                              .button15, .button16, .button17, .button18, .button19,
                                              .button20, .button21]
}

/// An generic axis
enum MapperAxis: Int {
    /// Generic axis 0
    case axis0

    /// Generic axis 1
    case axis1

    /// Generic axis 2
    case axis2

    /// Generic axis 3
    case axis3

    /// Generic axis 4
    case axis4

    /// Generic axis 5
    case axis5
}

/// Specialized gamepad backend.
/// This protocol should be implemented by specialized gamepads
protocol SpecializedGamepadBackend {

    /// The buttons mask of all navigation buttons
    var navigationGrabButtonsMask: MapperButtonsMask { get }

    /// The axes mask of all navigation axes
    var navigationGrabAxesMask: MapperAxesMask { get }

    /// Translate a button mask into a gamepad event
    ///
    /// - Parameter button: the button to translate
    /// - returns: a navigation event if the mask is related to navigation
    func eventFrom(button: MapperButton) -> VirtualGamepadEvent?

    /// Updates the grab state
    ///
    /// - Parameters:
    ///     - buttonsMask: mask of all grabbed buttons
    ///     - axesMask: mask of all grabbed axes
    ///     - pressedButtons: mask of all pressed buttons
    func updateGrabState(buttonsMask: MapperButtonsMask, axesMask: MapperAxesMask, pressedButtons: MapperButtonsMask)

    /// Updates the states of the given button
    ///
    /// - Parameters:
    ///     - button: the button that triggered the event
    ///     - event: the event triggered
    func updateButtonEventState(button: MapperButton, event: ArsdkFeatureMapperButtonEvent)

    /// Updates the value of the given axis
    ///
    /// - Parameters:
    ///     - axis: the axis that triggered the value change
    ///     - value: the current axis value
    func updateAxisEventValue(axis: MapperAxis, value: Int)

    /// Clears all buttons mappings
    func clearAllButtonsMappings()

    /// Removes a button mapping entry by its uid
    ///
    /// - Parameter uid: the uid of the mapping entry to remove
    func removeButtonsMappingEntry(withUid uid: UInt)

    /// Adds a button mapping entry
    ///
    /// - Parameters:
    ///   - uid: the uid of the entry
    ///   - droneModel: drone model the entry applies on
    ///   - action: buttons action the mapping entry triggers
    ///   - buttons: mask of buttons that triggers the action
    func addButtonsMappingEntry(
        uid: UInt, droneModel: Drone.Model, action: ButtonsMappableAction, buttons: MapperButtonsMask)

    /// Synchronizes all known button mappings with the public gamepad interface.
    func updateButtonsMappings()

    /// Clears all axes mappings
    func clearAllAxisMappings()

    /// Removes an axis mapping entry by its uid
    ///
    /// - Parameter uid: the uid of the mapping entry to remove
    func removeAxisMappingEntry(withUid uid: UInt)

    /// Adds an axis mapping entry
    ///
    /// - Parameters:
    ///   - uid: the uid of the entry
    ///   - droneModel: drone model the entry applies on
    ///   - action: buttons action the mapping entry triggers
    ///   - axis: axis that triggers the action
    ///   - buttons: mask of buttons that triggers the action
    func addAxisMappingEntry(
        uid: UInt, droneModel: Drone.Model, action: AxisMappableAction, axis: MapperAxis, buttons: MapperButtonsMask)

    /// Synchronizes all known axis mappings with the public gamepad interface.
    func updateAxisMappings()

    /// Updates the active drone model
    ///
    /// - Parameter droneModel: the drone model which is active
    func updateActiveDroneModel(_ droneModel: Drone.Model)

    /// Clears all axis interpolators
    func clearAllAxisInterpolators()

    /// Removes an axis interpolator by its uid
    ///
    /// - Parameter uid: the uid of the interpolator to remove
    func removeAxisInterpolator(withUid uid: UInt)

    /// Adds an axis interpolator
    ///
    /// - Parameters:
    ///   - uid: uid of the axis interpolator
    ///   - droneModel: drone model the interpolator applies on
    ///   - axis: axis on which the interpolator applies
    ///   - interpolator: interpolator to set
    func addAxisInterpolator(uid: UInt, droneModel: Drone.Model, axis: MapperAxis, interpolator: AxisInterpolator)

    /// Synchronizes all known axis interpolators with the public gamepad interface.
    func updateAxisInterpolators()

    /// Clears all known reversed axes.
    func clearAllReversedAxes()

    /// Removes a reversed axis entry.
    ///
    /// - Parameter uid: uid of the reversed axis entry to be removed
    func removeReversedAxis(withUid uid: UInt)

    /// Adds a reversed axis entry.
    ///
    /// - Parameters:
    ///   - uid: uid of the reversed axis entry
    ///   - droneModel: drone model the entry applies on
    ///   - axis: axis on which the entry applies
    ///   - reversed: true for an inverted axis, false otherwise
    func addReversedAxis(uid: UInt, droneModel: Drone.Model, axis: MapperAxis, reversed: Bool)

    /// Synchronizes all known reversed axes with the public gamepad interface.
    func updateReversedAxis()
}

/// Virtual gamepad controller for Mapper message based remote control.
///
/// - Note: This gamepad must be backed by a specialized gamepad. This specialized gamepad must set the
/// `specializedBackend` var of this object.
class MapperVirtualGamepad: DeviceComponentController {

    /// VirtualGamepad component
    private var virtualGamepad: VirtualGamepadCore!

    /// Whether or not the navigation gamepad is currently grabbed
    private var isNavigationGamepadGrabbed = false

    /// Whether or not the navigation gamepad is preempted by the specialized gamepad
    private var isNavigationGamepadPreempted = false

    /// Whether or not the grab has been requested for navigation
    private var isGrabRequestedForNav = false

    /// Supported drone models.
    /// For the moment, it is filled by drone models received in the expo event
    private var supportedDroneModels = Set<Drone.Model>()

    /// The specialized gamepad backend
    var specializedBackend: SpecializedGamepadBackend!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        virtualGamepad = VirtualGamepadCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        virtualGamepad.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        virtualGamepad.resetNavListener()
        virtualGamepad.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        super.didReceiveCommand(command)
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureMapperUid {
            ArsdkFeatureMapper.decode(command, callback: self)
        }
    }

    /// Grabs the given buttons and axes for an other purpose than navigation
    ///
    /// - Parameters:
    ///     - buttonsMask: all buttons that should be grabbed
    ///     - axesMask: all axes that should be grabbed
    final func grab(buttonsMask: MapperButtonsMask, axesMask: MapperAxesMask) {
        grab(buttonsMask: buttonsMask, axesMask: axesMask, forNav: false)
    }

    /// Grabs the given buttons and axes
    ///
    /// - Parameters:
    ///     - buttonsMask: all buttons that should be grabbed
    ///     - axesMask: all axes that should be grabbed
    ///     - forNav: whether the grab is for navigation purpose or not
    private func grab(buttonsMask: MapperButtonsMask, axesMask: MapperAxesMask, forNav: Bool) {
        var buttons = buttonsMask
        var axes = axesMask
        isGrabRequestedForNav = forNav
        // if it is an ungrab requested by a specialized gamepad and the nav was preempted
        if buttonsMask == .none && axesMask == .none && !isGrabRequestedForNav && isNavigationGamepadPreempted {
            isNavigationGamepadPreempted = false
            if isNavigationGamepadGrabbed {
                specializedBackend.updateGrabState(buttonsMask: .none, axesMask: .none, pressedButtons: .none)
                buttons = specializedBackend.navigationGrabButtonsMask
                axes = specializedBackend.navigationGrabAxesMask
                isGrabRequestedForNav = true
            }
        }
        sendCommand(ArsdkFeatureMapper.grabEncoder(buttons: buttons.rawValue, axes: axes.rawValue))
    }

    /// Sends the command to configure a button mapping entry
    ///
    /// - Parameters:
    ///   - droneModel: the drone model the entry applies on
    ///   - action: buttons action the mapping entry triggers
    ///   - buttonsMask: mask of buttons that triggers the action
    final func sendAddButtonsMappingEntry(
        droneModel: Drone.Model, action: ButtonsMappableAction, buttonsMask: MapperButtonsMask) {
        sendCommand(ArsdkFeatureMapper.mapButtonActionEncoder(
            product: UInt(droneModel.internalId),
            action: MapperVirtualGamepad.Actions.arsdkButtonsActions[action]!,
            buttons: buttonsMask.rawValue))
    }

    /// Sends the command to remove a button mapping entry
    ///
    /// - Parameters:
    ///   - droneModel: the drone model on which the entry that should be removed applies
    ///   - action: buttons action the mapping entry triggers
    final func sendRemoveButtonsMappingEntry(droneModel: Drone.Model, action: ButtonsMappableAction) {
        sendCommand(ArsdkFeatureMapper.mapButtonActionEncoder(
            product: UInt(droneModel.internalId),
            action: MapperVirtualGamepad.Actions.arsdkButtonsActions[action]!,
            buttons: 0))
    }

    /// Sends the command to configure an axis mapping entry
    ///
    /// - Parameters:
    ///   - droneModel: the drone model the entry applies on
    ///   - action: axis action the mapping entry triggers
    ///   - axis: axis that triggers the action
    ///   - buttonsMask: mask of buttons that triggers the action
    final func sendAddAxisMappingEntry(
        droneModel: Drone.Model, action: AxisMappableAction, axis: MapperAxis,
        buttonsMask: MapperButtonsMask) {
        sendCommand(ArsdkFeatureMapper.mapAxisActionEncoder(
            product: UInt(droneModel.internalId),
            action: MapperVirtualGamepad.Actions.arsdkAxisActions[action]!, axis: axis.rawValue,
            buttons: buttonsMask.rawValue))
    }

    /// Sends the command to remove an axis mapping entry
    ///
    /// - Parameters:
    ///   - droneModel: the drone model on which the entry that should be removed applies
    ///   - action: axis action the mapping entry triggers
    final func sendRemoveAxisMappingEntry(droneModel: Drone.Model, action: AxisMappableAction) {
        sendCommand(ArsdkFeatureMapper.mapAxisActionEncoder(
            product: UInt(droneModel.internalId),
            action: MapperVirtualGamepad.Actions.arsdkAxisActions[action]!, axis: -1, buttons: 0))
    }

    /// Sends the command to reset the mapping of a given drone model (or all models)
    ///
    /// - Parameter model: drone model for which the mapping should be reset, or nil to reset all models mappings
    final func sendResetMapping(forModel model: Drone.Model?) {
        let product: UInt?
        if let model = model {
            product = UInt(model.internalId)
        } else {
            product = 0
        }
        if let product = product {
            sendCommand(ArsdkFeatureMapper.resetMappingEncoder(product: product))
        }
    }

    /// Send the command that configures an axis interpolator
    ///
    /// - Parameters:
    ///   - interpolator: interpolator to set for the given axis and drone model
    ///   - droneModel: drone model onto which the interpolator applies
    ///   - axisValue: value of the axis onto which the interpolator applies
    final func send(
        interpolator: AxisInterpolator, forDroneModel droneModel: Drone.Model,
        onAxis axis: MapperAxis) {

        let expoType: ArsdkFeatureMapperExpoType
        switch interpolator {
        case .linear:
            expoType = .linear
        case .lightExponential:
            expoType = .expo0
        case .mediumExponential:
            expoType = .expo1
        case .strongExponential:
            expoType = .expo2
        case .strongestExponential:
            expoType = .expo4
        }
        // we can force unwrap axis mask because it comes from a specific
        sendCommand(ArsdkFeatureMapper.setExpoEncoder(
            product: UInt(droneModel.internalId), axis: axis.rawValue, expo: expoType))
    }

    /// Sends the command that configures the axis inversion
    ///
    /// - Parameters:
    ///   - axis: mask of the axis onto which the inversion applies
    ///   - droneModel: drone model onto which the axis inversion applies
    ///   - reversed: true to make the axis reversed, false otherwise
    final func send(axis: MapperAxis, forDroneModel droneModel: Drone.Model, reversed: Bool) {
        sendCommand(ArsdkFeatureMapper.setInvertedEncoder(
            product: UInt(droneModel.internalId), axis: axis.rawValue, inverted: reversed ? 1 : 0))
    }
}

/// VirtualGamepad backend implementation
extension MapperVirtualGamepad: VirtualGamepadBackend {
    func grabNavigation() -> Bool {
        // only grab for navigation if it was not already grabbing for navigation and it is not preempted
        if !isNavigationGamepadGrabbed && !isNavigationGamepadPreempted {
            grab(buttonsMask: specializedBackend.navigationGrabButtonsMask,
                 axesMask: specializedBackend.navigationGrabAxesMask, forNav: true)
            return true
        }
        return false
    }

    func ungrabNavigation() {
        // ungrab only if the grab was for the navigation and it is not currently preempted
        if isNavigationGamepadGrabbed && !isNavigationGamepadPreempted {
            grab(buttonsMask: .none, axesMask: .none, forNav: true)
        }
        isNavigationGamepadGrabbed = false
        virtualGamepad.update(isGrabbed: false).notifyUpdated()
    }
}

/// Mapper decode callback implementation
extension MapperVirtualGamepad: ArsdkFeatureMapperCallback {
    public func onGrabState(buttons: UInt, axes: UInt, buttonsState: UInt) {
        let buttonsGrabbed = MapperButtonsMask(rawValue: buttons)
        let buttonsPressed = MapperButtonsMask(rawValue: buttonsState)
        let axesGrabbed = MapperAxesMask(rawValue: axes)
        // if ungrabbed
        if buttonsGrabbed == .none && axesGrabbed == .none {
            isNavigationGamepadGrabbed = false
            isNavigationGamepadPreempted = false
            virtualGamepad.update(isGrabbed: false).update(isPreempted: false).notifyUpdated()

            specializedBackend.updateGrabState(
                buttonsMask: buttonsGrabbed, axesMask: axesGrabbed, pressedButtons: buttonsPressed)
        } else {
            if isGrabRequestedForNav {
                let navButtons = specializedBackend.navigationGrabButtonsMask
                let navAxes = specializedBackend.navigationGrabAxesMask
                // if at least one button or axis grabbed is in the list of nav buttons/axes
                if !buttonsGrabbed.isDisjoint(with: navButtons) || !axesGrabbed.isDisjoint(with: navAxes) {

                    isNavigationGamepadGrabbed = true
                    virtualGamepad.update(isGrabbed: true).update(isPreempted: false).notifyUpdated()

                    if !buttonsGrabbed.contains(navButtons) {
                        ULog.w(.mapperTag, "Missing grabbed buttons for navigation. " +
                            "\(navButtons.rawValue) is not fully contained in: \(buttonsGrabbed.rawValue)")
                    }
                    if !axesGrabbed.contains(navAxes) {
                        ULog.w(.mapperTag, "Missing grabbed axes for navigation. " +
                            "\(navAxes.rawValue) is not fully contained in: \(axesGrabbed.rawValue)")
                    }
                    // send a nav event for each event associated to a buttons which is pressed
                    for button in MapperButton.allCases {
                        let event = specializedBackend.eventFrom(button: button)
                        if let event = event, buttonsPressed.contains(MapperButtonsMask.from(button)) {
                            virtualGamepad.notifyNavigationEvent(event, state: .pressed)
                        }
                    }
                }
            } else {
                isNavigationGamepadPreempted = true
                virtualGamepad.update(isPreempted: true).notifyUpdated()

                specializedBackend.updateGrabState(
                    buttonsMask: buttonsGrabbed, axesMask: axesGrabbed, pressedButtons: buttonsPressed)
            }
        }
    }

    func onGrabButtonEvent(button: UInt, event: ArsdkFeatureMapperButtonEvent) {
        if let mapperButton = MapperButton(rawValue: Int(button)) {
            if isNavigationGamepadGrabbed && !isNavigationGamepadPreempted {
                let navEvent = specializedBackend.eventFrom(button: mapperButton)
                if let navEvent = navEvent {
                    let state: VirtualGamepadEventState
                    switch event {
                    case .press:
                        state = .pressed
                    case .release:
                        state = .released
                    case .sdkCoreUnknown:
                        // don't change anything if value is unknown
                        ULog.w(.tag, "Unknown button event, skipping this event.")
                        return
                    }
                    virtualGamepad.notifyNavigationEvent(navEvent, state: state)
                }
            } else {
                specializedBackend.updateButtonEventState(
                    button: mapperButton, event: event)
            }
        }
    }

    func onGrabAxisEvent(axis: UInt, value: Int) {
        if let mapperAxis = MapperAxis(rawValue: Int(axis)) {
            specializedBackend.updateAxisEventValue(axis: mapperAxis, value: value)
        } else {
            ULog.w(.mapperTag, "Invalid axis \(axis), dropping grab axis event")
        }
    }

    func onButtonMappingItem(
        uid: UInt, product: UInt, action: ArsdkFeatureMapperButtonAction, buttons: UInt, listFlagsBitField: UInt) {

        let clearMappings = ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField)
        if clearMappings {
            specializedBackend.clearAllButtonsMappings()
        } else if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
            specializedBackend.removeButtonsMappingEntry(withUid: uid)
        } else {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                specializedBackend.clearAllButtonsMappings()
            }

            if case DeviceModel.drone(let droneModel)? = DeviceModel.from(internalId: Int(product)),
                let buttonsAction = Actions.gsdkButtonsActions[action] {
                specializedBackend.addButtonsMappingEntry(
                    uid: uid, droneModel: droneModel, action: buttonsAction,
                    buttons: MapperButtonsMask(rawValue: buttons))
            } else {
                ULog.w(.mapperTag, "Invalid product \(product) or action \(action), dropping mapping [uid: \(uid)" +
                    " product: \(product) buttons: \(buttons)")
            }
        }

        if clearMappings || ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
            specializedBackend.updateButtonsMappings()
        }
    }

    func onAxisMappingItem(
        uid: UInt, product: UInt, action: ArsdkFeatureMapperAxisAction, axis: Int, buttons: UInt,
        listFlagsBitField: UInt) {

        let clearMappings = ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField)
        if clearMappings {
            specializedBackend.clearAllAxisMappings()
        } else if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
            specializedBackend.removeAxisMappingEntry(withUid: uid)
        } else {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                specializedBackend.clearAllAxisMappings()
            }

            if case DeviceModel.drone(let droneModel)? = DeviceModel.from(internalId: Int(product)),
                let axisAction = Actions.gsdkAxisActions[action],
                let mapperAxis = MapperAxis(rawValue: axis) {
                specializedBackend.addAxisMappingEntry(
                    uid: uid, droneModel: droneModel, action: axisAction,
                    axis: mapperAxis, buttons: MapperButtonsMask(rawValue: buttons))
            } else {
                ULog.w(.mapperTag, "Invalid product \(product) or action \(action) or axis \(axis), " +
                    "dropping mapping [uid: \(uid) product: \(product) axis: \(axis) buttons: \(buttons)")
            }
        }

        if clearMappings || ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
            specializedBackend.updateAxisMappings()
        }
    }

    func onApplicationAxisEvent(action: ArsdkFeatureMapperAxisAction, value: Int) {

    }

    func onApplicationButtonEvent(action: ArsdkFeatureMapperButtonAction) {
        let appAction = Actions.gsdkButtonsActions[action]
        if let appAction = appAction {
            virtualGamepad.notifyAppAction(appAction)
        }
    }

    func onExpoMapItem(
        uid: UInt, product: UInt, axis: Int, expo: ArsdkFeatureMapperExpoType, listFlagsBitField: UInt) {

        let clearMappings = ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField)
        if clearMappings {
            specializedBackend.clearAllAxisInterpolators()
        } else if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
            specializedBackend.removeAxisInterpolator(withUid: uid)
        } else {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                specializedBackend.clearAllAxisInterpolators()
            }

            if case DeviceModel.drone(let droneModel)? = DeviceModel.from(internalId: Int(product)),
                let mapperAxis = MapperAxis(rawValue: axis) {
                let interpolator: AxisInterpolator
                switch expo {
                case .linear:
                    interpolator = .linear
                case .expo0:
                    interpolator = .lightExponential
                case .expo1:
                    interpolator = .mediumExponential
                case .expo2:
                    interpolator = .strongExponential
                case .expo4:
                    interpolator = .strongestExponential
                case .sdkCoreUnknown:
                    // don't change anything if value is unknown
                    ULog.w(.mapperTag, "Unknown expo, skipping this event.")
                    return
                }
                specializedBackend.addAxisInterpolator(
                    uid: uid, droneModel: droneModel, axis: mapperAxis,
                    interpolator: interpolator)
            } else {
                ULog.w(.mapperTag, "Invalid product \(product) or axis \(axis), dropping axis interpolator " +
                    "[uid: \(uid) product: \(product) axis: \(axis) expo: \(expo)")
            }
        }

        if clearMappings || ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
            specializedBackend.updateAxisInterpolators()
        }
    }

    func onInvertedMapItem(uid: UInt, product: UInt, axis: Int, inverted: UInt, listFlagsBitField: UInt) {

        let clearMappings = ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField)
        if clearMappings {
            specializedBackend.clearAllReversedAxes()
        } else if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
            specializedBackend.removeReversedAxis(withUid: uid)
        } else {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                specializedBackend.clearAllReversedAxes()
            }

            if case DeviceModel.drone(let droneModel)? = DeviceModel.from(internalId: Int(product)),
                let mapperAxis = MapperAxis(rawValue: axis) {
                specializedBackend.addReversedAxis(
                    uid: uid, droneModel: droneModel, axis: mapperAxis,
                    reversed: inverted == 1)
            } else {
                ULog.w(.mapperTag, "Invalid product \(product) or axis \(axis), dropping axis inversion " +
                    "[uid: \(uid) product: \(product) axis: \(axis) inverted: \(inverted)")
            }
        }

        if clearMappings || ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
            specializedBackend.updateReversedAxis()
        }
    }

    func onActiveProduct(product: UInt) {
        if case DeviceModel.drone(let droneModel)? = DeviceModel.from(internalId: Int(product)) {
            specializedBackend.updateActiveDroneModel(droneModel)
        } else {
            ULog.w(.mapperTag, "Unknown product \(product)")
        }
    }
}

/// Extension of MapperVirtualGamepad that contains Actions type declaration
extension MapperVirtualGamepad {
    /// Converts mappable actions to/from mapper button actions
    final class Actions {

        /// Map that associates a button mappable action to a button action
        static var gsdkButtonsActions: [ArsdkFeatureMapperButtonAction: ButtonsMappableAction] = {
            return buttonMapper.gsdkActions
        }()

        /// Map that associates a button action to a button mappable action
        static var arsdkButtonsActions: [ButtonsMappableAction: ArsdkFeatureMapperButtonAction] = {
            return buttonMapper.arsdkActions
        }()

        /// Map that associates an axis action to an axis mappable action
        static var gsdkAxisActions: [ArsdkFeatureMapperAxisAction: AxisMappableAction] = {
            return axisMapper.gsdkActions
        }()

        /// Map that associates an axis action to an axis mappable action
        static var arsdkAxisActions: [AxisMappableAction: ArsdkFeatureMapperAxisAction] = {
            return axisMapper.arsdkActions
        }()

        private typealias ButtonMapperType = (
            gsdkActions: [ArsdkFeatureMapperButtonAction: ButtonsMappableAction],
            arsdkActions: [ButtonsMappableAction: ArsdkFeatureMapperButtonAction])

        private typealias AxisMapperType = (
            gsdkActions: [ArsdkFeatureMapperAxisAction: AxisMappableAction],
            arsdkActions: [AxisMappableAction: ArsdkFeatureMapperAxisAction])

        /// Lazy var which maps each button action to each button mappable action
        private static var buttonMapper: ButtonMapperType = {
            var mapper = (gsdkActions: [ArsdkFeatureMapperButtonAction: ButtonsMappableAction](),
                          arsdkActions: [ButtonsMappableAction: ArsdkFeatureMapperButtonAction]())

            func map(arsdkAction: ArsdkFeatureMapperButtonAction, gsdkAction: ButtonsMappableAction) {
                mapper.arsdkActions[gsdkAction] = arsdkAction
                mapper.gsdkActions[arsdkAction] = gsdkAction
            }

            // map application button actions
            map(arsdkAction: .app0, gsdkAction: .appActionSettings)
            map(arsdkAction: .app1, gsdkAction: .appAction1)
            map(arsdkAction: .app2, gsdkAction: .appAction2)
            map(arsdkAction: .app3, gsdkAction: .appAction3)
            map(arsdkAction: .app4, gsdkAction: .appAction4)
            map(arsdkAction: .app5, gsdkAction: .appAction5)
            map(arsdkAction: .app6, gsdkAction: .appAction6)
            map(arsdkAction: .app7, gsdkAction: .appAction7)
            map(arsdkAction: .app8, gsdkAction: .appAction8)
            map(arsdkAction: .app9, gsdkAction: .appAction9)
            map(arsdkAction: .app10, gsdkAction: .appAction10)
            map(arsdkAction: .app11, gsdkAction: .appAction11)
            map(arsdkAction: .app12, gsdkAction: .appAction12)
            map(arsdkAction: .app13, gsdkAction: .appAction13)
            map(arsdkAction: .app14, gsdkAction: .appAction14)
            map(arsdkAction: .app15, gsdkAction: .appAction15)

            // map predefined buttons actions
            map(arsdkAction: .returnHome, gsdkAction: .returnHome)
            map(arsdkAction: .takeoffLand, gsdkAction: .takeOffOrLand)
            map(arsdkAction: .videoRecord, gsdkAction: .recordVideo)
            map(arsdkAction: .takePicture, gsdkAction: .takePicture)
            map(arsdkAction: .cameraAuto, gsdkAction: .photoOrVideo)
            map(arsdkAction: .cameraExpositionInc, gsdkAction: .increaseCameraExposition)
            map(arsdkAction: .cameraExpositionDec, gsdkAction: .decreaseCameraExposition)
            map(arsdkAction: .flipLeft, gsdkAction: .flipLeft)
            map(arsdkAction: .flipRight, gsdkAction: .flipRight)
            map(arsdkAction: .flipFront, gsdkAction: .flipFront)
            map(arsdkAction: .flipBack, gsdkAction: .flipBack)
            map(arsdkAction: .emergency, gsdkAction: .emergencyCutOff)
            map(arsdkAction: .centerCamera, gsdkAction: .centerCamera)
            map(arsdkAction: .cycleHud, gsdkAction: .cycleHud)

            return mapper
        }()

        /// Lazy var which maps each axis action to each axis mappable action
        private static var axisMapper: AxisMapperType = {
            var mapper = (gsdkActions: [ArsdkFeatureMapperAxisAction: AxisMappableAction](),
                          arsdkActions: [AxisMappableAction: ArsdkFeatureMapperAxisAction]())

            func map(arsdkAction: ArsdkFeatureMapperAxisAction, gsdkAction: AxisMappableAction) {
                mapper.arsdkActions[gsdkAction] = arsdkAction
                mapper.gsdkActions[arsdkAction] = gsdkAction
            }

            // map predefined axes actions
            map(arsdkAction: .roll, gsdkAction: .controlRoll)
            map(arsdkAction: .pitch, gsdkAction: .controlPitch)
            map(arsdkAction: .yaw, gsdkAction: .controlYawRotationSpeed)
            map(arsdkAction: .gaz, gsdkAction: .controlThrottle)
            map(arsdkAction: .cameraPan, gsdkAction: .panCamera)
            map(arsdkAction: .cameraTilt, gsdkAction: .tiltCamera)
            map(arsdkAction: .cameraZoom, gsdkAction: .zoomCamera)

            return mapper
        }()
    }
}
