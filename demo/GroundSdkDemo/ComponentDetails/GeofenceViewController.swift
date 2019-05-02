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

class GeofenceViewController: UIViewController, DeviceViewController {

    @IBOutlet weak var maxAltitudeView: NumSettingView!
    @IBOutlet weak var maxDistanceView: NumSettingView!

    @IBOutlet weak var modeView: UISegmentedControl!

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var geofence: Ref<Geofence>?

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let drone = groundSdk.getDrone(uid: droneUid!) {
            geofence = drone.getPeripheral(Peripherals.geofence) { [weak self] geofence in
                if let geofence = geofence {
                    self?.maxAltitudeView.updateWith(doubleSetting: geofence.maxAltitude)
                    self?.maxDistanceView.updateWith(doubleSetting: geofence.maxDistance)
                    self?.modeView.selectedSegmentIndex = geofence.mode.value.rawValue
                    self?.modeView.isEnabled = true
                } else {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    @IBAction func maxAltitudeDidChange(_ sender: NumSettingView) {
        geofence?.value?.maxAltitude.value = Double(sender.value)
    }

    @IBAction func maxDistanceDidChange(_ sender: NumSettingView) {
        geofence?.value?.maxDistance.value = Double(sender.value)
    }

    @IBAction func modeDidChange(_ sender: AnyObject) {
        if let mode = GeofenceMode(rawValue: sender.selectedSegmentIndex) {
            geofence?.value?.mode.value = mode
        }
    }
}
