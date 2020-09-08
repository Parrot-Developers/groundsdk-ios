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
import MapKit

class GuidedPilotingItfViewController: UIViewController, DeviceViewController {

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var moveToLatValue: UILabel!
    @IBOutlet var moveToLonValue: UILabel!

    @IBOutlet var droneLatValue: UILabel!
    @IBOutlet var droneLonValue: UILabel!

    @IBOutlet var orientationPicker: UIPickerView!
    let pickerDataSource:[(name: String, value: OrientationDirective)] = [
        ("None", .none), ("To Target", .toTarget), ("Heading Start", .headingStart(0)),
        ("Heading During", .headingDuring(0))]

    @IBOutlet var headingLocation: UITextField!
    @IBOutlet var altitudeValue: UILabel!
    @IBOutlet var horizontalSpeedValue: UILabel!
    @IBOutlet var verticalSpeedValue: UILabel!
    @IBOutlet var yawSpeedValue: UILabel!
    @IBOutlet var altitudeSlider: UISlider!
    @IBOutlet var horizontalSpeedSlider: UISlider!
    @IBOutlet var verticalSpeedSlider: UISlider!
    @IBOutlet var yawSpeedSlider: UISlider!

    @IBOutlet var forwardField: UITextField!
    @IBOutlet var rightField: UITextField!
    @IBOutlet var downwardField: UITextField!
    @IBOutlet var headingField: UITextField!

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var pilotingItf: Ref<GuidedPilotingItf>?
    private var gps: Ref<Gps>?

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    var locationDestination: CLLocationCoordinate2D? {
        didSet {
            if locationDestination == nil {
                moveToLatValue.text = "?"
                moveToLonValue.text = "?"
            } else {
                moveToLatValue.text = locationDestination!.latitude.description
                moveToLonValue.text = locationDestination!.longitude.description
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        orientationPicker.dataSource = self
        orientationPicker.delegate = self

        if let drone = groundSdk.getDrone(uid: droneUid!) {
            pilotingItf = drone.getPilotingItf(PilotingItfs.guided) { [weak self] pilotingItf in
                if pilotingItf == nil {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
            }
            gps = drone.getInstrument(Instruments.gps) { [unowned self] gps in
                if let location = gps?.lastKnownLocation {
                    self.droneLatValue.text = location.coordinate.latitude.description
                    self.droneLonValue.text = location.coordinate.longitude.description
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // update the altitude slider
        altitudeDidChange(altitudeSlider)
    }

    // embed the map, set self as delegate (in order to track the MoveToLocation value)
    // and get the current Move To Location
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mapViewController = segue.destination as? AnnotationMapViewController {
            mapViewController.setDeviceUid(droneUid!)
            mapViewController.delegate = self
            locationDestination = mapViewController.moveDestination
        }
    }

    // Altitude
    @IBAction func altitudeDidChange(_ sender: UISlider) {
        altitudeValue.text = String(format: "%.2f", sender.value )
    }

    // Horizontal speed
    @IBAction func horizontalSpeedDidChange(_ sender: UISlider) {
        horizontalSpeedValue.text = String(format: "%.2f", sender.value )
    }

    // Vertical speed
    @IBAction func verticalSpeedDidChange(_ sender: UISlider) {
        verticalSpeedValue.text = String(format: "%.2f", sender.value )
    }

    // Yaw speed
    @IBAction func yawSpeedDidChange(_ sender: UISlider) {
        yawSpeedValue.text = String(format: "%.2f", sender.value )
    }

    // Tap on Go To Locatoin Button
    @IBAction func goToLocation(_ sender: Any) {

        if let locationDestination = locationDestination {

            let selectedOrientation = pickerDataSource[orientationPicker.selectedRow(inComponent: 0)].value
            let headingValue = Double(headingLocation.text ?? "0") ?? 0
            let orientation: OrientationDirective
            switch selectedOrientation {
            case .none:
                orientation = .none
            case .toTarget:
                orientation = .toTarget
            case .headingStart:
                orientation = .headingStart(headingValue)
            case .headingDuring:
                orientation = .headingDuring(headingValue)
            }

            // Add speed
            let locationDirective = LocationDirective(latitude: locationDestination.latitude,
                                                      longitude: locationDestination.longitude,
                                                      altitude: Double(altitudeSlider.value),
                                                      orientation: orientation, speed: getSpeed())
            pilotingItf?.value?.move(directive: locationDirective)
        }
    }

    @IBAction func goRelative(_ sender: Any) {
        let forward = Double(forwardField.text ?? "0") ?? 0
        let right = Double(rightField.text ?? "0") ?? 0
        let downward = Double(downwardField.text ?? "0") ?? 0
        let heading = Double(headingField.text ?? "0") ?? 0

        // Add speed
        let relativeDirective = RelativeMoveDirective(forwardComponent: forward,
                                                      rightComponent: right,
                                                      downwardComponent: downward,
                                                      headingRotation: heading, speed: getSpeed())
        pilotingItf?.value?.move(directive: relativeDirective)
    }

    func getSpeed() -> GuidedPilotingSpeed? {
        let horizontalSpeed = Double(horizontalSpeedSlider.value)
        let verticalSpeed = Double(verticalSpeedSlider.value)
        let yawSpeed = Double(yawSpeedSlider.value)
        if horizontalSpeed > 0 || verticalSpeed > 0 || yawSpeed > 0 {
            return GuidedPilotingSpeed(horizontalSpeed: horizontalSpeed, verticalSpeed: verticalSpeed,
                                       yawRotationSpeed: yawSpeed)
        }
        return nil
    }
}

// MARK: MapAnnotationDelegate
extension GuidedPilotingItfViewController: AnnotationMapDelegate {
    func destinationDidChange(moveLocation: CLLocationCoordinate2D?) {
        locationDestination = moveLocation
    }
}

// MARK: UIPickerViewDataSource
extension GuidedPilotingItfViewController: UIPickerViewDataSource, UIPickerViewDelegate {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerDataSource.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerDataSource[row].name
    }
}

// MARK: UITextFieldDelegate
extension GuidedPilotingItfViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let text = textField.text, let userVal = Double(text) {
            textField.text = String(format: "%.2f", userVal)
        } else {
            textField.text = "0"
        }
        return true
    }
}

// MARK: UIScrollViewDelegate
extension GuidedPilotingItfViewController: UIScrollViewDelegate {
    // dissmiss any keyboard when draging the scroll view
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
}
