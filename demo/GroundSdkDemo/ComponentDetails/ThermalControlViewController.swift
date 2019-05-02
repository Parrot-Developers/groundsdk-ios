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

class ThermalControlViewController: UITableViewController, DeviceViewController {

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var thermalControl: Ref<ThermalControl>?
    private var stateRef: Ref<DeviceState>?

    @IBOutlet weak var mode: UILabel!
    @IBOutlet weak var sensitivityRange: UILabel!

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let drone = groundSdk.getDrone(uid: droneUid!) {
            thermalControl = drone.getPeripheral(Peripherals.thermalControl) { [weak self] thermalControl in
                if let thermalControl = thermalControl, let `self` = self {
                    // mode
                    self.mode.text = thermalControl.setting.mode.description
                    self.sensitivityRange.text = thermalControl.sensitivitySetting.sensitivityRange.description
                    self.stateRef = drone.getState { [unowned self] _ in
                        self.tableView.reloadData()
                    }
                } else {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let thermalControl = thermalControl?.value, let target = segue.destination as? ChooseEnumViewController {
            if let indexPath = tableView.indexPathForSelectedRow {
                if indexPath.row == 0 {
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [ThermalControlMode](thermalControl.setting.supportedModes),
                        selectedValue: thermalControl.setting.mode.description,
                        itemDidSelect: { [unowned self] value in
                            self.thermalControl?.value?.setting.mode = value as! ThermalControlMode
                        }
                    ))
                } else if indexPath.row == 1 {
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource:
                            [ThermalSensitivityRange](thermalControl.sensitivitySetting.supportedSensitivityRanges),
                        selectedValue: thermalControl.sensitivitySetting.sensitivityRange.description,
                        itemDidSelect: { [unowned self] value in
                            self.thermalControl?.value?.sensitivitySetting.sensitivityRange =
                                value as! ThermalSensitivityRange
                        }
                    ))
                }
            }
        } else if segue.identifier == "selectEmissivityValue" {
            (segue.destination as! ThermalEmissivityViewController).setDeviceUid(droneUid!)
        } else if segue.identifier == "selectColorPalette" {
            (segue.destination as! ThermalChoosePaletteViewController).setDeviceUid(droneUid!)
        } else if segue.identifier == "selectBackgroundTemperature" {
            (segue.destination as! ThermalBackgroundTemperatureVC).setDeviceUid(droneUid!)
        } else if segue.identifier == "selectRendering" {
            (segue.destination as! ThermalRenderingViewController).setDeviceUid(droneUid!)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row < 2 {
            performSegue(withIdentifier: "selectEnumValue", sender: self)
        } else if indexPath.section == 0 && indexPath.row == 2 {
            performSegue(withIdentifier: "selectEmissivityValue", sender: self)
        } else if indexPath.section == 0 && indexPath.row == 3 {
            performSegue(withIdentifier: "selectBackgroundTemperature", sender: self)
        } else if indexPath.section == 0 && indexPath.row == 4 {
            performSegue(withIdentifier: "selectColorPalette", sender: self)
        } else if indexPath.section == 0 && indexPath.row == 5 {
            performSegue(withIdentifier: "selectRendering", sender: self)
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
         var rowHeight: CGFloat = 44.0

        if let state = stateRef?.value?.connectionState {
            if state == .disconnected {
                if indexPath.row > 1 {
                    rowHeight = 0.0
                }
            }
        }
        return rowHeight
    }
}

private extension UITableView {
    func enable(section: Int, on: Bool) {
        for cellIndex in 0..<numberOfRows(inSection: section) {
            cellForRow(at: IndexPath(item: cellIndex, section: section))?.enable(on: on)
        }
    }
}

private extension UITableViewCell {
    func enable(on: Bool) {
        for view in contentView.subviews {
            view.isUserInteractionEnabled = on
            view.alpha = on ? 1 : 0.5
        }
    }
}
