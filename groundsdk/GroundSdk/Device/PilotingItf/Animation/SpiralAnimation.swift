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

/// Spiral animation configuration class.
///
/// Allows to configure the following parameters for this animation:
/// - **speed**: animation execution speed, in meters per second. If `with(speed:)` is not customized,
///   then the drone will apply its own default value for this parameter.
/// - **radius variation**: animation radius variation.
///   If `with(radiusVariation:)` is not customized, then the drone will apply its own default value for this
///   parameter.
/// - **vertical distance**: distance the drone will fly vertically, in meters. Positive values
///   instruct the drone to fly up, negative value instructs to fly down.
///   If `with(verticalDistance:)` is not customized, then the drone will apply its own default value for this
///   parameter.
/// - **revolution number**: number of revolutions the drone will perform around the target. Positive values instruct
///   the drone to circle clockwise, negative values instruct to circle counter-clockwise.
///   If `with(revolutionAmount:)` is not customized, then the drone will apply its own default value for this
///   parameter.
/// - **mode**: animation execution mode. If `with(mode:)` is not customized, then the drone will apply its
///   own default value for this parameter: `.once`.
@objcMembers
@objc(GSSpiralAnimationConfig)
public class SpiralAnimationConfig: NSObject, AnimationConfig {

    public let type = AnimationType.spiral

    /// Custom speed, in meters per second.
    /// Value is `nil` if `with(speed:)` has never been called.
    public private(set) var speed: Double?

    /// Desired relative radius variation.
    /// Value is `nil` if `with(radiusVariation:)` has never been called.
    /// A value of 2 means that the ending radius will be twice as big as the starting radius.
    /// A value of -2 means that the ending radius will half of the size of the starting radius.
    /// A value of 1 means that the radius will not change during the animation.
    public private(set) var radiusVariation: Double?

    /// Custom vertical distance, in meters.
    /// Value is `nil` if `with(verticalDistance:)` has never been called.
    /// If negative, the spiral will be directed to the ground.
    public private(set) var verticalDistance: Double?

    /// Revolution amount, the number of revolution (in turn).
    /// Value is `nil` if `with(revolutionAmount:)` has never been called.
    /// Positive value makes a clockwise spiral, negative is anti-clockwise.
    public private(set) var revolutionAmount: Double?

    /// Custom execution mode.
    /// Value is `nil` if `with(mode:)` has never been called.
    public private(set) var mode: AnimationMode?

    /// Configures a custom animation speed.
    ///
    /// - Parameter speed: custom animation speed, in meters per second
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(speed: Double) -> SpiralAnimationConfig {
        self.speed = speed
        return self
    }

    /// Configures a custom radius variation.
    ///
    /// - Parameter radiusVariation: custom radius variation
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(radiusVariation: Double) -> SpiralAnimationConfig {
        self.radiusVariation = radiusVariation
        return self
    }

    /// Configures a custom animation vertical distance.
    ///
    /// - Parameter verticalDistance: custom vertical distance, in meters
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(verticalDistance: Double) -> SpiralAnimationConfig {
        self.verticalDistance = verticalDistance
        return self
    }

    /// Configures a custom animation revolution amount.
    ///
    /// - Parameter revolutionAmount: custom revolution amount
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(revolutionAmount: Double) -> SpiralAnimationConfig {
        self.revolutionAmount = revolutionAmount
        return self
    }

    /// Configures a custom animation execution mode.
    ///
    /// - Parameter mode: custom execution mode
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(mode: AnimationMode) -> SpiralAnimationConfig {
        self.mode = mode
        return self
    }
}

/// Extension that brings Obj-C support.
extension SpiralAnimationConfig {
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

/// Spiral animation.
///
/// This animation instructs the drone to circle around the target, possibly in a spiral shape and possibly also while
/// flying vertically (up or down).
/// The target in question depends on the currently active `ActivablePilotingItf`.
@objc(GSSpiralAnimation)
public protocol SpiralAnimation: Animation {

    /// Current animation speed, in meters per second.
    var speed: Double { get }

    /// Current animation radius variation.
    var radiusVariation: Double { get }

    /// Current animation vertical distance, in meters.
    var verticalDistance: Double { get }

    /// Current animation revolution amount.
    var revolutionAmount: Double { get }

    /// Current animation execution mode.
    var mode: AnimationMode { get }
}
