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

class HmdDemoViewController: HmdViewController, DeviceViewController {

    @IBOutlet weak var viewHudDemo: UIView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var tapButton: UIButton!

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var streamServerRef: Ref<StreamServer>?
    private var cameraLiveRef: Ref<CameraLive>?

    private var lastMaxIndex = 0

    private weak var hudContentViewController: HmdHudContent?

    // display 2 sprites on the phone's camera screen
    private var sprite1: HmdSprite? = HmdSprite(imageName: "icn_poi", scale: 2)
    private var sprite2: HmdSprite? = HmdSprite(imageName: "icn_quadri", scale: 2)

    // display a sprite on the stream overlay
    private var spriteForStream: HmdSprite?

    private var moveLeft = false
    private var moveDown = false

    private var modelsId: [String]?
    private var currentModelInd: Int = 0

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    private func setModelWithIndice(_ ind: Int) {
        if let nbModel = modelsId?.count {
            if ind >= nbModel {
                currentModelInd = 0
            } else {
                currentModelInd = ind
            }
            if let name = modelsId?[currentModelInd] {
                setCockpitModel(model: name)
            }
        }
    }

    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        let value = UIInterfaceOrientation.landscapeLeft.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        // call the super.viewDidLoad() after the new orientation
        super.viewDidLoad()
        debugDistortionOff = false

        let fileName = "hmd.bin"
        if let fileURL = Bundle.main.url(forResource: fileName, withExtension: "") {
            setupCockpitRessources(fileURL: fileURL)
            modelsId = allCockpitModels()
            currentModelInd = 0
            if modelsId?.count ?? 0 <= 0 {
                print("Error: CockitsRessources(\(fileName)) - no models in file")
            }
        } else {
            print("Error: CockitsRessources(\(fileName)) - no ressource in Bundle")
        }

        setModelWithIndice(0)

        if let sprite = sprite1 {
            addCameraSprite(sprite: sprite)
        }
        if let sprite2 = sprite2 {
            addCameraSprite(sprite: sprite2)
        }
    }
    @IBAction func backAction(_ sender: Any) {
        dismiss(animated: true)
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    override var shouldAutorotate: Bool {
        return true
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoOrigin = .phoneCamera
        initStream()
    }

    private func setUpHmdContent() {
        let nameCockpit = modelsId?[currentModelInd] ?? "WELCOME"
        messageToHud(nameCockpit)
        self.setViewForHud(view: viewHudDemo, refreshRateHz: 15, fallBackMinRefreshRateHz: 5)
        offScreenStreamRender?.contentZoneListener = { [weak self] rect in
            if let self = self {
                if let existingSprite = self.spriteForStream {
                    self.removeStreamSprite(existingSprite)
                }
                self.spriteForStream = HmdSprite(imageName: "gridPhoto", size: rect.size)
                if let spriteForStream = self.spriteForStream {
                    spriteForStream.currentPosition = rect.origin
                    self.addStreamSprite(sprite: spriteForStream)
                    self.displayStreamOverlay(true)
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        streamServerRef?.value?.enabled = true
        playCameraLive()
        moveSpriteOnphoneCamera()
        view.bringSubviewToFront(tapButton)
        view.bringSubviewToFront(backButton)
        setUpHmdContent()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.setViewForHud(view: nil, refreshRateHz: 0)
        offScreenStreamRender?.contentZoneListener = nil
        deinitStream()
    }

   /// How to change cokpitGlasses when the HMD is active
   private func changeCockpitOnScreen() {
        // Clean
        deinitStream()
        // change the cockpit
        currentModelInd += 1
        setModelWithIndice(currentModelInd)
        // redo (stream and hud content)
        initStream()
        setUpHmdContent()
    }

    /// How to change the vertical offset
    func exampleOffset() {
        verticalOffset = 6.5
    }

    @IBAction func tabOnScreen(_ sender: Any) {
       changeCockpitOnScreen()
    }

    private func initStream() {
        if let drone = groundSdk.getDrone(uid: droneUid!) {
            streamServerRef = drone.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
                if let self = self {
                    if streamServer != nil {
                        self.videoOrigin = .droneCamera
                        self.messageToHud("")
                    } else {
                        if self.videoOrigin == .droneCamera {
                            self.messageToHud("Back to phone's camera")
                        }
                        self.videoOrigin = .phoneCamera
                    }
                }
                if let streamServer = streamServer {
                    self?.cameraLiveRef = streamServer.live { [weak self] stream in
                        self?.offScreenStreamRender?.setStream(stream: stream)
                        self?.offScreenStreamRender?.overlayer = self
                        self?.offScreenStreamRender?.histogramsEnabled = true
                        self?.offScreenStreamRender?.zebrasEnabled = true
                        self?.offScreenStreamRender?.zebrasThreshold = 0.75
                        if stream?.playState  != .playing {
                            _ = stream?.play()
                        }
                    }
                }
            }
        }
    }

    private func deinitStream() {
        offScreenStreamRender?.setStream(stream: nil)
        streamServerRef = nil
        cameraLiveRef = nil
    }

    private func playCameraLive() {
        if let cameraLiveRef = cameraLiveRef, let stream = cameraLiveRef.value {
            if stream.playState != .playing {
                _ = stream.play()
            }
        }
    }

    private func displayStreamOverlay(_ display: Bool) {
        spriteForStream?.enable = display
        streamOverlayNeedsRefresh()
    }

    private func moveSpriteOnphoneCamera () {
        sprite1?.enable = true
        sprite2?.enable = false
        cameraOverlayNeedsRefresh()
        refreshUpdate = { [weak self] in
            // We use the refreshUpdate closure to move the sprites one the phone's camera overlay
            // But of course, it's possible to do something else
            if let self = self, self.videoOrigin == .phoneCamera, let cameraSize = self.phoneCameraSize,
                let sprite = self.sprite1, let sprite2 = self.sprite2 {
                var posX = sprite.currentPosition.x
                var posY = sprite.currentPosition.y
                if self.moveLeft {
                    if posX > 0 {
                        posX -= 3
                    } else {
                        self.moveLeft = false
                    }
                } else {
                    if posX < cameraSize.width - sprite.displaySize.width {
                        posX += 3
                    } else {
                        self.moveLeft = true
                    }
                }
                if self.moveDown {
                    if posY > 0 {
                        posY -= 3
                    } else {
                        self.moveDown = false
                    }
                } else {
                    if posY < cameraSize.height - sprite.displaySize.height {
                        posY += 3
                    } else {
                        self.moveDown = true
                    }
                }
                sprite.currentPosition = CGPoint(x: posX, y: posY)
                sprite2.currentPosition = CGPoint(x: posX, y: posY)
                if Int.random(in: 0...60) == 1 {
                    sprite.enable = !sprite.enable
                    sprite2.enable = !sprite2.enable
                }
                self.cameraOverlayNeedsRefresh()
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "contentHudSegueId", let hudVC = segue.destination as? HmdHudContent {
            hudContentViewController = hudVC
        }
    }

    private func messageToHud(_ message: String) {
        if let hudVC = self.hudContentViewController {
            hudVC.setMessage(message)
        }
    }
}

extension HmdDemoViewController: Overlayer {
    func overlay(renderPos: UnsafeRawPointer, contentPos: UnsafeRawPointer, histogram: Histogram?) {
        guard let histogram = histogram else {
            return
        }
        if let histogramLuma = histogram.histogramLuma {
            let maxIndex = histogramLuma.lastIndex(of: histogramLuma.max() ?? 0.0) ?? 0
            if maxIndex != lastMaxIndex {
                lastMaxIndex = maxIndex
                DispatchQueue.main.async { [weak self] in
                    self?.messageToHud(maxIndex.description)
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.messageToHud("")
            }
        }
    }
}
