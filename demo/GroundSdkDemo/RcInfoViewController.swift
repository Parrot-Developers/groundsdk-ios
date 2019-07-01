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

class RcInfoViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, DeviceViewController {

    @IBOutlet weak var modelLabel: UILabel!
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var forgetButton: UIButton!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var appActionLabel: UILabel!

    private let groundSdk = GroundSdk()
    internal var rcUid: String?
    private var remoteControl: RemoteControl?
    private var nameRef: Ref<String>?
    private var stateRef: Ref<DeviceState>?

    private var notificationCenterObserver: Any?

    private let sections = ["Instruments", "Peripheral"]
    private let instrumentSection = 0
    private let peripheralSection = 1

    private enum ToastState {
        case hidden
        case showing
        case shown
        case hidding
    }

    private var appActionLabelState = ToastState.hidden
    private var appActionHideTimer: Timer?

    private var cells = [[DeviceContentCell](), [DeviceContentCell]()]

    func setDeviceUid(_ uid: String) {
        rcUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        appActionLabel.isHidden = true

        if let rcUid = self.rcUid {
            remoteControl = groundSdk.getRemoteControl(uid: rcUid) { [weak self] _ in
                _ = self?.navigationController?.popViewController(animated: true)
            }
        }
        // get the drone
        if let remoteControl = remoteControl {
            // header
            modelLabel.text = remoteControl.model.description
            nameRef = remoteControl.getName {[unowned self] name in
                self.title = name!
            }
            stateRef = remoteControl.getState {[unowned self] state in
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
            addCell("batteryInfo", section: instrumentSection)
            addCell("compass", section: instrumentSection)
            // Peripheral
            addCell("dronefinder", section: peripheralSection)
            addCell("virtualGamepad", section: peripheralSection)
            addCell("skyCtrl3Gamepad", section: peripheralSection)
            addCell("systemInfo", section: peripheralSection)
            addCell("updater", section: peripheralSection)
            addCell("crashReporter", section: peripheralSection)
            addCell("flightLogDownloader", section: peripheralSection)
            addCell("wifiAccessPoint", section: peripheralSection)
            addCell("magnetometer", section: peripheralSection)
            addCell("copilot", section: peripheralSection)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if remoteControl == nil {
            _ = self.navigationController?.popViewController(animated: animated)
        }
        notificationCenterObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GsdkActionGamepadAppAction, object: nil, queue: nil,
            using: { [unowned self] notification in
                if self.appActionLabelState == .hidden {
                    self.appActionLabel.isHidden = false
                    self.appActionLabel.frame.origin.y = self.view.frame.size.height
                } else if self.appActionLabelState == .hidding {
                    self.appActionLabel.layer.removeAllAnimations()
                }

                // set the text
                let appAction = notification.userInfo?[GsdkActionGamepadAppActionKey] as! ButtonsMappableAction
                self.appActionLabel.text = "App action received: \(appAction.description)"

                // delay the hidding operation
                if let appActionHideTimer = self.appActionHideTimer {
                    appActionHideTimer.invalidate()
                }
                self.appActionHideTimer = Timer.scheduledTimer(
                    timeInterval: 2.0, target: self, selector: #selector(self.hideAppActionLabel), userInfo: nil,
                    repeats: false)

                // show if it is in state hidden or hidding
                if self.appActionLabelState == .hidden || self.appActionLabelState == .hidding {
                    self.appActionLabelState = .showing
                    UIView.animate(withDuration: 0.7, delay: 0.0, options: .curveEaseIn, animations: {
                        self.appActionLabel.frame.origin.y =
                            self.view.frame.size.height - self.appActionLabel.frame.size.height
                    }, completion: { _ in
                        self.appActionLabelState = .shown
                    })
                }
        })
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let notificationCenterObserver = notificationCenterObserver {
            NotificationCenter.default.removeObserver(notificationCenterObserver)
        }
    }

    @objc
    private func hideAppActionLabel() {
        self.appActionLabelState = .hidding
        UIView.animate(withDuration: 0.7, delay: 0.0, options: .curveEaseOut, animations: {
            self.appActionLabel.frame.origin.y = self.view.frame.size.height
        }, completion: { finished in
            if finished {
                self.appActionLabelState = .hidden
                self.appActionLabel.isHidden = true
            }
        })
    }

    private func addCell(_ identifier: String, section: Int) {
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
        if let cell = cell as? DeviceContentCell {
            if let instrumentCell = cell as? InstrumentProviderContentCell {
                instrumentCell.initContent(provider: remoteControl!, tableView: tableView)
            } else if let peripheralCell = cell as? PeripheralProviderContentCell {
                peripheralCell.initContent(provider: remoteControl!, tableView: tableView)
            }

            // cell-type specific actions
            if let magnetometerCell = cell as? MagnetometerCell {
                magnetometerCell.viewController = self
            }

            cells[section].append(cell)
        }
    }

    @IBAction func forget(_ sender: UIButton) {
        _ = remoteControl?.forget()
    }

    @IBAction func connectDisconnect(_ sender: UIButton) {
        if let connectionState = stateRef?.value?.connectionState {
            if connectionState == DeviceState.ConnectionState.disconnected {
                _ = remoteControl?.connect()
            } else {
                _ = remoteControl?.disconnect()
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if let viewController = ((segue.destination as? UINavigationController)?.topViewController
            ?? segue.destination) as? DeviceViewController, let rcUid = rcUid {
            viewController.setDeviceUid(rcUid)
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
