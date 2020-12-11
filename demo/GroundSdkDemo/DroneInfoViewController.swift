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

class DroneInfoViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, DeviceViewController {

    @IBOutlet weak var modelLabel: UILabel!
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var forgetButton: UIButton!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var tableView: UITableView!

    private let copterHudSegue = "CopterHudSegue"

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var drone: Drone?
    private var nameRef: Ref<String>?
    private var stateRef: Ref<DeviceState>?

    private let sections = ["Instruments", "Piloting Interfaces", "Peripheral"]
    private let instrumentSection = 0
    private let pilotingItfSection = 1
    private let peripheralSection = 2

    private var cells = [[DeviceContentCell](), [DeviceContentCell](), [DeviceContentCell]()]

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let droneUid = self.droneUid {
            drone = groundSdk.getDrone(uid: droneUid) { [weak self] _ in
                _ = self?.navigationController?.popViewController(animated: true)
            }
        }
        // get the drone
        if let drone = drone {
            // header
            modelLabel.text = drone.model.description
            nameRef = drone.getName { [unowned self] name in
                self.title = name!
            }
            stateRef = drone.getState { [unowned self] state in
                // state is never nil
                self.stateLabel.text = state!.description

                self.forgetButton.isEnabled = state!.canBeForgotten
                self.connectButton.isEnabled = state!.canBeConnected || state!.canBeDisconnected
                if state!.connectionState == .disconnected {
                    self.connectButton.setTitle("Connect", for: UIControl.State())
                } else {
                    self.connectButton.setTitle("Disconnect", for: UIControl.State())
                }
            }

            // Instruments
            addCell("alarms", section: instrumentSection)
            addCell("altimeter", section: instrumentSection)
            addCell("attitudeIndicator", section: instrumentSection)
            addCell("compass", section: instrumentSection)
            addCell("flightIndicators", section: instrumentSection)
            addCell("gps", section: instrumentSection)
            addCell("speedometer", section: instrumentSection)
            addCell("flightMeter", section: instrumentSection)
            addCell("radio", section: instrumentSection)
            addCell("batteryInfo", section: instrumentSection)
            addCell("cameraExposureValues", section: instrumentSection)
            addCell("photoProgressIndicator", section: instrumentSection)
            // PilotingItf
            addCell("manualCopter", section: pilotingItfSection)
            addCell("returnHome", section: pilotingItfSection)
            addCell("guided", section: pilotingItfSection)
            addCell("pointOfInterest", section: pilotingItfSection)
            addCell("lookAt", section: pilotingItfSection)
            addCell("followMe", section: pilotingItfSection)
            addCell("flightPlan", section: pilotingItfSection)
            addCell("animation", section: pilotingItfSection)
            // Peripheral
            addCell("magnetometer", section: peripheralSection)
            addCell("liveStream", section: peripheralSection)
            addCell("thermalStream", section: peripheralSection)
            addCell("hmd", section: peripheralSection)
            addCell("camera", section: peripheralSection)
            addCell("thermal", section: peripheralSection)
            addCell("blendedThermal", section: peripheralSection)
            addCell("antiflickering", section: peripheralSection)
            addCell("preciseHome", section: peripheralSection)
            addCell("thermalControl", section: peripheralSection)
            addCell("pilotingControl", section: peripheralSection)
            addCell("geofence", section: peripheralSection)
            addCell("gimbal", section: peripheralSection)
            addCell("systemInfo", section: peripheralSection)
            addCell("batteryGaugeFirmwareUpdater", section: peripheralSection)
            addCell("updater", section: peripheralSection)
            addCell("crashReporter", section: peripheralSection)
            addCell("mediaStore", section: peripheralSection)
            addCell("copterMotors", section: peripheralSection)
            addCell("wifiScanner", section: peripheralSection)
            addCell("wifiAccessPoint", section: peripheralSection)
            addCell("removableUserStorage", section: peripheralSection)
            addCell("beeper", section: peripheralSection)
            addCell("leds", section: peripheralSection)
            addCell("dri", section: peripheralSection)
            addCell("targetTracker", section: peripheralSection)
            addCell("crashReporter", section: peripheralSection)
            addCell("flightDataDownloader", section: peripheralSection)
            addCell("flightLogDownloader", section: peripheralSection)
            addCell("logControl", section: peripheralSection)
            addCell("certificateUploader", section: peripheralSection)
        }
    }

    private func addCell(_ identifier: String, section: Int) {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? DeviceContentCell else {
            preconditionFailure("\(identifier) is not a valid DeviceContentCell identifier.")
        }

        if let pilotingItfCell = cell as? PilotingItfProviderContentCell {
            pilotingItfCell.initContent(provider: drone!, tableView: tableView)
        } else if let instrumentCell = cell as? InstrumentProviderContentCell {
            instrumentCell.initContent(provider: drone!, tableView: tableView)
        } else if let peripheralCell = cell as? PeripheralProviderContentCell {
            peripheralCell.initContent(provider: drone!, tableView: tableView)
        }

        // cell-type specific actions
        if let flightPlanPilotingItfCell = cell as? FlightPlanPilotingItfCell {
            flightPlanPilotingItfCell.viewController = self
        } else if let animationPilotingItfCell = cell as? AnimationPilotingItfCell {
            animationPilotingItfCell.viewController = self
        } else if let magnetometerCell = cell as? MagnetometerCell {
            magnetometerCell.viewController = self
        } else if let removableUserStorageCell = cell as? RemovableUserStorageCell {
            removableUserStorageCell.viewController = self
        } else if let attitudeIndicatorCell = cell as? AttitudeIndicatorCell {
            attitudeIndicatorCell.viewController = self
        }

        cells[section].append(cell)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if drone == nil {
            _ = self.navigationController?.popViewController(animated: animated)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        GamepadController.sharedInstance.droneUid = self.droneUid
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        GamepadController.sharedInstance.droneUid = nil
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = ((segue.destination as? UINavigationController)?.topViewController
                                     ?? segue.destination) as? DeviceViewController, let droneUid = droneUid {
            viewController.setDeviceUid(droneUid)
        }
    }

    @IBAction func forget(_ sender: UIButton) {
        _ = drone?.forget()
    }

    @IBAction func connectDisconnect(_ sender: UIButton) {
        if let connectionState = stateRef?.value?.connectionState {
            if connectionState == DeviceState.ConnectionState.disconnected {
                if let drone = drone {
                    if drone.state.connectors.count > 1 {
                        let alert = UIAlertController(title: "Connect using", message: "", preferredStyle: .actionSheet)
                        if let popoverController = alert.popoverPresentationController {
                            popoverController.sourceView = sender
                            popoverController.sourceRect = sender.bounds
                        }
                        for connector in drone.state.connectors {
                            alert.addAction(
                                UIAlertAction(title: connector.description, style: .default) { [unowned self] _ in
                                    self.connect(drone: drone, connector: connector) })
                        }
                        present(alert, animated: true, completion: nil)
                    } else if drone.state.connectors.count == 1 {
                        connect(drone: drone, connector: drone.state.connectors[0])
                    }
                }
            } else {
                _ = drone?.disconnect()
            }
        }
    }

    @IBAction func showHud(_ sender: UIButton) {
        if let drone = drone {
            if drone.getPilotingItf(PilotingItfs.manualCopter) != nil {
                self.performSegue(withIdentifier: copterHudSegue, sender: self)
            }
        }
    }

    @IBAction func showDefaultDetail(unwindSegue: UIStoryboardSegue) {
        if let splitViewController = self.splitViewController, splitViewController.isCollapsed {
            _ = self.navigationController?.popViewController(animated: true)
        } else {
            self.performSegue(withIdentifier: "showDefault", sender: self)
        }
    }

    private func connect(drone: Drone, connector: DeviceConnector) {
        if drone.state.connectionStateCause == .badPassword {
            // ask for password
            let alert = UIAlertController(title: "Password", message: "", preferredStyle: .alert)
            alert.addTextField(configurationHandler: nil)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                if let password = alert.textFields?[0].text {
                    _ = drone.connect(connector: connector, password: password)
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            _ = drone.connect(connector: connector)
        }
    }

// MARK: UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.section][indexPath.row]
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = cells[indexPath.section][indexPath.row]
        if !cell.visible {
            return 0
        }
        return cell.height
    }
}
