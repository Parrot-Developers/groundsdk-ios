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

/// Candle animation configuration class.
///
/// Allows to configure the following parameters for this animation:
/// - **speed**: animation execution speed, in meters per second. If `with(speed:)` is not customized,
///   then the drone will apply its own default value for this parameter.
/// - **angle**: angle between the drone/target axis and the target/destination axis, in degrees.
///   The drone will slide horizontally according to that angle.
///   If `with(angle:)` is not customized, then the drone will apply its own default value for this parameter.
/// - **horizontal distance**: distance the drone will slide horizontally, in meters.
///   If `with(horizontalDistance:)` is not customized, then the drone will apply its own default value for this
///   parameter.
/// - **mode**: animation execution mode. If `with(mode:)` is not customized, then the drone will apply its
///   own default value for this parameter: `.once`.
@objcMembers
@objc(GSDollySlideAnimationConfig)
public class DollySlideAnimationConfig: NSObject, AnimationConfig {

    public let type = AnimationType.dollySlide

    /// Custom speed, in meters per second.
    /// Value is `nil` if `with(speed:)` has never been called.
    public private(set) var speed: Double?

    /// Custom angle, in degrees.
    /// Value is `nil` if `with(angle:)` has never been called.
    public private(set) var angle: Double?

    /// Custom horizontal distance, in meters.
    /// Value is `nil` if `with(horizontalDistance:)` has never been called.
    public private(set) var horizontalDistance: Double?

    /// Custom execution mode.
    /// Value is `nil` if `with(mode:)` has never been called.
    public private(set) var mode: AnimationMode?

    /// Configures a custom animation speed.
    ///
    /// - Parameter speed: custom animation speed, in meters per second
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(speed: Double) -> DollySlideAnimationConfig {
        self.speed = speed
        return self
    }

    /// Configures a custom animation angle.
    ///
    /// - Parameter speed: custom animation angle, in degrees
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(angle: Double) -> DollySlideAnimationConfig {
        self.angle = angle
        return self
    }

    /// Configures a custom animation horizontal distance.
    ///
    /// - Parameter horizontalDistance: custom horizontal distance, in meters
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(horizontalDistance: Double) -> DollySlideAnimationConfig {
        self.horizontalDistance = horizontalDistance
        return self
    }

    /// Configures a custom animation execution mode.
    ///
    /// - Parameter mode: custom execution mode
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(mode: AnimationMode) -> DollySlideAnimationConfig {
        self.mode = mode
        return self
    }
}

/// Extension that brings Obj-C support.
extension DollySlideAnimationConfig {
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

/// Dolly slide animation.
///
/// This animation instructs the drone to fly horizontally with respect to a specific angle between its original
/// position (before the animation begins), the target, and its destination.
/// The target in question depends on the currently active `ActivablePilotingItf`.
@objc(GSDollySlideAnimation)
public protocol DollySlideAnimation: Animation {

    /// Current animation speed, in meters per second.
    var speed: Double { get }

    /// Current animation angle, in degrees.
    var angle: Double { get }

    /// Current animation horizontal distance, in meters.
    var horizontalDistance: Double { get }

    /// Current animation execution mode.
    var mode: AnimationMode { get }
}
