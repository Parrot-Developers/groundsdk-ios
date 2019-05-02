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

class DroneFinderViewController: UITableViewController, DeviceViewController {

    private let groundSdk = GroundSdk()
    private var rcUid: String?
    private var droneFinder: Ref<DroneFinder>?
    private var droneList: [DiscoveredDrone]?

    func setDeviceUid(_ uid: String) {
        rcUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let remoteControl = groundSdk.getRemoteControl(uid: rcUid!) {
            droneFinder = remoteControl.getPeripheral(Peripherals.droneFinder) { [weak self] droneFinder in
                if let droneFinder = droneFinder {
                    if droneFinder.state != .scanning {
                        self?.droneList = droneFinder.discoveredDrones
                        self?.tableView.reloadData()
                        self?.refreshControl?.endRefreshing()
                    }
                } else {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        refreshControl?.beginRefreshing()
        droneList?.removeAll()
        droneFinder?.value?.refresh()
    }

    override func viewDidDisappear(_ animated: Bool) {
        droneFinder?.value?.clear()
    }

    @IBAction func refresh(_ sender: AnyObject) {
        droneFinder?.value?.refresh()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DiscoveredDrone", for: indexPath)
        if let entry = droneList?[indexPath.row] {
            cell.textLabel?.text = entry.name
            cell.detailTextLabel?.text =
                "\(entry.uid) \(entry.model) \(entry.known ? "Known" : "") " +
                "\(entry.rssi) dBm \(entry.connectionSecurity.description)"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let droneInfo = droneList?[indexPath.row] {
            switch droneInfo.connectionSecurity {
            case .none,
                 .savedPassword:
                _ = droneFinder?.value?.connect(discoveredDrone: droneInfo, password: "")
            case .password:
                let alert = UIAlertController(title: "Password", message: "", preferredStyle: .alert)
                alert.addTextField(configurationHandler: nil)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                    if let password = alert.textFields?[0].text {
                        _ = self?.droneFinder?.value?.connect(discoveredDrone: droneInfo, password: password)
                    }
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return droneList?.count ?? 0
    }

}
