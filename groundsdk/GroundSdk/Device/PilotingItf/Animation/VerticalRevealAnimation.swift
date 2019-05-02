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

/// Vertical reveal animation configuration class.
///
/// Allows to configure the following parameters for this animation:
/// - **vertical speed**: animation vertical speed, in meters per second. If `with(verticalSpeed:)` is not customized,
///   then the drone will apply its own default value for this parameter.
/// - **vertical distance**: distance the drone will fly vertically, in meters. Positive values
///   instruct the drone to fly up, negative value instructs to fly down.
///   If `with(verticalDistance:)` is not customized, then the drone will apply its own default value for this
///   parameter.
/// - **rotation angle**: angle for the panorama the drone will perform after having flown up, in degrees.
///   Positive values make the drone rotate clockwise, negative values make it rotate counter-clockwise.
///   Absolute value may be greater than 360 degrees to perform more than one complete rotation.
///   If `with(rotationAngle:)` is not called, then the drone will apply its own default value for this parameter.
/// - **rotation speed**: angular speed of the rotation, in degrees per second. If `with(rotationSpeed:)` is not called,
///   then the drone will apply its own default value for this parameter.
/// - **mode**: animation execution mode. If `with(mode:)` is not customized, then the drone will apply its
///   own default value for this parameter: `.once`.
@objcMembers
@objc(GSVerticalRevealAnimationConfig)
public class VerticalRevealAnimationConfig: NSObject, AnimationConfig {

    public let type = AnimationType.verticalReveal

    /// Custom vertical speed, in meters per second.
    /// Value is `nil` if `with(verticalSpeed:)` has never been called.
    public private(set) var verticalSpeed: Double?

    /// Custom vertical distance, in meters.
    /// Value is `nil` if `with(verticalDistance:)` has never been called.
    public private(set) var verticalDistance: Double?

    /// Custom rotation angle, in degrees.
    /// Value is `nil` if `with(rotationAngle:)` has never been called.
    public internal(set) var rotationAngle: Double?

    /// Custom rotation speed, in degrees per second.
    /// Value is `nil` if `with(rotationSpeed:)` has never been called.
    public internal(set) var rotationSpeed: Double?

    /// Custom execution mode.
    /// Value is `nil` if `with(mode:)` has never been called.
    public private(set) var mode: AnimationMode?

    /// Configures a custom animation vertical speed.
    ///
    /// - Parameter speed: custom animation speed, in meters per second
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(verticalSpeed: Double) -> VerticalRevealAnimationConfig {
        self.verticalSpeed = verticalSpeed
        return self
    }

    /// Configures a custom animation vertical distance.
    ///
    /// - Parameter verticalDistance: custom vertical distance, in meters
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(verticalDistance: Double) -> VerticalRevealAnimationConfig {
        self.verticalDistance = verticalDistance
        return self
    }

    /// Configures a custom rotation angle.
    ///
    /// - Parameter rotationAngle: custom rotation angle, in degrees
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(rotationAngle: Double) -> VerticalRevealAnimationConfig {
        self.rotationAngle = rotationAngle
        return self
    }

    /// Configures a custom rotation speed.
    ///
    /// - Parameter rotationSpeed: custom rotation speed, in degrees per second
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(rotationSpeed: Double) -> VerticalRevealAnimationConfig {
        self.rotationSpeed = rotationSpeed
        return self
    }

    /// Configures a custom animation execution mode.
    ///
    /// - Parameter mode: custom execution mode
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(mode: AnimationMode) -> VerticalRevealAnimationConfig {
        self.mode = mode
        return self
    }
}

/// Extension that brings Obj-C support.
extension VerticalRevealAnimationConfig {
    /// `true` when `with(mode:)` has been called once.
    /// ObjC-only api. In Swift, use `mode`.
    public var modeIsCustom: Bool {
        return mode != nil
    }

    /// Custom mode.
    /// Value is meaningless if `modeIsCustom` is `false`.
    /// ObjC-only api. In Swift, use `mode`.
    public var customMode: AnimationMode {
        return mode ?? .once
    }
}

/// Vertical reveal animation.
///
/// This animation instructs the drone to start looking down, then to fly up slowly looking at the horizon. Once the
/// drone reaches its target altitude, it rotates on itself to perform an horizontal panorama.
@objc(GSVerticalRevealAnimation)
public protocol VerticalRevealAnimation: Animation {

    /// Current animation vertical speed, in meters per second.
    var verticalSpeed: Double { get }

    /// Current animation vertical distance, in meters.
    var verticalDistance: Double { get }

    /// Current animation rotation angle, in degrees.
    var rotationAngle: Double { get }

    /// Current animation rotation angular speed, in degrees per second.
    var rotationSpeed: Double { get }

    /// Current animation execution mode.
    var mode: AnimationMode { get }
}
