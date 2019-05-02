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

/// SkyController 3 Gamepad backend
public protocol SkyCtrl3GamepadBackend: class {
    /// Grabs the given set of inputs
    ///
    /// - Parameters:
    ///   - buttons: set of buttons to grab
    ///   - axes: set of axes to grab
    func grab(buttons: Set<SkyCtrl3Button>, axes: Set<SkyCtrl3Axis>)

    /// Setups a given mapping entry
    ///
    /// - Parameters:
    ///   - mappingEntry: the mapping entry
    ///   - register: true to register the given entry, false to unregister it
    func setup(mappingEntry: SkyCtrl3MappingEntry, register: Bool)

    /// Resets the mapping for a given drone model
    ///
    /// - Parameter model: the drone model for which the mapping should be reset
    func resetMapping(forModel model: Drone.Model?)

    /// Sets the interpolation formula to be applied on an axis.
    ///
    /// - Parameters:
    ///   - interpolator: interpolator to set
    ///   - droneModel: drone model for which the axis interpolator must be applied
    ///   - axis: axis to set the interpolator for
    func set(interpolator: AxisInterpolator, forDroneModel droneModel: Drone.Model, onAxis axis: SkyCtrl3Axis)

    /// Sets a gamepad axis inversion.
    ///
    /// - Parameters:
    ///   - axis: axis to reverse
    ///   - droneModel: drone model for which the axis must be reversed
    ///   - reversed: whether or not the axis should be reverted
    func set(axis: SkyCtrl3Axis, forDroneModel droneModel: Drone.Model, reversed: Bool)
}

/// Internal SkyCtrl3Gamepad peripheral implementation
@objcMembers // objc compatibility only for testing purpose
public class SkyCtrl3GamepadCore: PeripheralCore, SkyCtrl3Gamepad {

    /// Struct that contains an axis interpolator and associate it with an axis and a drone model.
    public struct AxisInterpolatorEntry {
        /// Drone model associated to the interpolator
        public let droneModel: Drone.Model

        /// Axis concerned by the interpolator
        let axis: SkyCtrl3Axis

        /// Axis interpolator
        let interpolator: AxisInterpolator

        /// Constructor
        ///
        /// - Parameters:
        ///   - droneModel: drone model onto which the interpolator applies.
        ///   - axis: axis onto which the interpolator applies.
        ///   - interpolator: axis interpolator
        public init(droneModel: Drone.Model, axis: SkyCtrl3Axis, interpolator: AxisInterpolator) {
            self.droneModel = droneModel
            self.axis = axis
            self.interpolator = interpolator
        }
    }

    /// Struct that represents axis inversion info.
    public struct ReversedAxisEntry {

        /// Drone model associated to the axis
        let droneModel: Drone.Model

        /// Axis concerned
        let axis: SkyCtrl3Axis

        /// Inversion information
        let reversed: Bool

        /// Constructor
        ///
        /// - Parameters:
        ///   - droneModel: drone model onto which the axis inversion applies.
        ///   - axis: axis onto which the inversion applies.
        ///   - reversed: true for a reversed axis, false otherwise
        public init(droneModel: Drone.Model, axis: SkyCtrl3Axis, reversed: Bool) {
            self.droneModel = droneModel
            self.axis = axis
            self.reversed = reversed
        }
    }

    /// Implementation backend
    private unowned let backend: SkyCtrl3GamepadBackend

    /// Listener that will be called when button events are grabbed, and that their state changes.
    /// Parameter event of the listener represents the button event that is concerned.
    /// Parameter state of the listener represents the state of the button event
    public var buttonEventListener: ((_ event: SkyCtrl3ButtonEvent, _ state: SkyCtrl3ButtonEventState) -> Void)?

    /// Listener that will be called when axis events are grabbed, and that their value changes.
    /// Parameter event of the listener represents the axis event that is concerned.
    /// Parameter value of the listener represents the current position of the axis, i.e. an int value in range
    /// [-100, 100], where -100 corresponds to the axis at start of its course
    /// (left for horizontal axes, down for vertical axes), and 100 represents the axis at end of its course
    /// (right for horizontal axes, up for vertical axes).
    public var axisEventListener: ((_ event: SkyCtrl3AxisEvent, _ value: Int) -> Void)?

    /// Set of currently grabbed buttons.
    public var grabbedButtons = Set<SkyCtrl3Button>()

    /// Set of currently grabbed axes.
    public var grabbedAxes = Set<SkyCtrl3Axis>()

    /// Current state of all the button events produced by all the grabbed inputs.
    public var grabbedButtonsState = [SkyCtrl3ButtonEvent: SkyCtrl3ButtonEventState]()

    /// Set of drone models supported by the remote control.
    public var supportedDroneModels = Set<Drone.Model>()

    /// Currently active drone model.
    ///
    /// The active drone model is the model of the drone currently connected through the remote control, or the latest
    /// connected drone's model if the remote control is not connected to any drone at the moment.
    public var activeDroneModel: Drone.Model?

    /// Current mappings indexed by drone model
    /// A mapping for a supported drone model could be nil if not received yet, however, the function
    /// `mapping(forModel:)` should return an empty set in this case.
    private var mappings: [Drone.Model: Set<SkyCtrl3MappingEntry>] = [:]

    /// Dictionary of interpolators indexed by axis. Interpolators is itself a dictionary of an axis interpolator value
    /// indexed by an axis.
    private var axisInterpolators: [Drone.Model: [SkyCtrl3Axis: AxisInterpolator]] = [:]

    /// Set of reversed axes indexed by drone models.
    private var reversedAxes: [Drone.Model: Set<SkyCtrl3Axis>] = [:]

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: VirtualGamepad backend
    public init(store: ComponentStoreCore, backend: SkyCtrl3GamepadBackend) {
        self.backend = backend
        super.init(desc: Peripherals.skyCtrl3Gamepad, store: store)
    }

    public func grab(buttons: Set<SkyCtrl3Button>, axes: Set<SkyCtrl3Axis>) {
        if buttons != grabbedButtons || axes != grabbedAxes {
            backend.grab(buttons: buttons, axes: axes)
        }
    }

    public func mapping(forModel droneModel: Drone.Model) -> Set<SkyCtrl3MappingEntry>? {
        // if the drone is not supported, returns nil
        // otherwise, return at least an empty set
        // the case where a mapping for a supported model is nil can happen if the user removed all entries for this
        // model
        return (supportedDroneModels.contains(droneModel)) ? mappings[droneModel] ?? [] : nil
    }

    @objc(registerMappingEntry:)
    public func register(mappingEntry: SkyCtrl3MappingEntry) {
        // if the drone model of the mapping entry is supported and the mappings does not contain the entry
        if supportedDroneModels.contains(mappingEntry.droneModel) &&
            !(mappings[mappingEntry.droneModel]?.contains(mappingEntry) ?? false) {
            // do not allow to add a button mapping entry without buttons
            if let buttonEntry = mappingEntry as? SkyCtrl3ButtonsMappingEntry, buttonEntry.buttonEvents.isEmpty {
                return
            }
            backend.setup(mappingEntry: mappingEntry, register: true)
        }
    }

    @objc(unregisterMappingEntry:)
    public func unregister(mappingEntry: SkyCtrl3MappingEntry) {
        // if the drone model of the mapping entry is supported and the mappings contain the entry
        if supportedDroneModels.contains(mappingEntry.droneModel) &&
            mappings[mappingEntry.droneModel]?.contains(mappingEntry) ?? true {
            backend.setup(mappingEntry: mappingEntry, register: false)
        }
    }

    @objc(resetMappingForModel:)
    public func resetMapping(forModel droneModel: Drone.Model) {
        if supportedDroneModels.contains(droneModel) {
            backend.resetMapping(forModel: droneModel)
        }
    }

    public func resetAllMappings() {
        backend.resetMapping(forModel: nil)
    }

    @objc(setInterpolator:forAxis:droneModel:)
    public func set(interpolator: AxisInterpolator, forAxis axis: SkyCtrl3Axis, droneModel: Drone.Model) {
        if let interpolators = axisInterpolators[droneModel], interpolators[axis] != interpolator {
            backend.set(interpolator: interpolator, forDroneModel: droneModel, onAxis: axis)
        }
    }

    public func interpolator(forAxis axis: SkyCtrl3Axis, droneModel: Drone.Model) -> AxisInterpolator? {
        return axisInterpolators[droneModel]?[axis]
    }

    @objc(reverseAxis:forDroneModel:)
    public func reverse(axis: SkyCtrl3Axis, forDroneModel droneModel: Drone.Model) {
        if let reversedAxes = reversedAxes[droneModel] {
            backend.set(axis: axis, forDroneModel: droneModel, reversed: !reversedAxes.contains(axis))
        }
    }

    public func reversedAxes(forDroneModel droneModel: Drone.Model) -> Set<SkyCtrl3Axis>? {
        // if the drone is not supported, returns nil
        // otherwise, return at least an empty set
        return (supportedDroneModels.contains(droneModel)) ? reversedAxes[droneModel] ?? [] : nil
    }

    private func updateMappings(_ mappingsToAdd: [SkyCtrl3MappingEntry], target: SkyCtrl3MappingEntryType) {
        // remove all current mapping entries matching target types
        mappings.forEach { model, set in
            mappings[model] = Set(set.filter {
                if $0.type == target {
                    markChanged()
                    return false
                }
                return true
            })
        }

        // add all new mappings
        mappingsToAdd.forEach { mapping in
            let droneModel = mapping.droneModel
            var droneMappings = mappings[droneModel]
            if droneMappings == nil {
                droneMappings = []
            }
            if droneMappings!.insert(mapping).inserted {
                mappings[droneModel] = droneMappings
                markChanged()
            }
        }
    }
}

/// Extension of SkyCtrl3GamepadCore that provides function that can be called by the backend
extension SkyCtrl3GamepadCore {

    /// Updates the set of currently grabbed buttons
    ///
    /// - Parameter buttons: the new set of grabbed buttons
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult
    public func updateGrabbedButtons(_ buttons: Set<SkyCtrl3Button>) -> SkyCtrl3GamepadCore {
        if grabbedButtons != buttons {
            grabbedButtons = buttons
            markChanged()
        }
        return self
    }

    /// Updates the set of currently grabbed axes
    ///
    /// - Parameter axes: the new set of grabbed axes
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult
    public func updateGrabbedAxes(_ axes: Set<SkyCtrl3Axis>) -> SkyCtrl3GamepadCore {
        if grabbedAxes != axes {
            grabbedAxes = axes
            markChanged()
        }
        return self
    }

    /// Updates the state of the buttons events corresponding to the currently grabbed buttons
    ///
    /// This should typically be called when initial states are set after a grab.
    ///
    /// This will also forward button events and their state to the application for all buttons that are in the
    /// `.pressed` state in the provided state map.
    ///
    /// - Parameter buttonEventsState: a dictionary that associates a state to a button event
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult
    public func updateButtonEventStates(_ buttonEventStates: [SkyCtrl3ButtonEvent: SkyCtrl3ButtonEventState])
        -> SkyCtrl3GamepadCore {
            if grabbedButtonsState != buttonEventStates {
                grabbedButtonsState = buttonEventStates
                markChanged()
                // also forward currently pressed buttons as events
                if let buttonEventListener = buttonEventListener {
                    for (buttonEvent, buttonState) in grabbedButtonsState where buttonState == .pressed {
                        buttonEventListener(buttonEvent, buttonState)
                    }
                }
            }
            return self
    }

    /// Updates the state of a given button event.
    ///
    /// Update is only done if the button event has already been set once during this grab through
    /// `updateButtonEventStates(buttonEventStates)`.
    ///
    /// This will also forward button events and its state to the application.
    ///
    /// - Parameters:
    ///    - buttonEvent: the button event to update
    ///    - state: the state of the button
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult
    public func updateButtonEventState(_ buttonEvent: SkyCtrl3ButtonEvent, state: SkyCtrl3ButtonEventState)
        -> SkyCtrl3GamepadCore {
            let currentState = grabbedButtonsState[buttonEvent]
            if let currentState = currentState, currentState != state {
                grabbedButtonsState[buttonEvent] = state
                markChanged()
                if let buttonEventListener = buttonEventListener {
                    buttonEventListener(buttonEvent, state)
                }
            }
            return self
    }

    /// Forward to the application the value for the given axis event.
    ///
    /// - Parameters:
    ///    - axisEvent: axis event to forward
    ///    - value: axis value (in range [-100;100])
    /// - Returns: self to allow call chaining
    @discardableResult
    public func updateAxisEventValue(_ axisEvent: SkyCtrl3AxisEvent, value: Int) -> SkyCtrl3GamepadCore {
        if let axisEventListener = axisEventListener {
            axisEventListener(axisEvent, value)
        }
        return self
    }

    /// Update the button mappings
    ///
    /// - Parameter mappings: new list of buttons mapping entries
    /// - Returns: self to allow call chaining
    @discardableResult
    public func updateButtonsMappings(_ mappings: [SkyCtrl3ButtonsMappingEntry]) -> SkyCtrl3GamepadCore {
        updateMappings(mappings, target: .buttons)
        return self
    }

    /// Update the axis mappings
    ///
    /// - Parameter mappings: new list of axis mapping entries
    /// - Returns: self to allow call chaining
    @discardableResult
    public func updateAxisMappings(_ mappings: [SkyCtrl3AxisMappingEntry]) -> SkyCtrl3GamepadCore {
        updateMappings(mappings, target: .axis)
        return self
    }

    /// Update the active drone model
    ///
    /// - Parameter droneModel: new active drone model
    /// - Returns: self to allow call chaining
    @discardableResult
    public func updateActiveDroneModel(_ droneModel: Drone.Model) -> SkyCtrl3GamepadCore {
        if activeDroneModel != droneModel {
            activeDroneModel = droneModel
            markChanged()
        }
        return self
    }

    /// Update the set of of the supported drone models
    ///
    /// - Parameter droneModels: new set of supported drone models
    /// - Returns: self to allow call chaining
    @discardableResult
    public func updateSupportedDroneModels(_ droneModels: Set<Drone.Model>) -> SkyCtrl3GamepadCore {
        if supportedDroneModels != droneModels {
            supportedDroneModels = droneModels
            markChanged()
        }
        return self
    }

    /// Updates all axis interpolators.
    ///
    /// - Note: calling this function will automatically set changed to true since it would be to heavy to check if the
    ///     issued new dictionary is different from the old one.
    ///
    /// - Parameter interpolators: new array of axis interpolator entries
    /// - Returns: self to allow call chaining
    @discardableResult
    public func updateAxisInterpolators(_ interpolators: [AxisInterpolatorEntry]) -> SkyCtrl3GamepadCore {
        axisInterpolators.removeAll()
        interpolators.forEach { entry in
            var droneInterpolators = axisInterpolators[entry.droneModel]
            if droneInterpolators == nil {
                droneInterpolators = [:]
            }
            droneInterpolators![entry.axis] = entry.interpolator
            axisInterpolators[entry.droneModel] = droneInterpolators
        }

        // we assume that the device notifies us with a real change
        markChanged()

        return self
    }

    /// Updates all reversed axes.
    ///
    /// - Note: calling this function will automatically set changed to true since it would be to heavy to check if the
    ///     issued new dictionary is different from the old one.
    ///
    /// - Parameter newReversedAxes: new array of reversed axis entries
    /// - Returns: self to allow call chaining
    @discardableResult
    public func updateReversedAxes(_ newReversedAxes: [ReversedAxisEntry]) -> SkyCtrl3GamepadCore {
        reversedAxes.removeAll()
        newReversedAxes.forEach { entry in
            var droneReversedAxes = reversedAxes[entry.droneModel]
            if droneReversedAxes == nil {
                droneReversedAxes = []
            }
            if entry.reversed {
                droneReversedAxes!.insert(entry.axis)
            }
            reversedAxes[entry.droneModel] = droneReversedAxes
        }

        // we assume that the device notifies us with a real change
        markChanged()

        return self
    }

    /// Resets the button and axis listeners
    /// Should be called before that the component is unpublished
    public func resetEventListeners() {
        buttonEventListener = nil
        axisEventListener = nil
    }

    override func reset() {
        super.reset()
        buttonEventListener = nil
        axisEventListener = nil
        grabbedButtons = []
        grabbedAxes = []
        grabbedButtonsState = [:]
        supportedDroneModels = []
        mappings = [:]
        axisInterpolators = [:]
        reversedAxes = [:]
    }
}

/// Extension of SkyCtrl3GamepadCore that implements the GSSkyCtrl3Gamepad (obj-c protocol).
/// Only transforms Obj-C compatible objects into Swift ones
extension SkyCtrl3GamepadCore: GSSkyCtrl3Gamepad {
    public func getGrabbedButtonsState() -> [Int: Int] {
        var buttonsState = [Int: Int]()
        for (event, state) in grabbedButtonsState {
            buttonsState[event.rawValue] = state.rawValue
        }
        return buttonsState
    }

    public func getGrabbedButtons() -> GSSkyCtrl3ButtonSet {
        return GSSkyCtrl3ButtonSet(buttonSet: grabbedButtons)
    }

    public func getGrabbedAxes() -> GSSkyCtrl3AxisSet {
        return GSSkyCtrl3AxisSet(axisSet: grabbedAxes)
    }

    public func grab(buttonSet: GSSkyCtrl3ButtonSet, axisSet: GSSkyCtrl3AxisSet) {
        grab(buttons: buttonSet.set, axes: axisSet.set)
    }

    public func getSupportedDroneModels() -> Drone.GSDroneModelSet {
        return Drone.GSDroneModelSet(modelSet: supportedDroneModels)
    }

    public var activeDroneModelAsNumber: NSNumber? {
        if let activeDroneModel = activeDroneModel {
            return NSNumber(value: activeDroneModel.rawValue)
        }
        return nil
    }

    public func gsInterpolator(forAxis axis: SkyCtrl3Axis, droneModel: Drone.Model) -> NSNumber? {
        if let axisInterpolator = interpolator(forAxis: axis, droneModel: droneModel) {
            return NSNumber(value: axisInterpolator.rawValue)
        }
        return nil
    }

    public func gsReversedAxes(forDroneModel droneModel: Drone.Model) -> GSSkyCtrl3AxisSet? {
        if let axisSet = reversedAxes(forDroneModel: droneModel) {
            return GSSkyCtrl3AxisSet(axisSet: axisSet)
        }
        return nil
    }
}
