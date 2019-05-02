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

import GroundSdk
import UIKit

class AutoConnectionCell: FacilityCell {

    @IBOutlet weak var state: UILabel!
    @IBOutlet weak var drone: UILabel!
    @IBOutlet weak var rc: UILabel!
    @IBOutlet weak var startStopBt: UIButton!

    private var autoConnection: Ref<AutoConnection>?

    override func initContent(tableView: UITableView) {
        super.initContent(tableView: tableView)

        autoConnection = groundSdk.getFacility(Facilities.autoConnection) { [weak self] autoConnection in
            if let autoConnection = autoConnection {
                self?.show()
                self?.state.text = autoConnection.state.description
                if autoConnection.state == .started {
                    self?.startStopBt.setTitle("Stop", for: .normal)
                    self?.drone.text = autoConnection.drone?.name ?? "none"
                    self?.rc.text = autoConnection.remoteControl?.name ?? "none"
                } else {
                    self?.startStopBt.setTitle("Start", for: .normal)
                    self?.drone.text = "-"
                    self?.rc.text = "-"
                }
            } else {
                self?.hide()
            }
        }
    }

    @IBAction func startStopAutoConnection(_ sender: UIButton) {
        if let autoConnection = autoConnection?.value {
            if autoConnection.state == .started {
                autoConnection.stop()
            } else {
                autoConnection.start()
            }
        }
    }
}
