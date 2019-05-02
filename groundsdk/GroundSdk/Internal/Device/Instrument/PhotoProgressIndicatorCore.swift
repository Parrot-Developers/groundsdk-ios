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

/// Internal photo progress indicator core instrument implementation
public class PhotoProgressIndicatorCore: InstrumentCore, PhotoProgressIndicator {

    private (set) public var remainingTime: Double?

    private (set) public var remainingDistance: Double?

    /// Debug description
    public override var description: String {
        return "PhotoProgressIndicatorCore: remainingTime = \(String(describing: remainingTime)),"
            + " remainingDistance = \(String(describing: remainingDistance))"
    }

    /// Constructor
    ///
    /// - Parameter store: component store owning this component
    public init(store: ComponentStoreCore) {
        super.init(desc: Instruments.photoProgressIndicator, store: store)
    }
}

/// Backend callback methods
extension PhotoProgressIndicatorCore {
    /// Updates the remaining time value.
    ///
    /// - Parameter remainingTime: the new remaining time to set in seconds
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(remainingTime newValue: Double) -> PhotoProgressIndicatorCore {
        if remainingTime != newValue {
            markChanged()
            remainingTime = newValue
        }
        return self
    }

    /// Resets the remaining time before next photo, marking it unavailable.
    ///
    /// - Returns: self to allow call chaining
    @discardableResult public func resetRemainingTime() -> PhotoProgressIndicatorCore {
        if remainingTime != nil {
            markChanged()
            remainingTime = nil
        }
        return self
    }

    /// Updates the remaining distance value.
    ///
    /// - Parameter remainingDistance: the new remaining distance to set in meters
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(remainingDistance newValue: Double) -> PhotoProgressIndicatorCore {
        if remainingDistance != newValue {
            markChanged()
            remainingDistance = newValue
        }
        return self
    }

    /// Resets the remaining distance before next photo, marking it unavailable.
    ///
    /// - Returns: self to allow call chaining
    @discardableResult public func resetRemainingDistance() -> PhotoProgressIndicatorCore {
        if remainingDistance != nil {
            markChanged()
            remainingDistance = nil
        }
        return self
    }
}
