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

/// Class to store the target detection results.
@objcMembers
@objc(GSTargetDetectionInfo)
public class TargetDetectionInfo: NSObject {

    /// Horizontal north-drone-target angle in radian.
    public let targetAzimuth: Double

    /// Vertical angle horizon-drone-target in radian.
    public let targetElevation: Double

    /// Normalized relative radial speed in 1/second.
    public let changeOfScale: Double

    /// Confidence of the detection (from 0 to 1, the highest is the best).
    public let confidence: Double

    /// `true` if the target box is new, `false` otherwise.
    public let isNewTarget: Bool

    /// Acquisition time of processed picture in milliseconds.
    public let timestamp: UInt64

    /// Constructor for the target detection results.
    ///
    /// - Parameters:
    ///   - targetAzimuth: Horizontal north-drone-target angle in radian
    ///   - targetElevation: Vertical angle horizon-drone-target in radian
    ///   - changeOfScale: Normalized relative radial speed in 1/second
    ///   - confidenceIndex: Confidence index of the detection (from 0 to 255, the highest is the best)
    ///   - isNewTarget: `true` if the target is new, `false` otherwise
    ///   - timestamp: Acquisition time in millisecond
    public init(
        targetAzimuth: Double, targetElevation: Double, changeOfScale: Double, confidence: Double, isNewTarget: Bool,
        timestamp: UInt64) {

        self.targetAzimuth = targetAzimuth
        self.targetElevation = targetElevation
        self.changeOfScale = changeOfScale
        self.confidence = confidence
        self.isNewTarget = isNewTarget
        self.timestamp = timestamp
        super.init()
    }

    /// Debug description.
    override public var description: String {
        return "TargetDetectionInfo: targetAzimuth = \(targetAzimuth), targetElevation = \(targetElevation)" +
        ", changeOfScale = \(changeOfScale), confidence = \(confidence), isNewTarget = \(isNewTarget)" +
        "timeStamp = \(timestamp)"
    }
}

/// Target framing setting.
///
/// Allows to configure positioning of the tracked target in the drone video stream.
public protocol TargetFramingSetting: class {
    /// Whether the setting is currently updating.
    var updating: Bool { get }

    /// Position of the desired target in frame.
    /// - horizontal: horizontal position in the video (relative position, from left (0.0) to right (1.0) )
    /// - vertical: vertical position in the video (relative position, from bottom (0.0) to top (1.0) )
    var value: (horizontal: Double, vertical: Double) { get set }
}

/// Information on the analyzed trajectory of the target.
@objc (GSTargetTrajectory)
public protocol TargetTrajectory {
    /// Target latitude (in degrees).
    var latitude: Double { get }

    /// Target longitude (in degrees).
    var longitude: Double { get }

    /// Target altitude (in meters, relative to sea level).
    var altitude: Double { get }

    /// Target north speed (in m/s).
    var northSpeed: Double { get }

    /// Target east speed (in m/s).
    var eastSpeed: Double { get }

    /// Target down speed (in m/s).
    var downSpeed: Double { get }

    /// Description.
    var description: String { get }
}

/// The targetTracker is the peripheral used by features such as Look-At or Follow-Me. It allows to
/// activate/ deactivate the different detection modes of the target:
///  - control whether user device/controller barometer and location are actively monitored and
/// sent to the connected drone, in order to allow the latter to track the user and/or controller,
/// - forward external target detection information to the drone, in order to allow the latter to track a given target
/// - configure the tracked target desired position (framing) in the video stream.
///
/// Look-At and Follow-Me interfaces will be will be activatable according to the target's detection quality level.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.targetTracker)
/// ```
public protocol TargetTracker: Peripheral {
    /// Position of the desired target framing in the video.
    var framing: TargetFramingSetting { get }

    /// Whether the controller is used as target.
    ///
    /// see `enableControllerTracking()` and `disableControllerTracking()`
    var targetIsController: Bool { get }

    /// Information on the analyzed trajectory of the target, may be nil.
    var targetTrajectory: TargetTrajectory? { get }

    /// Forwards the result of the target analysis.
    ///
    /// - Parameter info: TargetDetectionInfo object
    func sendTargetDetectionInfo(_ info: TargetDetectionInfo)

    /// Enables tracking of the controller (user device or remote-control) as the current target.
    ///
    /// Calling this method enables forwarding of controller barometer and location information to the connected drone,
    /// so that it may track the user (or controller).
    ///
    /// This method should be called prior to activating the piloting interface that tracks the user such as
    /// `LookAtPilotingItf` or `FollowPilotingItf`.
    ///
    /// - Note: This function will force the use of Device Location Services. In order not to use these services
    /// uselessly, it is strongly recommended to stop the tracking when target detection is no longer necessary
    /// (see `disableControllerTracking`).
    func enableControllerTracking()

    /// Disables tracking of the controller (user device or remote-control) as the current target.
    ///
    /// Calling this method disables forwarding of controller barometer and location information to the connected drone
    /// (see `enableControllerTracking`).
    ///
    /// This method should be called once controller barometer and location info are not required to pilot the drone
    /// (eg when interfaces like LookAt or Follow are no longer used), because monitoring the barometer and device
    /// location increases battery consumption.
    func disableControllerTracking()
}

// MARK: - objc compatibility

/// Objective-C version of the Target framing setting.
///
/// Allows to configure positioning of the tracked target in the drone video stream.
@objc
public protocol GSTargetFramingSetting {
    /// Whether the setting is currently updating.
    var updating: Bool { get }

    /// Horizontal position in the video (relative position, from left (0.0) to right (1.0)).
    var horizontalPosition: Double { get }

    /// Vertical position in the video (relative position, from bottom (0.0) to top (1.0)).
    var verticalPosition: Double { get }

    /// Sets the position of the desired target in frame.
    ///
    /// - Parameters:
    /// - horizontal: Horizontal position in the video (relative position, from left (0.0) to right (1.0))
    /// - vertical: Vertical position in the video (relative position, from bottom (0.0) to top (1.0))
    func setValue(horizontal: Double, vertical: Double)
}

/// Objective-C version of TargetTracker.
///
/// The targetTracker is the peripheral used by features such as Look-At or Follow-Me. It allows to
/// activate/ deactivate the different detection modes of the target:
///  - control whether user device/controller barometer and location are actively monitored and
/// sent to the connected drone, in order to allow the latter to track the user and/or controller,
/// - forward external target detection information to the drone, in order to allow the latter to track a given target
/// - configure the tracked target desired position (framing) in the video stream.
///
/// Look-At and Follow-Me interfaces will be will be activatable according to the target's detection quality level.
///
/// - Note: This class is for Objective-C only and must not be used in Swift.
@objc
public protocol GSTargetTracker: Peripheral {
    /// Position of the desired target framing in the video.
    @objc(framing)
    var gsFraming: GSTargetFramingSetting { get }

    /// Whether the controller is used as target.
    ///
    /// see `enableControllerTracking()` and `disableControllerTracking()`
    var targetIsController: Bool { get }

    /// Information on the analyzed trajectory of the target, may be nil
    var targetTrajectory: TargetTrajectory? { get }

    /// Forwards the result of the target analysis.
    ///
    /// - Parameter info: ImageDetectionInfo object
    func sendTargetDetectionInfo(_ info: TargetDetectionInfo)

    /// Enables tracking of the controller (user device or remote-control) as the current target.
    ///
    /// Calling this method enables forwarding of controller barometer and location information to the connected drone,
    /// so that it may track the user (or controller).
    ///
    /// This method should be called prior to activating the piloting interface that tracks the user such as
    /// `LookAtPilotingItf` or `FollowPilotingItf`.
    ///
    /// - Note: This function will force the use of Device Location Services. In order not to use these services
    /// uselessly, it is strongly recommended to stop the tracking when target detection is no longer necessary
    /// (see `disableControllerTracking`).
    func enableControllerTracking()

    /// Disables tracking of the controller (user device or remote-control) as the current target.
    ///
    /// Calling this method disables forwarding of controller barometer and location information to the connected drone
    /// (see `enableControllerTracking`).
    ///
    /// This method should be called once controller barometer and location info are not required to pilot the drone
    /// (eg when interfaces like LookAt or Follow are no longer used), because monitoring the barometer and device
    /// location increases battery consumption.
    func disableControllerTracking()
}

/// :nodoc:
/// TargetTracker description
@objc(GSTargetTrackerDesc)
public class TargetTrackerDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = TargetTracker
    public let uid = PeripheralUid.targetTracker.rawValue
    public let parent: ComponentDescriptor? = nil
}
