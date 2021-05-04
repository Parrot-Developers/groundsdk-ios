// Copyright (C) 2020 Parrot Drones SAS
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

/// DRI backend part.
public protocol DriBackend: class {
    /// Sets mode.
    ///
    /// - Parameter mode: the new mode. `true` to activate DRI mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: Bool) -> Bool

    /// Sets type configuration.
    ///
    /// - Parameter type: the new type configuration
    func set(type: DriTypeConfig?)
}

/// Implementation of setting to change the DRI type.
class DriTypeSettingCore: DriTypeSetting, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties.
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes.
    let timeout = SettingTimeout()

    public internal(set) var state: DriTypeState?

    /// Supported types.
    public internal(set) var supportedTypes = Set<DriType>()

    /// DRI type configuration as defined by the user.
    var type: DriTypeConfig? {
        get {
            return _type
        }
        set(newType) {
            if _type != newType
                && (newType == nil
                        || (supportedTypes.contains(newType!.type) && newType!.isValid)) {
                backend(newType)
            }
        }
    }

    /// DRI type configuration as defined by the user (internal value).
    private var _type: DriTypeConfig?

    /// Closure to call to change the type configuration.
    private let backend: ((DriTypeConfig?) -> Void)

    /// Constructor.
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (DriTypeConfig?) -> Void) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Updates the DRI type configuration state.
    ///
    /// - Parameter state: new state
    func update(state newState: DriTypeState?) -> Bool {
        if state != newState {
            state = newState
            return true
        }
        return false
    }

    /// Updates supported DRI types.
    ///
    /// - Parameter supportedTypes: new supported types
    func update(supportedTypes newSupportedTypes: Set<DriType>) -> Bool {
        if supportedTypes != newSupportedTypes {
            supportedTypes = newSupportedTypes
            return true
        }
        return false
    }

    /// Updates the DRI type configuration defined by the user.
    ///
    /// - Parameter type: new type configuration
    func update(type newType: DriTypeConfig?) -> Bool {
        if _type != newType {
            _type = newType
            return true
        }
        return false
    }

    /// Debug description.
    var debugDescription: String {
        return "type: \(String(describing: _type)) state: \(String(describing: state))"
    }
}

/// Internal DRI peripheral implementation
public class DriCore: PeripheralCore, Dri {
    /// DRI drone id.
    public var droneId: (type: DriIdType, id: String)? {
        return _droneId
    }

    /// DRI mode setting.
    public var mode: BoolSetting? { _mode }

    /// Internal storage for mode setting.
    private var _mode: BoolSettingCore?

    /// DRI type setting.
    public var type: DriTypeSetting { _type }

    /// Internal storage for type setting.
    private var _type: DriTypeSettingCore!

    /// Internal storage for drone id.
    private var _droneId: (type: DriIdType, id: String)?

    /// Implementation backend.
    private unowned let backend: DriBackend

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: Dri backend
    public init(store: ComponentStoreCore, backend: DriBackend) {
        self.backend = backend
        super.init(desc: Peripherals.dri, store: store)
        _type = DriTypeSettingCore(didChangeDelegate: self) { [unowned self] newType in
            self.backend.set(type: newType)
        }
    }
}

extension DriCore {

    /// Drone identifier.
    public struct DroneIdentifier {

        /// Identifier type.
        public let type: DriIdType

        /// Identifier.
        public let id: String

        /// Constructor.
        ///
        /// - Parameters:
        ///   - type: identifier type
        ///   - id: identifier
        public init(type: DriIdType, id: String) {
            self.type = type
            self.id = id
        }
    }

    /// Set the switch state.
    ///
    /// - Parameter mode: tells the dri switch state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(mode newValue: Bool) -> DriCore {
        if _mode == nil {
            _mode = BoolSettingCore(didChangeDelegate: self) { [unowned self] newValue in
                return self.backend.set(mode: newValue)
            }
            markChanged()
        }
        if _mode!.update(value: newValue) {
            markChanged()
        }
        return self
    }

    /// Updates the drone id.
    ///
    /// - Parameter droneId : new drone identifier
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(droneId newValue: DroneIdentifier) -> DriCore {
        if _droneId?.type != newValue.type || _droneId?.id != newValue.id {
            self._droneId = (type: newValue.type, id: newValue.id)
            markChanged()
        }
        return self
    }

    /// Updates to DRI type configuration state.
    ///
    /// - Parameter state: new state
    @discardableResult public func update(typeState newTypeState: DriTypeState?) -> DriCore {
        if _type.update(state: newTypeState) == true {
            markChanged()
        }
        return self
    }

    /// Updates supported DRI types.
    ///
    /// - Parameter supportedTypes: new supported types
    @discardableResult public func update(supportedTypes newSupportedTypes: Set<DriType>) -> DriCore {
        if _type.update(supportedTypes: newSupportedTypes) {
            markChanged()
        }
        return self
    }

    /// Updates the DRI type configuration defined by the user.
    ///
    /// - Parameter type: new type configuration
    @discardableResult public func update(type newType: DriTypeConfig?) -> DriCore {
        if _type!.update(type: newType) {
            markChanged()
        }
        return self
    }

    /// Cancels all pending settings rollbacks.
    ///
    /// - Returns: self to allow call chaining
    /// - note: changes are not notified until notifyUpdated() is called
    @discardableResult public func cancelSettingsRollback() -> DriCore {
        _mode?.cancelRollback { markChanged() }
        return self
    }
}

/// Extension for configuration validation.
extension DriTypeConfig {
    /// Tells if an operator identifier conforms to EN4709 standard.
    ///
    /// Per EN4709, operator string contains 19 characters composed of:
    /// - 3 characters for ISO 3166 Alpha-3 code of country
    /// - 12 characters for operator identifier
    /// - 1 character for checksum
    /// - 1 hyphen
    /// - 3 secret characters used to check checksum
    ///
    /// - Parameter uasOperator: operator identifier to verify
    /// - Returns: `true` if the operator identifier is valid, `false` otherwise
    func validateEn4709UasOperator(_ uasOperator: String) -> Bool {
        guard uasOperator.count == 20 else {
            // invalid operator length
            return false
        }

        let countryStart = uasOperator.startIndex
        let operatorIdStart = uasOperator.index(countryStart, offsetBy: 3)
        let checkSumStart = uasOperator.index(operatorIdStart, offsetBy: 12)
        let hyphenStart = uasOperator.index(checkSumStart, offsetBy: 1)
        let secretStart = uasOperator.index(hyphenStart, offsetBy: 1)

        let country = uasOperator[countryStart..<operatorIdStart]
        let operatorId = uasOperator[operatorIdStart..<checkSumStart]
        let checksum = uasOperator[checkSumStart..<hyphenStart]
        let hyphen = uasOperator[hyphenStart..<secretStart]
        let secret = uasOperator[secretStart..<uasOperator.endIndex]

        // verify country code is in upper case
        if !country.allSatisfy({ $0.isUppercase }) {
            return false
        }
        // verify hyphen
        if hyphen != "-" {
            return false
        }
        let secretOperatorId = String(operatorId) + String(secret) + String(checksum)
        // verify operator identifier does not contain any upper case letter
        if !secretOperatorId.allSatisfy({ !$0.isUppercase }) {
            return false
        }
        // verify operator identifier with Luhn mod 36 algorithm
        return secretOperatorId.validateLuhn(base: 36)
    }
}

/// Extension for validation with Luhn mod N algorithm.
extension String {
    /// Validates the string with Luhn mod N algorithm.
    ///
    /// - Parameter base: number of valid characters, in range [1,  36]
    /// - Returns: `true` is the string is valid, `false` otherwise
    func validateLuhn(base: Int) -> Bool {
        guard base > 0 && base <= 36 else {
            return false
        }

        var sum = 0
        let digitStrings = reversed().map { String($0) }

        for tuple in digitStrings.enumerated() {
            if let digit = Int(tuple.element, radix: base) {
                let factor = tuple.offset % 2 == 0 ? 1 : 2
                let digit = digit * factor
                sum += digit / base
                sum += digit % base
            } else {
                return false
            }
        }
        return sum % base == 0
    }
}
