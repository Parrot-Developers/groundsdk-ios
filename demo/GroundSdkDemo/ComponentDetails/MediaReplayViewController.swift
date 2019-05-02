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

class MediaReplayViewController: UIViewController {

    @IBOutlet weak var streamView: StreamView!
    @IBOutlet weak var playPauseBtn: UIBarButtonItem!
    @IBOutlet weak var stopBtn: UIBarButtonItem!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var positionLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var media: MediaItem?
    private var streamServer: Ref<StreamServer>?
    private var mediaReplay: Ref<MediaReplay>?

    // formatter for the time position
    private lazy var timeFormatter: DateComponentsFormatter = {
        let durationFormatter = DateComponentsFormatter()
        durationFormatter.unitsStyle = .abbreviated
        return durationFormatter
    }()

    func set(droneUid: String, media: MediaItem) {
        self.droneUid = droneUid
        self.media = media
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        timeSlider.minimumValue = 0
        if let drone = groundSdk.getDrone(uid: droneUid!) {
            streamServer = drone.getPeripheral(Peripherals.streamServer) { streamServer in
                streamServer?.enabled = true
            }
        }
        if let streamServer = streamServer, let resource = getNextStreamableResource() {
            let track = resource.getAvailableTracks()
            let source = MediaReplaySourceFactory.videoTrackOf(resource: resource,
                                                               track: (track != nil ? track!.first! : .defaultVideo))
            mediaReplay = streamServer.value?.replay(source: source) { [weak self] stream in
                self?.stopBtn.isEnabled = stream?.state != .stopped
                self?.playPauseBtn.title = stream?.playState != .playing ? "Play" : "Pause"
                self?.streamView.setStream(stream: stream)

                self?.durationLabel.text = self?.timeFormatter.string(from: stream?.duration ?? 0)
                self?.timeSlider.maximumValue = Float(stream?.duration ?? 0)
                self?.refreshStreamPosition()
            }

         }
    }

    @objc func refreshStreamPosition() {
        let position = mediaReplay?.value?.position ?? 0
        print("refreshStreamPosition \(position)")
        positionLabel.text = timeFormatter.string(from: position)
        timeSlider.value = Float(position)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(refreshStreamPosition),
                                               object: nil)
        if mediaReplay?.value?.state == .started {
            perform(#selector(refreshStreamPosition), with: nil, afterDelay: 0.1)
        }
    }

    func getNextStreamableResource() -> MediaItem.Resource? {
        if let media = media {
            return media.resources.first(where: { return $0.streamable})
        }
        return nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        streamView.setStream(stream: nil)
        streamServer = nil
    }

    @IBAction func playPauseStream(_ sender: UIBarButtonItem) {
        if let mediaReplayRef = mediaReplay, let stream = mediaReplayRef.value {
            if stream.playState == .playing {
                _ = stream.pause()
            } else {
                _ = stream.play()
            }
        }
    }

    @IBAction func stopStream(_ sender: UIBarButtonItem) {
        if let stream = mediaReplay, stream.value?.state != .stopped {
            stream.value?.stop()
        }
    }

    @IBAction func seekTo(_ sender: UISlider) {
        _ = mediaReplay?.value?.seekTo(position: TimeInterval(sender.value))
        print("seekTo \(sender.value)")
    }
}
