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

import XCTest
@testable import GroundSdk

/// Test CopterMotors peripheral
class CopterMotorsTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: CopterMotorsCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = CopterMotorsCore(store: store!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.copterMotors), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.copterMotors), nilValue())
    }

    func testMotorErrors() {
        impl.publish()
        var cnt = 0
        let copterMotors = store.get(Peripherals.copterMotors)!
        _ = store.register(desc: Peripherals.copterMotors) {
            cnt += 1
        }

        // test initial value
        assertThat(copterMotors, motorsHaveNoErrors([.frontLeft, .frontRight, .rearLeft, .rearRight]))
        assertThat(cnt, `is`(0))

        // set a current error
        impl.update(currentError: .stalled, onMotor: .frontLeft).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(copterMotors, hasCurrentMotorErrors([.frontLeft: .stalled]))
        assertThat(copterMotors, motorsHaveNoErrors([.frontRight, .rearLeft, .rearRight]))

        // change the current error
        impl.update(currentError: .securityMode, onMotor: .frontLeft).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(copterMotors, hasCurrentMotorErrors([.frontLeft: .securityMode]))
        assertThat(copterMotors, motorsHaveNoErrors([.frontRight, .rearLeft, .rearRight]))

        // set same error, should not trigger a notify
        impl.update(currentError: .securityMode, onMotor: .frontLeft).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(copterMotors, hasCurrentMotorErrors([.frontLeft: .securityMode]))
        assertThat(copterMotors, motorsHaveNoErrors([.frontRight, .rearLeft, .rearRight]))

        // set a different past error on same motor, should not change the error
        impl.update(pastError: .emergencyStop, onMotor: .frontLeft).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(copterMotors, hasCurrentMotorErrors([.frontLeft: .securityMode]))
        assertThat(copterMotors, motorsHaveNoErrors([.frontRight, .rearLeft, .rearRight]))

        // reset current error on the motor, motor should not be in error anymore, but past error should be kept.
        impl.update(currentError: .noError, onMotor: .frontLeft).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(copterMotors, hasPastMotorErrors([.frontLeft: .emergencyStop]))
        assertThat(copterMotors, motorsHaveNoErrors([.frontRight, .rearLeft, .rearRight]))

        // change the past error, should update accordingly
        impl.update(pastError: .other, onMotor: .frontLeft).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(copterMotors, hasPastMotorErrors([.frontLeft: .other]))
        assertThat(copterMotors, motorsHaveNoErrors([.frontRight, .rearLeft, .rearRight]))

        // set other motors errors, check it does not impact the already set past error
        impl.update(currentError: .stalled, onMotor: .rearLeft)
            .update(currentError: .securityMode, onMotor: .rearRight)
            .notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(copterMotors, hasCurrentMotorErrors([.rearRight: .securityMode, .rearLeft: .stalled]))
        assertThat(copterMotors, hasPastMotorErrors([.frontLeft: .other]))
        assertThat(copterMotors, motorsHaveNoErrors([.frontRight]))

        // update motors past errors, check it only alter motors not currently in error
        impl.update(pastError: .securityMode, onMotor: .frontRight)
            .update(pastError: .stalled, onMotor: .frontLeft)
            .update(pastError: .emergencyStop, onMotor: .rearRight)
            .notifyUpdated()
        assertThat(cnt, `is`(6))
        assertThat(copterMotors, hasCurrentMotorErrors([.rearLeft: .stalled, .rearRight: .securityMode]))
        assertThat(copterMotors, hasPastMotorErrors([.frontLeft: .stalled, .frontRight: .securityMode]))

        // clear all current errors
        impl.update(currentError: .noError, onMotor: .frontRight)
            .update(currentError: .noError, onMotor: .frontLeft)
            .update(currentError: .noError, onMotor: .rearRight)
            .update(currentError: .noError, onMotor: .rearLeft)
            .notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(copterMotors,
                   hasPastMotorErrors([.frontLeft: .stalled, .frontRight: .securityMode, .rearRight: .emergencyStop]))
        assertThat(copterMotors, motorsHaveNoErrors([.rearLeft]))

        // clear all past errors
        impl.update(pastError: .noError, onMotor: .frontRight)
            .update(pastError: .noError, onMotor: .frontLeft)
            .update(pastError: .noError, onMotor: .rearRight)
            .update(pastError: .noError, onMotor: .rearLeft)
            .notifyUpdated()
        assertThat(cnt, `is`(8))
        assertThat(copterMotors, motorsHaveNoErrors([.frontLeft, .frontRight, .rearLeft, .rearRight]))
    }
}
