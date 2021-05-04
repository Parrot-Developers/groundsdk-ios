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

/// Anafi 4k specific drone controller
class AnafiFamilyDroneController: DroneController {

    /// Shared last known state of the tracking function at the drone level
    private let trackingSharing = FollowFeatureTrackingSharing()

    /// Constructor
    ///
    /// - Parameters:
    ///    - engine: arsdk engine instance
    ///    - deviceUid: device uid
    ///    - name: drone name
    ///    - model: drone model
    init(engine: ArsdkEngine, deviceUid: String, name: String, model: Drone.Model) {
        super.init(engine: engine, deviceUid: deviceUid, model: model, name: name,
                   pcmdEncoder: PilotingCommand.Encoder.AnafiCopter(),
                   ephemerisConfig: EphemerisConfig(fileType: .ublox, uploader: HttpEphemerisUploader()),
                   defaultPilotingItfFactory: { activationController in
                    return AnafiCopterManualPilotingItf(activationController: activationController)
        })
        // add all component controllers
        // Activable Piloting Itfs
        componentControllers.append(pilotingItfActivationController.defaultPilotingItf)
        componentControllers.append(AnafiReturnHomePilotingItf(
            activationController: pilotingItfActivationController))
        componentControllers.append(HttpFlightPlanPilotingItfController(
            activationController: pilotingItfActivationController))
        componentControllers.append(AnafiGuidedPilotingItf(
            activationController: pilotingItfActivationController))
        componentControllers.append(AnafiPoiPilotingItf(
            activationController: pilotingItfActivationController))

        componentControllers.append(FollowFeatureLookAtPilotingItf(
            activationController: pilotingItfActivationController, trackingSharing: trackingSharing))
        componentControllers.append(FollowFeatureFollowMePilotingItf(
            activationController: pilotingItfActivationController, trackingSharing: trackingSharing))
        // Not activable piloting Itfs
        componentControllers.append(AnimFeaturePilotingItfController(droneController: self))
        // Instruments
        componentControllers.append(AnafiFlyingIndicators(deviceController: self))
        componentControllers.append(AnafiAlarms(deviceController: self))
        componentControllers.append(AnafiGps(deviceController: self))
        componentControllers.append(AnafiCompass(deviceController: self))
        componentControllers.append(AnafiAltimeter(deviceController: self))
        componentControllers.append(AnafiSpeedometer(deviceController: self))
        componentControllers.append(AnafiAttitudeIndicator(deviceController: self))
        componentControllers.append(CommonRadio(deviceController: self))
        componentControllers.append(CommonBatteryInfo(deviceController: self))
        componentControllers.append(AnafiFlightMeter(deviceController: self))
        componentControllers.append(CameraFeatureExposureValues(deviceController: self))
        // Peripherals
        componentControllers.append(AnafiMagnetometer(deviceController: self))
        componentControllers.append(StreamServerController(deviceController: self))
        componentControllers.append(CameraFeatureCameraRouter(deviceController: self))
        componentControllers.append(CameraFeatureAntiflicker(deviceController: self))
        componentControllers.append(HttpMediaStore(deviceController: self))
        componentControllers.append(AnafiSystemInfo(deviceController: self))
        if let firmwareStore = engine.utilities.getUtility(Utilities.firmwareStore),
            let firmwareDownloader = engine.utilities.getUtility(Utilities.firmwareDownloader) {
            componentControllers.append(
                UpdaterController(deviceController: self,
                                     config: UpdaterController.Config(deviceModel: deviceModel, uploaderType: .http),
                                     firmwareStore: firmwareStore, firmwareDownloader: firmwareDownloader))
        }
        componentControllers.append(AnafiCopterMotors(deviceController: self))
        if let crashReportStorage = engine.utilities.getUtility(Utilities.crashReportStorage) {
            componentControllers.append(
                HttpCrashmlDownloader(deviceController: self, crashReportStorage: crashReportStorage))
        }
        if let flightDataStorage = engine.utilities.getUtility(Utilities.flightDataStorage) {
            componentControllers.append(
                HttpFlightDataDownloader(deviceController: self, flightDataStorage: flightDataStorage))
        }
        if let flightLogStorage = engine.utilities.getUtility(Utilities.flightLogStorage) {
            componentControllers.append(
                HttpFlightLogDownloader(deviceController: self, flightLogStorage: flightLogStorage,
                                        converter: GutmaLogProducer.create(deviceController: self)))
        }
        componentControllers.append(WifiFeatureWifiAccessPoint(deviceController: self))
        componentControllers.append(UserStorageRemovableUserStorage(deviceController: self))
        componentControllers.append(AnafiBeeper(deviceController: self))
        componentControllers.append(GimbalFeatureGimbal(deviceController: self))
        componentControllers.append(TargetTrackerController(deviceController: self))
        componentControllers.append(AnafiGeofence(deviceController: self))
        componentControllers.append(PreciseHomeController(deviceController: self))
        componentControllers.append(ThermalController(deviceController: self))
        componentControllers.append(LedsController(deviceController: self))
        componentControllers.append(PhotoProgressIndicatorController(deviceController: self))
        componentControllers.append(AnafiPilotingControl(deviceController: self))
        componentControllers.append(BatteryGaugeUpdaterController(deviceController: self))
        componentControllers.append(DriController(deviceController: self))
        componentControllers.append(LogControlController(deviceController: self))
        componentControllers.append(CertificateUploaderController(deviceController: self))
        if GroundSdkConfig.sharedInstance.enableDevToolbox {
            componentControllers.append(AnafiDevToolbox(deviceController: self))
        }
        sendDateAndTime = { [weak self] in
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = NSTimeZone.system
            dateFormatter.locale = NSLocale.system
            let currentDate = Date()

            // send date/time
            dateFormatter.dateFormat = "yyyyMMdd'T'HHmmssZZZ"
            let currentDateStr = dateFormatter.string(from: currentDate)
            self?.sendCommand(ArsdkFeatureCommonCommon.currentDateTimeEncoder(datetime: currentDateStr))
        }
    }

    override func protocolDidConnect() {
        (ephemerisConfig?.uploader as? HttpEphemerisUploader)?.droneServer = droneServer
        super.protocolDidConnect()
    }

    override func protocolDidReceiveCommand(_ command: OpaquePointer) {
        super.protocolDidReceiveCommand(command)
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        }
    }
}

extension AnafiFamilyDroneController: ArsdkFeatureArdrone3PilotingstateCallback {
    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        self.isLanded = (state == .landed || state == .emergency)
    }
}
