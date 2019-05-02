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

class UpdaterCell: PeripheralProviderContentCell {
    @IBOutlet weak var toDownloadLabel: UILabel!
    @IBOutlet weak var dlUnavailabilityReasonsLabel: UILabel!
    @IBOutlet weak var downloadingLabel: UILabel!

    @IBOutlet weak var toApplyLabel: UILabel!
    @IBOutlet weak var updateUnavailabilityReasonsLabel: UILabel!
    @IBOutlet weak var updatingLabel: UILabel!

    @IBOutlet weak var idealVersionLabel: UILabel!

    @IBOutlet weak var downloadBt: UIButton!
    @IBOutlet weak var updateBt: UIButton!

    private var firmwareUpdater: Ref<Updater>?

    private let groundSdk = GroundSdk()

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        selectionStyle = .none
        firmwareUpdater = provider.getPeripheral(Peripherals.updater) { [unowned self] firmwareUpdater in
            if let firmwareUpdater = firmwareUpdater {
                self.show()

                self.toDownloadLabel.text = firmwareUpdater.downloadableFirmwares
                    .map { $0.firmwareIdentifier.version.description }.joined(separator: ", ")
                self.dlUnavailabilityReasonsLabel.text = firmwareUpdater.downloadUnavailabilityReasons
                    .map { $0.description }.joined(separator: ", ")
                if let download = firmwareUpdater.currentDownload {
                    self.downloadingLabel.text = "\(download.currentFirmware.firmwareIdentifier.version)\n" +
                        "\(download.currentIndex) (\(download.currentProgress)%) / " +
                        "\(download.totalCount) (\(download.totalProgress)%)"
                } else {
                    self.downloadingLabel.text = "-"
                }

                self.toApplyLabel.text = firmwareUpdater.applicableFirmwares
                    .map { $0.firmwareIdentifier.version.description }.joined(separator: ", ")
                self.updateUnavailabilityReasonsLabel.text = firmwareUpdater.updateUnavailabilityReasons
                    .map { $0.description }.joined(separator: ", ")
                if let update = firmwareUpdater.currentUpdate {
                    self.updatingLabel.text = "\(update.currentFirmware.firmwareIdentifier.version)\n" +
                        "\(update.state.description)\n" +
                        "\(update.currentIndex) (\(update.currentProgress)%) / " +
                    "\(update.totalCount) (\(update.totalProgress)%)"
                } else {
                    self.updatingLabel.text = "-"
                }

                self.idealVersionLabel.text = firmwareUpdater.idealVersion?.description ?? "-"

                // button is enabled if there is at least one fw to download and there is no unavailability reasons
                // or if there is a current download (to be able to cancel it)
                self.downloadBt.isEnabled = (firmwareUpdater.downloadUnavailabilityReasons.isEmpty &&
                    !firmwareUpdater.downloadableFirmwares.isEmpty) || firmwareUpdater.currentDownload != nil
                self.downloadBt.setTitle(firmwareUpdater.currentDownload == nil ? "Download" : "Cancel", for: .normal)

                self.updateBt.isEnabled = (firmwareUpdater.updateUnavailabilityReasons.isEmpty &&
                    !firmwareUpdater.applicableFirmwares.isEmpty) || firmwareUpdater.currentUpdate != nil
                self.updateBt.setTitle(firmwareUpdater.currentUpdate == nil ? "Update" : "Cancel", for: .normal)
            } else {
                self.hide()
            }
        }
    }

    @IBAction func downloadBtPushed(_ sender: UIButton) {
        if let firmwareUpdater = firmwareUpdater?.value {
            if firmwareUpdater.currentDownload == nil {
                firmwareUpdater.downloadAllFirmwares()
            } else {
                firmwareUpdater.cancelDownload()
            }
        }
    }

    @IBAction func updateBtPushed(_ sender: UIButton) {
        if let firmwareUpdater = firmwareUpdater?.value {
            if firmwareUpdater.currentUpdate == nil {
                firmwareUpdater.updateToLatestFirmware()
            } else {
                firmwareUpdater.cancelUpdate()
            }
        }
    }
}
