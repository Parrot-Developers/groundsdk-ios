// Copyright (C) 2020 Parrot Drones SAS
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

class DriViewController: UITableViewController, DeviceViewController {

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var dri: Ref<Dri>?

    @IBOutlet weak var typeState: UILabel!
    @IBOutlet weak var typeConfig: UILabel!
    @IBOutlet weak var typeOperatorId: UITextField!

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let drone = groundSdk.getDrone(uid: droneUid!) {
            dri = drone.getPeripheral(Peripherals.dri) { [weak self] dri in
                if let dri = dri, let `self` = self {
                    self.typeState.text = dri.type.state?.description ?? "-"
                    self.typeConfig.text = dri.type.type?.type.description ?? "-"
                    if case .en4709_002(let operatorId) = dri.type.type {
                        self.typeOperatorId.text = operatorId
                        self.typeOperatorId.isEnabled = true
                    } else {
                        self.typeOperatorId.text = ""
                        self.typeOperatorId.isEnabled = false
                    }
                } else {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    func driTypeConfig(type: DriType?, operatorId: String?) -> DriTypeConfig? {
        switch type {
        case .en4709_002:
            if let operatorId = operatorId {
                return .en4709_002(operatorId: operatorId)
            } else {
                return nil
            }
        case .french:
            return .french
        case .none:
            return nil
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let cell = sender as? UITableViewCell
        if let dri = dri?.value,
           let reuseIdentifier = cell?.reuseIdentifier,
           reuseIdentifier == "type" {
            switch segue.destination {
            case let target as ChooseEnumViewController:
                target.initialize(data: ChooseEnumViewController.Data(
                    dataSource: [DriType](dri.type.supportedTypes),
                    selectedValue: dri.type.type?.description,
                    itemDidSelect: { [unowned self] value in
                        dri.type.type = driTypeConfig(type: value as? DriType,
                                                      operatorId: self.typeOperatorId.text)
                    }
                ))
            default:
                return
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if let reuseIdentifier = cell?.reuseIdentifier {
            let segueIdentifier: String
            switch reuseIdentifier {
            case "type":
                segueIdentifier = "selectEnumValue"
            default:
                return
            }
            performSegue(withIdentifier: segueIdentifier, sender: cell)
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
}

extension DriViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let dri = dri?.value,
           let type = dri.type.type {
            dri.type.type = driTypeConfig(type: type.type,
                                          operatorId: typeOperatorId.text)
        }
        return true
    }
}
