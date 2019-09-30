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
import CoreLocation

/// Device controller for a drone.
class DroneController: DeviceController {

    /// Piloting activation controller
    var pilotingItfActivationController: PilotingItfActivationController!

    /// Whether or not the piloting command is running
    var pcmdRunning = false

    /// Get the drone managed by this controller
    var drone: DroneCore {
        return device as! DroneCore
    }

    /// Ephemeris config
    var ephemerisConfig: EphemerisConfig?

    /// Ephemeris utility
    private var ephemerisUtility: EphemerisUtilityCore?

    /// Whether the drone is landed or not
    ///
    /// Should be set by subclasses
    var isLanded = false {
        didSet {
            guard isLanded != oldValue else {
                return
            }
            dataSyncAllowanceMightHaveChanged()
            if isLanded {
                // remove any "suspend" request for the user Location
                // (do nothing if the current value is false)
                userLocationUnwanted = false
            } else {
                // the drone is not landed
                // check if the connection with the phone is wifi
                // Note: the first level (phone's App) is the first provider without parent
                // (meaning: provider!.connector.connectorType is `.local` and not a `.remoteControl`)
                var provider = activeProvider
                while let parent = provider?.parent {
                    provider = parent
                }
                if provider?.connector.technology == .wifi {
                    // the phone's GPS service disturbs the wifi connection.
                    // Ask (if possible) to suspend the GPS continuous update
                    userLocationUnwanted = true
                }
            }
        }
    }

    /// Utility for device's location services.
    private var systemPositionUtility: SystemPositionCore?
    /// Monitor the userLocation (with systemPositionUtility)
    private var userLocationMonitor: MonitorCore?

    /// Indicates whether or not the connected drone stops updating the GPS position of the user.
    /// Indeed, the phone's GPS service disturbs the wifi connection.
    /// The conditions to suspend are:
    /// - that the drone or the remote is directly connected via wifi
    /// - and the drone is flying.
    ///
    /// Using a USB remote control avoids the suspend request
    /// - Note: a 'requestSuspendUpdating()' does not guarantee a stop of the location updating. Indeed, the location
    /// updating can be forced by other requests
    private var userLocationUnwanted = false {
        didSet {
            guard userLocationUnwanted != oldValue else {
                return
            }
            if let systemPositionCore = engine.utilities.getUtility(Utilities.systemPosition) {
                if userLocationUnwanted {
                    systemPositionCore.requestSuspendUpdating()
                } else {
                    systemPositionCore.unrequestSuspendUpdating()
                }
            }
        }
    }

    override var dataSyncAllowed: Bool {
        return super.dataSyncAllowed && isLanded
    }

    /// Constructor
    ///
    /// - Parameters:
    ///     - engine: arsdk engine instance
    ///     - deviceUid: device uid
    ///     - model: drone model
    ///     - name: drone name
    ///     - pcmdEncoder: Piloting command encoder. The `pcmdEncoder.pilotingCommandPeriod` will fix the period of
    ///       the NoAckCommandLoop
    ///     - ephemerisConfig: ephemeris config or nil if not supported by drone
    ///         default value is nil
    ///     - defaultPilotingItfFactory: Closure that will create the default piloting interface.
    init(engine: ArsdkEngine, deviceUid: String, model: Drone.Model, name: String,
         pcmdEncoder: PilotingCommandEncoder,
         ephemerisConfig: EphemerisConfig? = nil,
         defaultPilotingItfFactory: ((PilotingItfActivationController) -> ActivablePilotingItfController)) {

        self.ephemerisConfig = ephemerisConfig
        super.init(engine: engine, deviceUid: deviceUid,
                   deviceModel: .drone(model),
                   noAckLoopPeriod: pcmdEncoder.pilotingCommandPeriod) {  delegate in
                    return DroneCore(uid: deviceUid, model: model, name: name, delegate: delegate)
        }

        pilotingItfActivationController = PilotingItfActivationController(
            droneController: self, pilotingCommandEncoder: pcmdEncoder,
            defaultPilotingItfFactory: defaultPilotingItfFactory)

        getAllSettingsEncoder = ArsdkFeatureCommonSettings.allSettingsEncoder()
        getAllStatesEncoder = ArsdkFeatureCommonCommon.allStatesEncoder()

        ephemerisUtility = engine.utilities.getUtility(Utilities.ephemeris)
    }

    /// Called back when the current piloting command sent to the drone changes.
    ///
    /// - Parameter pilotingCommand: up-to-date piloting command
    func pilotingCommandDidChange(_ pilotingCommand: PilotingCommand) {
        if let blackBoxSession = blackBoxSession as? BlackBoxDroneSession {
            blackBoxSession.pilotingCommandDidChange(pilotingCommand)
        }
    }

    /// Create a video stream instance from a url.
    ///
    /// - Parameters:
    ///    - url: stream url
    ///    - track: stream track
    ///    - listener: the listener that should be called for stream events
    /// - Returns: a new instance of a stream or null if an error happened
    func createVideoStream(url: String, track: String, listener: SdkCoreStreamListener) -> ArsdkStream? {
        if let backend = backend {
            return backend.createVideoStream(url: url, track: track, listener: listener)
        } else {
            ULog.w(.ctrlTag, "createVideoStream called without backend")
        }
        return nil
    }

    /// Device controller did start
    override func controllerDidStart() {
        super.controllerDidStart()
        // publish drone
        // Can force unwrap drone store utility because we know it is always available after the engine's start
        engine.utilities.getUtility(Utilities.droneStore)!.add(drone)
    }

    /// Device controller did stop
    override func controllerDidStop() {
        // unpublish drone
        // Can force unwrap drone store utility because we know it is always available after the engine's start
        engine.utilities.getUtility(Utilities.droneStore)!.remove(drone)
    }

    override func protocolWillConnect() {
        super.protocolWillConnect()

        if let blackBoxRecorder = engine.blackBoxRecoder {
            var providerUid: String?
            if  activeProvider?.connector.connectorType == .remoteControl {
                providerUid = activeProvider?.connector.uid
            }
            blackBoxSession = blackBoxRecorder.openDroneSession(drone: drone, providerUid: providerUid)
        }
    }

    override func protocolDidConnect() {
        pilotingItfActivationController.didConnect()
        super.protocolDidConnect()

        /// Utility for device's location services.
        systemPositionUtility = engine.utilities.getUtility(Utilities.systemPosition)
        if let systemPositionUtility = systemPositionUtility {
            userLocationMonitor = systemPositionUtility.startLocationMonitoring(
                passive: false, userLocationDidChange: { [unowned self] newLocation in
                    if let newLocation = newLocation {
                        // Check that the location is not too old (15 sec max)
                        if abs(newLocation.timestamp.timeIntervalSinceNow) <= 15 {
                            // this position is valid and can be sent to the drone
                            self.locationDidChange(newLocation)
                        } else {
                             ULog.d(.ctrlTag,
                                    "reject old timestamp Location \(abs(newLocation.timestamp.timeIntervalSinceNow))")
                        }
                    }
                }, stoppedDidChange: {_ in }, authorizedDidChange: {_ in })
        }
        uploadEphemerisIfAllowed()
    }

    override func protocolDidDisconnect() {
        // stop monitoring location
        userLocationMonitor?.stop()
        userLocationMonitor = nil

        pilotingItfActivationController.didDisconnect()
        // remove any "suspend" request for the user Location
        // (do nothing if the current value is false)
        userLocationUnwanted = false
        super.protocolDidDisconnect()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func protocolDidReceiveCommand(_ command: OpaquePointer) {

        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonSettingsstateUid {
            ArsdkFeatureCommonSettingsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonCommonstateUid {
            ArsdkFeatureCommonCommonstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonNetworkeventUid {
            ArsdkFeatureCommonNetworkevent.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlCommoneventstateUid {
            ArsdkFeatureSkyctrlCommoneventstate.decode(command, callback: self)
        }

        super.protocolDidReceiveCommand(command)
    }

    override func firmwareDidUpload() {
        sendCommand(ArsdkFeatureCommonCommon.rebootEncoder())
    }

    private func uploadEphemerisIfAllowed() {
        if let ephemerisConfig = ephemerisConfig,
            let ephemerisUrl = ephemerisUtility?.getLatestEphemeris(forType: ephemerisConfig.fileType),
            dataSyncAllowed {
            ephemerisConfig.uploader.upload(ephemeris: ephemerisUrl)
        }
    }

    /// Processes system geographic location changes and sends them to the drone.
    private func locationDidChange(_ newLocation: CLLocation) {
        // converts speed and cource in north / east values
        var northSpeed = 0.0
        var eastSpeed = 0.0
        // CLLocation doc: A negative value indicates an invalid speed or an invalid course
        if newLocation.speed > 0 && newLocation.course > 0 {
            let courseRad = newLocation.course.toRadians()
            northSpeed = cos(courseRad) * newLocation.speed
            eastSpeed = sin(courseRad) * newLocation.speed
        }
        // send command :
        //        - Parameter latitude: Latitude of the controller (in deg)
        //        - Parameter longitude: Longitude of the controller (in deg)
        //        - Parameter altitude: Altitude of the controller (in meters, according to sea level)
        //        - Parameter horizontal_accuracy: Horizontal accuracy (in meter)
        //        - Parameter vertical_accuracy: Vertical accuracy (in meter)
        //        - Parameter north_speed: North speed (in meter per second)
        //        - Parameter east_speed: East speed (in meter per second)
        //        - Parameter down_speed: Vertical speed (in meter per second) (down is positive)
        //          -> force 0 for downSpeed
        //        - Parameter timestamp: Timestamp of the gps info
        sendCommand(ArsdkFeatureControllerInfo.gpsEncoder(
            latitude: newLocation.coordinate.latitude, longitude: newLocation.coordinate.longitude,
            altitude: Float(newLocation.altitude), horizontalAccuracy: Float( newLocation.horizontalAccuracy),
            verticalAccuracy: Float(newLocation.verticalAccuracy), northSpeed: Float(northSpeed),
            eastSpeed: Float(eastSpeed), downSpeed: 0, timestamp: newLocation.timestamp.timeIntervalSince1970))
    }
}

/// Common settings events dispatcher, used to receive onAllSettingsChanged
extension DroneController: ArsdkFeatureCommonSettingsstateCallback {
    func onAllSettingsChanged() {
        if connectionSession.state == .gettingAllSettings {
            transitToNextConnectionState()
        }
    }

    func onProductNameChanged(name: String!) {
        device.nameHolder.update(name: name)
        deviceStore.write(key: PersistentStore.deviceName, value: name).commit()
    }

    func onProductVersionChanged(software: String!, hardware: String!) {
        if let firmwareVersion = FirmwareVersion.parse(versionStr: software) {
            device.firmwareVersionHolder.update(version: firmwareVersion)
            deviceStore.write(key: PersistentStore.deviceFirmwareVersion, value: software).commit()
        }
    }
}

/// Common state events dispatcher, used to receive onAllStatesChanged
extension DroneController: ArsdkFeatureCommonCommonstateCallback {
    func onAllStatesChanged() {
        if connectionSession.state == .gettingAllStates {
            transitToNextConnectionState()
        }
    }
}

/// Network event dispatcher, used to receive onDisconnection
extension DroneController: ArsdkFeatureCommonNetworkeventCallback {
    func onDisconnection(cause: ArsdkFeatureCommonNetworkeventDisconnectionCause) {
        if cause == ArsdkFeatureCommonNetworkeventDisconnectionCause.offButton {
            autoReconnect = false
            _ = doDisconnect(cause: .userRequest)
        }
    }
}

/// Skyctrl Common event state dispatcher, used to receive onShutdown
extension DroneController: ArsdkFeatureSkyctrlCommoneventstateCallback {
    func onShutdown(reason: ArsdkFeatureSkyctrlCommoneventstateShutdownReason) {
        if reason == ArsdkFeatureSkyctrlCommoneventstateShutdownReason.poweroffButton {
            autoReconnect = false
            _ = doDisconnect(cause: .userRequest)
        }
    }
}
