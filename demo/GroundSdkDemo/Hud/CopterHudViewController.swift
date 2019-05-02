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

import UIKit
import GroundSdk
import GameController
import CoreLocation

class CopterHudViewController: UIViewController, DeviceViewController {

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var drone: Drone?

    private let dimInstrumentAlpha: CGFloat = 0.4

    // formatter for the distance
    private lazy var distanceFormatter: MeasurementFormatter = {
        let distanceFormatter = MeasurementFormatter()
        distanceFormatter.unitOptions = .naturalScale
        distanceFormatter.numberFormatter.maximumFractionDigits = 1
        return distanceFormatter
    }()

    // formatter for the speed
    private lazy var speedFormatter: MeasurementFormatter = {
        let speedFormatter = MeasurementFormatter()
        speedFormatter.unitOptions = .naturalScale
        speedFormatter.unitStyle = .short
        speedFormatter.numberFormatter.maximumFractionDigits = 1
        return speedFormatter
    }()

    private var flyingIndicators: Ref<FlyingIndicators>?
    private var alarms: Ref<Alarms>?
    private var pilotingItf: Ref<ManualCopterPilotingItf>?
    private var pointOfInterestItf: Ref<PointOfInterestPilotingItf>?
    private var returnHomePilotingItf: Ref<ReturnHomePilotingItf>?
    private var followMePilotingItf: Ref<FollowMePilotingItf>?
    private var lookAtPilotingItf: Ref<LookAtPilotingItf>?
    private var gps: Ref<Gps>?
    private var altimeter: Ref<Altimeter>?
    private var compass: Ref<Compass>?
    private var speedometer: Ref<Speedometer>?
    private var batteryInfo: Ref<BatteryInfo>?
    private var attitudeIndicator: Ref<AttitudeIndicator>?
    private var camera: Ref<MainCamera>?
    private var streamServer: Ref<StreamServer>?
    private var cameraLive: Ref<CameraLive>?

    private var refLocation: Ref<UserLocation>?

    private var lastDroneLocation: CLLocation?
    private var lastUserLocation: CLLocation?

    @IBOutlet weak var flyingIndicatorsLabel: UILabel!
    @IBOutlet weak var alarmsLabel: UILabel!
    @IBOutlet weak var emergencyButton: UIButton!
    @IBOutlet weak var takoffLandButton: UIButton!
    @IBOutlet weak var stopPoiButton: UIButton!
    @IBOutlet weak var returnHomeButton: UIButton!
    @IBOutlet weak var joysticksView: UIView!
    @IBOutlet weak var gpsImageView: UIImageView!
    @IBOutlet weak var gpsLabel: UILabel!
    @IBOutlet weak var altimeterView: AltimeterView!
    @IBOutlet weak var verticalSpeedView: VerticalSlider!
    @IBOutlet weak var compassView: CompassView!
    @IBOutlet weak var attitudeIndicatorView: AttitudeIndicatorView!
    @IBOutlet weak var speedometerView: UIView!
    @IBOutlet weak var speedometerLabel: UILabel!
    @IBOutlet weak var droneDistanceLabel: UILabel!
    @IBOutlet weak var droneDistanceView: UIView!
    @IBOutlet weak var droneBatteryLabel: UILabel!
    @IBOutlet weak var droneBatteryView: UIView!
    @IBOutlet weak var zoomVelocitySlider: UISlider!
    @IBOutlet weak var streamView: StreamView!

    let gpsFixedImage = UIImage(named: "ic_gps_fixed.png")
    let gpsNotFixedImage = UIImage(named: "ic_gps_not_fixed.png")

    let takeOffButtonImage = UIImage(named: "ic_flight_takeoff_48pt")
    let landButtonImage = UIImage(named: "ic_flight_land_48pt")
    let handButtonImage = UIImage(named: "ic_flight_hand_48pt")

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        returnHomeButton.setImage(returnHomeButton.image(for: UIControl.State())?.withRenderingMode(.alwaysTemplate),
            for: .highlighted)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetAllInstrumentsViews()
        // get the drone
        if let droneUid = droneUid {
            drone = groundSdk.getDrone(uid: droneUid) { [unowned self] _ in
                self.dismiss(self)
            }
        }
        if let drone = drone {
            initDroneRefs(drone)
        } else {
            dismiss(self)
        }

        getFacilities()
        listenToGamecontrollerNotifs()
        if GamepadController.sharedInstance.gamepadIsConnected {
            gamepadControllerIsConnected()
        } else {
            gamepadControllerIsDisconnected()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        stopListeningToGamecontrollerNotifs()
        GamepadController.sharedInstance.droneUid = self.droneUid
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        streamView.setStream(stream: nil)
        dropFacilities()
        dropAllInstruments()
        GamepadController.sharedInstance.droneUid = nil
        streamServer = nil
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeLeft
    }

    private func resetAllInstrumentsViews() {
        updateFlyingIndicatorLabel(nil)
        updateAlarmsLabel(nil)
        updateReturnHomeButton(nil)
        updateAltimeter(nil)
        updateHeading(nil)
        updateSpeedometer(nil)
        updateBatteryInfo(nil)
        updateAttitudeIndicator(nil)
        updateGroundDistance()
    }

    private func initDroneRefs(_ drone: Drone) {
        flyingIndicators = drone.getInstrument(Instruments.flyingIndicators) { [unowned self] flyingIndicators in
            self.updateFlyingIndicatorLabel(flyingIndicators)
        }

        alarms = drone.getInstrument(Instruments.alarms) { [unowned self] alarms in
            self.updateAlarmsLabel(alarms)
        }

        pilotingItf = drone.getPilotingItf(PilotingItfs.manualCopter) { [unowned self] pilotingItf in
            self.updateTakoffLandButton(pilotingItf)
            if let pilotingItf = pilotingItf {
                self.verticalSpeedView.set(maxValue: Double(pilotingItf.maxVerticalSpeed.value))
                self.verticalSpeedView.set(minValue: Double(-pilotingItf.maxVerticalSpeed.value))
            }
        }

        pointOfInterestItf = drone.getPilotingItf(PilotingItfs.pointOfInterest) { [unowned self] pointOfInterestItf in
            self.updateStopPoiButton(pointOfInterestItf)
        }

        returnHomePilotingItf = drone.getPilotingItf(PilotingItfs.returnHome) { [unowned self] pilotingItf in
            self.updateReturnHomeButton(pilotingItf)
        }

        followMePilotingItf = drone.getPilotingItf(PilotingItfs.followMe) {_ in}

        lookAtPilotingItf = drone.getPilotingItf(PilotingItfs.lookAt) {_ in}

        gps = drone.getInstrument(Instruments.gps) { [unowned self] gps in
            // keep the last location for the drone, in order to compute the ground distance
            if let lastKnownLocation = gps?.lastKnownLocation {
                self.lastDroneLocation = lastKnownLocation
            } else {
                self.lastDroneLocation = nil
            }
            self.updateGpsElements(gps)
            self.updateGroundDistance()
        }

        altimeter = drone.getInstrument(Instruments.altimeter) { [unowned self] altimeter in
            self.updateAltimeter(altimeter)
        }
        compass = drone.getInstrument(Instruments.compass) { [unowned self] compass in
            self.updateHeading(compass)
        }
        speedometer = drone.getInstrument(Instruments.speedometer) { [unowned self] speedometer in
            self.updateSpeedometer(speedometer)
        }
        batteryInfo = drone.getInstrument(Instruments.batteryInfo) { [unowned self] batteryInfo in
            self.updateBatteryInfo(batteryInfo)
        }
        attitudeIndicator = drone.getInstrument(Instruments.attitudeIndicator) { [unowned self] attitudeIndicator in
            self.updateAttitudeIndicator(attitudeIndicator)
        }
        camera = drone.getPeripheral(Peripherals.mainCamera) { [unowned self] camera in
            if let zoom = camera?.zoom {
                self.zoomVelocitySlider.isHidden = !zoom.isAvailable
            }
        }
        streamServer = drone.getPeripheral(Peripherals.streamServer) { streamServer in
            streamServer?.enabled = true
        }
        if let streamServer = streamServer {
            cameraLive = streamServer.value?.live { stream in
                self.streamView.setStream(stream: stream)
                _ = stream?.play()
            }
        }
    }

    private func dropAllInstruments() {
       flyingIndicators = nil
       alarms = nil
       pilotingItf = nil
       returnHomePilotingItf = nil
       gps = nil
       altimeter = nil
       compass = nil
       speedometer = nil
       batteryInfo = nil
       attitudeIndicator = nil
    }

    @IBAction func dismiss(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func leftJoystickUpdate(_ sender: JoystickView) {
        if let pilotingItf = pilotingItf?.value, pilotingItf.state == .active {
            pilotingItf.set(pitch: -sender.value.y)
            pilotingItf.set(roll: sender.value.x)
        } else if let pointOfInterestItf = pointOfInterestItf?.value, pointOfInterestItf.state == .active {
            pointOfInterestItf.set(pitch: -sender.value.y)
            pointOfInterestItf.set(roll: sender.value.x)
        } else if let lookAtPilotingItf = lookAtPilotingItf?.value, lookAtPilotingItf.state == .active {
            lookAtPilotingItf.set(pitch: -sender.value.y)
            lookAtPilotingItf.set(roll: sender.value.x)
        } else if let followMePilotingItf = followMePilotingItf?.value, followMePilotingItf.state == .active {
            followMePilotingItf.set(pitch: -sender.value.y)
            followMePilotingItf.set(roll: sender.value.x)
        }
}

    @IBAction func rightJoystickUpdate(_ sender: JoystickView) {
        if let pilotingItf = pilotingItf?.value, pilotingItf.state == .active {
            pilotingItf.set(verticalSpeed: sender.value.y)
            pilotingItf.set(yawRotationSpeed: sender.value.x)
        } else if let pointOfInterestItf = pointOfInterestItf?.value, pointOfInterestItf.state == .active {
            pointOfInterestItf.set(verticalSpeed: sender.value.y)
        } else if let lookAtPilotingItf = lookAtPilotingItf?.value, lookAtPilotingItf.state == .active {
            lookAtPilotingItf.set(verticalSpeed: sender.value.y)
        } else if let followMePilotingItf = followMePilotingItf?.value, followMePilotingItf.state == .active {
            followMePilotingItf.set(verticalSpeed: sender.value.y)
        }
    }

    @IBAction func emergencyClicked(_ sender: UIButton) {
        if let pilotingItf = pilotingItf?.value {
            pilotingItf.emergencyCutOut()
        }
    }

    @IBAction func takeOffLand(_ sender: UIButton) {
        if let pilotingItf = pilotingItf?.value {
            pilotingItf.smartTakeOffLand()
        }
    }

    @IBAction func stopPointOfInterest(_ sender: Any) {
        if let pointOfInterestItf = pointOfInterestItf?.value, pointOfInterestItf.state == .active {
            _ = pointOfInterestItf.deactivate()
        }
    }

    @IBAction func returnHomeClicked(_ sender: UIButton) {
        if let pilotingItf = returnHomePilotingItf?.value {
            switch pilotingItf.state {
            case .idle:
                _ = pilotingItf.activate()
            case .active:
                _ = pilotingItf.deactivate()
            default:
                break
            }
        }
    }

    @IBAction func zoomVelocityDidChange(_ sender: UISlider) {
        if let zoom = camera?.value?.zoom {
            zoom.control(mode: .velocity, target: Double(sender.value))
        }
    }

    @IBAction func zoomVelocityDidEndEditing(_ sender: UISlider) {
        set(zoomVelocity: 0.0)
    }

    private func set(zoomVelocity: Double) {
        zoomVelocitySlider.value = Float(zoomVelocity)
        zoomVelocitySlider.sendActions(for: .valueChanged)
    }

    private func updateFlyingIndicatorLabel(_ flyingIndicators: FlyingIndicators?) {
        if let flyingIndicators = flyingIndicators {
            if flyingIndicators.state == .flying {
                flyingIndicatorsLabel.text = "\(flyingIndicators.state.description)/" +
                    "\(flyingIndicators.flyingState.description)"
            } else {
                flyingIndicatorsLabel.text = "\(flyingIndicators.state.description)"
            }
        } else {
            flyingIndicatorsLabel.text = ""
        }
    }

    private func updateAlarmsLabel(_ alarms: Alarms?) {
        if let alarms = alarms {
            let text = NSMutableAttributedString()
            let critical = [NSAttributedString.Key.foregroundColor: UIColor.red]
            let warning = [NSAttributedString.Key.foregroundColor: UIColor.orange]
            for kind in Alarm.Kind.allCases {
                let alarm = alarms.getAlarm(kind: kind)
                switch alarm.level {
                case .warning:
                    text.append(NSMutableAttributedString(string: kind.description + " ",
                        attributes: warning))
                case .critical:
                    text.append(NSMutableAttributedString(string: kind.description + " ",
                        attributes: critical))
                default:
                    break
                }

            }
            alarmsLabel.attributedText = text
        } else {
            alarmsLabel.text = ""
        }
    }

    private func updateTakoffLandButton(_ pilotingItf: ManualCopterPilotingItf?) {
        if let pilotingItf = pilotingItf, pilotingItf.state == .active {
            takoffLandButton.isHidden = false
            let smartAction = pilotingItf.smartTakeOffLandAction
            switch smartAction {
            case .land:
                takoffLandButton.setImage(landButtonImage, for: .normal)
            case .takeOff:
                takoffLandButton.setImage(takeOffButtonImage, for: .normal)
            case .thrownTakeOff:
                takoffLandButton.setImage(handButtonImage, for: .normal)
            case .none:
                ()
            }
            takoffLandButton.isEnabled = smartAction != .none
        } else {
            takoffLandButton.isEnabled = false
            takoffLandButton.isHidden = true
        }
    }

    private func updateStopPoiButton(_ pilotingItf: PointOfInterestPilotingItf?) {
        if let pilotingItf = pilotingItf, pilotingItf.state == .active {
            stopPoiButton.isHidden = false
        } else {
            stopPoiButton.isHidden = true
        }
    }

    private func updateReturnHomeButton(_ pilotingItf: ReturnHomePilotingItf?) {
        if let pilotingItf = pilotingItf {
            switch pilotingItf.state {
            case .unavailable:
                returnHomeButton.isEnabled = false
                returnHomeButton.isHighlighted = false
            case .idle:
                returnHomeButton.isEnabled = true
                returnHomeButton.isHighlighted = false
            case .active:
                returnHomeButton.isEnabled = true
                returnHomeButton.isHighlighted = true
            }
        } else {
            returnHomeButton.isEnabled = false
            returnHomeButton.isSelected = false
        }

    }

    private func updateGpsElements(_ gps: Gps?) {
        var fixed = false
        var labelText = ""
        if let gps = gps {
            fixed = gps.fixed
            labelText = "(\(gps.satelliteCount)) "
        }

        if fixed {
            gpsImageView.image = gpsFixedImage
        } else {
            gpsImageView.image = gpsNotFixedImage
        }

        if let location = gps?.lastKnownLocation {
            labelText += String(format: "(%.6f, %.6f, %.2f)", location.coordinate.latitude,
                location.coordinate.longitude, location.altitude)
        }
        gpsLabel.text = labelText
    }

    private func updateAltimeter(_ altimeter: Altimeter?) {
        if let altimeter = altimeter, let takeoffRelativeAltitude = altimeter.takeoffRelativeAltitude {
            altimeterView.isHidden = false
            altimeterView.set(takeOffAltitude: takeoffRelativeAltitude)
            if let groundRelativeAltitude = altimeter.groundRelativeAltitude {
                altimeterView.set(groundAltitude: groundRelativeAltitude)
            } else {
                altimeterView.set(groundAltitude: takeoffRelativeAltitude)
            }
            if let verticalSpeed = altimeter.verticalSpeed {
                verticalSpeedView.set(currentValue: verticalSpeed)
            }
        } else {
            altimeterView.isHidden = true
        }
    }

    private func updateHeading(_ compass: Compass?) {
        if let compass = compass {
            compassView.isHidden = false
            compassView.set(heading: compass.heading)
        } else {
            compassView.isHidden = true
        }
    }

    private func updateSpeedometer(_ speedometer: Speedometer?) {
        let speedStr: String
        if let speedometer = speedometer {
            let measurementInMetersPerSecond = Measurement(
                value: speedometer.groundSpeed, unit: UnitSpeed.metersPerSecond)
            speedStr = speedFormatter.string(from: measurementInMetersPerSecond)
            speedometerView.alpha = 1
        } else {
            // dim the speedometer view if there is no speedometer instrument
            speedometerView.alpha = dimInstrumentAlpha
            speedStr = ""
        }
        speedometerLabel.text = speedStr
    }

    private func updateGroundDistance() {
        let distanceStr: String
        if let droneLocation = lastDroneLocation, let userLocation = lastUserLocation {
            // compute the distance
            let distance = droneLocation.distance(from: userLocation)
            let measurementInMeters = Measurement(value: distance, unit: UnitLength.meters)
            distanceStr = distanceFormatter.string(from: measurementInMeters)
            droneDistanceView.alpha = 1
        } else {
            // dim the groundDistanceview if there is no location for the drone OR for the user
            droneDistanceView.alpha = dimInstrumentAlpha
            distanceStr = ""
        }
        droneDistanceLabel.text = distanceStr
    }

    private func updateBatteryInfo(_ batteryInfo: BatteryInfo?) {
        let batteryStr: String
        if let batteryInfo = batteryInfo {
            batteryStr = String(format: "\(batteryInfo.batteryLevel)%%")
            droneBatteryView.alpha = 1
        } else {
            // dim the batery view if there is no battery instrument
            batteryStr = ""
            droneBatteryView.alpha = dimInstrumentAlpha
        }
        droneBatteryLabel.text = batteryStr
    }

    private func updateAttitudeIndicator(_ attitudeIndicator: AttitudeIndicator?) {
        if let attitudeIndicator = attitudeIndicator {
            attitudeIndicatorView.isHidden = false
            attitudeIndicatorView.set(roll: attitudeIndicator.roll)
            attitudeIndicatorView.set(pitch: attitudeIndicator.pitch)
        } else {
            attitudeIndicatorView.isHidden = true
        }
    }

    private func listenToGamecontrollerNotifs() {
        NotificationCenter.default.addObserver(self, selector: #selector(gamepadControllerIsConnected),
            name: NSNotification.Name(rawValue: GamepadController.GamepadDidConnect), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(gamepadControllerIsDisconnected),
            name: NSNotification.Name(rawValue: GamepadController.GamepadDidDisconnect), object: nil)
    }

    private func stopListeningToGamecontrollerNotifs() {
        NotificationCenter.default.removeObserver(
            self, name: Notification.Name(rawValue: GamepadController.GamepadDidConnect), object: nil)
        NotificationCenter.default.removeObserver(
            self, name: Notification.Name(rawValue: GamepadController.GamepadDidDisconnect), object: nil)
    }

    @objc
    private func gamepadControllerIsConnected() {
        joysticksView.isHidden = true
    }

    @objc
    private func gamepadControllerIsDisconnected() {
        joysticksView.isHidden = false
    }

    // MARK: - Facilities
    private func getFacilities() {
        refLocation = groundSdk.getFacility(Facilities.userLocation) { [weak self] userLocation in
            self?.lastUserLocation = userLocation?.location
            self?.updateGroundDistance()
        }
    }
    private func dropFacilities() {
        refLocation = nil
    }
}
