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

/// Settings to configure camera alignment.
public protocol CameraAlignment: class {
    /// Whether the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported alignment offset range applied to the yaw axis, in degrees.
    var supportedYawRange: ClosedRange<Double> { get }

    /// Alignment offset applied to the yaw axis, in degrees.
    var yaw: Double { get set }

    /// Supported alignment offset range applied to the pitch axis, in degrees.
    var supportedPitchRange: ClosedRange<Double> { get }

    /// Alignment offset applied to the pitch axis, in degrees.
    var pitch: Double { get set }

    /// Supported alignment offset range applied to the roll axis, in degrees
    var supportedRollRange: ClosedRange<Double> { get }

    /// Alignment offset applied to the roll axis, in degrees.
    var roll: Double { get set }

    /// Factory reset camera alignment.
    ///
    /// - Returns: `true` if the factory reset has begun
    func reset() -> Bool
}

@objc public protocol GSCameraAlignment: class {
    /// Whether the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Minimum supported alignment offset range applied to the yaw axis, in degrees.
    var gsMinSupportedYawRange: Double { get }

    /// Maximum supported alignment offset range applied to the yaw axis, in degrees.
    var gsMaxSupportedYawRange: Double { get }

    /// Alignment offset applied to the yaw axis, in degrees.
    var yaw: Double { get set }

    /// Minimum supported alignment offset range applied to the pitch axis, in degrees.
    var gsMinSupportedPitchRange: Double { get }

    /// Maximum supported alignment offset range applied to the pitch axis, in degrees.
    var gsMaxSupportedPitchRange: Double { get }

    /// Alignment offset applied to the pitch axis, in degrees.
    var pitch: Double { get }

    /// Minimum supported alignment offset range applied to the roll axis, in degrees.
    var gsMinSupportedRollRange: Double { get }

    /// Maximum supported alignment offset range applied to the roll axis, in degrees.
    var gsMaxSupportedRollRange: Double { get }

    /// Alignment offset applied to the roll axis, in degrees.
    var roll: Double { get }

    /// Factory reset camera alignment.
    ///
    /// - Returns: `true` if the factory reset has begun
    func reset() -> Bool
}
