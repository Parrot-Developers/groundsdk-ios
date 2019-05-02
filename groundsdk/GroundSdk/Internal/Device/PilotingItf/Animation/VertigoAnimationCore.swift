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

/// Core implementation of the vertigo animation
public class VertigoCore: AnimationCore, VertigoAnimation {
    public let duration: Double

    public let maxZoomLevel: Double

    public let finishAction: VertigoAnimationFinishAction

    public let mode: AnimationMode

    /// Constructor
    ///
    /// - Parameters:
    ///   - duration: duration, in second
    ///   - maxZoomLevel: max zoom level
    ///   - finishAction: finish action
    ///   - mode: execution mode
    public init(duration: Double, maxZoomLevel: Double, finishAction: VertigoAnimationFinishAction,
                mode: AnimationMode) {
        self.duration = duration
        self.maxZoomLevel = maxZoomLevel
        self.finishAction = finishAction
        self.mode = mode
        super.init(type: .vertigo)
        matcher = self
    }
}

/// Extension of ParabolaCore that implements AnimationCoreMatcher
extension VertigoCore: AnimationCoreMatcher {
    public func matchesConfig(_ config: AnimationConfig) -> Bool {
        guard let cfg = config as? VertigoAnimationConfig else {
            return false
        }
        return (cfg.duration == nil || cfg.duration! ≈≈ duration) &&
            (cfg.maxZoomLevel == nil || cfg.maxZoomLevel! ≈≈ maxZoomLevel) &&
            (cfg.finishAction == nil || cfg.finishAction == finishAction) &&
            (cfg.mode == nil || cfg.mode == mode)
    }

    func equalsTo(_ other: AnimationCore) -> Bool {
        guard let anim = other as? VertigoCore else {
            return false
        }
        return duration == anim.duration && maxZoomLevel == anim.maxZoomLevel &&
            finishAction == anim.finishAction && mode == anim.mode
    }
}
