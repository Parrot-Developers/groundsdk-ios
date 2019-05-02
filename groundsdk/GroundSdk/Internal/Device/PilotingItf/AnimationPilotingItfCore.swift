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

/// Animation piloting interface backend.
public protocol AnimationPilotingItfBackend: class {
    /// Starts an animation.
    ///
    /// - Parameter config: configuration of the animation to execute
    /// - Returns: true if an animation request was sent to the drone, false otherwise
    func startAnimation(config: AnimationConfig) -> Bool

    /// Aborts any currently executing animation.
    ///
    /// - Returns: true if an animation cancellation request was sent to the drone, false otherwise
    func abortCurrentAnimation() -> Bool
}

/// Internal animation piloting interface implementation
public class AnimationPilotingItfCore: ComponentCore, AnimationPilotingItf {

    public var animation: Animation? {
        return animCore
    }

    /// private core animation
    private var animCore: AnimationCore?

    public private(set) var availableAnimations: Set<AnimationType> = []

    /// Backend
    private let backend: AnimationPilotingItfBackend

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this interface will be stored
    ///    - backend: ManualCopterPilotingItf backend
    public init(store: ComponentStoreCore, backend: AnimationPilotingItfBackend) {
        self.backend = backend
        super.init(desc: PilotingItfs.animation, store: store)
    }

    public func startAnimation(config: AnimationConfig) -> Bool {
        return availableAnimations.contains(config.type) && backend.startAnimation(config: config)
    }

    public func abortCurrentAnimation() -> Bool {
        if let animation = animation, animation.status == .animating {
            return backend.abortCurrentAnimation()
        }
        return false
    }
}

/// Backend callback methods
extension AnimationPilotingItfCore {

    /// Changes the set of available animations
    ///
    /// - Parameter availableAnimations: new set of available animations
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(availableAnimations newSet: Set<AnimationType>) -> AnimationPilotingItfCore {
        if availableAnimations != newSet {
            availableAnimations = newSet
            markChanged()
        }
        return self
    }

    /// Changes the current animation
    ///
    /// - Parameter animation: new animation
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(animation newAnimation: AnimationCore?) -> AnimationPilotingItfCore {
        if animCore != newAnimation {
            animCore = newAnimation
            markChanged()
        }

        return self
    }

    /// Changes the current animation
    ///
    /// - Parameters:
    ///   - animation: new animation
    ///   - status: new status animation
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        animation newAnimation: AnimationCore?, status newStatus: AnimationStatus) -> AnimationPilotingItfCore {

        // first update the animation
        update(animation: newAnimation)
        // then update its status
        if let animCore = animCore, animCore.set(status: newStatus) {
            markChanged()
        }

        return self
    }

    /// Changes the progress of the current animation
    ///
    /// - Parameter animationProgress: new progress
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(progress newProgress: Int) -> AnimationPilotingItfCore {
        if let animCore = animCore, animCore.set(progress: newProgress) {
            markChanged()
        }
        return self
    }
}

/// Extension of AnimationPilotingItfCore that brings the support of the ObjC GSAnimationPilotingItf protocol.
extension AnimationPilotingItfCore: GSAnimationPilotingItf {
    public func isAnimationAvailable(_ animation: AnimationType) -> Bool {
        return availableAnimations.contains(animation)
    }
}
