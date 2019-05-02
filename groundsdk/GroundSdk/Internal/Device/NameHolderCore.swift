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

/// Hold an observable device name instance.
public class NameHolderCore {
    /// Listener notified when the held name change
    class Listener: NSObject {
        fileprivate let didChange: (String) -> Void

        /// Constructor
        ///
        /// - Parameter didChange: closure which should be called when the name changes
        fileprivate init(didChange: @escaping (String) -> Void) {
            self.didChange = didChange
        }
    }

    /// name
    public private(set) var name: String

    /// Listeners list
    private var listeners: Set<Listener>

    /// Constructor
    ///
    /// - Parameter name: initial name
    init(name: String) {
        listeners = []
        self.name = name
    }

    /// Destroy the holder
    deinit {
        listeners.removeAll()
    }

    /// Register a new listener
    ///
    /// - Parameter didChange: closure which should be called when the name changes
    /// - Returns: the created listener
    ///
    /// - Note: The returned listener should be unregistered with unregister().
    func register(didChange: @escaping (String?) -> Void) -> Listener {
        let listener = Listener(didChange: didChange)
        listeners.insert(listener)
        return listener
    }

    /// Unregister a listener
    ///
    /// - Parameter listener: the listener to unregister
    func unregister(listener: Listener) {
        listeners.remove(listener)
    }

    /// Update the name
    ///
    /// - Parameter name: new name
    ///
    /// - Note: All listeners will be notified that the name has changed.
    public func update(name: String) {
        self.name = name
        listeners.forEach { listener in
            // ensure listener has not be removed while iterating
            if listeners.contains(listener) {
                listener.didChange(name)
            }
        }
    }

    /// Clear the holder: keep the current name and remove all observers
    func clear() {
        listeners.removeAll()
    }
}
