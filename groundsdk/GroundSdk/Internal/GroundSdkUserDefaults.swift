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

/// Class to store persisting Data in UserDefaults.
internal class GroundSdkUserDefaults {

    /// Key for all data stored with this class.
    private let globalKey = "groundSdkStore"

    /// Root key with which to associate values.
    private var rootStoreKey: String

    /// UserDefaults Data
    private let userDefaults: UserDefaults

    /// Constructor
    ///
    /// - Parameters:
    ///   - rootStoreKey: Key used in the standardDefault Dictionary for load or save data ith this instance
    ///   - userDefaults: UserDefaults to use, by default it is `UserDefaults.standard`.
    ///
    ///  - Note: Datas are stored in the UserDefaults Standard dictionary at key "groundskStore.`rootStoreKey`"
    public init(_ rootStoreKey: String, userDefaults: UserDefaults = .standard) {
        self.rootStoreKey = rootStoreKey
        self.userDefaults = userDefaults
    }

    /// Set a object in UserDefault
    ///
    /// - Parameter value: the object to store in the defaults database. The value parameter can be only property
    /// list objects: NSData, NSString, NSNumber, NSDate, NSArray, or NSDictionary. For NSArray and NSDictionary
    /// objects, their content must be property list objects.
    ///
    /// - Note: Data are stored in the UserDefaults Standard dictionary at key "groundskStore.`rootStoreKey`".
    /// `groundskStore` is a constant, `rootStoreKey` is a parameter of the constructor.
    public func storeData(_ value: Any?) {
        // get the Groundsdk Store Dictionary and sav data
        var gsdkStoreDictionary = userDefaults.dictionary(forKey: globalKey) ?? [:]
        if let value = value {
            gsdkStoreDictionary[rootStoreKey] = value
        } else {
            gsdkStoreDictionary.removeValue(forKey: rootStoreKey)
        }
        userDefaults.set(gsdkStoreDictionary, forKey: globalKey)
    }

    /// Get the value previously saved with `storeData()`
    public func loadData() -> Any? {
        // get the Groundsdk Store Dictionary
        let gsdkStoreDictionary = userDefaults.dictionary(forKey: globalKey) ?? [:]
        return gsdkStoreDictionary[rootStoreKey]
    }
}
