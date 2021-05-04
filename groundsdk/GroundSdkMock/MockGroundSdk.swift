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
@testable import GroundSdk

@objcMembers
public class MockGroundSdk: NSObject {

    let gsdkCore = MockGroundSdkCore()
    let store = ComponentStoreCore()

    public var drones = [String: DroneCore]()
    public var remoteControls = [String: RemoteControlCore]()
    public var delegates = [String: DeviceDelegate]()

    public var engine: MockEngine {
        return gsdkCore.mockEngine!
    }

    override public init() {
        super.init()
        // auto start the engine
        engine.start()
    }

    deinit {
        engine.stop()
        gsdkCore.close()
    }

    public func addDrone(uid: String, model: Drone.Model, name: String) {
        let delegate = DeviceDelegate(mockGsdk: self, uid: uid, isDrone: true)
        let droneCore = DroneCore(uid: uid, model: model, name: name, delegate: delegate)
        drones[uid] = droneCore
        delegates[uid] = delegate
        gsdkCore.mockEngine!.add(drone: droneCore)
    }

    public func removeDrone(uid: String) {
        gsdkCore.mockEngine!.remove(drone: drones[uid]!)
    }

    public func getDrone(uid: String) -> DroneCore? {
        return drones[uid]
    }

    public func setDroneConnectors(uid: String, connectors: [DeviceConnectorCore]) {
        drones[uid]!.stateHolder.state.update(connectors: connectors)
    }

    public func updateDrone(uid: String, name: String) {
        drones[uid]!.nameHolder.update(name: name)
    }

    public func updateDrone(uid: String, connectionState: DeviceState.ConnectionState,
                            cause: DeviceState.ConnectionStateCause, persisted: Bool, visible: Bool) {
        drones[uid]!.stateHolder.state!.update(connectionState: connectionState, withCause: cause)
            .update(persisted: persisted).notifyUpdated()
    }

    public func addRemoteControl(uid: String, model: RemoteControl.Model, name: String) {
        let delegate = DeviceDelegate(mockGsdk: self, uid: uid, isDrone: false)
        let remoteControlCore = RemoteControlCore(uid: uid, model: model, name: name, delegate: delegate)
        remoteControls[uid] = remoteControlCore
        delegates[uid] = delegate
        gsdkCore.mockEngine!.add(remoteControl: remoteControlCore)
    }

    public func removeRemoteControl(uid: String) {
        gsdkCore.mockEngine!.remove(remoteControl: remoteControls[uid]!)
    }

    public func getRemoteControl(uid: String) -> RemoteControlCore? {
        return remoteControls[uid]
    }

    public func updateRemoteControl(uid: String, name: String) {
        remoteControls[uid]!.nameHolder.update(name: name)
    }

    public func setRemoteControlConnectors(uid: String, connectors: [DeviceConnectorCore]) {
        remoteControls[uid]!.stateHolder.state.update(connectors: connectors)
    }

    public func updateRemoteControl(uid: String, connectionState: DeviceState.ConnectionState,
                                    cause: DeviceState.ConnectionStateCause, persisted: Bool, visible: Bool) {
        remoteControls[uid]!.stateHolder.state!.update(connectionState: connectionState, withCause: cause)
            .update(persisted: persisted).notifyUpdated()
    }

    public func addFacility(uid: Int) {
        switch uid {
        case Facilities.autoConnection.uid,
             Facilities.crashReporter.uid,
             Facilities.userLocation.uid,
             Facilities.flightDataManager.uid,
             Facilities.flightLogReporter.uid:
            // no need since it is already published by the engine controller
            break
        default:
            print("Adding facility interface \(uid) is not implemented in MockGroundSdk")
        }
    }

    public func addInstrument(uid: Int, droneUid: String) {
        let drone = drones[droneUid]!
        switch uid {
        case Instruments.alarms.uid:
            let alarms = AlarmsCore(store: drone.instrumentStore,
                                    supportedAlarms: [Alarm.Kind.power, Alarm.Kind.motorCutOut])
            alarms.publish()
        case Instruments.flyingIndicators.uid:
            let flyingIndicators = FlyingIndicatorsCore(store: drone.instrumentStore)
            flyingIndicators.publish()
        case Instruments.altimeter.uid:
            let altimeter = AltimeterCore(store: drone.instrumentStore)
            altimeter.publish()
        case Instruments.attitudeIndicator.uid:
            let attitudeIndicator = AttitudeIndicatorCore(store: drone.instrumentStore)
            attitudeIndicator.publish()
        case Instruments.compass.uid:
            let compass = CompassCore(store: drone.instrumentStore)
            compass.publish()
        case Instruments.flyingIndicators.uid:
            let flyingIndicators = FlyingIndicatorsCore(store: drone.instrumentStore)
            flyingIndicators.publish()
        case Instruments.gps.uid:
            let gps = GpsCore(store: drone.instrumentStore)
            gps.publish()
        case Instruments.speedometer.uid:
            let speedometer = SpeedometerCore(store: drone.instrumentStore)
            speedometer.publish()
        case Instruments.radio.uid:
            let radio = RadioCore(store: drone.instrumentStore)
            radio.publish()
        case Instruments.batteryInfo.uid:
            let batteryInfo = BatteryInfoCore(store: drone.instrumentStore)
            batteryInfo.publish()
        case Instruments.flightMeter.uid:
            let flightMeter = FlightMeterCore(store: drone.instrumentStore)
            flightMeter.publish()
        case Instruments.cameraExposureValues.uid:
            let cameraExposureValues = CameraExposureValuesCore(store: drone.instrumentStore)
            cameraExposureValues.publish()
        default:
            print("Adding instrument \(uid) is not implemented in MockGourndSdk")
        }
    }

    public func addPilotingItf(uid: Int, droneUid: String) {
        let drone = drones[droneUid]!
        switch uid {
        case PilotingItfs.manualCopter.uid:
            let manualCopterPilotingItf = ManualCopterPilotingItfCore(
                store: drone.pilotingItfStore, backend: manualCopterPilotingItfMockBackend)
            manualCopterPilotingItf.publish()
        case PilotingItfs.returnHome.uid:
            let returnHomePilotingItf = ReturnHomePilotingItfCore(
                store: drone.pilotingItfStore, backend: returnHomePilotingItfMockBackend)
            returnHomePilotingItf.publish()
        case PilotingItfs.flightPlan.uid:
            let flightPlanPilotingItf = FlightPlanPilotingItfCore(
                store: drone.pilotingItfStore, backend: flightPlanPilotingItfMockBackend)
            flightPlanPilotingItf.publish()
        case PilotingItfs.animation.uid:
            let animationPilotingItf = AnimationPilotingItfCore(
                store: drone.pilotingItfStore, backend: animationPilotingItfMockBackend)
            animationPilotingItf.publish()
        case PilotingItfs.guided.uid:
            let guidedPilotingItf = GuidedPilotingItfCore(
                store: drone.pilotingItfStore, backend: guidedPilotingItfMockBackend)
            guidedPilotingItf.publish()
        case PilotingItfs.pointOfInterest.uid:
            let poiPilotingItf = PoiPilotingItfCore(
                store: drone.pilotingItfStore, backend: poiPilotingItfMockBackend)
            poiPilotingItf.publish()
        default:
            print("Adding piloting interface \(uid) is not implemented in MockGroundSdk")
        }
    }

    public func addPeripheral(uid: Int, droneUid: String) {
        let drone = drones[droneUid]!
        switch uid {
        case Peripherals.magnetometer.uid:
            let magnetometer = MagnetometerCore(store: drone.peripheralStore, backend: magnetometerMockBackend)
            magnetometer.publish()
        case Peripherals.magnetometerWith3StepCalibration.uid:
            let magnetometer = MagnetometerWith3StepCalibrationCore(
                store: drone.peripheralStore, backend: magnetometerMockBackend)
            magnetometer.publish()
        case Peripherals.magnetometerWith1StepCalibration.uid:
            let magnetometer = MagnetometerWith1StepCalibrationCore(
                store: drone.peripheralStore, backend: magnetometerMockBackend)
            magnetometer.publish()
        case Peripherals.droneFinder.uid:
            let droneFinder = DroneFinderCore(store: drone.peripheralStore, backend: droneFinderMockBackend)
            droneFinder.publish()
        case Peripherals.systemInfo.uid:
            let systemInfo = SystemInfoCore(
                store: drone.peripheralStore, backend: copterSystemInfoMockBackend)
            systemInfo.publish()
        case Peripherals.updater.uid:
            let firmwareUpdater = UpdaterCore(
                store: drone.peripheralStore, backend: firmwareUpdaterMockBackend)
            firmwareUpdater.publish()
        case Peripherals.mediaStore.uid:
            let mediaStore = MediaStoreCore(
                store: drone.peripheralStore,
                thumbnailCache: MediaStoreThumbnailCacheCore(mediaStoreBackend: mediaStoreMockBackend, size: 0),
                backend: mediaStoreMockBackend)
            mediaStore.publish()
        case Peripherals.mainCamera.uid:
            let camera = MainCameraCore(store: drone.peripheralStore, backend: cameraMockBackend)
            camera.update(supportedModes: [.recording]).update(mode: .recording)
            camera.update(supportedExposureModes: [.automatic]).update(supportedManualShutterSpeeds: [.one])
                .update(supportedManualIsoSensitivity: [.iso100]).update(supportedMaximumIsoSensitivity: [.iso3200])
                .update(exposureMode: .automatic).update(manualShutterSpeed: .one).update(manualIsoSensitivity: .iso100)
                .update(maximumIsoSensitivity: .iso3200).update(autoExposureMeteringMode: .standard)
            camera.update(supportedExposureCompensationValues: [.ev0_00]).update(exposureCompensationValue: .ev0_00)
            camera.update(supportedWhiteBalanceModes: [.automatic])
                .update(supportedCustomWhiteBalanceTemperatures: [.k1500])
                .update(whiteBalanceMode: .automatic).update(customWhiteBalanceTemperature: .k1500)

            camera.update(supportedStyles: [.standard])
            camera.update(activeStyle: .standard)
            camera.update(contrast: (4, 2, 4))
            camera.update(sharpness: (6, 3, 6))
            camera.update(recordingCapabilities: [CameraCore.RecordingCapabilitiesEntry(
                modes: [.standard], resolutions: [.resUhd4k], framerates: [.fps30], hdrAvailable: true)])
                .update(supportedRecordingHyperlapseValues: [.ratio30])
                .update(recordingMode: .standard).update(recordingResolution: .resUhd4k)
                .update(recordingFramerate: .fps30).update(recordingHyperlapseValue: .ratio30)
            camera.update(photoCapabilities: [CameraCore.PhotoCapabilitiesEntry(
                modes: [.single], formats: [.fullFrame], fileFormats: [.dng], hdrAvailable: true)])
                .update(supportedPhotoBurstValues: [.burst4Over1s])
                .update(supportedPhotoBracketingValues: [.preset1ev2ev])
                .update(photoMode: .single).update(photoFormat: .fullFrame).update(photoFileFormat: .dng)
                .update(photoBurstValue: .burst4Over1s).update(photoBracketingValue: .preset1ev2ev)
            camera.publish()
        case Peripherals.antiflicker.uid:
            let antiflicker = AntiflickerCore(store: drone.peripheralStore, backend: antiflickerMockBackend)
            antiflicker.publish()
        case Peripherals.geofence.uid:
            let geofence = GeofenceCore(store: drone.peripheralStore, backend: geofenceMockBackend)
            geofence.publish()
        case Peripherals.gimbal.uid:
            let gimbal = GimbalCore(store: drone.peripheralStore, backend: gimbalMockBackend)
            gimbal.publish()
        case Peripherals.streamServer.uid:
            let streamServer = StreamServerCore(
                store: drone.peripheralStore, backend: streamServerMockBackend)
            streamServer.publish()
        case Peripherals.wifiScanner.uid:
            let wifiScanner = WifiScannerCore(
                store: drone.peripheralStore, backend: wifiScannerMockBackend)
            wifiScanner.publish()
        case Peripherals.wifiAccessPoint.uid:
            let wifiAccessPoint = WifiAccessPointCore(
                store: drone.peripheralStore, backend: wifiAccessPointMockBackend)
            wifiAccessPoint.publish()
        case Peripherals.beeper.uid:
            let beeper = BeeperCore(
                store: drone.peripheralStore, backend: beeperMockBackend)
            beeper.publish()
        case Peripherals.leds.uid:
            let leds = LedsCore(
                store: drone.peripheralStore, backend: ledsMockBackend)
            leds.publish()
        case Peripherals.targetTracker.uid:
            let targetTracker = TargetTrackerCore(
                store: drone.peripheralStore, backend: targetTrackerMockBackend)
            targetTracker.publish()
        case Peripherals.flightDataDownloader.uid:
            let flightDataDownloader = FlightDataDownloaderCore(store: drone.peripheralStore)
            flightDataDownloader.publish()
        case Peripherals.flightLogDownloader.uid:
            let flightLogDownloader = FlightLogDownloaderCore(store: drone.peripheralStore)
            flightLogDownloader.publish()
        case Peripherals.crashReportDownloader.uid:
            let crashReportDownloader = CrashReportDownloaderCore(store: drone.peripheralStore)
            crashReportDownloader.publish()
        case Peripherals.removableUserStorage.uid:
            let removableUserStorage = RemovableUserStorageCore(store: drone.peripheralStore,
                                                                backend: removableUserStorageBackend)
            removableUserStorage.update(name: "storage1", capacity: 10)
            removableUserStorage.update(availableSpace: 5)
            removableUserStorage.update(canFormat: true)
            removableUserStorage.publish()
        case Peripherals.preciseHome.uid:
            let preciseHome = PreciseHomeCore(store: drone.peripheralStore, backend: preciseHomeMockBackend)
            preciseHome.publish()
        case Peripherals.pilotingControl.uid:
            let pilotingControl = PilotingControlCore(store: drone.peripheralStore, backend: pilotingControlMockBackend)
            pilotingControl.publish()
        case Peripherals.thermalControl.uid:
            let thermalControl = ThermalControlCore(store: drone.peripheralStore, backend: thermalControlMockBackend)
            thermalControl.publish()
        case Peripherals.copilot.uid:
            let copilot = CopilotCore(store: drone.peripheralStore, backend: copilotMockBackend)
            copilot.publish()
        case Peripherals.dri.uid:
            let dri = DriCore(
                store: drone.peripheralStore, backend: driMockBackend)
            dri.publish()
        default:
            print("Adding peripheral interface \(uid) is not implemented in MockGroundSdk")
        }
    }

    public func addPeripheral(uid: Int, rcUid: String) {
        let rc = remoteControls[rcUid]!
        switch uid {
        case Peripherals.skyCtrl3Gamepad.uid:
            let skyCtrl3Gamepad = SkyCtrl3GamepadCore(
                store: rc.peripheralStore,
                backend: skyCtrl3GamepadMockBackend)
            // mock the supported drone models
            skyCtrl3Gamepad.updateSupportedDroneModels([.anafi4k, .anafiThermal, .anafiUa, .anafiUsa])
            skyCtrl3Gamepad.publish()
        default:
            print("Adding peripheral interface \(uid) is not implemented in MockGroundSdk")
        }
    }

    class AutoConnectionMockBackend: AutoConnectionBackend {
        func startAutoConnection() -> Bool { return false }
        func stopAutoConnection() -> Bool { return false }
    }
    let autoConnectionBackend = AutoConnectionMockBackend()

    class ManualCopterPilotingItfMockBackend: ManualCopterPilotingItfBackend {
        func set(roll: Int) {}
        func set(pitch: Int) {}
        func set(yawRotationSpeed: Int) {}
        func set(verticalSpeed: Int) {}
        func hover() {}
        func activate() -> Bool { return false }
        func deactivate() -> Bool { return false }
        func takeOff() {}
        func land() {}
        func thrownTakeOff() {}
        func emergencyCutOut() {}
        func set(maxPitchRoll value: Double) -> Bool { return false }
        func set(maxPitchRollVelocity value: Double) -> Bool { return false }
        func set(maxVerticalSpeed value: Double) -> Bool { return false }
        func set(maxYawRotationSpeed value: Double) -> Bool { return false }
        func set(bankedTurnMode value: Bool) -> Bool { return false }
        func set(useThrownTakeOffForSmartTakeOff: Bool) -> Bool { return false }
    }
    let manualCopterPilotingItfMockBackend = ManualCopterPilotingItfMockBackend()

    class ReturnHomePilotingItfMockBackend: ReturnHomePilotingItfBackend {
        func activate() -> Bool { return false }
        func deactivate() -> Bool { return false }
        func cancelAutoTrigger() { }
        func set(preferredTarget: ReturnHomeTarget) -> Bool { return false }
        func set(minAltitude: Double) -> Bool { return false }
        func set(autoStartOnDisconnectDelay: Int) -> Bool { return false }
        func set(endingBehavior: ReturnHomeEndingBehavior) -> Bool { return false }
        func set(autoTriggerMode: Bool) -> Bool { return false }
        func set(endingHoveringAltitude: Double) -> Bool { return false }
        func setCustomLocation(latitude: Double, longitude: Double, altitude: Double) { }
    }
    let returnHomePilotingItfMockBackend = ReturnHomePilotingItfMockBackend()

    class GuidedPilotingItfMockBackend: GuidedPilotingItfBackend {
        func moveWithGuidedDirective(guidedDirective: GuidedDirective) {}

        func activate() -> Bool { return false }
        func deactivate() -> Bool { return false }

    }
    let guidedPilotingItfMockBackend = GuidedPilotingItfMockBackend()

    class PoiPilotingItfMockBackend: PoiPilotingItfBackend {
        func start(latitude: Double, longitude: Double, altitude: Double, mode: PointOfInterestMode) {}
        func set(roll: Int) {}
        func set(pitch: Int) {}
        func set(verticalSpeed: Int) {}
        func activate() -> Bool { return false }
        func deactivate() -> Bool { return false }
    }
    let poiPilotingItfMockBackend = PoiPilotingItfMockBackend()

    class FlightPlanPilotingItfMockBackend: FlightPlanPilotingItfBackend {
        func activate(restart: Bool) -> Bool { return false }
        func deactivate() -> Bool { return false }
        func uploadFlightPlan(filepath: String) { }
    }
    let flightPlanPilotingItfMockBackend = FlightPlanPilotingItfMockBackend()

    class AnimationPilotingItfMockBackend: AnimationPilotingItfBackend {
        func startAnimation(config: AnimationConfig) -> Bool { return false }
        func abortCurrentAnimation() -> Bool { return false }
    }
    let animationPilotingItfMockBackend = AnimationPilotingItfMockBackend()

    class MagnetometerMockBackend: MagnetometerBackend {
        func startCalibrationProcess() {}
        func cancelCalibrationProcess() {}
    }
    let magnetometerMockBackend = MagnetometerMockBackend()

    class DroneFinderMockBackend: DroneFinderBackend {
        func discoverDrones() {}
        func connectDrone(uid: String, password: String) -> Bool {return false}
    }
    let droneFinderMockBackend = DroneFinderMockBackend()

    class CopterSystemInfoMockBackend: SystemInfoBackend {
        func resetSettings() -> Bool { return false }
        func factoryReset() -> Bool { return false }
    }
    let copterSystemInfoMockBackend = CopterSystemInfoMockBackend()

    class FirmwareUpdaterMockBackend: UpdaterBackend {
        func download(firmwares: [FirmwareInfoCore], observer: @escaping (FirmwareDownloaderCoreTask) -> Void) {}
        func update(withFirmwares: [FirmwareInfoCore]) {}
        func cancelUpdate() {}
    }
    let firmwareUpdaterMockBackend = FirmwareUpdaterMockBackend()

    class MediaStoreMockBackend: MediaStoreBackend {

        func startWatchingContentChanges() { }

        func stopWatchingContentChanges() { }

        func browse(completion: @escaping (_ medias: [MediaItemCore]) -> Void) -> CancelableCore? {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            completion([MediaItemCore(
                uid: "1", name: "media1", type: .photo, runUid: "r1",
                creationDate: dateFormatter.date(from: "2016-01-02")!, expectedCount: nil, photoMode: .single,
                panoramaType: nil,
                resources: [MediaItemResourceCore(uid: "1-1", format: .mp4, size: 20, duration: 15.2,
                                                  streamUrl: "res1Url", location: nil, creationDate: Date()),
                            MediaItemResourceCore(uid: "1-2", format: .dng, size: 100, streamUrl: nil, location: nil,
                                                  creationDate: Date())],
                backendData: "A")])
            return nil
        }
        func downloadThumbnail(
            for owner: MediaStoreThumbnailCacheCore.ThumbnailOwner,
            completion: @escaping (Data?) -> Void) -> CancelableCore? {
            return nil
        }

        public func download(mediaResources: MediaResourceListCore, destination: DownloadDestination,
                             progress: @escaping (MediaDownloader) -> Void) -> CancelableTaskCore? {
            progress(MediaDownloader(totalMedia: 1, countMedia: 0, totalResources: 1, countResources: 0,
                                     currentFileProgress: 0, progress: 0, status: .running))
            return nil
        }

        func delete(medias: [MediaItemCore], progress: @escaping (MediaDeleter) -> Void) -> CancelableTaskCore? {
            progress(MediaDeleter(totalCount: 2, currentCount: 1, status: .running))
            return nil
        }

        func delete(mediaResources: MediaResourceListCore, progress: @escaping (MediaDeleter) -> Void)
            -> CancelableTaskCore? {
                progress(MediaDeleter(totalCount: 2, currentCount: 1, status: .running))
                return nil
        }

        func deleteAll(progress: @escaping (AllMediasDeleter) -> Void) -> CancelableTaskCore? {
            return nil
        }
    }
    let mediaStoreMockBackend = MediaStoreMockBackend()

    class SkyCtrl3GamepadMockBackend: SkyCtrl3GamepadBackend {

        func set(volatileMapping: Bool) -> Bool { return false }

        func grab(buttons: Set<SkyCtrl3Button>, axes: Set<SkyCtrl3Axis>) { }

        public func setup(mappingEntry: SkyCtrl3MappingEntry, register: Bool) { }

        public func resetMapping(forModel model: Drone.Model?) { }

        public func set(
            interpolator: AxisInterpolator, forDroneModel droneModel: Drone.Model, onAxis axis: SkyCtrl3Axis) { }

        public func set(axis: SkyCtrl3Axis, forDroneModel droneModel: Drone.Model, reversed: Bool) { }

    }
    let skyCtrl3GamepadMockBackend = SkyCtrl3GamepadMockBackend()

    class StreamServerMockBackend: StreamServerBackend {

        func openStream(url: String, track: String, listener: SdkCoreStreamListener) -> SdkCoreStream? {
            return SdkCoreStream()
        }
    }

    let streamServerMockBackend = StreamServerMockBackend()

    class CameraMockBackend: CameraBackend {
        func startPhotoCapture() -> Bool {
            return false
        }

        func stopPhotoCapture() -> Bool {
            return false
        }

        func set(mode: CameraMode) -> Bool {
            return false
        }

        func set(exposureMode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed,
                 manualIsoSensitivity: CameraIso, maximumIsoSensitivity: CameraIso,
                 autoExposureMeteringMode: CameraAutoExposureMeteringMode) -> Bool {
            return false
        }

        func set(exposureLockMode: CameraExposureLockMode) -> Bool {
            return false
        }

        func set(exposureCompensation: CameraEvCompensation) -> Bool {
            return false
        }

        func set(whiteBalanceMode: CameraWhiteBalanceMode, customTemperature: CameraWhiteBalanceTemperature) -> Bool {
            return false
        }

        func set(whiteBalanceLock: Bool) -> Bool {
            return false
        }

        func set(activeStyle: CameraStyle) -> Bool {
            return false
        }

        func set(styleParameters: (saturation: Int, contrast: Int, sharpness: Int)) -> Bool {
            return false
        }

        func set(recordingMode: CameraRecordingMode, resolution: CameraRecordingResolution?,
                 framerate: CameraRecordingFramerate?, hyperlapse: CameraHyperlapseValue?) -> Bool {
            return false
        }

        func set(autoRecord: Bool) -> Bool {
            return false
        }

        func set(photoMode: CameraPhotoMode, format: CameraPhotoFormat?, fileFormat: CameraPhotoFileFormat?,
                 burst: CameraBurstValue?, bracketing: CameraBracketingValue?, gpslapseCaptureInterval: Double?,
                 timelapseCaptureInterval: Double?) -> Bool {
            return false
        }

        func set(hdr: Bool) -> Bool {
            return false
        }

        func takePhoto() -> Bool {
            return false
        }

        func startRecording() -> Bool {
            return false
        }

        func stopRecording() -> Bool {
            return false
        }

        func set(maxZoomSpeed: Double) -> Bool {
            return false
        }

        func set(qualityDegradationAllowance: Bool) -> Bool {
            return false
        }

        func control(mode: CameraZoomControlMode, target: Double) { }

        func set(yawOffset: Double, pitchOffset: Double, rollOffset: Double) -> Bool {
            return false
        }

        func resetAlignment() -> Bool {
            return false
        }
    }
    let cameraMockBackend = CameraMockBackend()

    class AntiflickerMockBackend: AntiflickerBackend {
        func set(mode: AntiflickerMode) -> Bool {
            return false
        }
    }
    let antiflickerMockBackend = AntiflickerMockBackend()

    class PreciseHomeMockBackend: PreciseHomeBackend {
        func set(mode: PreciseHomeMode) -> Bool {
            return false
        }
    }
    let preciseHomeMockBackend = PreciseHomeMockBackend()

    class PilotingControlMockBackend: PilotingControlBackend {
        func set(behaviour: PilotingBehaviour) -> Bool {
            return false
        }
    }
    let pilotingControlMockBackend = PilotingControlMockBackend()

    class ThermalControlMockBackend: ThermalControlBackend {
        func set(range: ThermalSensitivityRange) -> Bool {
            return false
        }

        func set(backgroundTemperature: Double) {
        }

        func set(emissivity: Double) {
        }

        func set(mode: ThermalControlMode) -> Bool {
            return false
        }

        func set(calibrationMode: ThermalCalibrationMode) -> Bool {
            return false
        }

        func calibrate() -> Bool {
            return false
        }

        func set(palette: ThermalPalette) {
        }

        func set(rendering: ThermalRendering) {
        }
    }
    let thermalControlMockBackend = ThermalControlMockBackend()

    class CopilotMockBackend: CopilotBackend {
        func set(source: CopilotSource) -> Bool {
            return false
        }
    }

    let copilotMockBackend = CopilotMockBackend()

    class GeofenceMockBackend: GeofenceBackend {
        func set(mode: GeofenceMode) -> Bool {
            return false
        }

        func set(maxAltitude value: Double) -> Bool {
            return false
        }

        func set(maxDistance value: Double) -> Bool {
            return false
        }
    }

    let geofenceMockBackend = GeofenceMockBackend()

    class GimbalMockBackend: GimbalBackend {

        func set(stabilization: Bool, onAxis axis: GimbalAxis) -> Bool {
            return false
        }

        func set(maxSpeed: Double, onAxis axis: GimbalAxis) -> Bool {
            return false
        }

        func set(offsetCorrection: Double, onAxis axis: GimbalAxis) -> Bool {
            return false
        }

        func control(mode: GimbalControlMode, yaw: Double?, pitch: Double?, roll: Double?) { }

        func startOffsetsCorrectionProcess() { }

        func stopOffsetsCorrectionProcess() { }

        func startCalibration() { }

        func cancelCalibration() { }
    }
    let gimbalMockBackend = GimbalMockBackend()

    class WifiScannerMockBackend: WifiScannerBackend {
        func startScan() { }

        func stopScan() { }
    }
    let wifiScannerMockBackend = WifiScannerMockBackend()

    class WifiAccessPointMockBackend: WifiAccessPointBackend {
        func set(environment: Environment) -> Bool { return false }

        func set(country: String) -> Bool { return false }

        func set(ssid: String) -> Bool { return false }

        func set(security: SecurityMode, password: String?) -> Bool { return false }

        func select(channel: WifiChannel) -> Bool { return false }

        func autoSelectChannel(onBand band: Band?) -> Bool { return false }
    }
    let wifiAccessPointMockBackend = WifiAccessPointMockBackend()

    let beeperMockBackend = BeeperMockBackend()
    class BeeperMockBackend: BeeperBackend {
        func startAlertSound() -> Bool { return true }
        func stopAlertSound() -> Bool { return true }
    }

    let ledsMockBackend = LedsMockBackend()
    class LedsMockBackend: LedsBackend {
        func set(state: Bool) -> Bool { return true }
    }

    let batteryGaugeUpdaterMockBackend = BatteryGaugeUpdaterMockBackend()
    class BatteryGaugeUpdaterMockBackend: BatteryGaugeUpdaterBackend {
        func prepareUpdate() {}
        func update() {}
    }

    let targetTrackerMockBackend = TargetTrackerMockBackend()
    class TargetTrackerMockBackend: TargetTrackerBackend {
        func set(targetIsController: Bool) {}
        func set(targetDetectionInfo: TargetDetectionInfo) {}
        func set(framing: (horizontal: Double, vertical: Double)) -> Bool { return false }
    }

    let removableUserStorageBackend = RemovableUserStorageMockBackend()
    class RemovableUserStorageMockBackend: RemovableUserStorageCoreBackend {
        func formatWithEncryption(password: String, formattingType: FormattingType,
                                  newMediaName: String?) -> Bool { return true }

        func sendPassword(password: String, usage: PasswordUsage) -> Bool { return true }

        func format(formattingType: FormattingType, newMediaName: String?) -> Bool { return true }
    }

    let driMockBackend = DriMockBackend()
    class DriMockBackend: DriBackend {
        func set(mode: Bool) -> Bool {  return true }

        func set(type: DriTypeConfig?) { }
    }
}

public class DeviceDelegate: DeviceCoreDelegate {

    let mockGsdk: MockGroundSdk?
    let uid: String?
    let isDrone: Bool?

    var forgetCnt = 0
    var connectCnt = 0
    var connectConnectorUid: String?
    var disconnectCnt = 0

    init(mockGsdk: MockGroundSdk? = nil, uid: String? = nil, isDrone: Bool? = nil) {
        self.mockGsdk = mockGsdk
        self.uid = uid
        self.isDrone = isDrone
    }

    public func forget() -> Bool {
        forgetCnt += 1
        return true
    }

    public func connect(connector: DeviceConnector, password: String?) -> Bool {
        // mimic the fact that the device goes directly (synchronously) to connection state `connecting`
        if let mockGsdk = mockGsdk, let uid = uid, let isDrone = isDrone {
            let state: DeviceStateCore
            if isDrone {
                state = mockGsdk.getDrone(uid: uid)!.stateHolder.state
            } else {
                state = mockGsdk.getRemoteControl(uid: uid)!.stateHolder.state
            }
            state.update(connectionState: .connecting).update(activeConnector: (connector as! DeviceConnectorCore))
                .notifyUpdated()
        }
        connectCnt += 1
        connectConnectorUid = connector.uid
        return true
    }

    public func disconnect() -> Bool {
        // mimic the fact that the device goes directly (synchronously) to connection state `disconnecting`
        if let mockGsdk = mockGsdk, let uid = uid, let isDrone = isDrone {
            let state: DeviceStateCore
            if isDrone {
                state = mockGsdk.getDrone(uid: uid)!.stateHolder.state
            } else {
                state = mockGsdk.getRemoteControl(uid: uid)!.stateHolder.state
            }
            state.update(connectionState: .disconnecting).notifyUpdated()
        }
        disconnectCnt += 1
        return true
    }
}

protocol TestInstrument: Instrument {
}

class TestInstruments: NSObject, InstrumentClassDesc {
    typealias ApiProtocol = TestInstrument
    let uid = 999
    let parent: ComponentDescriptor? = nil
}

let testInstruments = TestInstruments()

class TestInstrumentCore: ComponentCore, TestInstrument {
    init() {
        super.init(desc: TestInstruments(), store: ComponentStoreCore())
    }
}

public protocol TestPilotingItf: PilotingItf {
}

public class TestPilotingItfs: NSObject, PilotingItfClassDesc {
    public typealias ApiProtocol = TestPilotingItf
    public let uid = 999
    public let parent: ComponentDescriptor? = nil
}

let testPilotingItfs = TestPilotingItfs()

class TestPilotingItfCore: ComponentCore, TestPilotingItf {
    let state = ActivablePilotingItfState.idle
    init() {
        super.init(desc: TestPilotingItfs(), store: ComponentStoreCore())
    }

    func activate() -> Bool { return true }
    func deactivate() -> Bool { return false }
}

public protocol TestPeripheral: Peripheral {
}

public class TestPeripherals: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = TestPeripheral
    public let uid = 999
    public let parent: ComponentDescriptor? = nil
}

let testPeripherals = TestPeripherals()

class TestPeripheralCore: ComponentCore, TestPeripheral {
    init() {
        super.init(desc: TestPeripherals(), store: ComponentStoreCore())
    }
}

extension MockGroundSdk: ManualCopterPilotingItfBackend, ReturnHomePilotingItfBackend,
GuidedPilotingItfBackend {

    public func moveWithGuidedDirective(guidedDirective: GuidedDirective) {}
    public func set(roll: Int) { }
    public func set(pitch: Int) { }
    public func set(yawRotationSpeed: Int) { }
    public func set(verticalSpeed: Int) { }
    public func set(throttle: Int) { }
    public func hover() {}
    public func activate() -> Bool { return false }
    public func deactivate() -> Bool { return false }
    public func takeOff() { }
    public func land() { }
    public func thrownTakeOff() {}
    public func cancelLanding() { }
    public func arm() { }
    public func cancelArming() { }
    public func emergencyCutOut() { }
    public func loiter() { }
    public func set(minAltitude value: Double) -> Bool { return false }
    public func set(maxPitchRoll value: Double) -> Bool { return false }
    public func set(maxPitchRollVelocity value: Double) -> Bool { return false }
    public func set(maxVerticalSpeed value: Double) -> Bool { return false }
    public func set(maxYawRotationSpeed value: Double) -> Bool { return false }
    public func set(bankedTurnMode value: Bool) -> Bool { return false }
    public func set(preferredTarget: ReturnHomeTarget) -> Bool { return false }
    public func set(autoStartOnDisconnectDelay: Int) -> Bool { return false }
    public func set(useThrownTakeOffForSmartTakeOff: Bool) -> Bool { return false }
    public func cancelAutoTrigger() { }
    public func set(endingBehavior: ReturnHomeEndingBehavior) -> Bool { return false }
    public func set(autoTriggerMode: Bool) -> Bool { return false }
    public func set(endingHoveringAltitude: Double) -> Bool { return false }
    public func setCustomLocation(latitude: Double, longitude: Double, altitude: Double) { }
}
