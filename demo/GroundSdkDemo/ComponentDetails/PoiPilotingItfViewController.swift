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

class PoiPilotingItfViewController: UIViewController, DeviceViewController {

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var poiLatValue: UILabel!
    @IBOutlet var poiLonValue: UILabel!
    @IBOutlet var poiAltitudeValue: UILabel!
    @IBOutlet var altitudeSlider: UISlider!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var interfaceStatusValue: UILabel!
    @IBOutlet var droneLatValue: UILabel!
    @IBOutlet var droneLonValue: UILabel!

    // commands on the current Poi
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var commandsView: UIStackView!
    @IBOutlet var currentLatValue: UILabel!
    @IBOutlet var currentLonValue: UILabel!
    @IBOutlet var currentAltValue: UILabel!
    @IBOutlet weak var pitchSlider: UISlider!
    @IBOutlet weak var pichValue: UILabel!
    @IBOutlet weak var rollSlider: UISlider!
    @IBOutlet weak var rollValue: UILabel!
    @IBOutlet weak var gazSlider: UISlider!
    @IBOutlet weak var gazValue: UILabel!

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var pilotingItf: Ref<PointOfInterestPilotingItf>?
    private var gps: Ref<Gps>?

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    var locationDestination: CLLocationCoordinate2D? {
        didSet {
            if locationDestination == nil {
                poiLatValue.text = "?"
                poiLonValue.text = "?"
            } else {
                poiLatValue.text = locationDestination!.latitude.description
                poiLonValue.text = locationDestination!.longitude.description
            }
            self.updateInterface(pointOfInterestItf: pilotingItf?.value)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let drone = groundSdk.getDrone(uid: droneUid!) {
            pilotingItf = drone.getPilotingItf(PilotingItfs.pointOfInterest) { [weak self] pilotingItf in
                if pilotingItf == nil {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
                self?.updateInterface(pointOfInterestItf: pilotingItf)
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

    private func updateInterface(pointOfInterestItf: PointOfInterestPilotingItf?) {

        guard let pointOfInterestItf = pointOfInterestItf else {
            self.actionButton.isEnabled = false
            self.commandsView.isHidden = true
            return
        }

        self.interfaceStatusValue.text = pointOfInterestItf.state.description

        switch pointOfInterestItf.state {
        case .idle:
            self.actionButton.setTitle("START P.O.I.", for: .normal)
            self.actionButton.isEnabled = locationDestination != nil
        case .active:
            // set button label
            self.actionButton.isEnabled = true
            self.actionButton.setTitle("STOP", for: .normal)
        case .unavailable:
            self.actionButton.isEnabled = false
            self.actionButton.setTitle("", for: .normal)
        }
        let showCommands: Bool
        if let currentPointOfInterest = pointOfInterestItf.currentPointOfInterest {
            showCommands = true
            self.updateButton.isEnabled = locationDestination != nil
            currentLatValue.text = currentPointOfInterest.latitude.description
            currentLonValue.text = currentPointOfInterest.longitude.description
            currentAltValue.text = currentPointOfInterest.altitude.description

        } else {
            showCommands = false
            self.updateButton.isEnabled = false
            currentLatValue.text = ""
            currentLonValue.text = ""
            currentAltValue.text = ""
        }

        if commandsView.isHidden != !showCommands {
            if showCommands {
                // displiyng the commands -> Reset sliders
                resetCommands(self)
            }
            UIView.animate(withDuration: 0.3) {
                self.commandsView.isHidden = !showCommands
            }
        }

    }

    // Altitude
    @IBAction func altitudeDidChange(_ sender: UISlider) {
        poiAltitudeValue.text = String(format: "%.2f", sender.value )
    }

    // Tap on action Button
    @IBAction func actionButton(_ sender: Any) {
        if let pointOfInterestItf = pilotingItf?.value {
            if pointOfInterestItf.currentPointOfInterest != nil {
                // send stop
                _ = pointOfInterestItf.deactivate()
            } else {
                if let locationDestination = locationDestination {
                    pointOfInterestItf.start(
                        latitude: locationDestination.latitude, longitude: locationDestination.longitude,
                        altitude: Double(altitudeSlider.value))
                }
            }
        }
    }

    // MARK: - User Commands
    @IBAction func resetCommands(_ sender: Any) {
        pitchSlider.setCommandValue(0)
        commandSliderValueChanged(pitchSlider)
        rollSlider.setCommandValue(0)
        commandSliderValueChanged(rollSlider)
        gazSlider.setCommandValue(0)
        commandSliderValueChanged(gazSlider)
    }

    @IBAction func commandSliderValueChanged(_ sender: UISlider) {
        let pointOfInterestItf = pilotingItf?.value
        let sliderValue = sender.getCommandValue()
        switch sender {
        case pitchSlider:
            pichValue.text = sliderValue.description
            pointOfInterestItf?.set(pitch: sliderValue)
        case rollSlider:
            rollValue.text = sliderValue.description
            pointOfInterestItf?.set(roll: sliderValue)
        case gazSlider:
            gazValue.text = sliderValue.description
            pointOfInterestItf?.set(verticalSpeed: sliderValue)
        default:
            break
        }
    }

    @IBAction func updatePOI(_ sender: Any) {
        if let pointOfInterestItf = pilotingItf?.value, let locationDestination = locationDestination,
            pointOfInterestItf.state == .active {
            pointOfInterestItf.start(
                latitude: locationDestination.latitude, longitude: locationDestination.longitude,
                altitude: Double(altitudeSlider.value))
        }
    }
}

// MARK: - MapAnnotationDelegate
extension PoiPilotingItfViewController: AnnotationMapDelegate {
    func destinationDidChange(moveLocation: CLLocationCoordinate2D?) {
        locationDestination = moveLocation
    }
}

// MARK: - UIScrollViewDelegate
extension PoiPilotingItfViewController: UIScrollViewDelegate {
    // dissmiss any keyboard when draging the scroll view
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
}

// MARK: - UISlider extension for user commands
extension UISlider {
    func getCommandValue() -> Int {
        return signedPercentInterval.clamp(Int(value.rounded()))
    }
    func setCommandValue(_ signedPercentValue: Int) {
        self.setValue(Float(signedPercentValue), animated: true)
    }
}
