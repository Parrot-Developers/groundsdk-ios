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

/// Virtual Gamepad backend
public protocol VirtualGamepadBackend: class {
    /// Grabs navigation input
    ///
    /// - Returns: true if navigation inputs could be grabbed, false otherwise.
    func grabNavigation() -> Bool

    /// Ungrab navigation inputs.
    func ungrabNavigation()
}

/// Internal VirtualGamepad peripheral implementation
public class VirtualGamepadCore: PeripheralCore, VirtualGamepad {

    /// Implementation backend
    private unowned let backend: VirtualGamepadBackend

    /// Whether or not the virtual gamepad is preempted by the specific gamepad.
    /// If this peripheral is grabbed and not preempted, you should receive navigation events through the listener.
    private (set) public var isPreempted = false

    /// Whether or not the virtual gamepad is currently grabbed.
    /// If this peripheral is grabbed and not preempted, you should receive navigation events through the listener.
    private (set) public var isGrabbed = false

    /// Whether or not the gamepad can be grabbed for navigation.
    public var canGrab: Bool {
        return !isGrabbed && !isPreempted
    }

    /// listener that will be called each time a navigation event is issued
    private var navListener: ((_ event: VirtualGamepadEvent, _ state: VirtualGamepadEventState) -> Void)?

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: VirtualGamepad backend
    public init(store: ComponentStoreCore, backend: VirtualGamepadBackend) {
        self.backend = backend
        super.init(desc: Peripherals.virtualGamepad, store: store)
    }

    public func grab(listener: @escaping (_ event: VirtualGamepadEvent, _ state: VirtualGamepadEventState) -> Void)
        -> Bool {
            if !isGrabbed {
                navListener = listener
                return backend.grabNavigation()
            }
            return false
    }

    public func ungrab() {
        if isGrabbed {
            navListener = nil
            backend.ungrabNavigation()
        }
    }
}

/// Backend callback methods
extension VirtualGamepadCore {
    /// Changes whether the virtual gamepad is preempted or not
    ///
    /// - Parameter isPreempted: the new value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(isPreempted: Bool) -> VirtualGamepadCore {
        if self.isPreempted != isPreempted {
            self.isPreempted = isPreempted
            markChanged()
        }
        return self
    }

    /// Changes whether the virtual gamepad is grabbed or not
    ///
    /// - Parameter isGrabbed: the new value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(isGrabbed: Bool) -> VirtualGamepadCore {
        if self.isGrabbed != isGrabbed {
            self.isGrabbed = isGrabbed
            markChanged()
        }
        return self
    }

    /// Forwards a navigation event to the application
    ///
    /// - Parameters:
    ///     - event: navigation event to forward
    ///     - state: navigation event state
    /// - Returns: self to allow call chaining
    @discardableResult
    public func notifyNavigationEvent(_ event: VirtualGamepadEvent, state: VirtualGamepadEventState)
        -> VirtualGamepadCore {
            if let navListener = navListener {
                navListener(event, state)
            }
            return self
    }

    /// Forwards an app action to the application
    ///
    /// - Parameter appAction: the application action to forward
    /// - Returns: self to allow call chaining
    @discardableResult
    public func notifyAppAction(_ appAction: ButtonsMappableAction) -> VirtualGamepadCore {
        NotificationCenter.default.post(
            name: NSNotification.Name.GsdkActionGamepadAppAction, object: self,
            userInfo: [GsdkActionGamepadAppActionKey: appAction])
        return self
    }

    /// Resets the navigation listener
    /// Should be called before that the component is unpublished
    public func resetNavListener() {
        navListener = nil
    }
}
