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

class DevToolboxCell: PeripheralProviderContentCell {

    @IBOutlet weak var debugSettingsCount: UILabel!
    @IBOutlet weak var latestDebugTagId: UILabel!
    private var devToolbox: Ref<DevToolbox>?

    var viewController: UIViewController?

    override func set(peripheralProvider: PeripheralProvider) {
        super.set(peripheralProvider: peripheralProvider)
        devToolbox = peripheralProvider.getPeripheral(Peripherals.devToolbox) { [unowned self] devToolbox in
            if devToolbox != nil {
                self.debugSettingsCount.text = devToolbox?.debugSettings.count.description
                self.latestDebugTagId.text = devToolbox?.latestDebugTagId?.description ?? "-"
                self.show()
            } else {
                self.hide()
            }
        }
    }

    @IBAction func sendDebugTag(_ sender: UIButton) {
        let alert = UIAlertController(title: "Debug tag", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "Enter debug tag here..."
        })

        alert.addAction(UIAlertAction(title: "Send", style: .default, handler: { [unowned self] _ in
            if let debugTag = alert.textFields?.first?.text {
                self.devToolbox?.value?.sendDebugTag(tag: debugTag)
            }
        }))
        if let presenter = alert.popoverPresentationController {
            presenter.sourceView = self
            presenter.sourceRect = self.bounds
        }

        viewController?.present(alert, animated: true)
    }
}
