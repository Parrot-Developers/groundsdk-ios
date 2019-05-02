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

/// Horizontal panorama animation configuration class.
///
/// Allows to configure the following parameters for this animation:
/// - **rotation angle**: angle of the rotation the drone should perform, in degrees. Positive values make the drone
///   rotate clockwise, negative values make it rotate counter-clockwise. Absolute value may be greater than 360 degrees
///   to perform more than one complete rotation. If `with(rotationAngle:)` is not called, then the drone will apply
///   its own default value for this parameter.
/// - **rotation speed**: angular speed of the rotation, in degrees per second. If `with(rotationSpeed:)` is not called,
///   then the drone will apply its own default value for this parameter.
@objcMembers
@objc(GSHorizontalPanoramaAnimationConfig)
public class HorizontalPanoramaAnimationConfig: NSObject, AnimationConfig {

    public let type = AnimationType.horizontalPanorama

    /// Custom rotation angle, in degrees.
    /// Value is `nil` if `with(rotationAngle:)` has never been called.
    public internal(set) var rotationAngle: Double?

    /// Custom rotation speed, in degrees per second.
    /// Value is `nil` if `with(rotationSpeed:)` has never been called.
    public internal(set) var rotationSpeed: Double?

    /// Configures a custom rotation angle.
    ///
    /// - Parameter rotationAngle: custom rotation angle, in degrees
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(rotationAngle: Double) -> HorizontalPanoramaAnimationConfig {
        self.rotationAngle = rotationAngle
        return self
    }

    /// Configures a custom rotation speed.
    ///
    /// - Parameter rotationSpeed: custom rotation speed, in degrees per second
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(rotationSpeed: Double) -> HorizontalPanoramaAnimationConfig {
        self.rotationSpeed = rotationSpeed
        return self
    }
}

/// Horizontal panorama animation.
///
/// This animation instructs the drone to rotate horizontally.
@objc(GSHorizontalPanoramaAnimation)
public protocol HorizontalPanoramaAnimation: Animation {

    /// Current animation rotation angle, in degrees.
    var rotationAngle: Double { get }

    /// Current animation rotation angular speed, in degrees per second.
    var rotationSpeed: Double { get }
}
