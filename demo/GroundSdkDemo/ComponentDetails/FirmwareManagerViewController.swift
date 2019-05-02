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

class FirmwareManagerViewController: UITableViewController {

    private let groundSdk = GroundSdk()
    private var firmwareManagerRef: Ref<FirmwareManager>?
    private var dataSource: [FirmwareManagerEntry] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        firmwareManagerRef = groundSdk.getFacility(Facilities.firmwareManager) { [unowned self] firmwareManager in
            if let firmwareManager = firmwareManager, let refreshControl = self.refreshControl {
                if firmwareManager.isQueryingRemoteUpdates {
                    refreshControl.beginRefreshing()
                } else {
                    refreshControl.endRefreshing()
                }
                self.dataSource = firmwareManager.firmwares
                self.tableView.reloadData()
            }
        }

        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FirmwareManagerCell", for: indexPath)
        if let cell = cell as? UpdateInfoCell {
            cell.update(withEntry: dataSource[indexPath.row])
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }

    @objc(refresh)
    public func refresh() {
        let queryIsRunning = firmwareManagerRef?.value?.queryRemoteUpdates() ?? false
        if !queryIsRunning {
            refreshControl?.endRefreshing()
        }
    }
}

@objc(UpdateInfoCell)
private class UpdateInfoCell: UITableViewCell {
    @IBOutlet weak var modelLabel: UILabel!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var downloadProgressLabel: UILabel!
    @IBOutlet weak var actionBt: UIButton!

    private var entry: FirmwareManagerEntry?

    func update(withEntry entry: FirmwareManagerEntry) {
        self.entry = entry
        let info = entry.info
        modelLabel.text = info.firmwareIdentifier.deviceModel.description
        versionLabel.text = info.firmwareIdentifier.version.description
        infoLabel.text = info.attributes.map { $0.description }.joined(separator: ", ")
        sizeLabel.text = ByteCountFormatter.string(fromByteCount: Int64(info.size), countStyle: .file)
        downloadProgressLabel.text = "\(entry.downloadProgress)%"

        actionBt.isEnabled = entry.state != .downloaded || entry.canDelete
        let actionStr: String
        switch entry.state {
        case .downloaded: actionStr = "Delete"
        case .downloading: actionStr = "Cancel"
        default: actionStr = "Download"
        }
        actionBt.setTitle(actionStr, for: .normal)
    }

    @IBAction func actionPushed(_ sender: Any) {
        if let entry = entry {
            switch entry.state {
            case .downloaded: _ = entry.delete()
            case .downloading: _ = entry.cancelDownload()
            default: _ = entry.download()
            }
        }
    }
}
