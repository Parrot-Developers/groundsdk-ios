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

/// Magnetometer calibration state
@objc(GSMagnetometerCalibrationState)
public enum MagnetometerCalibrationState: Int {
    /// Magnetometer is calibrated.
    case calibrated

    /// Magnetometer calibration is required.
    case required

    /// Magnetometer calibration is recommanded.
    case recommended

    /// Debug description.
    public var description: String {
        switch self {
        case .calibrated:
            return "calibrated"
        case .required:
            return "required"
        case .recommended:
            return "recommended"
        }
    }

    /// Set containing all possible cases.
    public static let allCases: Set<MagnetometerCalibrationState> = [.calibrated,
        .required, .recommended]
}

/// Magnetometer peripheral.
///
/// Base class telling whether the magnetometer is calibrated or not.
/// A subclass shall be used to control the calibration process, depending on the device, for instance
/// `MagnetometerWith1StepCalibration` or `MagnetometerWith3StepCalibration`.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.magnetometer)
/// ```
@objc(GSMagnetometer)
public protocol Magnetometer: Peripheral {

    /// Indicates the magnetometer calibration state.
    ///
    /// - Note: The magnetometer should be calibrated to make positioning related actions,
    /// such as ReturnToHome, FlightPlan...
    var calibrationState: MagnetometerCalibrationState { get }
}

/// :nodoc:
/// Magnetometer description
@objc(GSMagnetometerDesc)
public class MagnetometerDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = Magnetometer
    public let uid = PeripheralUid.magnetometer.rawValue
    public let parent: ComponentDescriptor? = nil
}
