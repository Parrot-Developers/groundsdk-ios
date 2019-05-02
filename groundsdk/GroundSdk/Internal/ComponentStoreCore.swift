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

/// A store of `Component`
public class ComponentStoreCore {

    /// Listener registered to as specific component notified when it changes
    class Listener: NSObject {
        /// Uid of the component this listener is attached to
        fileprivate let uid: Int
        /// Closure called when the component changes
        fileprivate let didChange: () -> Void

        /// Constructor
        ///
        /// - Parameters:
        ///    - uid: component uid
        ///    - didChange: closure to call when the component changes
        fileprivate init(uid: Int, didChange: @escaping () -> Void) {
            self.uid = uid
            self.didChange = didChange
        }
    }

    /// Components, by id
    ///
    /// Example hierarchy (parent->child): Comp_A -> Comp_B -> Comp_C
    ///
    /// key: an int (example Comp_B.desc.uid)
    ///
    /// value: in the example, the same object Comp_C is used for each key
    ///
    /// example [Comp_A_Descriptor.uid: Comp_C),
    ///         [Comp_B_Descriptor.uid: Comp_C,
    ///         [Comp_C_Descriptor.uid: Comp_C,]
    private var components: [Int: ComponentCore] = [:]

    /// Listeners lists by component id
    private var listeners: [Int: Set<Listener>] = [:]

    /// Register a listener on a component
    ///
    /// - Parameters:
    ///    - desc: descriptor of the component to register the listener for
    ///    - didChange: Closure to call when the component changes
    /// - Returns: registered listener, used to unregister it
    func register(desc: ComponentDescriptor, didChange: @escaping () -> Void) -> Listener {
        return register(uid: desc.uid, didChange: didChange)
    }

    /// Register a listener on a component identified by its uid
    ///
    /// - Parameters:
    ///    - uid: uid of the component to register the listener for
    ///    - didChange: Closure to call when the component changes
    /// - Returns: registered listener, used to unregister it
    func register(uid: Int, didChange: @escaping () -> Void) -> Listener {
        let isFirstListener = !hasListener(uid)
        let listener = Listener(uid: uid, didChange: didChange)
        if listeners[uid]?.insert(listener) == nil {
            listeners[uid] = [listener]
        }
        if isFirstListener {
            components[uid]?.didRegisterFirstListenerCallback()
        }
        return listener
    }

    /// Unregister a listener previously registered
    ///
    /// - Parameter listener: listener to unregister
    func unregister(listener: Listener) {
        let uid = listener.uid
        if listeners[uid] != nil {
            listeners[uid]?.remove(listener)
            if let componentListeners = listeners[uid] {
                if componentListeners.isEmpty {
                    listeners[uid] = nil
                    // The last listener was removed, call the callback if needed
                    if !hasListener(uid) {
                        components[uid]?.didUnregisterLastListenerCallback()
                    }
                }
            }
        }
    }

    /// Notify that a component has been updated.
    /// Notify all listener of the component and its parent component.
    ///
    /// - Parameter component: component that has been updated
    func notifyUpdated(_ component: Component) {
        if components[component.desc.uid] != nil {
            notifyChanged(component)
        }
    }

    /// Get a component
    ///
    /// - Parameter desc: descriptor of the component to get
    /// - Returns: the requested component
    public func get<Desc: ComponentApiDescriptor>(_ desc: Desc) -> Desc.ApiProtocol? {
        return components[desc.uid] as? Desc.ApiProtocol
    }

    //// Get a component by uid
    ///
    /// - Parameter uid: requested component uid
    /// - Returns: requested component
    public func get<ComponentType: Component>(uid: Int) -> ComponentType? {
        return components[uid] as? ComponentType
    }

    /// Add a component to the store
    ///
    /// - Parameter component: the component to add
    public func add(_ component: ComponentCore) {
        var desc: ComponentDescriptor? = component.desc
        while desc != nil {
            components[desc!.uid] = component
            desc = desc?.parent
        }
        // Check if at least one Listener exists for this component
        if hasListener(component.desc.uid) {
            // one or more listeners were present before the add of the component
            components[component.desc.uid]?.didRegisterFirstListenerCallback()
        }
        notifyChanged(component)
    }

    /// Remove a component from the store
    ///
    /// - Parameter component: the component to remove
    public func remove(_ component: Component) {
        var desc: ComponentDescriptor? = component.desc
        while desc != nil {
            components[desc!.uid] = nil
            desc = desc?.parent
        }
        notifyChanged(component)
    }

    /// For a given uid, check if this component has at least a listener. All components in the hierarchy (parents
    /// and childs) are checked.
    ///
    /// - Parameter uid: uid of the component to check
    /// - Returns: `true` if a component in the hierarchy has a least one listener.
    ///
    ///   Example hierarchy : Comp_A -> Comp_B -> Comp_C and testing with Comp_B.uid
    ///
    ///   Returns `true` if A or B or C has at least one registered listener (assuming A, B, C are added in the store).
    func hasListener(_ uid: Int) -> Bool {

        // guard the component exists
        guard let componentSearch = components[uid] else {
            return false
        }

        // Check from the last child, repeating the iteration of each parent
        // The last child in the hierarchy is `componentSearch`
        var searchDesc: ComponentDescriptor? = componentSearch.desc
        while searchDesc != nil {
            if listeners[searchDesc!.uid]?.count ?? 0 > 0 {
                return true
            }
            searchDesc = searchDesc?.parent
        }
        return false
    }

    /// Notify that a component has changed, has been added or removed.
    /// Notify all listener of the component and its parent component.
    ///
    /// - Parameter component: component that has been changed, added or removed
    private func notifyChanged(_ component: Component) {
        var desc: ComponentDescriptor? = component.desc
        while desc != nil {
            listeners[desc!.uid]?.forEach { listener in
                // ensure listener has not be removed while iterating
                if listeners[desc!.uid]?.contains(listener) ?? false {
                    listener.didChange()
                }
            }
            desc = desc!.parent
        }
    }

    /// Clear the store: remove all components and all observers
    func clear() {
        components.forEach {key, component in
            self.components.removeValue(forKey: key)
            notifyChanged(component)
        }
        listeners.removeAll()
    }
}
