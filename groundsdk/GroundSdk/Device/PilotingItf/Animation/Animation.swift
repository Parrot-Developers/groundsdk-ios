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

/// Type of animation.
@objc(GSAnimationType)
public enum AnimationType: Int {
    /// Unidentified animation. Animation of this type cannot be cast.
    case unidentified
    /// Candle animation. Animation of this type can be cast to `CandleAnimation`.
    case candle
    /// Dolly slide animation. Animation of this type can be cast to `DollySlideAnimation`.
    case dollySlide
    /// Dronie animation. Animation of this type can be cast to `DronieAnimation`.
    case dronie
    /// Flip animation. Animation of this type can be cast to `FlipAnimation`.
    case flip
    /// Horizontal panorama animation. Animation of this type can be cast to `HorizontalPanoramaAnimation`.
    case horizontalPanorama
    /// Horizontal reveal animation. Animation of this type can be cast to `HorizontalRevealAnimation`.
    case horizontalReveal
    /// Parabola animation. Animation of this type can be cast to `ParabolaAnimation`.
    case parabola
    /// Spiral animation. Animation of this type can be cast to `SpiralAnimation`.
    case spiral
    /// Vertical reveal animation. Animation of this type can be cast to `VerticalRevealAnimation`.
    case verticalReveal
    /// Vertigo animation. Animation of this type can be cast to `VertigoAnimation`.
    case vertigo
    /// Twist up animation. Animation of this type can be cast to "TwistUpAnimation".
    case twistUp
    /// Position twist up animation. Animation of this type can be cast to "PositionTwistUpAnimation".
    case positionTwistUp
    /// Horizontal 180 Photo panorama animation. Animation of this type can be cast to
    /// "Horizontal180PhotoPanoramaAnimation".
    case horizontal180PhotoPanorama
    /// Vertical 180 Photo panorama animation. Animation of this type can be cast to
    /// "Vertical180PhotoPanoramaAnimation".
    case vertical180PhotoPanorama
    /// Spherical Photo panorama animation. Animation of this type can be cast to "SphericalPhotoPanoramaAnimation".
    case sphericalPhotoPanorama

    /// Debug description.
    public var description: String {
        switch self {
        case .unidentified:             return "unidentified"
        case .candle:                   return "candle"
        case .dollySlide:               return "dollySlide"
        case .dronie:                   return "dronie"
        case .flip:                     return "flip"
        case .horizontalPanorama:       return "horizontalPanorama"
        case .horizontalReveal:         return "horizontalReveal"
        case .parabola:                 return "parabola"
        case .spiral:                   return "spiral"
        case .verticalReveal:           return "verticalReveal"
        case .vertigo:                  return "vertigo"
        case .twistUp:                  return "twistUp"
        case .positionTwistUp:          return "positionTwistUp"
        case .horizontal180PhotoPanorama:  return "horizontal180PhotoPanorama"
        case .vertical180PhotoPanorama:    return "vertical180PhotoPanorama"
        case .sphericalPhotoPanorama:   return "sphericalPhotoPanorama"
        }
    }
}

/// Execution mode used by some animations.
@objc(GSAnimationMode)
public enum AnimationMode: Int {
    /// Execute animation only once.
    case once
    /// Execute animation once, then a second time in reverse.
    case onceThenMirrored

    /// Debug description.
    public var description: String {
        switch self {
        case .once:             return "once"
        case .onceThenMirrored: return "onceThenMirrored"
        }
    }
}

/// Animation execution status.
@objc(GSAnimationStatus)
public enum AnimationStatus: Int {
    /// The drone is currently executing an animation.
    case animating
    /// The drone is currently in the process of aborting an executing animation.
    case aborting

    /// Debug description.
    public var description: String {
        switch self {
        case .animating:    return "animating"
        case .aborting:     return "aborting"
        }
    }
}

/// Base class for an `Animation` configuration.
///
/// Subclasses allow to build a configuration that instructs the drone to play the animation with whatever default
/// values if deems appropriate, depending on the current context and/or its own defaults.
///
/// Subclasses may also have mandatory parameters in their constructor.
///
/// Each method starting with `with` in subclasses allows to customize a different animation parameter.
/// When one of this method is called, the drone will use the provided parameter value instead of its own default,
/// if possible.
@objc(GSAnimationConfig)
public protocol AnimationConfig: class {
    /// Type of the configured animation.
    var type: AnimationType { get }
}

/// Base interface for an Animation.
@objc(GSAnimation)
public protocol Animation: class {
    /// Animation type.
    var type: AnimationType { get }

    /// Animation status.
    var status: AnimationStatus { get }

    /// Progress of the animation.
    /// From 0 to 100.
    var progress: Int { get }

    /// Tells whether the animation matches some configuration.
    ///
    /// Mandatory parameters are matched exactly to the corresponding animation current parameters.
    /// Optional parameters that have been forcefully customized in the provided configuration are matched exactly to
    /// the corresponding animation current parameters.
    /// Optional parameters that have been left to their defaults in the provided configuration are not matched.
    ///
    /// - Parameter config: configuration to match this animation against
    /// - Returns: `true` if the animation matched the given configuration, `false` otherwise
    func matches(config: AnimationConfig) -> Bool
}
