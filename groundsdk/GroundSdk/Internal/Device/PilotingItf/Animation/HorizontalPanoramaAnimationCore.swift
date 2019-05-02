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

/// Core implementation of the horizontal panorama animation
public class HorizontalPanoramaCore: AnimationCore, HorizontalPanoramaAnimation {
    public let rotationAngle: Double

    public let rotationSpeed: Double

    /// Constructor
    ///
    /// - Parameters:
    ///   - rotationAngle: rotation angle, in degrees
    ///   - rotationSpeed: rotation speed, in degrees per second
    public init(rotationAngle: Double, rotationSpeed: Double) {
        self.rotationAngle = rotationAngle
        self.rotationSpeed = rotationSpeed
        super.init(type: .horizontalPanorama)
        matcher = self
    }
}

/// Extension of HorizontalPanoramaCore that implements AnimationCoreMatcher
extension HorizontalPanoramaCore: AnimationCoreMatcher {
    public func matchesConfig(_ config: AnimationConfig) -> Bool {
        guard let cfg = config as? HorizontalPanoramaAnimationConfig else {
            return false
        }
        return (cfg.rotationAngle == nil || cfg.rotationAngle! ≈≈ rotationAngle) &&
            (cfg.rotationSpeed == nil || cfg.rotationSpeed! ≈≈ rotationSpeed)
    }

    func equalsTo(_ other: AnimationCore) -> Bool {
        guard let anim = other as? HorizontalPanoramaCore else {
            return false
        }
        return rotationAngle == anim.rotationAngle && rotationSpeed == anim.rotationSpeed
    }
}
