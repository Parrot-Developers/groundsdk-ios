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

/// Action to execute at the end of a Vertigo animation.
@objc(GSVertigoAnimationFinishAction)
public enum VertigoAnimationFinishAction: Int, CustomStringConvertible {
    /// No particular finish action.
    case none
    /// Move zoom level back to x1.
    case unzoom

    /// Debug description.
    public var description: String {
        switch self {
        case .none:     return "none"
        case .unzoom:   return "unzoom"
        }
    }
}

/// Vertigo animation configuration class.
///
/// Allows to configure the following parameters for this animation:
/// - **duration**: animation execution duration, in second. If `with(duration:)` is not customized,
///   then the drone will apply its own default value for this parameter.
/// - **maxZoomLevel**: maximal zoom level. If `with(maxZoomLevel:)` is not customized,
///   then the drone will apply its own default value for this parameter.
/// - **finishAction**: animation finish action. If `with(finishAction:)` is not customized,
///   then the drone will apply its own default value for this parameter.
/// - **mode**: animation execution mode. If `with(mode:)` is not customized, then the drone will apply its
///   own default value for this parameter: `.once`.
@objcMembers
@objc(GSVertigoAnimationConfig)
public class VertigoAnimationConfig: NSObject, AnimationConfig {

    public let type = AnimationType.vertigo

    /// Custom duration, in seconds.
    /// Value is `nil` if `with(duration:)` has never been called.
    public private(set) var duration: Double?

    /// Custom max zoom level.
    /// Value is `nil` if `with(maxZoomLevel:)` has never been called.
    public private(set) var maxZoomLevel: Double?

    /// Custom finish action.
    /// Value is `nil` if `with(finishAction:)` has never been called.
    public private(set) var finishAction: VertigoAnimationFinishAction?

    /// Custom execution mode.
    /// Value is `nil` if `with(mode:)` has never been called.
    public private(set) var mode: AnimationMode?

    /// Configures a custom animation duration.
    ///
    /// - Parameter duration: custom animation duration, in seconds
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(duration: Double) -> VertigoAnimationConfig {
        self.duration = duration
        return self
    }

    /// Configures a custom animation max zoom level.
    ///
    /// - Parameter maxZoomLevel: max zoom level
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(maxZoomLevel: Double) -> VertigoAnimationConfig {
        self.maxZoomLevel = maxZoomLevel
        return self
    }

    /// Configures a custom animation finish action.
    ///
    /// - Parameter finishAction: custom finish action
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(finishAction: VertigoAnimationFinishAction) -> VertigoAnimationConfig {
        self.finishAction = finishAction
        return self
    }

    /// Configures a custom animation execution mode.
    ///
    /// - Parameter mode: custom execution mode
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func with(mode: AnimationMode) -> VertigoAnimationConfig {
        self.mode = mode
        return self
    }
}

/// Extension that brings Obj-C support.
extension VertigoAnimationConfig {
    /// `true` when `with(finishAction:)` has been called once.
    /// ObjC-only api. In Swift, use `finishAction`.
    public var finishActionIsCustom: Bool {
        return finishAction != nil
    }

    /// Custom finish action.
    /// Value is meaningless if `finishActionIsCustom` is `false`.
    /// ObjC-only api. In Swift, use `finishAction`.
    public var customFinishAction: VertigoAnimationFinishAction {
        return finishAction ?? .none
    }

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

/// Vertigo animation.
///
/// This animation instructs the drone to zoom in on the target, while the drone moves away from it.
/// The target in question depends on the currently active `ActivablePilotingItf`.
@objc(GSVertigoAnimation)
public protocol VertigoAnimation: Animation {

    /// Current animation duration, in seconds.
    var duration: Double { get }

    /// Current animation max zoom level.
    var maxZoomLevel: Double { get }

    /// Current animation finish action.
    var finishAction: VertigoAnimationFinishAction { get }

    /// Current animation execution mode.
    var mode: AnimationMode { get }
}
