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

/// Instrument that informs about photo progress indicator.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.photoProgressIndicator)
/// ```
public protocol PhotoProgressIndicator: Instrument {

    /// Remaining time before the next photo is taken, in seconds.
    ///
    /// This value is only available when the current `CameraPhotoMode` is `.timeLapse` and CameraPhotoFunctionState is
    /// `.started`.
    /// It may also be unsupported depending on the drone model and/or firmware version.
    /// `nil` if not available.
    var remainingTime: Double? { get }

    /// Remaining distance before the next photo is taken, in meters.
    ///
    /// This value is only available when the current `CameraPhotoMode` is `.gpsLapse` and `CameraPhotoFunctionState` is
    /// `.started`.
    /// It may also be unsupported depending on the drone model and/or firmware version.
    /// `nil` if not available.
    var remainingDistance: Double? { get }
}

/// Instrument that informs about photo progress indicator.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.photoProgressIndicator)
/// ```
/// - Note: This protocol is for Objective-C only. Swift must use the protocol `PhotoProgressIndicator`.
@objc
public protocol GSPhotoProgressIndicator: Instrument {
    /// Retrieves the remaining time before the next photo is taken, in seconds.
    ///
    /// This value is only available when the current `CameraPhotoMode` is `.timeLapse` and `CameraPhotoFunctionState`
    /// is `.started`.
    /// It may also be unsupported depending on the drone model and/or firmware version.
    /// `nil` if not available.
    func getRemainingTime() -> NSNumber?

    /// Retrieves the remaining distance before the next photo is taken, in seconds.
    ///
    /// This value is only available when the current `CameraPhotoMode` is `.gpsLapse` and `CameraPhotoFunctionState`
    /// is `.started`.
    /// It may also be unsupported depending on the drone model and/or firmware version.
    /// `nil` if not available.
    func getRemainingDistance() -> NSNumber?
}

/// :nodoc:
/// Instrument descriptor
@objc(GSPhotoProgressIndicatorDesc)
public class PhotoProgressIndicatorDesc: NSObject, InstrumentClassDesc {
    public typealias ApiProtocol = PhotoProgressIndicator
    public let uid = InstrumentUid.photoProgressIndicator.rawValue
    public let parent: ComponentDescriptor? = nil
}
