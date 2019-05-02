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

@testable import ArsdkEngine

/// Set of keys that should be ignored if they are missing from the expected dictionary
private let ignoredKeys: Set<String> = ["version"]

/// Check whether the persistent store is the same as the given expected dictionary.
///
/// If not matching, will print a list of all errors.
func `is`(_ expectedDict: [String: AnyObject], testName: String) -> Matcher<PersistentStore> {
    return Matcher(expectedDict.description) { store -> MatchResult in
        if let dict = store.content {
            let results = matches(dict, expectedDict)
            if results.isEmpty {
                return .match
            } else {
                return .mismatch("\(testName): \(results.joined(separator: " && "))")
            }
        } else {
            return .mismatch("\(testName): store is empty")
        }
    }
}

/// Gets whether two dictionaries are the same.
/// Precondition: all leafs should be AnyHashable to be compared.
///
/// - Parameters:
///   - dict: first dictionary
///   - expectedDict: second dictionary
/// - Returns: a list of errors as strings. If empty, it means that there is no difference between these two
///   dictionaries
///
/// - Note: keys that are in `ignoredKeys` and in `dict` but missing from `expectedDict` are ignored and won't trigger
///   any error.
private func matches(_ dict: [String: AnyObject], _ expectedDict: [String: AnyObject]) -> [String] {
    var results = [String]()
    // iterate through all keys of the expected dict and check if the values are in the store
    expectedDict.forEach {
        let key = $0.key
        let expectedValue = $0.value
        if let value = dict[key] {

            if let expectedValue = expectedValue as? [String: AnyObject] {
                if let value = value as? [String: AnyObject] {

                    results.append(contentsOf: matches(value, expectedValue))
                }
                else {
                    results.append("value for key \(key) is not a dictionary")
                }
            } else {    // expected value is not a dictionary, it should be a leaf
                if let expectedValue = expectedValue as? AnyHashable,
                    let value = value as? AnyHashable {

                    if value != expectedValue {
                        results.append("value for key \(key) should be equal to \(expectedValue)")
                    }
                } else {
                    results.append("value for key \(key) is not a leaf of the dictionary")
                }
            }
        } else {
            results.append("\(key) does not exist in store")
        }
    }

    // also check that there is no keys in the dict that are not in the expected dict
    dict.forEach {
        let key = $0.key
        if !ignoredKeys.contains(key) && expectedDict[key] == nil {
            results.append("\(key) is not expected")
        }
    }
    return results
}
