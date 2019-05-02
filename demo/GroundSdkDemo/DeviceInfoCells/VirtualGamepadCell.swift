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

class VirtualGamepadCell: PeripheralProviderContentCell {
    @IBOutlet weak var isGrabbed: UILabel!
    @IBOutlet weak var isPreempted: UILabel!
    @IBOutlet weak var lastNavEvent: UILabel!
    @IBOutlet weak var grabReleaseBt: UIButton!
    private var virtualGamepad: Ref<VirtualGamepad>?

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        selectionStyle = .none
        virtualGamepad = provider.getPeripheral(Peripherals.virtualGamepad) { [unowned self] virtualGamepad in
            if let virtualGamepad = virtualGamepad {
                self.show()
                self.isGrabbed.text = virtualGamepad.isGrabbed ? "true" : "false"
                self.isPreempted.text = virtualGamepad.isPreempted ? "true" : "false"

                self.grabReleaseBt.isEnabled = true
                if virtualGamepad.isGrabbed {
                    self.grabReleaseBt.setTitle("Ungrab", for: UIControl.State.normal)
                } else {
                    self.grabReleaseBt.setTitle("Grab", for: UIControl.State.normal)
                    if virtualGamepad.isPreempted {
                        self.grabReleaseBt.isEnabled = false
                    }
                }
            } else {
                self.hide()
                self.isGrabbed.text = "-"
                self.isPreempted.text = "-"
                self.lastNavEvent.text = "-"
            }
        }
    }

    @IBAction func grabReleasePushed(_ sender: AnyObject) {
        if let virtualGamepad = virtualGamepad?.value {
            if !virtualGamepad.isGrabbed {
                _ = virtualGamepad.grab(listener: { [unowned self] event, state in
                    self.lastNavEvent.text = event.description + " " + state.description
                })
            } else {
                virtualGamepad.ungrab()
                self.lastNavEvent.text = "-"
            }
        }
    }
}
