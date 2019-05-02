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

/// Camera exposure lock mode.
public enum CameraExposureLockMode: Equatable, CustomStringConvertible {
    /// No exposure lock.
    case none
    /// Lock current exposure values.
    case currentValues
    /// Lock exposure on a given region of interest (taken from the video stream).
    /// - centerX: center X position of the region in the video (relative position, from left (0.0) to right (1.0))
    /// - centerY: center Y position of the region in the video (relative position, from bottom (0.0) to top (1.0))
    /// - width: width of the region (relative to the video stream width, from 0.0 to 1.0)
    /// - height: height of the region (relative to the video stream height, from 0.0 to 1.0)
    case region(centerX: Double, centerY: Double, width: Double, height: Double)

    /// Debug description.
    public var description: String {
        switch self {
        case .none:                                         return "none"
        case .currentValues:                                return "currentValues"
        case let .region(centerX, centerY, width, height):
            return "\(String(format: "region %.2f, %.2f, %.2f, %.2f", centerX, centerY, width, height))"
        }
    }

    public static func == (lhs: CameraExposureLockMode, rhs: CameraExposureLockMode) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none),
             (.currentValues, .currentValues):
            return true
        case let (.region(lx, ly, lw, lh), .region(rx, ry, rw, rh)):
            return lx == rx && ly == ry && lw == rw && lh == rh
        default:
            return false
        }
    }
}

/// Camera exposure lock.
///
///  Allows to lock/unlock the exposure according to a given mode.
public protocol CameraExposureLock: class {
    /// Tells if the mode has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Current lock mode.
    var mode: CameraExposureLockMode { get }

    /// Locks exposure on current exposure values.
    func lockOnCurrentValues()

    /// Locks exposure on a given region of interest defined by its center (taken from the video stream).
    ///
    /// - Parameters:
    ///   - centerX: Horizontal position in the video (relative position, from left (0.0) to right (1.0))
    ///   - centerY: vertical position in the video (relative position, from bottom (0.0) to top (1.0))
    func lockOnRegion(centerX: Double, centerY: Double)

    /// Unlocks exposure.
    func unlock()
}

// MARK: - objc compatibility

/// Camera exposure lock mode.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public enum GSCameraExposureLockMode: Int, CustomStringConvertible {
    /// No exposure lock.
    case none
    /// Lock current exposure values.
    case currentValues
    /// Lock exposure on a given region of interest (taken from the video stream).
    case region

    /// Debug description.
    public var description: String {
        switch self {
        case .none:             return "none"
        case .currentValues:    return "currentValues"
        case .region:           return "region"
        }
    }
}

/// Camera exposure lock.
///
///  Allows to lock/unlock the exposure according to a given mode.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCameraExposureLock {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Current lock mode.
    @objc(mode)
    var gsMode: GSCameraExposureLockMode { get }

    /// Horizontal position of the region center in the video (relative position, from left (0.0) to right (1.0)).
    /// Only accurate when mode is `.region`.
    var regionCenterX: Double { get }

    /// Vertical position of the region center in the video (relative position, from bottom (0.0) to top (1.0)).
    /// Only accurate when mode is `.region`.
    var regionCenterY: Double { get }

    /// Width of the region (relative to the video stream width, from 0.0 to 1.0).
    /// Only accurate when mode is `.region`.
    var regionWidth: Double { get }

    /// Height of the region (relative to the video stream height, from 0.0 to 1.0).
    /// Only accurate when mode is `.region`.
    var regionHeight: Double { get }

    /// Locks exposure on current exposure values.
    func lockOnCurrentValues()

    /// Locks exposure on a given region of interest defined by its center (taken from the video stream).
    ///
    /// - Parameters:
    ///   - horizontal: Horizontal position in the video (relative position, from left (0.0) to right (1.0))
    ///   - vertical: vertical position in the video (relative position, from bottom (0.0) to top (1.0))
    func lockOnRegion(centerX: Double, centerY: Double)

    /// Unlocks exposure.
    func unlock()
}
