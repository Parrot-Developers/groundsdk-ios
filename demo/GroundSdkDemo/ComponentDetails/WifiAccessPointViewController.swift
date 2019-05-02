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

class DisplayedCountry: CustomStringConvertible, Comparable {

    public private (set)  var isoCode: String
    private var name: String

    public var description: String {
        return name
    }

    init(isoCode: String) {
        self.isoCode = isoCode
        self.name = Locale.current.localizedString(forRegionCode: isoCode) ?? isoCode
    }
    /// Comparable concordance
    public static func == (lhs: DisplayedCountry, rhs: DisplayedCountry) -> Bool {
        return (lhs.name == rhs.name)
    }
    static func < (lhs: DisplayedCountry, rhs: DisplayedCountry) -> Bool {
        return (lhs.name < rhs.name)
    }

}

class WifiAccessPointViewController: UITableViewController, DeviceViewController {

    @IBOutlet weak var environmentCell: UITableViewCell!
    @IBOutlet weak var countryCell: UITableViewCell!
    @IBOutlet weak var channelCell: UITableViewCell!
    @IBOutlet weak var securityCell: UITableViewCell!

    @IBOutlet weak var environment: UILabel!
    @IBOutlet weak var country: UILabel!
    @IBOutlet weak var channel: UILabel!
    @IBOutlet weak var ssid: UITextField!
    @IBOutlet weak var security: UILabel!
    @IBOutlet weak var autoSelectBt: UIButton!

    private let groundSdk = GroundSdk()
    private var deviceUid: String?
    private var wifiAccessPoint: Ref<WifiAccessPoint>?

    private var passwordOkAction: UIAlertAction?

    func setDeviceUid(_ uid: String) {
        deviceUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let peripheralProvider: PeripheralProvider?
        if let drone = groundSdk.getDrone(uid: deviceUid!) {
            peripheralProvider = drone
        } else if let remoteControl = groundSdk.getRemoteControl(uid: deviceUid!) {
            peripheralProvider = remoteControl
        } else {
            peripheralProvider = nil
        }

        if let peripheralProvider = peripheralProvider {
            wifiAccessPoint =
                peripheralProvider.getPeripheral(Peripherals.wifiAccessPoint) { [unowned self] wifiAccessPoint in
                    if let wifiAccessPoint = wifiAccessPoint {
                        if wifiAccessPoint.environment.mutable {
                            self.environmentCell.isUserInteractionEnabled = true
                            self.environmentCell.accessoryType = .disclosureIndicator
                        } else {
                            self.environmentCell.isUserInteractionEnabled = false
                            self.environmentCell.accessoryType = .none
                        }

                        if !wifiAccessPoint.availableCountries.isEmpty &&
                            wifiAccessPoint.availableCountries != [wifiAccessPoint.isoCountryCode.value] {
                            self.countryCell.isUserInteractionEnabled = true
                            self.countryCell.accessoryType = .disclosureIndicator
                        } else {
                            self.countryCell.isUserInteractionEnabled = false
                            self.countryCell.accessoryType = .none
                        }

                        if !wifiAccessPoint.security.supportedModes.isEmpty &&
                            wifiAccessPoint.security.supportedModes != [wifiAccessPoint.security.mode] {
                            self.securityCell.isUserInteractionEnabled = true
                            self.securityCell.accessoryType = .disclosureIndicator
                        } else {
                            self.securityCell.isUserInteractionEnabled = false
                            self.securityCell.accessoryType = .none
                        }

                        if !wifiAccessPoint.channel.availableChannels.isEmpty &&
                            wifiAccessPoint.channel.availableChannels != [wifiAccessPoint.channel.channel] {
                            self.channelCell.isUserInteractionEnabled = true
                            self.channelCell.accessoryType = .disclosureIndicator
                        } else {
                            self.channelCell.isUserInteractionEnabled = false
                            self.channelCell.accessoryType = .none
                        }

                        self.environment.text = wifiAccessPoint.environment.value.description
                        self.country.text = Locale.current.localizedString(
                            forRegionCode: wifiAccessPoint.isoCountryCode.value)
                        self.channel.text = wifiAccessPoint.channel.channel.description
                        self.ssid.text = wifiAccessPoint.ssid.value
                        self.security.text = wifiAccessPoint.security.mode.description

                        self.autoSelectBt.isEnabled = wifiAccessPoint.channel.canAutoSelect() ||
                            wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz) ||
                            wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz)
                    } else {
                        self.performSegue(withIdentifier: "exit", sender: self)
                    }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? WifiAccessPointSettingViewController,
            let identifier = segue.identifier, let wifiAccessPoint = wifiAccessPoint?.value {
            switch identifier {
            case "environmentSegue":
                viewController.dataSource = [Environment.indoor, Environment.outdoor]
                viewController.selectedValue = wifiAccessPoint.environment.value.description
                viewController.itemDidSelect = { [unowned self] value in
                    self.wifiAccessPoint?.value?.environment.value = value as! Environment
                }

            case "countrySegue":
                viewController.dataSource = self.sortedCountriesList(isoCodes: wifiAccessPoint.availableCountries)
                viewController.selectedValue = DisplayedCountry(
                    isoCode: wifiAccessPoint.isoCountryCode.value).description
                viewController.itemDidSelect = { [unowned self] countrySelected in
                    let countrySelected = countrySelected as! DisplayedCountry
                    self.wifiAccessPoint?.value?.isoCountryCode.value = countrySelected.isoCode
                }
            case "channelSegue":
                viewController.dataSource =
                    wifiAccessPoint.channel.availableChannels.sorted(by: { (channel1, channel2) -> Bool in
                        return channel1.rawValue < channel2.rawValue
                    })
                viewController.selectedValue = wifiAccessPoint.channel.channel.description
                viewController.itemDidSelect = { [unowned self] value in
                    self.wifiAccessPoint?.value?.channel.select(channel: value as! WifiChannel)
                }
            case "securitySegue":
                viewController.dataSource = wifiAccessPoint.security.supportedModes.map { $0 }
                viewController.selectedValue = wifiAccessPoint.security.mode.description
                viewController.itemDidSelect = { [unowned self] value in
                    switch value as! SecurityMode {
                    case .open:
                        self.wifiAccessPoint?.value?.security.open()
                    case .wpa2Secured:
                        self.showPasswordInput()
                    }
                }
            default:
                break
            }
        }
    }

    @IBAction func autoSelect(_ sender: UIButton) {
        let alert = UIAlertController(title: "Auto select",
                                      message: "Choose the band on which the autoselection will be done",
                                      preferredStyle: .actionSheet)
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
        }
        if let wifiAccessPoint = wifiAccessPoint?.value {
            if wifiAccessPoint.channel.canAutoSelect() {
                alert.addAction(
                    UIAlertAction(
                    title: ChannelSelectionMode.autoAnyBand.description, style: .default) { [unowned self] _ in
                        self.wifiAccessPoint?.value?.channel.autoSelect()
                })
            }
            if wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz) {
                alert.addAction(
                    UIAlertAction(
                    title: ChannelSelectionMode.auto2_4GhzBand.description, style: .default) { [unowned self] _ in
                        self.wifiAccessPoint?.value?.channel.autoSelect(onBand: .band_2_4_Ghz)
                })
            }
            if wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz) {
                alert.addAction(
                    UIAlertAction(
                    title: ChannelSelectionMode.auto5GhzBand.description, style: .default) { [unowned self] _ in
                        self.wifiAccessPoint?.value?.channel.autoSelect(onBand: .band_5_Ghz)
                })
            }
        }
        present(alert, animated: true, completion: nil)
    }

    @IBAction func showPasswordInput() {
        let alert = UIAlertController(title: "Password", message: "", preferredStyle: .alert)
        alert.addTextField { passwdTextField in
            passwdTextField.addTarget(self, action: #selector(self.passwordDidChange(_:)), for: .editingChanged)
        }
        passwordOkAction = UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            if let password = alert.textFields?[0].text {
                _ = self?.wifiAccessPoint?.value?.security.secureWithWpa2(password: password)
            }
        })
        if let passwordOKAction = self.passwordOkAction {
            passwordOKAction.isEnabled = false
            alert.addAction(passwordOKAction)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc
    func passwordDidChange(_ textField: UITextField) {
        if WifiPasswordUtil.isValid(textField.text ?? "") {
            self.passwordOkAction?.isEnabled = true
            textField.textColor = UIColor.blue
        } else {
            self.passwordOkAction?.isEnabled = false
            textField.textColor = UIColor.red
        }
    }

    private func sortedCountriesList(isoCodes: Set<String> ) -> [DisplayedCountry] {
        return isoCodes.map { DisplayedCountry(isoCode: $0) }.sorted { $0 < $1 }
    }
}

extension WifiAccessPointViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let ssid = textField.text {
            wifiAccessPoint?.value?.ssid.value = ssid
        } else {
            ssid.text = wifiAccessPoint?.value?.ssid.value
        }
        return true
    }
}
