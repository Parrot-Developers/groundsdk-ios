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

/// Internal flying indicators instrument implementation
public class FlyingIndicatorsCore: InstrumentCore, FlyingIndicators {
    /// Current state
    internal(set) public var state: FlyingIndicatorsState = .landed
    /// Current landed state
    public var landedState: FlyingIndicatorsLandedState = .initializing
    /// Current flying state
    internal(set) public var flyingState: FlyingIndicatorsFlyingState = .none

    /// Debug description
    public override var description: String {
        return "FlyingIndicatorsCore \(state)-\(landedState)-\(flyingState)"
    }

    /// Constructor
    ///
    /// - Parameter store: component store owning this component
    public init(store: ComponentStoreCore) {
        super.init(desc: Instruments.flyingIndicators, store: store)
    }

    /// Constructor for subclasses
    ///
    /// - Parameters:
    ///    - desc: piloting interface component descriptor
    ///    - store: store where this interface will be stored
    ///    - didRegisterFirstListenerCallback: closure called when the first listener is registered
    ///    - didUnregisterLastListenerCallback: closure called when the last listener is unregistered
    override init(desc: ComponentDescriptor, store: ComponentStoreCore,
                  didRegisterFirstListenerCallback: @escaping ListenersDidChangeCallback = {},
                  didUnregisterLastListenerCallback: @escaping ListenersDidChangeCallback = {}) {
        super.init(desc: desc, store: store,
                   didRegisterFirstListenerCallback: didRegisterFirstListenerCallback,
                   didUnregisterLastListenerCallback: didUnregisterLastListenerCallback)
    }

    // can't be declared in the extension because it is overriden by subclasses
    /// Changes the current state to .Flying and change the flying state
    ///
    /// - Parameter flyingState: new flyingState state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(flyingState newFlyingState: FlyingIndicatorsFlyingState)
        -> FlyingIndicatorsCore {
            if newFlyingState != .none && state != .flying {
                update(state: .flying)
            }
            if newFlyingState != flyingState {
                markChanged()
                flyingState = newFlyingState
            }
            return self
    }

    // can't be declared in the extension because it is overriden by subclasses
    /// Changes the current state to .landed and change the landed state
    ///
    /// - Parameter landedState: new landedState state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(landedState newLandedState: FlyingIndicatorsLandedState)
        -> FlyingIndicatorsCore {
            if newLandedState != .none && state != .landed {
                update(state: .landed)
            }
            if newLandedState != landedState {
                markChanged()
                landedState = newLandedState
            }
            return self
    }

    // can't be declared in the extension because it is overriden by subclasses
    /// Changes the current state.
    /// If the new state is not .flying, flying state is set to .none
    /// If the new state is not .landed, landed state is set to .none
    ///
    /// - Parameter state: new state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(state newState: FlyingIndicatorsState) -> FlyingIndicatorsCore {
        if newState != state {
            markChanged()
            state = newState
            if state != .flying {
                flyingState = .none
            }
            if state != .landed {
                landedState = .none
            }
        }
        return self
    }
}
