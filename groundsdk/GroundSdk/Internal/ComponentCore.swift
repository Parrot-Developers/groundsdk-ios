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

/// Base for a component implementation class.
@objc(GSComponentCore)
public class ComponentCore: NSObject, Component {
    /// Component descriptor
    public let desc: ComponentDescriptor

    /// Callback type for listeners observers
    public typealias ListenersDidChangeCallback = () -> Void
    /// CallBack called when a first listener is registered for the component
    public let didRegisterFirstListenerCallback: ListenersDidChangeCallback
    /// CallBack called when the last listener is unregistered for the component
    public let didUnregisterLastListenerCallback: ListenersDidChangeCallback

    /// Component store where this component is stored
    private unowned var store: ComponentStoreCore

    /// Informs about pending changes waiting for notifyUpdated call
    private var changed = false

    /// Informs if this component has been published
    private(set) var published = false

    /// Constructor
    ///
    /// - Parameters:
    ///   - desc: piloting interface component descriptor
    ///   - store: store where this interface will be stored
    ///   - didRegisterFirstListenerCallback : CallBack called when a first listener is registered for the component.
    ///     For example, this callback can be used to start an activity only necessary when one or more listeners exist
    ///   - didUnregisterLastListenerCallback: CallBack called when the last listener is unregistered for the component.
    ///     For example, this callback can be used to stop an activity when no more listeners exist
    init(desc: ComponentDescriptor, store: ComponentStoreCore,
         didRegisterFirstListenerCallback: @escaping ListenersDidChangeCallback = {},
         didUnregisterLastListenerCallback: @escaping ListenersDidChangeCallback = {}) {
        self.desc = desc
        self.store = store
        self.didRegisterFirstListenerCallback = didRegisterFirstListenerCallback
        self.didUnregisterLastListenerCallback = didUnregisterLastListenerCallback
        super.init()
    }

    func markChanged() {
        changed = true
    }
}

extension ComponentCore: SettingChangeDelegate {
    func userDidChangeSetting() {
        markChanged()
        notifyUpdated()
    }
}

/// Backend callback methods
extension ComponentCore {
    /// Publish the component by adding it to its store
    final public func publish() {
        if !published {
            store.add(self)
            published = true
            changed = false
        }
    }

    /// Unpublish the component by removing it to its store
    final public func unpublish() {
        if published {
            store.remove(self)
            published = false
        }
        reset()
    }

    /// Notify changes made by previously called setters
    @objc public func notifyUpdated() {
        if changed {
            changed = false
            store.notifyUpdated(self)
        }
    }

    /// Reset component state. Called when the component is unpublished.
    ///
    /// Subclass can override this function to reset other values
    @objc func reset() {
    }
}
