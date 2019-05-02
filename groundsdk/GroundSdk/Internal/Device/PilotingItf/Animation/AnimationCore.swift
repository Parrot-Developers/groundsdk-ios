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

/// Animation matcher protocol
protocol AnimationCoreMatcher {
    /// Tells whether the animation matches some configuration.
    ///
    /// Mandatory parameters are matched exactly to the corresponding animation current parameters.
    /// Optional parameters that have been forcefully customized in the provided configuration are matched exactly to
    /// the corresponding animation current parameters.
    /// Optional parameters that have been left to their defaults in the provided configuration are not matched.
    ///
    /// Only called if the config is the same type as the animation. So the config can be directly cast into the same
    /// type as the animation.
    ///
    /// - Parameter config: configuration to match this animation against
    /// - Returns: `true` if the animation matched the given configuration, `false` otherwise
    func matchesConfig(_ config: AnimationConfig) -> Bool

    /// Returns true if the other animation is considered the same as this one.
    ///
    /// Only called if other is the same type as the animation. So other can be directly cast into the same type as the
    /// animation.
    ///
    /// - Note: Only static params are taken in account.
    ///
    /// - Parameter other: the other animation
    /// - Returns: `true` if they are equals, `false` otherwise
    func equalsTo(_ other: AnimationCore) -> Bool
}

/// Core class of the Animation.
/// This class should be considered as an abstract class.
public class AnimationCore: Animation {

    /// Animation with unidentified type.
    public class Unidentified: AnimationCore, AnimationCoreMatcher {

        /// Constructor.
        public init() {
            super.init(type: .unidentified)
            matcher = self
        }

        public func matchesConfig(_ config: AnimationConfig) -> Bool {
            return false
        }

        func equalsTo(_ other: AnimationCore) -> Bool {
            return true
        }
    }

    public let type: AnimationType

    public private(set) var status = AnimationStatus.animating

    public private(set) var progress = 0

    /// Matcher that should be set by subclasses
    var matcher: AnimationCoreMatcher!

    /// Constructor
    ///
    /// - Parameters:
    ///   - type: type of the animation
    ///   - status: status of the animation
    init(type: AnimationType) {
        self.type = type
    }

    public final func matches(config: AnimationConfig) -> Bool {
        return type == config.type && matcher.matchesConfig(config)
    }
}

extension AnimationCore: Equatable {
    static public func == (lhs: AnimationCore, rhs: AnimationCore) -> Bool {
        return lhs.type == rhs.type && lhs.matcher.equalsTo(rhs)
    }
}

/// Extension to AnimationCore that adds internal setters
extension AnimationCore {
    /// Sets the status of the animation
    ///
    /// - Parameter newStatus: new value
    /// - Returns: `true` if the status has been changed, `false` otherwise.
    func set(status newStatus: AnimationStatus) -> Bool {
        if status != newStatus {
            status = newStatus
            return true
        }
        return false
    }

    /// Sets the progress of the animation
    ///
    /// - Parameter newProgress: new value
    /// - Returns: `true` if the progress has been changed, `false` otherwise.
    func set(progress newProgress: Int) -> Bool {
        if progress != newProgress {
            progress = newProgress
            return true
        }
        return false
    }
}
