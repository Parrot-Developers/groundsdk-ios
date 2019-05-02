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

/// Internal Radio instrument implementation
public class RadioCore: InstrumentCore, Radio {

    // received signal strength indication (RSSI), expressed in dBm.
    private(set) public var rssi = 0

    // The link signal quality varies from 1 to 5.
    private(set) public var linkSignalQuality: Int?

    /// Tells whether the radio link is perturbed by external elements.
    private(set) public var isLinkPerturbed = false

    /// Tells whether the smartphone's 4G is interfering.
     private(set) public var is4GInterfering = false

    /// Debug description
    public override var description: String {
        return "RadioCore - rssi: \(rssi)  linkSignalQuality: \(linkSignalQuality ?? -1)" +
        " isLinkPerturbed: \(isLinkPerturbed) is4GInterfering: \(is4GInterfering)"
    }

    /// Constructor
    ///
    /// - Parameter store: component store owning this component
    public init(store: ComponentStoreCore) {
        super.init(desc: Instruments.radio, store: store)
    }
}

/// Backend callback methods
extension RadioCore {

    /// Changes the received signal strength indication.
    ///
    /// - Parameter rssi: rssi value to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(rssi newValue: Int) -> RadioCore {
        if rssi != newValue {
            markChanged()
            rssi = newValue
        }
        return self
    }

    /// Changes the linkSignalQuality indication.
    ///
    /// - Parameter linkSignalQuality: signal quality value to set (1..5 if exists)
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(linkSignalQuality newValue: Int?) -> RadioCore {
        if linkSignalQuality != newValue {
            markChanged()
            linkSignalQuality = newValue
        }
        return self
    }

    /// Changes the link perturbed indication.
    ///
    /// - Parameter isLinkPerturbed: whether link is perturbed or not
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(isLinkPerturbed newValue: Bool) -> RadioCore {
        if isLinkPerturbed != newValue {
            isLinkPerturbed = newValue
            markChanged()
        }
        return self
    }

    /// Changes the 4G interfering indication.
    ///
    /// - Parameter is4GInterfering: whether smartphone's 4G is interfering or not
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(is4GInterfering newValue: Bool) -> RadioCore {
        if is4GInterfering != newValue {
            is4GInterfering = newValue
            markChanged()
        }
        return self
    }
}

// MARK: Objective-C API
/// - Note: this protocol is for Objective-C only. Swift must use the protocol `Radio`
extension RadioCore: GSRadio {
    public var gsLinkSignalQuality: Int {
        return linkSignalQuality ?? -1
    }
}
