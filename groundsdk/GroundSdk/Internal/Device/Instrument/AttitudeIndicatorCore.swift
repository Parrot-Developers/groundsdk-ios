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

/// Internal Attitude indicator instrument implementation
public class AttitudeIndicatorCore: InstrumentCore, AttitudeIndicator {

    /// Angle (in degrees) on the roll axis of the drone
    private(set) public var roll: Double = 0

    /// Angle (in degrees) on the pitch axis of the drone
    private(set) public var pitch: Double = 0

    /// Debug description
    public override var description: String {
        return "AttitudeIndicator: roll = \(roll), pitch = \(pitch)"
    }

    /// Constructor
    ///
    /// - Parameter store: component store owning this component
    public init(store: ComponentStoreCore) {
        super.init(desc: Instruments.attitudeIndicator, store: store)
    }
}

/// Backend callback methods
extension AttitudeIndicatorCore {

    /// Changes the roll angle value.
    /// In degrees in range [0, 360[
    ///
    /// - Parameter roll: the roll to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(roll newValue: Double) -> AttitudeIndicatorCore {
        if roll != newValue {
            markChanged()
            roll = newValue
        }
        return self
    }

    /// Changes the pitch angle value.
    /// In degrees in range [0, 360[
    ///
    /// - Parameter pitch: the pitch to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(pitch newValue: Double) -> AttitudeIndicatorCore {
        if pitch != newValue {
            markChanged()
            pitch = newValue
        }
        return self
    }
}
