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

class ThermalStreamViewController: UIViewController, DeviceViewController {

    @IBOutlet weak var streamView: StreamView!
    @IBOutlet weak var thermalSwitch: UISwitch!
    @IBOutlet weak var enableStreamSwitch: UISwitch!

    @IBOutlet weak var cameraLivePlayPauseBtn: UIButton!
    @IBOutlet weak var cameraLivePlayStateLabel: UILabel!
    @IBOutlet weak var cameraLiveStateLabel: UILabel!

    @IBOutlet weak var mainCameraLabel: UILabel!
    @IBOutlet weak var thermalCameraLabel: UILabel!

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var streamServer: Ref<StreamServer>?
    private var thermalControl: Ref<ThermalControl>?
    private var cameraLive: Ref<CameraLive>?
    private var mainCamera: Ref<MainCamera>?
    private var thermalCamera: Ref<ThermalCamera>?

    var textureSpec = TextureSpec.fixedAspectRatio(ratioNumerator: 4, ratioDenominator: 3)
    var textureLoaderCnt = 0

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        initStream()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        deinitStream()
    }

    private func initStream() {
        if let drone = groundSdk.getDrone(uid: droneUid!) {
            streamServer = drone.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
                if let streamServer = streamServer {
                    self?.enableStreamSwitch.isOn = streamServer.enabled
                }
            }
            thermalControl = drone.getPeripheral(Peripherals.thermalControl) { [weak self] thermalControl in
                if let thermalControl = thermalControl {
                    print("thermalControl.setting  mode:", thermalControl.setting.mode,
                          " updating:", thermalControl.setting.updating)
                    self?.thermalSwitch.isEnabled = !thermalControl.setting.updating
                    self?.enableStreamSwitch.isEnabled = !thermalControl.setting.updating
                    self?.thermalSwitch.isOn = thermalControl.setting.mode == .standard
                }
            }

            // On the main Camera Events
            mainCamera = drone.getPeripheral(Peripherals.mainCamera) { [weak self] camera in
                if let camera = camera {
                    self?.mainCameraLabel.text = camera.isActive ? "On" : "Off"
                } else {
                    self?.mainCameraLabel.text = "nil"
                }

                // test if mainCamera is asked and if the stream is active
                if let thermalControl = self?.thermalControl, let streamServer = self?.streamServer,
                    let camera = camera,
                    // If stream is enabled
                    streamServer.value?.enabled == true,
                    // if the asked video is on the "Main Camera" (thermal is disabled)
                    thermalControl.value?.setting.mode == .disabled,
                    // if the main camera is active
                    camera.isActive == true,
                    // If the playstate is not .playing, call the play function
                    let cameraLiveRef = self?.cameraLive, let stream = cameraLiveRef.value, // if the stream
                    stream.playState  != .playing {
                        _ = stream.play()
                }
            }

            // On the thermal Camera Events
            thermalCamera = drone.getPeripheral(Peripherals.thermalCamera) { [weak self] camera in
                if let camera = camera {
                    self?.thermalCameraLabel.text = camera.isActive ? "On" : "Off"
                } else {
                    self?.thermalCameraLabel.text = "nil"
                }

                if let thermalControl = self?.thermalControl, let streamServer = self?.streamServer,
                    let camera = camera,
                    // If stream is enabled
                    streamServer.value?.enabled == true,
                    // if the asked video is on the "Thermal Camera" (thermal mode is .stadard))
                    thermalControl.value?.setting.mode == .standard,
                    // if the thermal camera is active
                    camera.isActive == true,
                    // If the playstate is not .playing, call the play function
                    let cameraLiveRef = self?.cameraLive, let stream = cameraLiveRef.value, // if the stream
                    stream.playState  != .playing {
                    _ = stream.play()
                }
            }
        }
        if let streamServer = streamServer {
            cameraLive = streamServer.value?.live { [weak self] stream in
                if let stream = stream {
                    self?.cameraLivePlayPauseBtn.setTitle(stream.playState == .playing ? "Pause" : "Play", for: .normal)
                    self?.cameraLiveStateLabel.text = stream.state.description
                    self?.cameraLivePlayStateLabel.text = stream.playState.description
                    self?.streamView.setStream(stream: stream)
                } else {
                    self?.cameraLiveStateLabel.text = "stream nil"
                    self?.cameraLivePlayStateLabel.text = "stream nil"
                }
            }
        }
    }

    private func deinitStream() {
        streamView.setStream(stream: nil)
        streamServer = nil
        cameraLive = nil
    }

    @IBAction func actionSwitchThermal(_ sender: UISwitch) {
        thermalControl?.value?.setting.mode = sender.isOn ? .standard : .disabled
    }

    @IBAction func startStream(_ sender: UISwitch) {
        streamServer?.value?.enabled = sender.isOn
    }

    @IBAction func playPauseCameraLive(_ sender: UIButton) {
        if let cameraLiveRef = cameraLive, let stream = cameraLiveRef.value {
            if stream.playState == .playing {
                _ = stream.pause()
            } else {
                _ = stream.play()
            }
        }
    }

    @IBAction func stopCameraLive(_ sender: UIButton) {
        if let cameraLive = cameraLive, cameraLive.value?.state != .stopped {
            cameraLive.value?.stop()
        }
    }
}

extension ThermalStreamViewController: TextureLoader {

    func loadTexture(width: Int, height: Int, frame: TextureLoaderFrame?) -> Bool {
        textureLoaderCnt += 1
        let colorLvl = Float(textureLoaderCnt % 256) / 256.0
        glClearColor(colorLvl, 1.0 - colorLvl, colorLvl, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        return true
    }
}
