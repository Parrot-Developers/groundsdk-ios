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

class GeofenceCell: PeripheralProviderContentCell {

    private var geofence: Ref<Geofence>?

    @IBOutlet weak var modeValue: UILabel!
    @IBOutlet weak var maxAltitudeValue: UILabel!
    @IBOutlet weak var maxDistanceValue: UILabel!
    @IBOutlet weak var latitudeValue: UILabel!
    @IBOutlet weak var longitudeValue: UILabel!

    override func set(peripheralProvider provider: PeripheralProvider) {
        super.set(peripheralProvider: provider)
        geofence = provider.getPeripheral(Peripherals.geofence) { [unowned self] geofence in
            if let geofence = geofence {
                self.modeValue.text = geofence.mode.value.description
                self.maxAltitudeValue.text = geofence.maxAltitude.displayString
                self.maxDistanceValue.text = geofence.maxDistance.displayString
                if let center = geofence.center {
                    self.latitudeValue.text = center.coordinate.latitude.description
                    self.longitudeValue.text = center.coordinate.longitude.description
                } else {
                    self.latitudeValue.text = "-"
                    self.longitudeValue.text = "-"
                }
                self.show()
            } else {
                self.hide()
            }
        }
    }
}
