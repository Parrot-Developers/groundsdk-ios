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

class SkyCtrl3GrabViewController: UITableViewController, DeviceViewController {

    private let buttonSection = 0
    private let axisSection = 1

    private let groundSdk = GroundSdk()
    private var rcUid: String?
    private var skyCtrl3Gamepad: Ref<SkyCtrl3Gamepad>?

    private lazy var buttons: [SkyCtrl3Button] = {
        return Array(SkyCtrl3Button.allCases)
    }()
    private lazy var axes: [SkyCtrl3Axis] = {
        return Array(SkyCtrl3Axis.allCases)
    }()

    func setDeviceUid(_ uid: String) {
        rcUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let remoteControl = groundSdk.getRemoteControl(uid: rcUid!) {
            skyCtrl3Gamepad =
                remoteControl.getPeripheral(Peripherals.skyCtrl3Gamepad) { [weak self] skyCtrl3Gamepad in
                    if skyCtrl3Gamepad != nil {
                        self?.tableView.reloadData()
                    } else {
                        self?.performSegue(withIdentifier: "exit", sender: self)
                    }
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "input", for: indexPath)
        if let cell = cell as? SkyCtrl3GrabInputCell {
            switch indexPath.section {
            case 0:
                let button = buttons[indexPath.row]
                let isChecked = skyCtrl3Gamepad?.value?.grabbedButtons.contains(button) ?? false
                cell.updateWith(button: button, isChecked: isChecked)
            default:
                let axis = axes[indexPath.row]
                let isChecked = skyCtrl3Gamepad?.value?.grabbedAxes.contains(axis) ?? false
                cell.updateWith(axis: axis, isChecked: isChecked)
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let skyCtrl3Gamepad = skyCtrl3Gamepad?.value {
            var grabbedButtons = skyCtrl3Gamepad.grabbedButtons
            var grabbedAxes = skyCtrl3Gamepad.grabbedAxes

            switch indexPath.section {
            case buttonSection:
                let buttonInput = buttons[indexPath.row]
                if grabbedButtons.contains(buttonInput) {
                    grabbedButtons.remove(buttonInput)
                } else {
                    grabbedButtons.insert(buttonInput)
                }
            case axisSection:
                let axisInput = axes[indexPath.row]
                if grabbedAxes.contains(axisInput) {
                    grabbedAxes.remove(axisInput)
                } else {
                    grabbedAxes.insert(axisInput)
                }
            default: break
            }
            skyCtrl3Gamepad.grab(buttons: grabbedButtons, axes: grabbedAxes)
            tableView.reloadRows(at: [indexPath], with: .fade)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case buttonSection: return "Buttons"
        case axisSection: return "Axes"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case buttonSection: return buttons.count
        case axisSection: return axes.count
        default: return 0
        }
    }
}

class SkyCtrl3GrabInputCell: UITableViewCell {

    fileprivate func updateWith(button: SkyCtrl3Button, isChecked: Bool) {
        textLabel?.text = button.description
        accessoryType = isChecked ? .checkmark : .none
    }

    fileprivate func updateWith(axis: SkyCtrl3Axis, isChecked: Bool) {
        textLabel?.text = axis.description
        accessoryType = isChecked ? .checkmark : .none
    }
}
