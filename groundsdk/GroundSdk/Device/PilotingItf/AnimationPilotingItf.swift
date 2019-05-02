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

/// Animation piloting interface.
///
/// This piloting interface cannot be activated or deactivated. It is present as soon as a drone supporting animations
/// is connected. It is removed as soon as the drone is disconnected.
///
/// According to different parameters, the list of available animations can change.
/// These parameters can be (not exhaustive):
/// - Current activated piloting interface
/// - Information about the controller (such as location)
/// - Internal state of the drone (such as battery level, gps fix...)
///
/// This piloting interface can be retrieved by:
/// ```
/// drone.getPilotingItf(animation)
/// ```
public protocol AnimationPilotingItf: PilotingItf {

    /// Set of currently available animations.
    var availableAnimations: Set<AnimationType> { get }

    /// Currently executing animation.
    /// `nil` if no animation is playing.
    var animation: Animation? { get }

    /// Starts an animation.
    ///
    /// - Parameter config: configuration of the animation to execute
    /// - Returns: `true` if an animation request was sent to the drone, `false` otherwise
    func startAnimation(config: AnimationConfig) -> Bool

    /// Aborts any currently executing animation.
    ///
    /// - Returns: `true` if an animation cancellation request was sent to the drone, `false` otherwise
    func abortCurrentAnimation() -> Bool
}

/// Animation piloting interface.
///
/// This piloting interface cannot be activated or deactivated. It is present as soon as a drone supporting animations
/// is connected. It is removed as soon as the drone is disconnected.
///
/// According to different parameters, the list of available animation can change.
/// These parameters can be (not exhaustive):
/// - Current activated piloting interface
/// - Information about the controller (such as location)
/// - Internal state of the drone (such as battery level, gps fix...)
///
/// This peripheral can be retrieved by:
/// ```
/// (id<AnimationPilotingItf>) [drone getPilotingItf:GSPilotingItfs.animation]
/// ```
///
/// - Note: this protocol is for Objective-C only. Swift must use the protocol `AnimationPilotingItf`.
@objc
public protocol GSAnimationPilotingItf: PilotingItf {

    /// Currently executing animation.
    /// `nil` if no animation is playing
    var animation: Animation? { get }

    /// Tells whether the given animation type is currently available on the drone.
    ///
    /// - Parameter animation: the animation type to query
    /// - Returns: `true` if this type of animation is currently available
    func isAnimationAvailable(_ animation: AnimationType) -> Bool

    /// Starts an animation.
    ///
    /// - Parameter config: configuration of the animation to execute
    /// - Returns: `true` if an animation request was sent to the drone, `false` otherwise
    func startAnimation(config: AnimationConfig) -> Bool

    /// Aborts any currently executing animation.
    ///
    /// - Returns: `true` if an animation cancellation request was sent to the drone, `false` otherwise
    func abortCurrentAnimation() -> Bool
}

/// :nodoc:
/// Animation piloting interface description
@objc(GSAnimationPilotingItfs)
public class AnimationPilotingItfs: NSObject, PilotingItfClassDesc {
    public typealias ApiProtocol = AnimationPilotingItf
    public let uid = PilotingItfUid.animation.rawValue
    public let parent: ComponentDescriptor? = nil
}
