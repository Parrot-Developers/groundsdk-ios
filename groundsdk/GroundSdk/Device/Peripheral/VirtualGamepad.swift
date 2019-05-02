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

/// A navigation event sent when the appropriate remote control input is triggered.
@objc(GSVirtualGamepadEvent)
public enum VirtualGamepadEvent: Int {

    /// Input used to validate an action was triggered.
    case ok

    /// Input used to cancel an action was triggered.
    case cancel

    /// Input used to navigate left was triggered.
    case left

    /// Input used to navigate right was triggered.
    case right

    /// Input used to navigate up was triggered.
    case up

    /// Input used to navigate down was triggered.
    case down

    /// Debug description.
    public var description: String {
        switch self {
        case .ok:       return "ok"
        case .cancel:   return "cancel"
        case .left:     return "left"
        case .right:    return "right"
        case .up:       return "up"
        case .down:     return "down"
        }
    }
}

/// State of an input associated to the event that was sent.
@objc(GSVirtualGamepadEventState)
public enum VirtualGamepadEventState: Int {

    /// Input was pressed.
    case pressed

    /// Input was released.
    case released

    /// Debug description.
    public var description: String {
        switch self {
        case .pressed:  return "pressed"
        case .released: return "released"
        }
    }
}

/// Virtual gamepad peripheral for `RemoteControl` devices.
///
/// Through this peripheral, you can receive navigation events when some predefined inputs are triggered on the remote
/// control.
///
/// The mapping between physical inputs (buttons, axes, etc.) on the device and received navigation events is specific
/// to the remote control in use: please refer to the remote control documentation for further information.
/// This peripheral is provided by all remote control devices, unless explicitly stated otherwise in the specific
/// remote control documentation.
///
/// To start receiving navigation events, the virtual gamepad peripheral must be grabbed and a listener (that will
/// receive all events) must be provided.
///
/// When the virtual gamepad is grabbed, the remote control will stop forwarding events associated to its navigation
/// inputs to the connected drone (if any) and instead forward those events to the application-provided listener.
/// To stop receiving events and having the device forward navigation input events back to the connected drone, the
/// virtual gamepad must be ungrabbed.
///
/// Most remote control devices also provide a more specialized gamepad interface (please refer to the remote control
/// documentation for further information), which usually allows to listen to finer-grained remote control input events.
/// However, when inputs are grabbed using such a specialized interface, the virtual gamepad is preempted, thus it
/// cannot be used anymore. While preempted, the navigation event won't be forwarded to the listener anymore, until all
/// inputs on the specialized gamepad interface are released.
/// At that point, the virtual gamepad will grab the navigation inputs again and resume forwarding events to the
/// application listener.
///
/// This peripheral is also in charge of notifying application events through the `NotificationCenter`.
/// Those events are the appAction* values defined in `ButtonsMappableAction` enum.
/// To subscribe to these notifications, please refer to the `GsdkActionGamepadAppAction` notification key
/// documentation.
///
/// This peripheral can be retrieved by:
/// ```
/// drone.getPeripheral(Peripherals.virtualGamepad)
/// ```
@objc(GSVirtualGamepad)
public protocol VirtualGamepad: Peripheral {

    /// Whether othe virtual gamepad is currently grabbed.
    /// If this peripheral is grabbed and not preempted, you should receive navigation events through the listener.
    var isGrabbed: Bool { get }

    /// Whether the virtual gamepad is preempted by the specific gamepad.
    /// If this peripheral is grabbed and not preempted, you should receive navigation events through the listener.
    var isPreempted: Bool { get }

    /// Whether or not the gamepad can be grabbed for navigation.
    var canGrab: Bool { get }

    /// Grabs the remote control navigation inputs.
    ///
    /// - Note: When grabbed, the remote control will stop forwarding events associated to its navigation
    /// inputs to the connected drone (if any) and instead forward those events to the application-provided listener.
    ///
    /// - Parameters:
    ///     - listener: the listener to forward navigation events to
    ///     - event: the virtual gamepad event that has been received
    ///     - state: the state corresponding to the event
    /// - Returns: `true` if navigation inputs could be grabbed, `false` otherwise.
    func grab(listener: @escaping (_ event: VirtualGamepadEvent, _ state: VirtualGamepadEventState) -> Void) -> Bool

    /// Ungrabs the remote control navigation inputs.
    ///
    /// This stops forwarding navigation events to the application listener and resumes forwarding them to the connected
    /// drone.
    ///
    /// - note: Navigation inputs are automatically released, and the application listener is unregistered as soon
    /// as the gamepad peripheral disappears.
    func ungrab()
}

/// :nodoc:
/// Virtual gamepad descriptor
@objc(GSVirtualGamepadDesc)
public class VirtualGamepadDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = VirtualGamepad
    public let uid = PeripheralUid.virtualGamepad.rawValue
    public let parent: ComponentDescriptor? = nil
}

/// Extension of NSNotification to declare app event key
extension NSNotification.Name {
    /// Key of a notification posted when an app event has been triggered from the remote control device.
    ///
    /// The notification’s userInfo contains the app action as a `ButtonsMappableAction` as the value of the
    /// `GsdkActionGamepadAppActionKey` key.
    public static let GsdkActionGamepadAppAction = NSNotification.Name(rawValue: "GsdkActionGamepadAppAction")
}

/// The key for the corresponding `ButtonsMappableAction` app action.
/// - Note: Only `appAction*` enums of `ButtonsMappableAction` are dispatched to the application as app actions.
public let GsdkActionGamepadAppActionKey = "GsdkActionGamepadAppActionKey"
