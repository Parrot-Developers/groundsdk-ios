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

/// A persistent store backed by a NSUserDefaults storing devices as dictionary
class PersistentStore {

    /// Name of main entry in the shared preferences
    private static let storeName = "arsdkenginestore"

    /// Key for the version (value associated is an int)
    private static let versionKey = "version"

    /// Current version
    private static let currentVersion = 1

    // device keys
    /// Key of a device type (value is an int, value of DeviceModel.internalId)
    static let deviceType = "type"

    /// Key of a device type
    static let deviceName = "name"

    /// Key of a device firmware version
    static let deviceFirmwareVersion = "firmwareVersion"

    /// Key of a device board identifier
    static let deviceBoardId = "boardId"

    /// Key of a device preset uid
    static let devicePresetUid = "preset"

    /// UserDefault instance to back up data
    ///
    /// - note: set as internal var to be overriden by mocks
    internal var userDefaults = UserDefaults.init()

    /// Whole store content, loaded from UserDefault
    ///
    /// Visibility is internal for testing purposes
    var content: [String: AnyObject]!

    /// set of all root dictionaries owned by clients
    private var rootDictonnaries = Set<RootPersistentDictionaryRef>()

    /// Constructor
    init() {
        if let data = userDefaults.dictionary(forKey: PersistentStore.storeName) {
            content = data as [String: AnyObject]
        } else {
            content = [:]
        }
        let version = content[PersistentStore.versionKey] as? Int
        if version != PersistentStore.currentVersion {
            content[PersistentStore.versionKey] = PersistentStore.currentVersion as AnyObject?
            userDefaults.set(content, forKey: PersistentStore.storeName)
        }
    }

    /// Get the list of stored device uid
    ///
    /// - Returns: the set of stored device uids
    func getDevicesUid() -> Set<String> {
        var keySet: Set<String>
        if let keys = (content[RootPersistentDictionary.DictType.devices.rawValue] as? [String: AnyObject])?.keys {
            keySet = Set(keys)
        } else {
            keySet = Set()
        }
        return keySet
    }

    /// Gets a stored device identified by uid
    ///
    /// - Parameter uid: device uid
    /// - Returns: PersistentDictionary for the requested device
    func getDevice(uid: String) -> PersistentDictionary {
        return RootPersistentDictionary(type: .devices, key: uid, store: self)
    }

    func getPreset(uid: String, didChangeCallback: (() -> Void)? = nil) -> PersistentDictionary {
        let dict = RootPersistentDictionary(type: .presets, key: uid, store: self)
        dict.didChangeListener = didChangeCallback
        return dict
    }

    fileprivate func registerRootDictionaryRef(_ dictionaryRef: RootPersistentDictionaryRef) {
        rootDictonnaries.insert(dictionaryRef)
    }

    fileprivate func unregisterRootDictionaryRef(_ dictionaryRef: RootPersistentDictionaryRef) {
        rootDictonnaries.remove(dictionaryRef)
    }

    fileprivate func notifyRootDictionaryChanged(_ dictionary: RootPersistentDictionary) {
        for ref in rootDictonnaries where ref.dictionary != dictionary &&
            ref.dictionary.type == dictionary.type && ref.dictionary.key == dictionary.key {
                ref.dictionary.didChangeListener?()
        }
    }

    fileprivate func getRootEntryContent(typeKey type: String, key: String) -> [String: AnyObject]? {
        return content[type]?[key] as? [String: AnyObject]
    }

    fileprivate func updateRootEntryContent(typeKey type: String, key: String, content data: [String: AnyObject]?) {
        var rootEntry = content[type] as? [String: AnyObject]
        // if no device exists, create the dictionary container
        if rootEntry == nil {
            rootEntry = [:]
        }
        rootEntry![key] = data as AnyObject?
        content[type] = rootEntry as AnyObject?
        userDefaults.set(content, forKey: PersistentStore.storeName)
    }
}

/// Key value dictionary
class PersistentDictionary {
    /// Dictionary key
    let key: String

    /// Dictionary content
    fileprivate var content: [String: AnyObject]?

    /// Dictionary containing this dictionary, nil for the root dictionary
    private var parent: PersistentDictionary?

    /// Check if this dictionary has content
    var exist: Bool { return content != nil }

    /// Checks if it's a new dictionary that has not been saved to the store
    private (set) var new: Bool

    /// Constructor
    ///
    /// - Parameters:
    ///    - key: dictionary key
    ///    - content: initial dict content
    ///    - parent: parent dictionary
    fileprivate init(key: String, content: [String: AnyObject]?, parent: PersistentDictionary?) {
        self.key = key
        self.content = content
        self.new = content == nil
        self.parent = parent
    }

    /// Access entry by key
    subscript(key: String) -> AnyObject? {
        get {
            return content?[key]
        }
        set(newElem) {
            doUpdate(newElem, forKey: key)
        }
    }

    /// Merge the content of the given dictionary into this persistent dictionary.
    ///
    /// - Note: in case of a key already present in this dictionary, the associated value will be replaced by the one
    ///         given in `other`.
    ///
    /// - Parameter other: the content to merge.
    func merge(_ other: [String: AnyObject]) {
        content?.merge(other) { (_, new) in new }
    }

    /// Get all Keys if dictionary exists
    ///
    /// - Returns: array of keys or nil
    func getAllKeys() -> [String]? {
        if let content = content {
            let arrayKeys = Array(content.keys)
            return arrayKeys
        }
        return nil
    }

    /// Get or Create a sub dictionary
    ///
    /// - Parameter key: sub dictionary key
    /// - Returns: sub dictionary
    func getPersistentDictionary(key: String) -> PersistentDictionary {
        return PersistentDictionary(key: key, content: content?[key] as? [String: AnyObject], parent: self)
    }

    func reload() {
        parent?.reload()
    }

    /// Commit all modification made in the dictionary tree
    func commit() {
        self.new = content == nil
        parent?.commit()
    }

    /// Remove all content of this dictionary and remove it from its parent dictionary
    ///
    /// - Returns: self to allow call chaining
    @discardableResult func clear() -> PersistentDictionary {
        content = nil
        self.new = true
        parent?.doUpdate(nil, forKey: key)
        return self
    }

    /// Update an entry
    ///
    /// - Parameters:
    ///    - value: value to update
    ///    - key:   key of the entry to update
    /// - Returns: self to allow call chaining
    @discardableResult func doUpdate(_ value: AnyObject?, forKey key: String) -> PersistentDictionary {
        if content == nil {
            content = [:]
        }
        content?[key] = value
        parent?.doUpdate(content as AnyObject?, forKey: self.key)
        return self
    }
}

private class RootPersistentDictionary: PersistentDictionary, Equatable {
    /// Root store types
    enum DictType: String {
        /// Store devices: array of devices, by uid
        case devices = "devices"
        /// Store Presets: array of presets, by uid
        case presets = "presets"
    }
    /// Dictionary type
    let type: DictType
    /// Instance of the persistent store
    private unowned let store: PersistentStore
    /// True when the dictionary has been changed since the last commit
    private var changed = false
    /// Closure to call when the Dictionary content has been changed by an other instance
    var didChangeListener: (() -> Void)?
    /// weak reference on self, to register ourself into the store root dictionary set
    private var ref: RootPersistentDictionaryRef!

    /// Constructor
    ///
    /// - Parameters:
    ///    - type: Root dictionary type
    ///    - key: key of the device
    ///    - store: instance of the persistent store
    init(type: DictType, key: String, store: PersistentStore) {
        self.store = store
        self.type = type
        super.init(key: key, content: store.getRootEntryContent(typeKey: type.rawValue, key: key), parent: nil)
        self.ref = RootPersistentDictionaryRef(dictionary: self)
        self.store.registerRootDictionaryRef(self.ref)
    }

    deinit {
        store.unregisterRootDictionaryRef(self.ref)
    }

    override func reload() {
        content = store.getRootEntryContent(typeKey: type.rawValue, key: key)
    }

    override func commit() {
        super.commit()
        if changed {
            store.updateRootEntryContent(typeKey: type.rawValue, key: key, content: content)
            changed = false
            store.notifyRootDictionaryChanged(self)
        }
    }

    override func clear() -> PersistentDictionary {
        changed = true
        return super.clear()
    }

    @discardableResult override func doUpdate(_ value: AnyObject?, forKey key: String) -> PersistentDictionary {
        changed = true
        return super.doUpdate(value, forKey: key)
    }
}

private class RootPersistentDictionaryRef: Hashable {
    unowned let dictionary: RootPersistentDictionary

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    init(dictionary: RootPersistentDictionary) {
        self.dictionary = dictionary
    }
}

private func != <T: Equatable>(lhs: [T]?, rhs: [T]?) -> Bool {
    switch (lhs, rhs) {
    case (.some(let lhs), .some(let rhs)):
        return lhs != rhs
    case (.none, .none):
        return false
    default:
        return true
    }
}

private func == (lhs: RootPersistentDictionary, rhs: RootPersistentDictionary) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}

private func == (lhs: RootPersistentDictionaryRef, rhs: RootPersistentDictionaryRef) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}
