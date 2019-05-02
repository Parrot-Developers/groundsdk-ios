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

/// Internal copter motors peripheral implementation
public class CopterMotorsCore: PeripheralCore, CopterMotors {

    /// A description of a error
    private class MotorErrorDescription {
        /// the error itself
        var error = MotorError.noError

        /// Whether or not the error is current
        var errorIsCurrent = false
    }

    /// All motors currently undergoing some error.
    public var motorsCurrentlyInError: Set<CopterMotor> {
        let motors = currentMotorErrors.map { motor, error -> CopterMotor? in
            return (error != .noError) ? motor : nil
            }
            .compactMap {$0}
        return Set(motors)
    }

    private var currentMotorErrors: [CopterMotor: MotorError] = [:]

    private var pastMotorErrors: [CopterMotor: MotorError] = [:]

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: System info backend
    public init(store: ComponentStoreCore) {
        for motor in CopterMotor.allCases {
            currentMotorErrors[motor] = .noError
            pastMotorErrors[motor] = .noError
        }
        super.init(desc: Peripherals.copterMotors, store: store)
    }

    /// Gets a motor's latest error status.
    ///
    /// - Parameter motor: motor whose error must be retrieved
    /// - Returns:  latest error of the provided motor
    public func latestError(onMotor motor: CopterMotor) -> MotorError {
        // we can force unwrap the value because current and pastMotorErrors have a corresponding error for all motors
        let currentError = currentMotorErrors[motor]!
        return (currentError != .noError) ? currentError : pastMotorErrors[motor]!
    }

    /// Debug description.
    public override var description: String {
        return currentMotorErrors.map { motor, error in
            var description = "\(motor.description): "
            if error != .noError {
                description += error.description + "(current)"
            } else if pastMotorErrors[motor]! != .noError {
                description += pastMotorErrors[motor]!.description + "(past)"
            } else {
                description += "noError"
            }
            return description
            }.joined(separator: ", ")
    }
}

/// Backend callback methods
extension CopterMotorsCore {
    /// Changes an error as current error on a given motor
    ///
    /// - Parameters:
    ///    - currentError: the current error
    ///    - motor: the motor which is impacted by the given error
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(currentError error: MotorError, onMotor motor: CopterMotor)
        -> CopterMotorsCore {
        if currentMotorErrors[motor] != error {
            currentMotorErrors[motor] = error
            markChanged()
        }
        return self
    }

    /// Changes an error as past error on a given motor
    ///
    /// - Parameters:
    ///    - pastError: the latest error (not current)
    ///    - motor: the motor which is impacted by the given error
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(pastError error: MotorError, onMotor motor: CopterMotor) -> CopterMotorsCore {
            if pastMotorErrors[motor] != error {
                pastMotorErrors[motor] = error
                // only report a change if the motor is not currently in error.
                if currentMotorErrors[motor]! == .noError {
                    markChanged()
                }
            }
            return self
    }
}

/// Implementation of the Obj-C protocol GSCopterSystemInfo
extension CopterMotorsCore: GSCopterMotors {
    /// All motors currently undergoing some error.
    public var motorsWithCurrentError: Set<Int> {
        var set: Set<Int> = []
        for motor in self.motorsCurrentlyInError {
            set.insert(motor.rawValue)
        }
        return set
    }
}
