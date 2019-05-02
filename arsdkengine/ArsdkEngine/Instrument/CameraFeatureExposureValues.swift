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

/// Camera exposure values component controller for Camera feature based drones
///
/// The component will be published as soon as the device is connected if exposure values have been received during the
/// connection process. If it is not the case, it will be published as soon as the first exposure values are received
/// after the connection process.
///
/// The component is unpublished when the device is not connected.
class CameraFeatureExposureValues: DeviceComponentController {

    /// Camera exposure values component
    private var exposureValues: CameraExposureValuesCore!

    /// Whether values have been received at least once during this connection session.
    ///
    /// This is kept because the event used is non-ack so we are not sure that the event will be received before the end
    /// of the connection process.
    private var hasReceivedValues = false

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        self.exposureValues = CameraExposureValuesCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        if hasReceivedValues {
            exposureValues.publish()
        }
    }

    /// Drone is disconnected
    override func didDisconnect() {
        exposureValues.unpublish()
        hasReceivedValues = false
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCameraUid {
            ArsdkFeatureCamera.decode(command, callback: self)
        }
    }
}

/// Common common state decode callback implementation
extension CameraFeatureExposureValues: ArsdkFeatureCameraCallback {
    func onExposure(
        camId: UInt, shutterSpeed: ArsdkFeatureCameraShutterSpeed, isoSensitivity: ArsdkFeatureCameraIsoSensitivity,
        lock: ArsdkFeatureCameraState, lockRoiX: Float, lockRoiY: Float, lockRoiWidth: Float, lockRoiHeight: Float) {

        guard let gsdkShutterSpeed = CameraShutterSpeed(fromArsdk: shutterSpeed),
            let gsdkIsoSensitivity = CameraIso(fromArsdk: isoSensitivity) else {
            return
        }

        exposureValues.update(shutterSpeed: gsdkShutterSpeed).update(isoSensitivity: gsdkIsoSensitivity).notifyUpdated()
        if !hasReceivedValues {
            hasReceivedValues = true
            // if it is the first time that we receive the values and we are connected, publish the component.
            // (if we are not connected, the publish will be done in the didConnect callback)
            if connected {
                exposureValues.publish()
            }
        }
    }
}
