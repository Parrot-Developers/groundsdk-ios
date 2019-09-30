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

/// Gamepad peripheral for `skyCtrl3` remote control devices.
///
/// This peripheral allows:
/// * To receive events when physical inputs (buttons/axes) on the device are triggered.
/// * To configure mappings between combinations of physical inputs and predefined actions to execute or
/// events to forward to the application when such combinations are triggered.
///
/// To start receiving events, a set of `SkyCtrl3Button` and `SkyCtrl3Axis` must be grabbed and
/// and some event listener has to be provided.
///
/// When a gamepad input is grabbed, the remote control will stop forwarding events associated to this input to the
/// connected drone (if any) and instead forward those events to the application-provided listener.
///
/// Each input may produce at least one, but possibly multiple specific events, which is documented in
/// `SkyCtrl3Button` and `SkyCtrl3Axis`.
///
/// To stop receiving events, the input must be ungrabbed, and by doing so the remote control will resume forwarding
/// that input events back to the connected drone instead, or, if the `VirtualGamepad` was grabbing navigation events,
/// it will receive again the navigation events.
///
/// Alternatively the application can unregister its event listeners to stop receiving events from all grabbed inputs
/// altogether. Note, however, that doing so does not release any input, so the drone still won't receive the grabbed
/// input events.
///
/// To receive input events, the application must register some listener to which those event will be forwarded.
/// Event listeners come in two kind, depending on the event to be listened to:
/// * A `(_ event: SkyCtrl3ButtonEvent, _ state: SkyCtrl3ButtonEventState) -> Void` that receives events from inputs
/// producing `SkyCtrl3ButtonEvent` events.
/// This listener also provides the physical state of the associated input, i.e. whether the associated button is
/// `.pressed` or `.released`.
/// Note that physical axes produce a button press event every time they reach the start or end of their course,
/// and a button release event every time they quit that position.
/// * A `(_ event: SkyCtrl3AxisEvent, _ value: Int) -> Void` that receives events from inputs producing
/// `SkyCtrl3AxisEvent` events.
/// This listener also provides the current value of the associated input, i.e. an int value in range [-100, 100]
/// that represents the current position of the axis, where -100 corresponds to the axis at start of its course
/// (left for horizontal axes, down for vertical axes), and 100 represents the axis at end of its course
/// (right for horizontal axes, up for vertical axes).
///
/// A mapping defines a set of actions that may each be triggered by a specific combination of inputs events
/// (buttons, and/or axes) produced by the remote control.
/// Those mappings can be edited and are persisted on the remote control device: entries can be modified, removed,
/// and new entries can be added as well.
///
/// A `SkyCtrl3MappingEntry` in a mapping defines the association between such an action, the drone model on which
/// it should apply, and the combination of input events that should trigger the action.
/// Two different kind of entries are available:
///   - a `SkyCtrl3ButtonsMappingEntry` entry allows to trigger a `SkyCtrl3ButtonsMappableAction` when the gamepad
///     inputs produce some set of `SkyCtrl3ButtonEvent` in the `.pressed` state.
///   - a `SkyCtrl3AxisMappingEntry` entry allows to trigger an `SkyCtrl3AxisMappableAction` when the gamepad inputs
///     produce some `SkyCtrl3AxisEvent`, optionally in conjunction with some set of
///     `SkyCtrl3ButtonEvent` in the `.pressed` state.
///
/// This peripheral can be retrieved by:
/// ```
/// drone.getPeripheral(Peripherals.skyCtrl3Gamepad)
/// ```
public protocol SkyCtrl3Gamepad: Peripheral {

    /// Listener that will be called when input button events are grabbed, and that their state changes.
    /// Parameter event of the listener represents the button event that is concerned.
    /// Parameter state of the listener represents the state of the button event
    var buttonEventListener: ((_ event: SkyCtrl3ButtonEvent, _ state: SkyCtrl3ButtonEventState) -> Void)? { get set }

    /// Listener that will be called when input axis events are grabbed, and that their value changes.
    /// Parameter event of the listener represents the axis event that is concerned.
    /// Parameter value of the listener represents the current position of the axis, i.e. an int value in range
    /// [-100, 100], where -100 corresponds to the axis at start of its course
    /// (left for horizontal axes, down for vertical axes), and 100 represents the axis at end of its course
    /// (right for horizontal axes, up for vertical axes).
    var axisEventListener: ((_ event: SkyCtrl3AxisEvent, _ value: Int) -> Void)? { get set }

    /// Set of currently grabbed buttons.
    var grabbedButtons: Set<SkyCtrl3Button> { get }

    /// Set of currently grabbed axes.
    var grabbedAxes: Set<SkyCtrl3Axis> { get }

    /// Current state of all the button events produced by all the grabbed inputs.
    var grabbedButtonsState: [SkyCtrl3ButtonEvent: SkyCtrl3ButtonEventState] { get }

    /// Set of drone models supported by the remote control.
    ///
    /// This defines the set of drone models for which the application can edit mappings.
    var supportedDroneModels: Set<Drone.Model> { get }

    /// Currently active drone model.
    ///
    /// The active drone model is the model of the drone currently connected through the remote control, or the latest
    /// connected drone's model if the remote control is not connected to any drone at the moment.
    var activeDroneModel: Drone.Model? { get }

    /// Grabs gamepad inputs.
    ///
    /// Grabs the given set of inputs, requiring the skycontroller3 device to send events from those inputs
    /// to the application listener instead forwarding them of the drone.
    ///
    /// The provided set of inputs completely overrides the current set of grabbed inputs (if any). So, for instance,
    /// to release all inputs, this method should be called with an empty set.
    /// To grab or release some specific inputs without altering the rest of the grabbed inputs,
    /// `grabbedButtons` and `grabbedAxes` may be used to construct a new set of inputs to provide to this
    /// method.
    ///
    /// - Parameters:
    ///   - buttons: set of buttons to be grabbed
    ///   - axes: set of axes to be grabbed
    func grab(buttons: Set<SkyCtrl3Button>, axes: Set<SkyCtrl3Axis>)

    /// Gets a mapping for a given drone model
    ///
    /// - Parameter droneModel: the drone model for which to retrieve the mapping
    /// - Returns: set of current mapping entries as configured for the provided drone model (possibly empty if no entry
    ///     is defined for that model), otherwise nil in case the drone model is not supported.
    func mapping(forModel droneModel: Drone.Model) -> Set<SkyCtrl3MappingEntry>?

    /// Registers a mapping entry.
    ///
    /// This allows to setup a new mapping entry in a drone model's mapping (in case the entry's action is not
    /// registered yet in the drone mapping) or to modify an existing entry (in case the entry's action is already
    /// registered in the drone mapping).
    ///
    /// If the drone model is supported, the entry gets persisted in the corresponding mapping on the remote control.
    ///
    /// - note: that adding or editing a mapping entry may have impact on other existing entries in the same
    ///     mapping, since the same combination of input events cannot be used on more than one mapping entry at the
    ///     same time.
    ///     As a result, when hitting such a situation, the existing conflicting entry is removed, and the new entry is
    ///     registered instead.
    ///
    ///     Also note that adding a `SkyCtrl3ButtonsMappingEntry` with an empty button events set will be refused.
    ///
    /// - Parameter mappingEntry: mapping entry to register
    func register(mappingEntry: SkyCtrl3MappingEntry)

    /// Unregisters a mapping entry
    ///
    /// This allows to remove a mapping entry from a drone model's mapping.
    /// If the drone model is supported, the entry gets persistently removed from the corresponding mapping on the
    /// remote control.
    ///
    /// - Parameter mappingEntry: mapping entry to unregister
    func unregister(mappingEntry: SkyCtrl3MappingEntry)

    /// Resets a drone model mapping to its default (built-in) value.
    ///
    /// - Parameter droneModel: the drone model for which to reset the mapping
    func resetMapping(forModel droneModel: Drone.Model)

    /// Resets all supported drone models mappings to their default (built-in) value.
    func resetAllMappings()

    /// Sets the interpolation formula to be applied on an axis.
    ///
    /// An axis interpolator affects the values sent to the connected drone when moving the gamepad axis.
    /// It maps the physical linear position of the axis to another value by applying a predefined formula.
    ///
    /// - note:  Note that the current interpolator set on an axis also affects the values sent through
    /// `axisEventListener` for grabbed inputs.
    ///
    /// - Parameters:
    ///   - interpolator: interpolator to set
    ///   - axis: axis to set the interpolator for
    ///   - droneModel: drone model for which the axis interpolator must be applied
    func set(interpolator: AxisInterpolator, forAxis axis: SkyCtrl3Axis, droneModel: Drone.Model)

    /// Gets the axis interpolator currently applied on a given drone model on a given axis.
    ///
    /// - Parameters:
    ///   - axis: axis of the given drone model whose interpolator must be retrieved
    ///   - droneModel: drone model whose axis interpolators must be retrieved
    /// - Returns: an interpolator if the drone model is supported and the interpolator is known, otherwise nil
    func interpolator(forAxis axis: SkyCtrl3Axis, droneModel: Drone.Model) -> AxisInterpolator?

    /// Reverses a gamepad axis.
    ///
    /// A reversed axis produces values reversed symmetrically around the axis standstill value (0).
    /// For instance, an horizontal axis will produce values from 100 when held at (left) start of its course,
    /// to -100, when held at (right) end of its course, while when not reversed, it will produce values from -100 when
    /// held at (left) start of its course, to 100 when held at (right) end of its course.
    /// Same thing applies to vertical axes, where produced values will range from 100 (bottom start) to -100 (top end)
    /// instead of -100 (bottom start) to 100 (top end).
    ///
    /// Reversing an already reversed axis sets the axis back to normal operation mode.
    ///
    /// The axis inversion stage occurs **before** any interpolation formula is applied.
    ///
    ///
    /// - Note: Note that axis inversion has no effect whatsoever on the values sent through `axisEventListener`
    /// for grabbed inputs. In other words, when receiving grabbed axes events, it can be considered that the axis is
    /// never reversed.
    ///
    /// - Parameters:
    ///   - axis: axis to reverse
    ///   - droneModel: drone model for which the axis must be reversed
    func reverse(axis: SkyCtrl3Axis, forDroneModel droneModel: Drone.Model)

    /// Gets all currently reversed axis for a given drone model.
    ///
    /// - Parameter droneModel: drone model whose reversed axes must be retrieved
    /// - Returns: the set of currently reversed axes, or `nil` if the provided drone model is not supported
    func reversedAxes(forDroneModel droneModel: Drone.Model) -> Set<SkyCtrl3Axis>?

    /// Setting for volatile mapping mode
    /// All mapping entries registered with volatile mapping enabled will be removed when it is disabled or when
    /// remote control is disconnected. Disabling volatile mapping also cancels any ongoing action.
    /// Setting is nil if volatile mapping is not supported.
    var volatileMappingSetting: BoolSetting? { get }

}

/// :nodoc:
/// SkyController 3 gamepad descriptor
@objc(GSSkyCtrl3GamepadDesc)
public class SkyCtrl3GamepadDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = SkyCtrl3Gamepad
    public let uid = PeripheralUid.skyCtrl3Gamepad.rawValue
    public let parent: ComponentDescriptor? = nil
}

/// Gamepad peripheral for `skyCtrl3` remote control devices.
///
/// This peripheral allows:
/// * To receive events when physical inputs (buttons/axes) on the device are triggered.
/// * To configure mappings between combinations of physical inputs and predefined actions to execute or
/// events to forward to the application when such combinations are triggered.
///
/// To start receiving events, a set of `SkyCtrl3Button` and `SkyCtrl3Axis` must be grabbed and
/// and some event listener has to be provided.
///
/// When a gamepad input is grabbed, the remote control will stop forwarding events associated to this input to the
/// connected drone (if any) and instead forward those events to the application-provided listener.
///
/// Each input may produce at least one, but possibly multiple specific events, which is documented in
/// `SkyCtrl3Button` and `SkyCtrl3Axis`.
///
/// To stop receiving events, the input must be ungrabbed, and by doing so the remote control will resume forwarding
/// that input events back to the connected drone instead, or, if the `VirtualGamepad` was grabbing navigation events,
/// it will receive again the navigation events.
///
/// Alternatively the application can unregister its event listeners to stop receiving events from all grabbed inputs
/// altogether. Note, however, that doing so does not release any input, so the drone still won't receive the grabbed
/// input events.
///
/// To receive input events, the application must register some listener to which those event will be forwarded.
/// Event listeners come in two kind, depending on the event to be listened to:
/// * A `(_ event: SkyCtrl3ButtonEvent, _ state: SkyCtrl3ButtonEventState) -> Void` that receives events from inputs
/// producing `SkyCtrl3ButtonEvent` events.
/// This listener also provides the physical state of the associated input, i.e. whether the associated button is
/// `.pressed` or `.released`.
/// Note that physical axes produce a button press event every time they reach the start or end of their course,
/// and a button release event every time they quit that position.
/// * A `(_ event: SkyCtrl3AxisEvent, _ value: Int) -> Void` that receives events from inputs producing
/// `SkyCtrl3AxisEvent` events.
/// This listener also provides the current value of the associated input, i.e. an int value in range [-100, 100]
/// that represents the current position of the axis, where -100 corresponds to the axis at start of its course
/// (left for horizontal axes, down for vertical axes), and 100 represents the axis at end of its course
/// (right for horizontal axes, up for vertical axes).
///
/// A mapping defines a set of actions that may each be triggered by a specific combination of inputs events
/// (buttons, and/or axes) produced by the remote control.
/// Those mappings can be edited and are persisted on the remote control device: entries can be modified, removed,
/// and new entries can be added as well.
///
/// A `SkyCtrl3MappingEntry` in a mapping defines the association between such an action, the drone model on which
/// it should apply, and the combination of input events that should trigger the action.
/// Two different kind of entries are available:
///   - a `SkyCtrl3ButtonsMappingEntry` entry allows to trigger a `SkyCtrl3ButtonsMappableAction` when the gamepad
///     inputs produce some set of `SkyCtrl3ButtonEvent` in the `.pressed` state.
///   - a `SkyCtrl3AxisMappingEntry` entry allows to trigger an `SkyCtrl3AxisMappableAction` when the gamepad inputs
///     produce some `SkyCtrl3AxisEvent`, optionally in conjunction with some set of
///     `SkyCtrl3ButtonEvent` in the `.pressed` state.
///
/// This peripheral can be retrieved by:
///
/// ```
/// (id<GSSkyCtrl3Gamepad>) [drone getPeripheral:GSPeripherals.skyCtrl3Gamepad]
/// ```
///
/// - note: this protocol is for Objective-C only. Swift must use the protocol `SkyCtrl3Gamepad`
@objc
public protocol GSSkyCtrl3Gamepad: Peripheral {

    /// Listener that will be called when input button events are grabbed, and that their state changes.
    /// Parameter event of the listener represents the button event that is concerned.
    /// Parameter state of the listener represents the state of the button event
    var buttonEventListener: ((_ event: SkyCtrl3ButtonEvent, _ state: SkyCtrl3ButtonEventState) -> Void)? { get set }

    /// Listener that will be called when input axis events are grabbed, and that their value changes.
    /// Parameter event of the listener represents the axis event that is concerned.
    /// Parameter value of the listener represents the current position of the axis, i.e. an int value in range
    /// [-100, 100], where -100 corresponds to the axis at start of its course
    /// (left for horizontal axes, down for vertical axes), and 100 represents the axis at end of its course
    /// (right for horizontal axes, up for vertical axes).
    var axisEventListener: ((_ event: SkyCtrl3AxisEvent, _ value: Int) -> Void)? { get set }

    /// Currently active drone model.
    ///
    /// The active drone model is the model of the drone currently connected through the remote control, or the latest
    /// connected drone's model if the remote control is not connected to any drone at the moment.
    var activeDroneModelAsNumber: NSNumber? { get }

    /// Current state of all the button events produced by all the grabbed inputs.
    /// This maps a `SkyCtrl3ButtonEventState` raw value to a `SkyCtrl3ButtonEvent` raw value as key.
    func getGrabbedButtonsState() -> [Int: Int]

    /// Gets the set of currently grabbed button inputs.
    ///
    /// - Returns: the set of grabbed buttons
    func getGrabbedButtons() -> GSSkyCtrl3ButtonSet

    /// Gets the set of currently grabbed axis inputs.
    ///
    /// - Returns: the set of grabbed axes
    func getGrabbedAxes() -> GSSkyCtrl3AxisSet

    /// Grabs gamepad inputs.
    ///
    /// Grabs the given set of inputs, requiring the skycontroller3 device to send events from those inputs
    /// to the application listener instead forwarding them of the drone.
    ///
    /// The provided set of inputs completely overrides the current set of grabbed inputs (if any). So, for instance,
    /// to release all inputs, this method should be called with an empty set.
    /// To grab or release some specific inputs without altering the rest of the grabbed inputs,
    /// `getGrabbedButtons()` and `getGrabbedAxes()` may be used to construct a new set of inputs to
    /// provide to this method.
    ///
    /// - Parameters:
    ///   - buttonSet: set of buttons to be grabbed
    ///   - axisSet: set of axes to be grabbed
    func grab(buttonSet: GSSkyCtrl3ButtonSet, axisSet: GSSkyCtrl3AxisSet)

    /// Gets the set of drone models supported by the remote control.
    ///
    /// This defines the set of drone models for which the application can edit mappings.
    ///
    /// - Returns: a set of drone models
    func getSupportedDroneModels() -> Drone.GSDroneModelSet

    /// Gets a mapping for a given drone model
    ///
    /// - Parameter droneModel: the drone model for which to retrieve the mapping
    /// - Returns: set of current mapping entries as configured for the provided drone model (possibly empty if no entry
    ///     is defined for that model), otherwise nil in case the drone model is not supported.
    func mapping(forModel droneModel: Drone.Model) -> Set<SkyCtrl3MappingEntry>?

    /// Registers a mapping entry.
    ///
    /// This allows to setup a new mapping entry in a drone model's mapping (in case the entry's action is not
    /// registered yet in the drone mapping) or to modify an existing entry (in case the entry's action is already
    /// registered in the drone mapping).
    ///
    /// If the drone model is supported, the entry gets persisted in the corresponding mapping on the remote control.
    ///
    /// - note: that adding or editing a mapping entry may have impact on other existing entries in the same
    ///     mapping, since the same combination of input events cannot be used on more than one mapping entry at the
    ///     same time.
    ///     As a result, when hitting such a situation, the existing conflicting entry is removed, and the new entry is
    ///     registered instead.
    ///
    ///     Also note that adding a `SkyCtrl3ButtonsMappingEntry` with an empty button events set will be refused.
    ///
    /// - Parameter mappingEntry: mapping entry to register
    @objc(registerMappingEntry:)
    func register(mappingEntry: SkyCtrl3MappingEntry)

    /// Unregisters a mapping entry
    ///
    /// This allows to remove a mapping entry from a drone model's mapping.
    /// If the drone model is supported, the entry gets persistently removed from the corresponding mapping on the
    /// remote control.
    ///
    /// - Parameter mappingEntry: mapping entry to unregister
    @objc(unregisterMappingEntry:)
    func unregister(mappingEntry: SkyCtrl3MappingEntry)

    /// Resets a drone model mapping to its default (built-in) value.
    ///
    /// - Parameter droneModel: the drone model for which to reset the mapping
    @objc(resetMappingForModel:)
    func resetMapping(forModel  droneModel: Drone.Model)

    /// Resets all supported drone models' mappings to their default (built-in) value.
    func resetAllMappings()

    /// Sets the interpolation formula to be applied on an axis.
    ///
    /// An axis interpolator affects the values sent to the connected drone when moving the gamepad axis.
    /// It maps the physical linear position of the axis to another value by applying a predefined formula.
    ///
    /// - note:  Note that the current interpolator set on an axis also affects the values sent through
    /// `axisEventListener` for grabbed inputs.
    ///
    /// - Parameters:
    ///   - interpolator: interpolator to set
    ///   - axis: axis to set the interpolator for
    ///   - droneModel: drone model for which the axis interpolator must be applied
    @objc(setInterpolator:forAxis:droneModel:)
    func set(interpolator: AxisInterpolator, forAxis axis: SkyCtrl3Axis, droneModel: Drone.Model)

    /// Gets the axis interpolator currently applied on a given drone model on a given axis.
    ///
    /// - Parameters:
    ///   - axis: axis of the given drone model whose interpolator must be retrieved
    ///   - droneModel: drone model whose axis interpolators must be retrieved
    /// - Returns: an interpolator if the drone model is supported and the interpolator is known, otherwise nil
    @objc(interpolatorForAxis:droneModel:)
    func gsInterpolator(forAxis axis: SkyCtrl3Axis, droneModel: Drone.Model) -> NSNumber?

    /// Reverses a gamepad axis.
    ///
    /// A reversed axis produces values reversed symmetrically around the axis standstill value (0).
    /// For instance, an horizontal axis will produce values from 100 when held at (left) start of its course,
    /// to -100, when held at (right) end of its course, while when not reversed, it will produce values from -100 when
    /// held at (left) start of its course, to 100 when held at (right) end of its course.
    /// Same thing applies to vertical axes, where produced values will range from 100 (bottom start) to -100 (top end)
    /// instead of -100 (bottom start) to 100 (top end).
    ///
    /// Reversing an already reversed axis sets the axis back to normal operation mode.
    ///
    /// The axis inversion stage occurs **before** any interpolation formula is applied.
    ///
    ///
    /// - Note: Note that axis inversion has no effect whatsoever on the values sent through `axisEventListener`
    /// for grabbed inputs. In other words, when receiving grabbed axes events, it can be considered that the axis is
    /// never reversed.
    ///
    /// - Parameters:
    ///   - axis: axis to reverse
    ///   - droneModel: drone model for which the axis must be reversed
    @objc(reverseAxis:forDroneModel:)
    func reverse(axis: SkyCtrl3Axis, forDroneModel droneModel: Drone.Model)

    /// Gets all currently reversed axis for a given drone model.
    ///
    /// - Parameter droneModel: drone model whose reversed axes must be retrieved
    /// - Returns: the set of currently reversed axes, or `nil` if the provided drone model is not supported
    @objc(reversedAxesForDroneModel:)
    func gsReversedAxes(forDroneModel droneModel: Drone.Model) -> GSSkyCtrl3AxisSet?

    /// Setting for volatile mapping mode
    /// All mapping entries registered with volatile mapping enabled will be removed when it is disabled or when
    /// remote control is disconnected. Disabling volatile mapping also cancels any ongoing action.
    /// Setting is nil if volatile mapping is not supported.
    var volatileMappingSetting: BoolSetting? { get }
}
