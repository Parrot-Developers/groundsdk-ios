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

/// Base protocol for a type that can be stored in a SettingsStore
protocol StorableProtocol {
    /// Content of the value as AnyObject
    var content: AnyObject { get }

    /// Create a storable from any object
    ///
    /// - Parameter content: content to use to create the storable
    init?(from content: AnyObject?)

    /// Create a storable from an AnyStorable
    ///
    /// - Parameter anyStorable: AnyStorable containing the data to create the storable
    init?(_ anyStorable: AnyStorable?)
}

// Default StorableProtocol implementation
extension StorableProtocol {
    /// Create a storable from an AnyStorable
    ///
    /// - Parameter anyStorable: AnyStorable containing the data to create the storable
    init?(_ anyStorable: AnyStorable?) {
        self.init(from: anyStorable?.content)
    }
}

/// A Storable value
protocol Storable: StorableProtocol {
    /// Type of the value
    associatedtype ValueType
    /// Storable actual value
    var storableValue: ValueType { get }
}

/// Default implementation when the value type conforming to Storable is the type itself
extension Storable where ValueType == Self {
    /// Content of the value as AnyObject
    var content: AnyObject {
        return self as AnyObject
    }

    /// Storable actual value
    var storableValue: ValueType {
        return self
    }

    /// Create a storable from any object
    ///
    /// - Parameter content: content to use to create the storable
    init?(from content: AnyObject?) {
        if let content = content as? ValueType {
            self = content
        } else {
            return nil
        }
    }
}

// Make basic types that can be written to a plist Storable
extension UInt: Storable {}
extension Int: Storable {}
extension Float: Storable {}
extension Double: Storable {}
extension Bool: Storable {}
extension String: Storable {}
extension Date: Storable {}

/// Protocol an enum must conform to, to become Storable
protocol StorableEnum: Storable where ValueType: Hashable {
    /// Mapper that map enum type to strings
    static var storableMapper: Mapper<ValueType, String> { get }
}

/// Storable enum default implementation
extension StorableEnum where ValueType == Self {
    /// Content of the value as AnyObject
    var content: AnyObject {
        return Self.storableMapper.map(from: self)! as AnyObject
    }

    /// Storable actual value
    var storableValue: ValueType {
        return self
    }

    /// Create a storable from any object
    ///
    /// - Parameter content: content to use to create the storable
    init?(from content: AnyObject?) {
        if let content = content as? String, let me = Self.storableMapper.reverseMap(from: content ) {
            self = me
        } else {
            return nil
        }
    }
}

/// Protocol for a custom storable type
protocol StorableType: StorableProtocol {
    /// return the storable type as storable
    func asStorable() -> StorableProtocol
}

/// StorableType default implementation
extension StorableType {
    var content: AnyObject {
        return asStorable().content
    }
}

/// Storable Type eraser
struct AnyStorable: Storable {
    /// Content of the value as AnyObject
    let content: AnyObject

    /// Storable actual value
    var storableValue: AnyObject {
        return content
    }

    /// Init from a simple value
    init<T: Storable>(_ value: T) {
        self.content = value.content
    }

    /// Init from an array
    init<T: Storable>(_ value: [T]) {
        self.content = StorableArray<T>(value).content
    }

    /// Init from an Dictionary
    init<K: Storable, V: Storable>(_ value: [K: V]) {
        self.content = StorableDict<K, V>(value).content
    }

    /// Create a storable from any object
    ///
    /// - Parameter content: content to use to create the storable
    init?(from content: AnyObject?) {
        if let content = content {
            self.content = content
        } else {
            return nil
        }
    }
}

/// Storable for a simple value
struct StorableValue<T>: Storable {
    /// Content of the value as AnyObject
    var content: AnyObject {
        return storableValue as AnyObject
    }

    /// Storable actual value
    let storableValue: T

    /// Constructor from a value
    ///
    /// - Parameter value: Storable value
    init(_ value: T) {
        self.storableValue = value
    }

    /// Create a storable from any object
    ///
    /// - Parameter content: content to use to create the storable
    init?(from content: AnyObject?) {
        if let content = content as? T {
            self.storableValue = content
        } else {
            return nil
        }
    }
}

/// A Storable array
struct StorableArray<T: StorableProtocol>: Storable {
    /// Content of the value as AnyObject
    var content: AnyObject {
        return storableValue.map {$0.content} as AnyObject
    }

    /// Storable actual value
    let storableValue: [T]

    /// Constructor from an array
    ///
    /// - Parameter value: Storable values array
    init(_ value: [T]) {
        self.storableValue = value
    }

    /// Create a storable from any object
    ///
    /// - Parameter content: content to use to create the storable
    init?(from content: AnyObject?) {
        if let content = content as? [AnyObject] {
            storableValue = content.map {T.init(from: $0)}.filter {$0 != nil}.map {$0!}
        } else {
            return nil
        }
    }
}

/// Extension when the StorableArray data type is AnyStorable
extension StorableArray where T == AnyStorable {
    init<T: Storable>(_ value: [T]) {
        self.storableValue = value.map {AnyStorable($0)}
    }
}

/// A Storable dictionary
struct StorableDict<K: StorableProtocol & Hashable, V: StorableProtocol>: Storable {
    /// Content of the value as AnyObject
    var content: AnyObject {
        var result = [String: AnyObject]()
        for (key, value) in storableValue {
            if let key = key.content as? String {
                result[key] = value.content
            }
        }
        return result as AnyObject
    }

    /// Storable actual value
    let storableValue: [K: V]

    /// Constructor from an array
    ///
    /// - Parameter value: Storable values array
    init(_ value: [K: V]) {
        self.storableValue = value
    }

    /// Get entry by key
    subscript(key: K) -> V? {
        return storableValue[key]
    }

    /// Create a storable from any object
    ///
    /// - Parameter content: content to use to create the storable
   init?(from content: AnyObject?) {
        if let content = content as? [String: AnyObject] {
            var result = [K: V]()
            for (key, value) in content {
                if let key = K.init(from: key as AnyObject), let value = V.init(from: value) {
                    result[key] =  value
                }
            }
            self.storableValue = result
        } else {
            return nil
        }
    }
}

/// Extension when the StorableDict value data type is AnyStorable
extension StorableDict where V == AnyStorable {
    init<T: Storable>(_ value: [K: T]) {
        self.storableValue = value.mapValues {AnyStorable($0)}
    }
}
