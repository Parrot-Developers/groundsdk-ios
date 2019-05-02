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
import CoreLocation

/// Core implementation of the UserLocation facility
class UserLocationCore: FacilityCore, UserLocation {

    private (set) public var location: CLLocation?

    private (set) public var stopped = false

    private (set) public var authorized = false

    override var description: String {
        return "UserLocation: \(String(describing: location)), " +
        "stopped: \(stopped) " +
        "authorized :\(authorized)"
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: component store owning this component
    ///   - didRegisterFirstListenerCallback: called when a first listener is registered for the component
    ///   - didUnregisterLastListenerCallback: when the last listener is unregistered for the component
    init(store: ComponentStoreCore,
         didRegisterFirstListenerCallback: @escaping ListenersDidChangeCallback = {},
         didUnregisterLastListenerCallback: @escaping ListenersDidChangeCallback = {}) {
        super.init(
            desc: Facilities.userLocation, store: store,
            didRegisterFirstListenerCallback: didRegisterFirstListenerCallback,
            didUnregisterLastListenerCallback: didUnregisterLastListenerCallback)
    }
}

/// Backend callback methods
extension UserLocationCore {
    /// Changes current location.
    ///
    /// - Parameter location: new CLLocation
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(userLocation newValue: CLLocation?) -> UserLocationCore {
        if location != newValue {
            location = newValue
            markChanged()
        }
        return self
    }

    /// Changes stopped.
    ///
    /// - Parameter stopped: boolean indicating if the location updates are stopped
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(stopped newValue: Bool) -> UserLocationCore {
        if stopped != newValue {
            stopped = newValue
            markChanged()
        }
        return self
    }

    /// Changes authorized.
    ///
    /// - Parameter authorized: boolean indicating if the APP authorizes location services
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(authorized newValue: Bool) -> UserLocationCore {
        if authorized != newValue {
            authorized = newValue
            markChanged()
        }
        return self
    }
}
