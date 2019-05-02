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

class DevicesListViewController: UITableViewController, UISplitViewControllerDelegate {

    private let droneInfoSegue = "DroneInfoSegue"
    private let rcInfoSegue = "RcInfoSegue"
    @IBOutlet private weak var version: UILabel!

    private let groundSdk = GroundSdk()
    private var rcListRef: Ref<[RemoteControlListEntry]>!
    private var rcList: [RemoteControlListEntry]?
    private var droneListRef: Ref<[DroneListEntry]>!
    private var droneList: [DroneListEntry]?

    private var selectedUid: String?

    private let rcSection = 0
    private let droneSection = 1

    private let boldFont = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)

    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.delegate = self
        splitViewController?.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
        rcListRef = groundSdk.getRemoteControlList(
            observer: {  [unowned self] entryList in
                self.rcList = entryList
                self.tableView.reloadData()
        })
        droneListRef = groundSdk.getDroneList(
            observer: { [unowned self] entryList in
                self.droneList = entryList
                self.tableView.reloadData()
        })
        version.text = "version: \(AppInfoCore.sdkVersion)"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DroneCell", for: indexPath)
        if let cell = cell as? DeviceCell {
            switch indexPath.section {
            case rcSection:
                if let rcEntry = self.rcList?[indexPath.row] {
                    cell.name.text = rcEntry.name
                    cell.uid.text = rcEntry.uid
                    cell.model.text = rcEntry.model.description
                    let state = rcEntry.state
                    cell.connectionState.text =
                        "\(state.connectionState.description)-\(state.connectionStateCause.description)"
                    cell.connectors.attributedText = formatConnectors(
                        state.connectors, activeConnector: state.activeConnector)
                }
            case droneSection:
                if let droneEntry =  self.droneList?[indexPath.row] {
                    cell.name.text = droneEntry.name
                    cell.uid.text = droneEntry.uid
                    cell.model.text = droneEntry.model.description
                    let state = droneEntry.state
                    cell.connectionState.text =
                        "\(state.connectionState.description)-\(state.connectionStateCause.description)"

                    cell.connectors.attributedText = formatConnectors(
                        state.connectors, activeConnector: state.activeConnector)
                }
            default:
                break
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case rcSection:
            if let rcEntry = self.rcList?[indexPath.row] {
                selectedUid = rcEntry.uid
                performSegue(withIdentifier: rcInfoSegue, sender: self)
            }
        case droneSection:
            if let droneEntry = self.droneList?[indexPath.row] {
                selectedUid = droneEntry.uid
                performSegue(withIdentifier: droneInfoSegue, sender: self)
            }
        default:
            break
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case rcSection: return "Remote Controls"
        case droneSection: return "Drones"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case rcSection: return rcList?.count ?? 0
        case droneSection: return droneList?.count ?? 0
        default: return 0
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == droneInfoSegue ||  segue.identifier == rcInfoSegue {
            if let viewController = segue.destination as? DeviceViewController,
                let selectedUid = selectedUid {
                viewController.setDeviceUid(selectedUid)
            }
        }
    }

    // MARK: - UISplitViewControllerDelegate
    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
        return true
    }

    private func formatConnectors(
        _ connectors: [DeviceConnector], activeConnector: DeviceConnector?) -> NSAttributedString {

        let connectorsStr = connectors.debugDescription
        let connectorsAttrStr = NSMutableAttributedString(string: connectorsStr)
        if let activeConnector = activeConnector,
            let activeConnectorRange = connectorsStr.range(of: activeConnector.description) {
            let activeConnectorNSRange = NSRange(activeConnectorRange, in: connectorsStr)
            connectorsAttrStr.addAttribute(NSAttributedString.Key.font, value: boldFont, range: activeConnectorNSRange)
        }
        return connectorsAttrStr
    }

}

@objc(DeviceCell)
private class DeviceCell: UITableViewCell {
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var model: UILabel!
    @IBOutlet weak var uid: UILabel!
    @IBOutlet weak var connectionState: UILabel!
    @IBOutlet weak var connectors: UILabel!
}
