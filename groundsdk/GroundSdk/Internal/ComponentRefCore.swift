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

/// A `Ref` to a component in the component store
public class ComponentRefCore<Desc: ComponentApiDescriptor>: Ref<Desc.ApiProtocol> {

    /// Store instance
    private let store: ComponentStoreCore
    /// Component descriptor
    private let desc: Desc
    /// Store listener
    private var storeListener: ComponentStoreCore.Listener!

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: the component store
    ///    - desc: descriptor of the referenced component
    ///    - observer: reference observer
    init(store: ComponentStoreCore, desc: Desc, observer: @escaping Ref<Desc.ApiProtocol>.Observer) {
        self.store = store
        self.desc = desc
        super.init(observer: observer)
        storeListener = store.register(desc: desc, didChange: {
            [unowned self] in
            self.update(newValue: self.store.get(self.desc))
        })
        self.setup(value: store.get(desc))
    }

    /// Destructor
    deinit {
        store.unregister(listener: storeListener)
    }
}

/// A `Ref` to a component in the component store, but using the component uid to identify it.
/// Used by objc compatibility api
public class ComponentUidRefCore<T: Component>: Ref<T> {
    /// Store instance
    private let store: ComponentStoreCore
    /// Component uid
    private let uid: Int
    /// Store listener
    private var storeListener: ComponentStoreCore.Listener!

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: the component store
    ///    - uid: component uid
    ///    - observer: reference observer
    init(store: ComponentStoreCore, uid: Int, observer: @escaping (T?) -> Void) {
        self.store = store
        self.uid = uid
        super.init(observer: observer)
        self.storeListener = store.register(uid: uid, didChange: {
            [unowned self] in
            self.update(newValue: self.store.get(uid: self.uid))
        })
        self.setup(value: store.get(uid: uid))
    }

    deinit {
        store.unregister(listener: storeListener)
    }
}
