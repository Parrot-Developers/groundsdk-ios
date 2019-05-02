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

/// Motor description.
@objc(GSCopterMotor)
public enum CopterMotor: Int {

    /// Front left motor (copter viewed from above).
    case frontLeft

    /// Front right motor (copter viewed from above).
    case frontRight

    /// Back right motor (copter viewed from above).
    case rearRight

    /// Back left motor (copter viewed from above).
    case rearLeft

    /// Debug description.
    public var description: String {
        switch self {
        case .frontLeft:
            return "frontLeft"
        case .frontRight:
            return "frontRight"
        case .rearRight:
            return "rearRight"
        case .rearLeft:
            return "rearLeft"
        }
    }

    /// Set containing all possible motors.
    public static let allCases: Set<CopterMotor> = [.frontLeft, .frontRight, .rearRight, .rearLeft]
}

/// CopterMotors peripheral interface for copter drones.
///
/// Allows to query the error status of each of the copter's motors.
///
/// This peripheral can be retrieved by:
/// ```
/// drone.getPeripheral(Peripherals.copterMotors)
/// ```
public protocol CopterMotors: Peripheral {
    /// All motors currently undergoing some error.
    var motorsCurrentlyInError: Set<CopterMotor> { get }

    /// Gets a motor's latest error status.
    ///
    /// - Parameter motor: motor whose error must be retrieved
    /// - Returns: latest error of the provided motor
    func latestError(onMotor motor: CopterMotor) -> MotorError
}

/// :nodoc:
/// CopterMotors description
@objc(GSCopterMotorsDesc)
public class CopterMotorsDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = CopterMotors
    public let uid = PeripheralUid.copterMotors.rawValue
    public let parent: ComponentDescriptor? = nil
}

// MARK: Objective-C API

/// CopterMotors peripheral interface for copter drones.
///
/// Allows to query the error status of each of the copter's motors.
///
/// This peripheral can be retrieved by:
/// ```
/// drone.getPeripheral(Peripherals.copterMotors)
/// ```
/// - Note: This protocol is for Objective-C only. Swift must use the protocol `CopterMotors`.
@objc
public protocol GSCopterMotors: Peripheral {
    /// All motors currently undergoing some error.
    var motorsWithCurrentError: Set<Int> { get }

    /// Gets a motor's latest error status.
    ///
    /// - Parameter motor: motor whose error must be retrieved
    /// - Returns: latest error of the provided motor
    func latestError(onMotor motor: CopterMotor) -> MotorError
}
