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

class VideoStreamViewController: UIViewController, DeviceViewController {

    @IBOutlet weak var streamView: StreamView!
    @IBOutlet weak var zebraSwitch: UISwitch!
    @IBOutlet weak var startStreamSwitch: UISwitch!
    @IBOutlet weak var histogramsSwitch: UISwitch!
    @IBOutlet weak var lumaLabel: UILabel!
    @IBOutlet weak var scaleTypeView: UISegmentedControl!
    @IBOutlet weak var paddingFillView: UISegmentedControl!

    @IBOutlet weak var cameraLivePlayPauseBtn: UIButton!
    @IBOutlet weak var cameraLivePlayStateLabel: UILabel!
    @IBOutlet weak var cameraLiveStateLabel: UILabel!

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var streamServer: Ref<StreamServer>?
    private var cameraLive: Ref<CameraLive>?

    private var lastMaxIndex = 0

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        streamView.overlayer = self
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
                    self?.startStreamSwitch.isOn = streamServer.enabled
                }
            }
        }
        if let streamServer = streamServer {
            cameraLive = streamServer.value?.live { [weak self] stream in
                self?.cameraLivePlayPauseBtn.setTitle(stream?.playState == .playing ? "Pause" : "Play", for: .normal)
                self?.cameraLiveStateLabel.text = stream?.state.description
                self?.cameraLivePlayStateLabel.text = stream?.playState.description
                self?.streamView.setStream(stream: stream)
                self?.zebraSwitch.isOn = self?.streamView.zebrasEnabled ?? false
                self?.histogramsSwitch.isOn = self?.streamView.histogramsEnabled ?? false
                self?.scaleTypeView.selectedSegmentIndex = self?.streamView.renderingScaleType.rawValue ?? 0
                self?.paddingFillView.selectedSegmentIndex = self?.streamView.renderingPaddingFill.rawValue ?? 0
            }
        }

        zebraSwitch.isOn = streamView.zebrasEnabled
        histogramsSwitch.isOn = streamView.histogramsEnabled
    }

    private func deinitStream() {
        streamView.setStream(stream: nil)
        streamServer = nil
        cameraLive = nil
    }

    @IBAction func actionZebra(_ sender: UISwitch) {
        streamView.zebrasEnabled = sender.isOn
    }

    @IBAction func actionHistograms(_ sender: UISwitch) {
        streamView.histogramsEnabled = sender.isOn
    }

    @IBAction func startStream(_ sender: UISwitch) {
        streamServer?.value?.enabled = sender.isOn
        zebraSwitch.isOn = streamView.zebrasEnabled
        histogramsSwitch.isOn = streamView.histogramsEnabled
    }

    @IBAction func setScaleType(_ sender: UISegmentedControl) {
        streamView.renderingScaleType = StreamView.ScaleType(rawValue: sender.selectedSegmentIndex) ?? .crop
    }

    @IBAction func setPaddingFill(_ sender: UISegmentedControl) {
        streamView.renderingPaddingFill = StreamView.PaddingFill(rawValue: sender.selectedSegmentIndex) ?? .none
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

extension VideoStreamViewController: Overlayer {

    func overlay(renderPos: UnsafeRawPointer, contentPos: UnsafeRawPointer, histogram: Histogram?) {
        guard let histogram = histogram else {
            return
        }
        if let histogramLuma = histogram.histogramLuma {
            let maxIndex = histogramLuma.lastIndex(of: histogramLuma.max() ?? 0.0) ?? 0
            if maxIndex != lastMaxIndex {
                lastMaxIndex = maxIndex
                DispatchQueue.main.async { [weak self] in
                    self?.lumaLabel.text = maxIndex.description
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.lumaLabel.text = "?"
            }
        }
    }
}
