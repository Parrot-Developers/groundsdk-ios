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

/// Way of controlling the zoom.
@objc(GSCameraZoomControlMode)
public enum CameraZoomControlMode: Int, CustomStringConvertible {
    /// Control the zoom giving level targets.
    case level
    /// Control the zoom giving velocity targets.
    case velocity

    /// Debug description.
    public var description: String {
        switch self {
        case .level: return "level"
        case .velocity: return "velocity"
        }
    }
}

/// A camera zoom.
///
/// Zoom level can be changed whether by giving a desired level (`set(level:)`)
/// or by giving a desired zoom change velocity (`set(velocity:)`).
@objc(GSCameraZoom)
public protocol CameraZoom: class {
    /// Max zoom speed setting.
    var maxSpeed: DoubleSetting { get }

    /// Whether  zoom level changes using zoom velocity will stop at the `maxLossyLevel` or at the
    /// `maxLossLessLevel` to avoid image quality degradation.
    /// If quality degradation is not allowed, it will stop at `maxLossLessZoomLevel`.
    var velocityQualityDegradationAllowance: BoolSetting { get }

    /// Whether zoom is currently available.
    /// - Note: this might change according to the drone actions. For example, zoom might be temporarily unavailable
    ///         if the drone is doing an animation.
    var isAvailable: Bool { get }

    /// Current zoom level, in focal length factor.
    ///
    /// 1 means no zoom.
    /// - Note: Zoom level can be changed either by specifying a new factor with `set(level:)` or by specifying a
    ///         zoom change velocity with `set(velocity:)`.
    var currentLevel: Double { get }

    /// Maximum zoom level available on the device
    /// - Note: from `maxLossLessLevel` to this value, image quality is altered.
    var maxLossyLevel: Double { get }

    /// Maximum zoom level to keep image quality at its best.
    /// - Note: If zoom level is greater than this value, image quality will be altered.
    var maxLossLessLevel: Double { get }

    /// Controls the zoom.
    ///
    /// Unit of the `target` depends on the value of the `mode` parameter:
    ///    - `.level`: target is in zoom level.1 means no zoom.
    ///                This value will be clamped to the `maxLossyLevel` if it is greater than this value.
    ///    - `.velocity`: value is in signed ratio (from -1 to 1) of `maxSpeed` setting value.
    ///                   Negative values will produce a zoom out, positive value will zoom in.
    ///
    /// - Parameters:
    ///   - mode: the mode that should be used to control the zoom.
    ///   - target: Either level or velocity zoom target.
    func control(mode: CameraZoomControlMode, target: Double)
}
