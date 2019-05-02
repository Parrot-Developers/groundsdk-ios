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

/// Type of a mapping entry.
@objc(GSSkyCtrl3MappingEntryType)
public enum SkyCtrl3MappingEntryType: Int {
    /// Entry of this type is a `SkyCtrl3ButtonsMappingEntry` and can be casted as such.
    case buttons

    /// Entry of this type is a `SkyCtrl3AxisMappingEntry` and can be casted as such.
    case axis

    /// Debug description.
    public var description: String {
        switch self {
        case .buttons:  return "buttons"
        case .axis:     return "axis"
        }
    }
}

/// Defines a mapping entry.
///
/// A mapping entry collects the drone model onto which the entry should apply, as well as the type of the entry which
/// defines the concrete subclass of the entry.
///
/// No instance of this class can be created, you must either create a `SkyCtrl3ButtonsMappingEntry` or a
/// `SkyCtrl3AxisMappingEntry`.
@objcMembers
@objc(GSSkyCtrl3MappingEntry)
public class SkyCtrl3MappingEntry: NSObject {

    /// Associated drone model.
    public let droneModel: Drone.Model

    /// Entry type.
    public let type: SkyCtrl3MappingEntryType

    /// Constructor (private).
    ///
    /// - Parameters:
    ///   - droneModel: drone model onto which the entry should apply
    ///   - type: type of the entry
    fileprivate init(droneModel: Drone.Model, type: SkyCtrl3MappingEntryType) {
        self.droneModel = droneModel
        self.type = type
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? SkyCtrl3MappingEntry {
            return droneModel == object.droneModel && type == object.type
        }
        return false
    }

    public override var hash: Int {
        return 11 * type.rawValue + 9 * droneModel.rawValue
    }
}

/// A mapping entry that defines a `ButtonsMappableAction` to be triggered when the gamepad inputs produce a set of
/// `SkyCtrl3ButtonEvent` in the state `.pressed`.
@objcMembers
@objc(GSSkyCtrl3ButtonsMappingEntry)
public class SkyCtrl3ButtonsMappingEntry: SkyCtrl3MappingEntry {
    /// Action to be triggered.
    public let action: ButtonsMappableAction

    /// Set of button events that triggers the action when in the `.pressed` state.
    public let buttonEvents: Set<SkyCtrl3ButtonEvent>

    /// Set of button events that triggers the action when in the `.pressed` state as an Int set.
    ///
    /// - Note: This should be only used in Objective-C.
    public var buttonEventsAsInt: Set<Int> {
        return Set(buttonEvents.map({ $0.rawValue }))
    }

    /// Constructor.
    ///
    /// - Parameters:
    ///   - droneModel: drone model onto which the entry should apply
    ///   - action: action to be triggered
    ///   - buttonEvents: event set that triggers the action
    public init(droneModel: Drone.Model, action: ButtonsMappableAction, buttonEvents: Set<SkyCtrl3ButtonEvent>) {
        self.action = action
        self.buttonEvents = buttonEvents
        super.init(droneModel: droneModel, type: .buttons)
    }

    /// Constructor.
    ///
    /// - Parameters:
    ///   - droneModel: drone model onto which the entry should apply
    ///   - action: action to be triggered
    ///   - buttonEventsAsInt: event set that triggers the action
    ///
    /// - Note: This function is for Objective-C only.
    ///     Swift must use the function
    ///     `init(droneModel: Drone.Model, action: ButtonsMappableAction, buttonEvents: Set<SkyCtrl3ButtonEvent>)`
    public convenience init(droneModel: Drone.Model, action: ButtonsMappableAction, buttonEventsAsInt: Set<Int>) {
        let buttonEvents = Set(buttonEventsAsInt.map({ SkyCtrl3ButtonEvent(rawValue: $0)! }))
        self.init(droneModel: droneModel, action: action, buttonEvents: buttonEvents)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? SkyCtrl3ButtonsMappingEntry {
            return super.isEqual(object) && action == object.action && buttonEvents == object.buttonEvents
        }
        return false
    }

    public override var hash: Int {
        return super.hash + 7 * action.rawValue + buttonEvents.hashValue
    }
}

/// A mapping entry that defines a `AxisMappableAction` to be triggered when the gamepad inputs produce an
/// `SkyCtrl3AxisEvent`, and optionally in conjunction with a specific set of `SkyCtrl3ButtonEvent` in the
/// state `.pressed`.
@objcMembers
@objc(GSSkyCtrl3AxisMappingEntry)
public class SkyCtrl3AxisMappingEntry: SkyCtrl3MappingEntry {

    /// Action to be triggered.
    public let action: AxisMappableAction

    /// Axis event that triggers the action.
    public let axisEvent: SkyCtrl3AxisEvent

    /// Set of button events that triggers the action when in the `.pressed` state.
    public let buttonEvents: Set<SkyCtrl3ButtonEvent>

    /// Set of button events that triggers the action when in the `.pressed` state as an Int set.
    ///
    /// This should be only used in Objective-C
    public var buttonEventsAsInt: Set<Int> {
        return Set(buttonEvents.map({ $0.rawValue }))
    }

    /// Constructor.
    ///
    /// - Parameters:
    ///   - droneModel: drone model onto which the entry should apply
    ///   - action: action to be triggered
    ///   - axisEvent: axis event that triggers the action
    ///   - buttonEvents: event set that triggers the action
    public init(droneModel: Drone.Model, action: AxisMappableAction, axisEvent: SkyCtrl3AxisEvent,
                buttonEvents: Set<SkyCtrl3ButtonEvent>) {
        self.action = action
        self.axisEvent = axisEvent
        self.buttonEvents = buttonEvents
        super.init(droneModel: droneModel, type: .axis)
    }

    /// Constructor.
    ///
    /// - Parameters:
    ///   - droneModel: drone model onto which the entry should apply
    ///   - action: action to be triggered
    ///   - axisEvent: axis event that triggers the action
    ///   - buttonEventsAsInt: event set that triggers the action
    ///
    /// - Note: This function is for Objective-C only.
    ///     Swift must use the function
    ///     `init(droneModel: Drone.Model, action: ButtonsMappableAction, axisEvent: SkyCtrl3AxisEvent,
    ///     buttonEvents: Set<SkyCtrl3ButtonEvent>)`
    public convenience init(
        droneModel: Drone.Model, action: AxisMappableAction, axisEvent: SkyCtrl3AxisEvent,
        buttonEventsAsInt: Set<Int>) {
        let buttonEvents = Set(buttonEventsAsInt.map({ SkyCtrl3ButtonEvent(rawValue: $0)! }))
        self.init(droneModel: droneModel, action: action, axisEvent: axisEvent, buttonEvents: buttonEvents)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? SkyCtrl3AxisMappingEntry {
            return super.isEqual(object) && action == object.action && axisEvent == object.axisEvent &&
                buttonEvents == object.buttonEvents
        }
        return false
    }

    public override var hash: Int {
        return super.hash + 7 * action.rawValue + 5 * axisEvent.rawValue + buttonEvents.hashValue
    }
}
