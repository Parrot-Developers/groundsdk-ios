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

/// A reference to an object that may change.
///
/// This is the base class used to access a backend object with an associated observer notified each time this
/// associated object changes. Associated object may be `nil` if the corresponding backend object doesn't exist yet
/// or has been removed. Observer is notified when the backend object is created or removed, and when the ref is
/// created if the backend object exists.
public class Ref<T> {

    /// Reference observer.
    ///
    /// - Parameter value: new referenced value
    public typealias Observer = (_ value: T?) -> Void

    /// The associated backend object. May be `nil`.
    public internal(set) var value: T?

    /// Closure called each time the value is changed or set.
    internal let onChanged: Observer

    /// Constructor.
    ///
    /// - Parameter observer: a closure called each time the value is changed
    ///
    /// - Note: Setup should be called to notify the first value.
    /// - Note: If initial value is `nil`, observer won't be notified.
    internal init(observer: @escaping Observer) {
        self.onChanged = observer
    }

    /// Notifies the observer with the first value only if the value is not `nil`.
    ///
    /// - Parameter value: the initial value
    internal func setup(value: T? = nil) {
        if value != nil {
            update(newValue: value)
        }
    }

    /// Updates the value and notify the observer.
    ///
    /// - Parameter newValue: the new value
    internal func update(newValue: T?) {
        value = newValue
        onChanged(value)
    }
}
