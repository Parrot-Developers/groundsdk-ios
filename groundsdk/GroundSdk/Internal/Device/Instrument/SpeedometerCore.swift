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

/// Internal speedometer instrument implementation
public class SpeedometerCore: InstrumentCore, Speedometer {

    /// Speed on the horizontal plan relative to the ground (in m/s)
    private (set) public var groundSpeed: Double = 0

    /// Speed along the north axis relative to the ground (in m/s)
    private (set) public var northSpeed: Double = 0

    /// Speed along the east axis relative to the ground (in m/s)
    private (set) public var eastSpeed: Double = 0

    /// Speed along the down axis relative to the ground (in m/s)
    private (set) public var downSpeed: Double = 0

    /// Speed along the front axis relative to the ground (in m/s)
    private (set) public var forwardSpeed: Double = 0

    /// Speed along the right axis relative to the ground (in m/s)
    private (set) public var rightSpeed: Double = 0

    /// Debug description
    public override var description: String {
        return "GroundSpeed : \(groundSpeed)"
    }

    /// Constructor
    ///
    /// - Parameter store: component store owning this component
    public init(store: ComponentStoreCore) {
        super.init(desc: Instruments.speedometer, store: store)
    }
}

/// Backend callback methods
extension SpeedometerCore {
    /// Changes the ground speed.
    ///
    /// - Parameter groundSpeed: the speed to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(groundSpeed newValue: Double) -> SpeedometerCore {
        if groundSpeed != newValue {
            markChanged()
            groundSpeed = newValue
        }
        return self
    }

    /// Changes the northSpeed.
    ///
    /// - Parameter northSpeed: the speed to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(northSpeed newValue: Double) -> SpeedometerCore {
        if northSpeed != newValue {
            markChanged()
            northSpeed = newValue
        }
        return self
    }

    /// Changes the eastSpeed.
    ///
    /// - Parameter eastSpeed: the speed to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(eastSpeed newValue: Double) -> SpeedometerCore {
        if eastSpeed != newValue {
            markChanged()
            eastSpeed = newValue
        }
        return self
    }

    /// Changes the downSpeed.
    ///
    /// - Parameter downSpeed: the speed to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(downSpeed newValue: Double) -> SpeedometerCore {
        if downSpeed != newValue {
            markChanged()
            downSpeed = newValue
        }
        return self
    }

    /// Changes the forwardSpeed.
    ///
    /// - Parameter forwardSpeed: the speed to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(forwardSpeed newValue: Double) -> SpeedometerCore {
        if forwardSpeed != newValue {
            markChanged()
            forwardSpeed = newValue
        }
        return self
    }

    /// Changes the rightSpeed.
    ///
    /// - Parameter rightSpeed: the speed to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(rightSpeed newValue: Double) -> SpeedometerCore {
        if rightSpeed != newValue {
            markChanged()
            rightSpeed = newValue
        }
        return self
    }
}

extension SpeedometerCore: GSSpeedometer {
    public func getGroundSpeed() -> Double {
        return groundSpeed
    }
}
