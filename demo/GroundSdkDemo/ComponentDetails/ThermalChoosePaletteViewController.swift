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

/// A view controller to select the palette type
class ThermalChoosePaletteViewController: UIViewController {
    @IBOutlet weak var absolutePaletteButton: UIButton!
    @IBOutlet weak var relativePaletteButton: UIButton!
    @IBOutlet weak var spotPaletteButton: UIButton!

    private let groundSdk = GroundSdk()
    private var thermalControl: Ref<ThermalControl>?
    private var droneUid: String!
    private var paletteChosen: String?

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        absolutePaletteButton.layer.cornerRadius = 0.5 * absolutePaletteButton.bounds.size.height
        absolutePaletteButton.clipsToBounds = true
        absolutePaletteButton.layer.borderWidth = 1
        absolutePaletteButton.layer.borderColor = absolutePaletteButton.tintColor.cgColor

        relativePaletteButton.layer.cornerRadius = 0.5 * relativePaletteButton.bounds.size.height
        relativePaletteButton.clipsToBounds = true
        relativePaletteButton.layer.borderWidth = 1
        relativePaletteButton.layer.borderColor = relativePaletteButton.tintColor.cgColor

        spotPaletteButton.layer.cornerRadius = 0.5 * spotPaletteButton.bounds.size.height
        spotPaletteButton.clipsToBounds = true
        spotPaletteButton.layer.borderWidth = 1
        spotPaletteButton.layer.borderColor = spotPaletteButton.tintColor.cgColor
        self.title = "Choose your type of palette"
        if let drone = groundSdk.getDrone(uid: droneUid) {
            thermalControl = drone.getPeripheral(Peripherals.thermalControl) { [weak self] thermalControl in
                if thermalControl == nil, let `self` = self {
                    self.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editColorPalette" {
            (segue.destination as! ThermalPaletteViewController).setDeviceUid(droneUid!)
            (segue.destination as! ThermalPaletteViewController).setPalette(paletteChosen!)
            (segue.destination as! ThermalPaletteViewController).title = paletteChosen
        }
    }

    @IBAction func touchUpInside(_ sender: UIButton) {
        if sender == absolutePaletteButton {
            paletteChosen = "absolute"
        } else if sender == relativePaletteButton {
            paletteChosen = "relative"
        } else if sender == spotPaletteButton {
            paletteChosen = "spot"
        }
        performSegue(withIdentifier: "editColorPalette", sender: self)
    }
}
