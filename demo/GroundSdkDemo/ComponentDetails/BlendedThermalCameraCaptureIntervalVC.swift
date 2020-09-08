// Copyright (C) 2020 Parrot Drones SAS
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

class BlendedThermalCameraCaptureIntervalVC: UIViewController {
    @IBOutlet weak var gpslapseCaptureIntervalTitleLabel: UILabel!
    @IBOutlet weak var gpslapseCaptureIntervalValueLabel: UILabel!
    @IBOutlet weak var gpslapseCaptureIntervalSlider: UISlider!

    @IBOutlet weak var timelapseCaptureIntervalTitleLabel: UILabel!
    @IBOutlet weak var timelapseCaptureIntervalValueLabel: UILabel!
    @IBOutlet weak var timelapseCaptureIntervalSlider: UISlider!

    private let groundSdk = GroundSdk()
    private var camera: Ref<BlendedThermalCamera>?
    private var droneUid: String!
    private var cameraPhotoMode: CameraPhotoMode!

    private var isEditingLevel = false

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    func setMode(_ mode: CameraPhotoMode) {
        cameraPhotoMode = mode
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let drone = groundSdk.getDrone(uid: droneUid) {
            camera = drone.getPeripheral(Peripherals.blendedThermalCamera) { [weak self] _ in
                self?.gpslapseCaptureIntervalSlider.minimumValue = 0
                self?.gpslapseCaptureIntervalSlider.maximumValue = 100

                self?.timelapseCaptureIntervalSlider.minimumValue = 0
                self?.timelapseCaptureIntervalSlider.maximumValue = 100
                if self?.cameraPhotoMode == .gpsLapse {
                    self?.timelapseCaptureIntervalTitleLabel.isHidden = true
                    self?.timelapseCaptureIntervalValueLabel.isHidden = true
                    self?.timelapseCaptureIntervalSlider.isHidden = true
                } else if self?.cameraPhotoMode == .timeLapse {
                    self?.gpslapseCaptureIntervalTitleLabel.isHidden = true
                    self?.gpslapseCaptureIntervalValueLabel.isHidden = true
                    self?.gpslapseCaptureIntervalSlider.isHidden = true
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // only set the captureInterval slider value when the view will appear.
        // After that, we let it where the user placed it.
        if let photoSettings = camera?.value?.photoSettings {
            gpslapseCaptureIntervalTitleLabel.text = "Capture Interval (meters)"
            gpslapseCaptureIntervalSlider.minimumValue =
                Float(photoSettings.supportedGpslapseIntervals.lowerBound)
            gpslapseCaptureIntervalSlider.value = Float(photoSettings.gpslapseCaptureInterval)
            gpslapseCaptureIntervalValueLabel.text = String(photoSettings.gpslapseCaptureInterval)

            timelapseCaptureIntervalTitleLabel.text = "Capture Interval (seconds)"
            timelapseCaptureIntervalSlider.minimumValue =
                Float(photoSettings.supportedTimelapseIntervals.lowerBound)
            timelapseCaptureIntervalSlider.value = Float(photoSettings.timelapseCaptureInterval)
            timelapseCaptureIntervalValueLabel.text = String(photoSettings.timelapseCaptureInterval)

        }
    }

    @IBAction func captureIntervalTouchUpInside(_ sender: UISlider) {
        if sender == timelapseCaptureIntervalSlider {
            timelapseCaptureIntervalValueLabel.text = String(Double(sender.value).roundedToDecimal(2))
            camera?.value?.photoSettings.timelapseCaptureInterval = Double(sender.value).roundedToDecimal(2)
        } else {
            gpslapseCaptureIntervalValueLabel.text = String(Double(sender.value).roundedToDecimal(2))
            camera?.value?.photoSettings.gpslapseCaptureInterval = Double(sender.value).roundedToDecimal(2)
        }
    }

    @IBAction func captureIntervalValueChanged(_ sender: UISlider) {
        if sender == timelapseCaptureIntervalSlider {
            timelapseCaptureIntervalValueLabel.text = String(Double(sender.value).roundedToDecimal(2))
        } else {
            gpslapseCaptureIntervalValueLabel.text = String(Double(sender.value).roundedToDecimal(2))
        }
    }
}
