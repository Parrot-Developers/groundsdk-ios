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

import GroundSdk

func hasCurrentMotorErrors(_ motorErrors: [CopterMotor:MotorError]) -> Matcher<CopterMotors> {
    let description = "\(motorErrors.map { "\($0.description): \($1.description)(current)" }.joined(separator: ", "))"
    return Matcher(description) { (value) -> MatchResult in
        for (motor, error) in motorErrors {
            if !value.motorsCurrentlyInError.contains(motor) {
                return MatchResult.mismatch("Motor \(motor.description) expected to have a current error")
            }
            if value.latestError(onMotor: motor) != error {
                return MatchResult.mismatch("Motor \(motor.description) expected error: \(error)")
            }
        }
        return .match
    }
}

func hasPastMotorErrors(_ motorErrors: [CopterMotor:MotorError]) -> Matcher<CopterMotors> {
    let description = "\(motorErrors.map { "\($0.description): \($1.description)(past)" }.joined(separator: ", "))"
    return Matcher(description) { (value) -> MatchResult in
        for (motor, error) in motorErrors {
            if value.motorsCurrentlyInError.contains(motor) {
                return MatchResult.mismatch("Motor \(motor.description) expected to have a past error")
            }
            if value.latestError(onMotor: motor) != error {
                return MatchResult.mismatch("Motor \(motor.description) expected error: \(error)")
            }
        }
        return .match
    }
}

func motorsHaveNoErrors(_ motors: [CopterMotor]) -> Matcher<CopterMotors> {
    return Matcher("\(motors.map { "\($0.description): noError" }.joined(separator: ", "))") { (value) -> MatchResult in
        for motor in motors {
            if value.latestError(onMotor: motor) != .noError {
                return MatchResult.mismatch("Motor \(motor.description) expected no error")
            }
        }
        return .match
    }
}

func hasCurrentMotorError(_ error: MotorError, onMotors motors: Set<CopterMotor>) -> Matcher<CopterMotors> {
    return Matcher("error = \(error.description) is current && motors = " +
        "\(motors.map { $0.description }.joined(separator: ", "))") { (value) -> MatchResult in
        if value.motorsCurrentlyInError != motors {
            return .mismatch("Given motors differs from motors on error")
        }
        for motor in CopterMotor.allCases {
            if motors.contains(motor) && value.latestError(onMotor: motor) != error {
                return .mismatch("latest error on motor \(motor.description): " +
                    "\(value.latestError(onMotor: motor).description)")
            }
        }
        return .match
    }
}

func hasPastMotorError(_ error: MotorError, onMotors motors: Set<CopterMotor>) -> Matcher<CopterMotors> {
    return Matcher("error = \(error.description) is past") { (value) -> MatchResult in
        if !value.motorsCurrentlyInError.isDisjoint(with: motors) {
            return .mismatch("Some given motors are currently in error")
        }
        for motor in CopterMotor.allCases {
            if motors.contains(motor) && value.latestError(onMotor: motor) != error {
                return .mismatch("latest error on motor \(motor.description): " +
                "\(value.latestError(onMotor: motor).description)")
            }
        }
        return .match
    }
}

func hasNoMotorError() -> Matcher<CopterMotors> {
    return Matcher("no error") { (value) -> MatchResult in
        if !value.motorsCurrentlyInError.isEmpty {
            return .mismatch("motor in error: " +
            "\(value.motorsCurrentlyInError.map { $0.description }.joined(separator: ", "))")
        }
        for motor in CopterMotor.allCases {
            if value.latestError(onMotor: motor) != .noError {
                return .mismatch("latest error on motor \(motor.description): " +
                "\(value.latestError(onMotor: motor).description)")
            }
        }
        return .match
    }
}
