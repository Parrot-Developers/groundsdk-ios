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
import GroundSdk

/// TargetTracker controller class
class TargetTrackerController: DeviceComponentController {

    /// TargetTracker component
    private var targetTracker: TargetTrackerCore!

    /// Framing / Position of the desired target in frame. Value requested from the interface
    /// - horizontal: Horizontal position in the video (relative position, from left (0.0) to right (1.0) )
    /// - vertical: vertical position in the video (relative position, from bottom (0.0) to top (1.0) )
    private var requestedFraming = (horizontal: 0.5, vertical: 0.5)

    /// Framing / Position of the desired target in frame. Vlaue received from drone
    /// - horizontal: Horizontal position in the video (relative position, from left (0.0) to right (1.0) )
    /// - vertical: vertical position in the video (relative position, from bottom (0.0) to top (1.0) )
    private var receivedFraming = (horizontal: 0.5, vertical: 0.5) {
        didSet {
            if connected {
                targetTracker.update(framing: receivedFraming).notifyUpdated()
            }
        }
    }

    /// Latest targetIsController value received from the drone
    ///
    /// The SystemPosition will be used with the `forceUpdating()` option
    /// (in order to force continuous location updates)
    private var receivedTargetIsController = false {
        didSet {
            if connected {
                useControllerLocation = receivedTargetIsController
                targetTracker.update(targetIsController: receivedTargetIsController).notifyUpdated()
            }
        }
    }

    /// true if the used of controller is requested from the interface, false otherwise
    private var requestedTargetIsController = false {
        didSet {
            if connected {
                sendTargetIsController()
            }
        }
    }

    /// Uses or not the controller Location. Forces location updates accordingly.
    private var useControllerLocation = false {
        didSet {
            if oldValue != useControllerLocation {
                if useControllerLocation {
                    systemPosition?.forceUpdating()
                } else {
                    systemPosition?.stopForceUpdating()
                }
            }
        }
    }

    /// System Position utility (used to force the used of location services)
    private lazy var systemPosition: SystemPositionCore? = {
        return deviceController.engine.utilities.getUtility(Utilities.systemPosition)
    }()

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        targetTracker = TargetTrackerCore(store: deviceController.device.peripheralStore, backend: self)
        // set default setting
        targetTracker.update(framing: requestedFraming)
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureFollowMeUid {
            ArsdkFeatureFollowMe.decode(command, callback: self)
        }
    }

    /// Drone is connected
    override func didConnect() {
        targetTracker.publish()
        // send the targetIsController if it is not the same as requested from the interface
        sendTargetIsController()
        // send the framing if is not the same as requested from the interface
        sendFramingCommand()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        // stop using location
        useControllerLocation = false
        targetTracker.update(targetTrajectory: nil).cancelSettingsRollback().notifyUpdated()
    }

    /// Device is about to be forgotten
    override func willForget() {
        targetTracker.unpublish()
        super.willForget()
    }

    /// Sends the TargetIsController choice to the drone if the value requested from the interface is not the current
    /// value on the drone
    private func sendTargetIsController() {
        if requestedTargetIsController != receivedTargetIsController {
            self.sendCommand(ArsdkFeatureFollowMe.setTargetIsControllerEncoder(
                targetIsController: requestedTargetIsController ? 1 : 0))
        }
    }

    /// Sends Command to set the desired target framing in the video, only if the value requested from the interface
    /// is not the current value on the drone
    private func sendFramingCommand () {
        guard receivedFraming != requestedFraming else {
            return
        }
        let horizontalInt = Int(round(100.0 * requestedFraming.horizontal))
        let verticalInt = Int(round(100.0 * requestedFraming.vertical))
        sendCommand(ArsdkFeatureFollowMe.targetFramingPositionEncoder(horizontal: horizontalInt, vertical: verticalInt))
    }
}

// MARK: - Backend
/// TargetTracker backend implementation.
extension TargetTrackerController: TargetTrackerBackend {

    func set(targetIsController: Bool) {
        requestedTargetIsController = targetIsController
    }

    func set(framing: (horizontal: Double, vertical: Double)) -> Bool {
        requestedFraming = framing
        if connected {
            // Change the framing (updating). It will be validated when the drone will change the framing
            sendFramingCommand()
            return true
        } else {
            targetTracker.update(framing: framing).notifyUpdated()
            return false
        }
    }

    func set(targetDetectionInfo: TargetDetectionInfo) {
        sendCommand(ArsdkFeatureFollowMe.targetImageDetectionEncoder(
            targetAzimuth: Float(targetDetectionInfo.targetAzimuth),
            targetElevation: Float(targetDetectionInfo.targetElevation),
            changeOfScale: Float(targetDetectionInfo.changeOfScale),
            confidenceIndex: UInt((targetDetectionInfo.confidence * 255).rounded()),
            isNewSelection: targetDetectionInfo.isNewTarget ? 1 : 0,
            timestamp: targetDetectionInfo.timestamp))
    }
}

// MARK: - Callbacks
/// TargetTracker - FollowMe Feature decode callback implementation
extension TargetTrackerController: ArsdkFeatureFollowMeCallback {

    func onTargetFramingPositionChanged(horizontal: Int, vertical: Int) {
        let horizontalPercentDouble = Double(horizontal) / 100.0
        let verticalPercentDouble = Double(vertical) / 100.0
        self.receivedFraming = (horizontalPercentDouble, verticalPercentDouble)
    }

    func onTargetIsController(state: UInt) {
        self.receivedTargetIsController = (state == 1)
    }

    func onTargetTrajectory(
        latitude: Double, longitude: Double, altitude: Float, northSpeed: Float, eastSpeed: Float, downSpeed: Float) {

        let targetTrajectory = TargetTrajectoryCore(
            latitude: latitude, longitude: longitude, altitude: Double(altitude), northSpeed: Double(northSpeed),
            eastSpeed: Double(eastSpeed), downSpeed: Double(downSpeed))

        targetTracker.update(targetTrajectory: targetTrajectory).notifyUpdated()
    }
}
