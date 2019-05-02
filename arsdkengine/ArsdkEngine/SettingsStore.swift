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

/// A String key store
protocol StoreKey {
    var key: String { get }
}

/// Make String type conform to StoreKey
extension String: StoreKey {
    var key: String {
        return self
    }
}

/// Add key var to String RawRepresentable to allow implementation StoreKey
extension RawRepresentable where RawValue == String {
    var key: String {
        return rawValue
    }
}

/// Wrapper around a PersistentDictionary with helper functions
class SettingsStore {

    /// Wrapper dictionary
    private let dictionary: PersistentDictionary

    /// Checks if it's a new dictionary that has not been saved to the store
    var new: Bool {
        return dictionary.new
    }

    /// Store key
    var key: String {
        return dictionary.key
    }

    /// Constructor
    ///
    /// - Parameter dictionary: wrapped dictionary
    init(dictionary: PersistentDictionary) {
        self.dictionary = dictionary
    }

    /// Write a storable
    ///
    /// - Parameters:
    ///   - key: key to write
    ///   - value: value to write
    /// - Returns: self for easy chaining
    @discardableResult func write<T>(key: StoreKey, value: T) -> SettingsStore where T: StorableProtocol {
        dictionary[key.key] = value.content

        return self
    }

    /// Write a storable if it doesn't exit in the store yet
    ///
    /// - Parameters:
    ///   - key: key to write
    ///   - value: value to write
    /// - Returns: self for easy chaining
    @discardableResult func writeIfNew<T>(key: StoreKey, value: T) -> SettingsStore where T: StorableProtocol {
        if dictionary[key.key] == nil {
            dictionary[key.key] = value.content
        }
        return self
    }

    /// Checks is an entry exists in the store
    ///
    /// - Parameter key: key to check
    /// - Returns: true if there is a value for this key
    func hasEntry(key: StoreKey) -> Bool {
        return dictionary[key.key] != nil
    }

    /// Get key entries starting with a key prefix
    ///
    /// - Parameter key: key prefix
    /// - Returns: array of key entries in dictionary
    func getEntriesForPrefix(key: StoreKey) -> [String]? {
        var array: [String] = []
        if let arrayKeys = dictionary.getAllKeys() {
            for keyFromArray in arrayKeys {
                if keyFromArray.hasPrefix(key.key) {
                    array.append(keyFromArray)
                }
            }
        }
        return array
    }

    /// Read a storable from the store
    ///
    /// - Parameter key: key to read
    /// - Returns: read value
    func read<T>(key: StoreKey) -> T? where T: StorableProtocol {
        if let value = dictionary[key.key] {
            return T.init(from: value)
        }
        return nil
    }

    /// Write a range of Storable in the store
    ///
    /// - Parameters:
    ///   - key: key to write
    ///   - min: range min value
    ///   - max: range max value
    /// - Returns: self for easy chaining
    @discardableResult func writeRange<T>(key: StoreKey, min: T, max: T) -> SettingsStore where T: StorableProtocol {
        dictionary[key.key] = StorableArray<T>([min, max]).content
        return self
    }

    /// Write a dictionary of range of Storable in the store
    ///
    /// - Parameters:
    ///   - key: key to write
    ///   - min: range min value
    ///   - max: range max value
    /// - Returns: self for easy chaining
    @discardableResult func writeMultiRange<K, V>(
        key: StoreKey, value: [K: (min: V, max: V)]) -> SettingsStore where K: StorableProtocol, V: StorableProtocol {

        dictionary[key.key] = StorableDict(value.mapValues { StorableArray([$0.min, $0.max]) }).content
        return self
    }

    /// Read a range of Storable from the store
    ///
    /// - Parameter key: key to read
    /// - Returns: tuple containing range min and max value
    func readRange<T>(key: StoreKey) -> (min: T, max: T)? where T: StorableProtocol {
        if let value = StorableArray<T>(from: dictionary[key.key]), value.storableValue.count == 2 {
            return (value.storableValue[0], value.storableValue[1])
        }
        return nil
    }

    /// Read a dictionary of range of Storable from the store
    ///
    /// - Parameter key: key to read
    /// - Returns: a dictionary of tuple containing range min and max value indexed by keys
    func readMultiRange<K, V>(key: StoreKey) -> [K: (min: V, max: V)]? where K: StorableProtocol, V: StorableProtocol {
        if let value = StorableDict<K, StorableArray<V>>(from: dictionary[key.key]) {
            var multiRange: [K: (min: V, max: V)] = [:]
            for (key, val) in value.storableValue {
                if val.storableValue.count == 2 {
                    multiRange[key] = (val.storableValue[0], val.storableValue[1])
                } else {
                    return nil
                }
            }
            return multiRange
        }
        return nil
    }

    /// Gets or creates a sub setting store
    ///
    /// - Parameter key: sub setting store key
    /// - Returns: sub stting store
    func getSettingsStore(key: StoreKey) -> SettingsStore {
        return SettingsStore(dictionary: dictionary.getPersistentDictionary(key: key.key))
    }

    /// Write flag telling a value is supported.
    /// - Parameter key: value key
    func writeSupportedFlag(key: StoreKey) {
        let savedFlag = StorableValue<Bool>(from: dictionary[key.key])
        if savedFlag == nil || !savedFlag!.storableValue {
            dictionary[key.key] = StorableValue(true).content
        }
    }

    /// Read the flag telling a value is supported
    /// - Parameter key: value key
    /// - returns: true if the flag is present
    func readSupportedFlag(key: StoreKey) -> Bool {
        return StorableValue<Bool>(from: dictionary[key.key]) != nil
    }

    /// Remove all content of this dictionary and remove it from its parent dictionary
    func clear() {
        dictionary.clear()
    }

    /// Commit all modification made in the dictionary tree
    func commit() {
        dictionary.commit()
    }
}
