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
import GroundSdk

/// Utility class for importing application default device(s) and model preset(s) definitions.
///
/// Application provides those default by providing a list of plist names in the config.
/// All these plist will be parsed and imported into the store.
///
/// Plist should be formatted as follows:
///
///     <?xml version="1.0" encoding="UTF-8"?>
///     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
///     <plist version="1.0">
///     <dict>
///         <key>device</key>
///         <dict>
///             <key>defaults</key>
///             <dict>
///                 <key>componentA</key>
///                 <dict>
///                     <key>setting1</key>
///                     <real>value1</real>
///                     <key>setting2</key>
///                     <string>value2</string>
///                     ...
///                 </dict>
///                 ...
///             </dict>
///             <key>overrides</key>
///             <dict>
///                 <key>componentA</key>
///                 <dict>
///                     <key>setting3</key>
///                     <false/>
///                     ...
///                 </dict>
///                 ...
///             </dict>
///         </dict>
///         <key>preset</key>
///         <dict>
///             <key>defaults</key>
///             <dict>
///                 <key>componentA</key>
///                 <dict>
///                     <key>setting1</key>
///                     <real>value1</real>
///                     <key>setting2</key>
///                     <string>value2</string>
///                     ...
///                 </dict>
///                 ...
///             </dict>
///             <key>overrides</key>
///             <dict>
///                 <key>componentB</key>
///                 <dict>
///                     <key>setting1</key>
///                     <string>value1</string>
///                     ...
///                 </dict>
///                 ...
///             </dict>
///         </dict>
///     </dict>
///
/// A device or preset block allow to:
/// - define default components' settings values, using a `defaults` block, and/or
/// - override stored component's settings values, using an `overrides` block
///
/// `defaults` values are merged into persistent storage if and only if no value already exists in the persistent
/// storage.
/// `overrides` values overwrite existing values into persistent storage. A 'null' value in an overrides block clears
/// the corresponding value in the persistent store, if it exists.
///
/// A `defaults` or `overrides` block may contains multiple `componentX` blocks, each addressing a specific arsdkengine
/// component; a `componentX` block may contain multiple `settingX` blocks, each addressing a specific setting value
/// from the enclosing component.
///
/// Components and setting keys are defined in arsdkengine `DeviceComponentController` implementation classes for
/// those components.
/// Application defaults are loaded, processed and merged according to the aforementioned rules into arsdkengine's
/// persistent store each time the engine is created.
class AppDefaults {
    /// Imports all application defaults into the given store.
    ///
    /// - Parameter persistentStore: persistent store to import to
    static func importTo(persistentStore: PersistentStore) {
        GroundSdkConfig.sharedInstance.appDefaults.forEach { model, plistName in
            guard let path = Bundle.main.path(forResource: plistName, ofType: "plist") else {
                preconditionFailure("AppDefault plist \(plistName) does not exist in main Bundle")
            }

            guard let rootDict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] else {
                preconditionFailure("plist \(plistName) is malformed")
            }
            importDict(rootDict, for: model, to: persistentStore)
        }
    }

    /// Imports the content of a given dictionary into the store
    ///
    /// - Parameters:
    ///   - dict: dictionary to import
    ///   - model: model targeted by this app default
    ///   - persistentStore: store to import to
    ///
    /// - Note: Visibility is internal for testing purposes
    static func importDict(_ dict: [String: AnyObject], for model: DeviceModel, to persistentStore: PersistentStore) {
        let presetUid = PersistentStore.presetKey(forModel: model)
        if let deviceDefaults = dict["device"] {
            guard let deviceDefaults = deviceDefaults as? [String: AnyObject] else {
                preconditionFailure("Device dictionary is malformed")
            }
            let deviceDict = persistentStore.getDevice(uid: model.defaultModelUid)
            deviceDict.mergeAll(from: deviceDefaults)

            // add model and preset name
            deviceDict.doUpdate(model.internalId as AnyObject, forKey: PersistentStore.deviceType)
            deviceDict.doUpdate(presetUid as AnyObject, forKey: PersistentStore.devicePresetUid)

            deviceDict.commit()
        }

        if let presetDefaults = dict["preset"] {
            guard let presetDefaults = presetDefaults as? [String: AnyObject] else {
                preconditionFailure("Preset dictionary is malformed")
            }
            let presetDict = persistentStore.getPreset(uid: presetUid)
            presetDict.mergeAll(from: presetDefaults)
            presetDict.commit()
        }
    }
}

private extension PersistentDictionary {
    /// Merges both application defaults and overrides declaration to the PersistentDictionary (device or preset).
    ///
    /// - Parameter toMerge: defaults and overrides values to merge
    func mergeAll(from toMerge: [String: AnyObject]) {
        // merge the values to override
        if let overrides = toMerge["overrides"] {
            guard let overrides = overrides as? [String: AnyObject] else {
                preconditionFailure("AppDefaults: Overrides dictionary is malformed")
            }
            merge(from: overrides, override: true)
        }

        // merge the default values
        if let defaults = toMerge["defaults"] {
            guard let defaults = defaults as? [String: AnyObject] else {
                preconditionFailure("AppDefaults: Defaults dictionary is malformed")
            }
            merge(from: defaults, override: false)
        }
    }

    /// Merges a single section (either defaults or overrides) of application defaults declaration to the
    /// PersistentDictionary.
    ///
    /// - Note: this method is recursive.
    ///
    /// - Parameters:
    ///   - toMerge: values to merge
    ///   - override: whether these values should override existing values
    func merge(from toMerge: [String: AnyObject], override: Bool) {
        toMerge.forEach {
            let key = $0.key
            let valueToMerge = $0.value
            let baseValue = self[key]

            // if value to merge and base value is a dictionary, merge it recursivelly in the base
            if let valueToMerge = valueToMerge as? [String: AnyObject],
                baseValue as? [String: AnyObject] != nil {
                let baseDict = getPersistentDictionary(key: key)
                baseDict.merge(from: valueToMerge, override: override)
            } else if override || self[key] == nil { // value is a leaf, merge it if it should be overriden or if there
                // is current value
                if let valueToMerge = valueToMerge as? NSData, valueToMerge.length == 0 {
                    self[key] = nil
                } else {
                    self[key] = valueToMerge
                }
            }
        }
    }
}
