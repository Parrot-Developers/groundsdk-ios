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

/// A view controller that can modify the rendering
class ThermalRenderingViewController: UIViewController {

    @IBOutlet weak var blendingRateLabel: UILabel!
    @IBOutlet weak var blendingRateSlider: UISlider!

    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!

    private let groundSdk = GroundSdk()
    private var thermalControl: Ref<ThermalControl>?
    private var droneUid: String!

    private var isEditingLevel = false

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        blendingRateSlider.minimumValue = 0.0
        blendingRateSlider.maximumValue = 1.0
        set(blendingRate: 0.0)
        modeSegmentedControl.removeAllSegments()
        modeSegmentedControl.insertSegment(withTitle: "Visible", at: 0, animated: false)
        modeSegmentedControl.insertSegment(withTitle: "Thermal", at: 1, animated: false)
        modeSegmentedControl.insertSegment(withTitle: "Blended", at: 2, animated: false)
        modeSegmentedControl.insertSegment(withTitle: "Monochrome", at: 3, animated: false)
        modeSegmentedControl.selectedSegmentIndex = 0
        if let drone = groundSdk.getDrone(uid: droneUid) {
            thermalControl = drone.getPeripheral(Peripherals.thermalControl) { [weak self] thermalControl in
                if thermalControl == nil, let `self` = self {
                    self.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    private func set(blendingRate: Double) {
        blendingRateSlider.value = Float(blendingRate)
        blendingRateSlider.sendActions(for: .valueChanged)
    }

    @IBAction func blendingRateDidChange(_ sender: UISlider) {
        blendingRateLabel.text = String(sender.value)
        sendCommandRendering()
    }

    @IBAction func modeDidChange(_ sender: UISegmentedControl) {
        sendCommandRendering()
    }

    private func sendCommandRendering() {
        var mode: ThermalRenderingMode
        switch modeSegmentedControl.selectedSegmentIndex {
        case 0:
            mode = .visible
        case 1:
            mode = .thermal
        case 2:
            mode = .blended
        case 3:
            mode = .monochrome
        default:
            mode = .visible
        }
        let rendering: ThermalRendering = ThermalRendering(mode: mode,
                                                           blendingRate: Double(blendingRateSlider.value))
        thermalControl?.value?.sendRendering(rendering: rendering)
    }
}
