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

class SkyCtrl3GamepadCell: PeripheralProviderContentCell {
    @IBOutlet var supportedModels: UILabel!
    @IBOutlet var grabbedButtons: UILabel!
    @IBOutlet var grabbedAxes: UILabel!
    @IBOutlet var grabbedButtonsState: UILabel!
    @IBOutlet var buttonEvtListener: UILabel!
    @IBOutlet var axisEvtListener: UILabel!
    @IBOutlet var volatileMapping: UILabel!
    @IBOutlet var volatileMappingButton: UIButton!

    private var skyCtrl3Gamepad: Ref<SkyCtrl3Gamepad>?

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        selectionStyle = .none
        self.buttonEvtListener.text = "-"
        self.axisEvtListener.text = "-"

        skyCtrl3Gamepad = provider.getPeripheral(
        Peripherals.skyCtrl3Gamepad) { [weak self] skyCtrl3Gamepad in
            if let skyCtrl3Gamepad = skyCtrl3Gamepad {
                self?.show()

                // supported models
                let modelsAsStr = skyCtrl3Gamepad.supportedDroneModels.map({
                    return NSAttributedString(
                        string: $0.description + " ",
                        attributes: ($0 == skyCtrl3Gamepad.activeDroneModel) ?
                            [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)] :
                        nil)
                })
                self?.supportedModels.attributedText = modelsAsStr.reduce(NSMutableAttributedString(string: ""), {
                    $0.append($1)
                    return $0
                })

                // listeners for grabbed events
                if !skyCtrl3Gamepad.grabbedButtons.isEmpty && skyCtrl3Gamepad.buttonEventListener == nil {
                    skyCtrl3Gamepad.buttonEventListener = {
                        [weak self] event, state in
                        self?.buttonEvtListener.text = event.description + ": " + state.description
                    }
                }
                if !skyCtrl3Gamepad.grabbedAxes.isEmpty && skyCtrl3Gamepad.axisEventListener == nil {
                    skyCtrl3Gamepad.axisEventListener = { [weak self] event, value in
                        self?.axisEvtListener.text = event.description + ": " + value.description
                    }
                }

                // grabbed inputs
                self?.grabbedButtons.text = skyCtrl3Gamepad.grabbedButtons.map({ $0.description }).description
                self?.grabbedAxes.text = skyCtrl3Gamepad.grabbedAxes.map({ $0.description }).description

                // grabbed events
                let grabbedEventsAsStr = skyCtrl3Gamepad.grabbedButtonsState.map({ event, state in
                    return NSAttributedString(
                        string: event.description + " ",
                        attributes: (state == .pressed) ?
                            [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)] :
                        nil)
                })
                self?.grabbedButtonsState.attributedText =
                    grabbedEventsAsStr.reduce(NSMutableAttributedString(string: ""), {
                        $0.append($1)
                        return $0
                    })
                if let state = skyCtrl3Gamepad.volatileMappingSetting?.value {
                    self?.volatileMapping.text = state ? "activated" : "Not activated"
                    self?.volatileMappingButton.isHidden = false
                    self?.volatileMapping.text = !state ? "Activate" : "Deactivate"
                } else {
                    self?.volatileMapping.text = "Not supported"
                    self?.volatileMappingButton.isHidden = true
                }
            } else {
                self?.hide()
                self?.supportedModels.text = "-"
                self?.grabbedButtons.text = "-"
                self?.grabbedAxes.text = "-"
                self?.grabbedButtonsState.text = "-"
                self?.buttonEvtListener.text = "-"
                self?.axisEvtListener.text = "-"
                self?.volatileMapping.text = ""
            }
        }
    }

    private func resetEventsListeners() {
        if let skyCtrl3Gamepad = skyCtrl3Gamepad?.value {
            skyCtrl3Gamepad.buttonEventListener = nil
            buttonEvtListener.text = "-"
            skyCtrl3Gamepad.axisEventListener = nil
            axisEvtListener.text = "-"
        }
    }

    override func prepareForReuse() {
        resetEventsListeners()
    }

    deinit {
        resetEventsListeners()
    }

    @IBAction func volatileMappingAction(_ sender: UIButton) {
        if let state = skyCtrl3Gamepad?.value?.volatileMappingSetting?.value {
            skyCtrl3Gamepad?.value?.volatileMappingSetting!.value = state
        }
    }
}
