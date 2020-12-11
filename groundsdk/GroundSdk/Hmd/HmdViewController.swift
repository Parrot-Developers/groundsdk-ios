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

/// Class to use in order to mark a specific view in a views hierarchy. The view with this class will be rendered.
/// See: `public func setViewForHud(view: UIView?, refreshRateHz: Double)`
open class DrawableView: UIView {
    let isDrawableView = true
}

/// The VC that supports all the display and OpenGl composition of the "HMD" view. You can subclass this ViewController
/// in order to implement a HMD feature
open class HmdViewController: UIViewController {

    /// enum to specify the camera source.
    public enum VideoOrigin {
        /// stream is disabled
        case none
        /// the phone's camera is used for the sream
        case phoneCamera
        /// the drone's camera is used for the sream
        case droneCamera
    }

    /// Cockpit Glasses ressources
    private var cockpitRessources: CockpitRessources?

    /// Cockpit model used for rendering. See `setCockpitModel(model: String)` to set or change the model.
    private var cockpitName: String?

    /// Can enable / disable CockpitGlasses VR rendering. Can be used during development to display the undistorted
    /// HMD screen. (`true` disables the distortion)
    public var debugDistortionOff: Bool = false {
        didSet {
            debugQuad?.enable = debugDistortionOff
            distortionMesh?.enable = !debugDistortionOff
        }
    }

    /// HMD Object that displays a video stream.
    public var offScreenStreamRender: OffScreenStreamRender?

    /// Specifies the camera source.
    public var videoOrigin = VideoOrigin.droneCamera {
        didSet {
            if oldValue != videoOrigin {
                applyVideoMode(origin: videoOrigin)
            }
        }
    }

    /// Phone's camera size (pixels) (read-only)
    public var phoneCameraSize: CGSize? {
        return cameraQuad?.renderSize
    }

    /// Phone's camera Field Of View (read-only)
    public var phoneCameraFov: Double {
        return cameraQuad?.fov ?? 0
    }

    /// Custom rendering vertical offset (in mm)
    public var verticalOffset: Double = 0 {
        didSet {
            distortionMesh?.setVerticalOffset(verticalOffset)
        }
    }

    /// Closure called at every frame refresh. At each draw(), this closure is called and allows to implement specific
    // processing
    public var refreshUpdate: (() -> Void)?

    /// Set true in this property will force the hud layer to be always render in low res
    ///
    /// Note: If the hud view uses the `fallBackMinRefreshRateHz`parameter (see `setViewForHud()`), the lowres
    /// rendering should be automatically activated in the case of a bad framerate.
    public var hudForceLowRes = false {
        didSet {
            if oldValue == false && hudForceLowRes == true {
                ULog.w(.hmdTag, "HMD: HUD rendered in LOW RES")
            }
        }
    }

    /// Open GL view (added as subview, in order to render the Hmd)
    private var gglView: GGLView?

    /// Drawable Opengl Object with distortion shader.
    private var distortionMesh: GGLDistortionMesh?
    /// MultiLayer OffScreen rendering system.
    private var multiLayer: GGLMultiLayer?
    // Size of the final fbo (in the multiLayer object). This size is a default one: an exact size, based on phone
    // physical size and dpi, can be computed later.
    private var fboSize = CGSize(width: 1280, height: 1280)

    // Hud
    /// layer id for the Hud
    private var hudLayerId: GGLMultiLayer.LayerId?
    /// Zoom factor to apply in the multilayer system so that the Hud screen "fits" the view (no crop).
    private var hudZoomForFit = CGFloat(1)
    /// Zoom factor to apply to the Hud view. By default, the HUD view is displayed in "fit" mode. A factor of 1. is
    /// the default. For example, to reduce the view in half, the zoom factor to use would be 0.5
    public var hudCustomZoom = CGFloat(1) {
        didSet {
            if oldValue != hudCustomZoom {
                if let hudLayerId = hudLayerId, let multiLayer = multiLayer {
                    multiLayer.setZoomForLayer(id: hudLayerId, zoom: hudZoomForFit * hudCustomZoom)
                }
            }
        }
    }
    /// The timer in charge of the refresh rate of the Hud
    private var hudTimer: GGLTimer?
    /// Refresh rate of the Hud (Hz)
    private var refreshHudHz: Double = 0
    /// Minimum refresh rate of the Hud (Hz). In case of poor performance, the refresh rate can be automatically
    /// reduced, but never below this value.
    private var minRefreshHudHz: Double?

    /// A struct object that checks the refresh rate of the Hud.
    private var hudFrequencyController: HudFrequencyController?
    /// The view containing the Hud. See `setViewForHud`()`
    private var hudView: UIView?

    // Camera
    /// An OpenGl rendering object specialized in rendering the frames of the phone's camera
    private var cameraQuad: GGLCameraQuad?
    /// layer id for the Hud
    private var cameraLayerId: GGLMultiLayer.LayerId?
    /// Zoom factor to apply in the multilayer system so that the camera screen "fits" the view (no crop).
    private var cameraZoomForFit: CGFloat = 1

    // Phone's Camera Overlay
    /// Sprites added in the camera overlay. See `addCameraSprite(sprite: HmdSprite)`
    private var spritesForCamera = Set<HmdSprite>()
    /// Layer id of the camera's orverlay
    private var overCameraLayerId: GGLMultiLayer.LayerId?

    // Drone's Stream Overlay
    /// Sprites added in the drone's stream overlay. See `addStreamSprite(sprite: HmdSprite)`
    private var spritesForStream = Set<HmdSprite>()
    /// Layer id of the camera's orverlay
    private var overStreamLayerId: GGLMultiLayer.LayerId?

    // debug Quad
    /// This Quad is used to render the HMD view without distortion. See the property `debugDistortionOff`
    private var debugQuad: GGLTexturedQuad?

    // Stream
    /// Layer id of the drone's video stream
    private var streamLayerId: GGLMultiLayer.LayerId?
    /// Zoom factor to apply in the multilayer system so that the video stream "fits" the view (no crop).
    private var streamZoomForFit: CGFloat = 1

    /// true / false if the rendering view is currently presented
    private var isRenderingOnScreen = false

    /// Setup OpenGl
    private func setupGGl() {
        guard let gglView = gglView, let cockpitName = cockpitName, let cockpitRessources = cockpitRessources else {
            return
        }
        EAGLContext.setCurrent(gglView.context)

        // get a quad Camera
        if cameraQuad == nil {
            cameraQuad = GGLCameraQuad()
            if let cameraQuad = cameraQuad {
                cameraQuad.drawableSetupGl(context: gglView.context)
                cameraQuad.enable = false
            }
        }

        // get a distortion mesh
        distortionMesh = GGLDistortionMesh(cockpitName: cockpitName, cockpitRessources: cockpitRessources)
        if let distortionMesh = distortionMesh {
            distortionMesh.setVerticalOffset(verticalOffset)
            gglView.addDrawable(distortionMesh)
            let sizeForFbo = distortionMesh.squarePixelSize
            fboSize = CGSize(width: sizeForFbo, height: sizeForFbo)
        }

        // get a OffScreen stream
        offScreenStreamRender = OffScreenStreamRender(context: gglView.context, size: fboSize)
        offScreenStreamRender?.frameReadyAction = { [weak self] in
            if let self = self {
                self.drawTheStream()
            }
        }

        // Add a Multilayer Object
        multiLayer = GGLMultiLayer(context: gglView.context, renderSize: fboSize)
        if let multiLayer = multiLayer {

            // add a layer for the camera and a overlay
            if let cameraQuad = cameraQuad {
                cameraLayerId = multiLayer.addFrameBufferLayer(size: cameraQuad.renderSize, flip: true)
                overCameraLayerId = multiLayer.addFrameBufferLayer(size: cameraQuad.renderSize, flip: true)
            }

            if let cameraLayerId = cameraLayerId, let overCameraLayerId = overCameraLayerId {
                cameraZoomForFit = distortionMesh?.zoomForAspectFit ?? 1
                multiLayer.setZoomForLayer(id: cameraLayerId, zoom: cameraZoomForFit )
                multiLayer.setZoomForLayer(id: overCameraLayerId, zoom: cameraZoomForFit )
            }

            // add a layer for the Stream overlay
            streamLayerId = multiLayer.addExternalTextureLayer(size: fboSize, flip: true, autorelease: false)
            overStreamLayerId = multiLayer.addFrameBufferLayer(size: fboSize, flip: true)
            if let streamLayerId = streamLayerId, let overStreamLayerId = overStreamLayerId {
                multiLayer.setZoomForLayer(id: streamLayerId, zoom: distortionMesh?.zoomForAspectFit ?? 1)
                multiLayer.setZoomForLayer(id: overStreamLayerId, zoom: distortionMesh?.zoomForAspectFit ?? 1)
            }

            // add a layer for the Hud
            hudLayerId = multiLayer.addExternalTextureLayer(size: fboSize, flip: false, autorelease: true)
            if let hudLayerId = hudLayerId {
                hudZoomForFit = (distortionMesh?.zoomForAspectFit ?? 1)
                multiLayer.setZoomForLayer(id: hudLayerId, zoom: hudZoomForFit * hudCustomZoom)
                // hide this layer. Waiting a view for the hud
                multiLayer.hide(layerId: hudLayerId, true)
            }

            // get a debug Quad
            let debugSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale,
                                   height: UIScreen.main.bounds.width * UIScreen.main.scale)
            debugQuad = try? GGLTexturedQuad(size: debugSize, orthoProjection: true)
            if let debugQuad = debugQuad {
                gglView.addDrawable(debugQuad)
                let posCenter = GLKMatrix4MakeTranslation(
                    Float(UIScreen.main.bounds.width * UIScreen.main.scale) / 2,
                    Float(UIScreen.main.bounds.height * UIScreen.main.scale) / 2, 0)
                debugQuad.modelviewMatrix = GLKMatrix4Scale(posCenter, 1, -1, 1)
            }
        }

        gglView.willDraw = { [weak self] in
            if let self = self {
                if let refreshUpdate = self.refreshUpdate {
                    refreshUpdate()
                }
                self.drawTheCamera()
                if let multiLayer = self.multiLayer {
                    if multiLayer.wasUpdatedSinceLastGetFinal {
                        if self.debugDistortionOff {
                            self.debugQuad?.updateTextureName(textId: multiLayer.getFinalFboTexture())
                        } else {
                            self.distortionMesh?.textureImage = multiLayer.getFinalFboTexture()
                        }
                    }
                }
            }
        }
        gglView.autoRefreshFps = 30
    }

    /// Remove all objects used for rendering
    private func removeGGLRenderer() {
        // keeps the cameraQuad, but disables it
        cameraQuad?.enable = false
        streamLayerId = nil
        overStreamLayerId = nil
        cameraLayerId = nil
        overCameraLayerId = nil
        hudLayerId = nil
        offScreenStreamRender?.frameReadyAction = nil
        if let stream = offScreenStreamRender?.stream as? StreamCore {
            stream.stop()
        }
        offScreenStreamRender = nil
        hudTimer = nil
        multiLayer = nil
        distortionMesh = nil
        debugQuad = nil
    }

    @available(iOS 10.0, *)
    /// Changes or sets a cockpit model for rendering
    /// - Parameter toModel: model tu use for rendering
    private func setRendering(toModel: String) {
        let cockpitNamess = cockpitRessources?.cockpitNames
        guard cockpitNamess?.contains(toModel) == true else {
            ULog.e(.hmdTag, "HMD: unknown model \(toModel)")
            return
        }

        guard let gglView = gglView else {
            return
        }

        EAGLContext.setCurrent(gglView.context)

        gglView.enabled = false
        gglView.willDraw = nil
        gglView.removeDrawables()
        // if a rendering is active, stop the rendering
        if isRenderingOnScreen {
            setRendering(active: false)
        }

        removeGGLRenderer()
        cockpitName = toModel
        setupGGl()

        // if a rendering was active, restart the rendering
        if isRenderingOnScreen {
            setRendering(active: true)
        }
    }

    /// Enables or disables the rendering
    /// - Parameter active: true for rendering, false otherwise
    private func setRendering(active: Bool) {
        if active {
            if let context = gglView?.context {
                EAGLContext.setCurrent(context)
                applyVideoMode(origin: videoOrigin)
                distortionMesh?.enable = !debugDistortionOff
                debugQuad?.enable = debugDistortionOff
                activeAutoRefreshHud()
                gglView?.enabled = true
            }
        } else {
            gglView?.enabled = false
            applyVideoMode(origin: .none)
            distortionMesh?.enable = false
            hudTimer = nil
        }
    }

    /// Enable or disable the camera overlay. The camera overlay should be visible if at least one sprite is defined
    /// and visible.
    ///
    /// - Returns: true if the camera overlay is visible, false otherwise.
    @discardableResult private func showCameraOverlayIdNeeded() -> Bool {
        guard let overCameraLayerId = overCameraLayerId else {
            return false
        }
        // show the overlay layer only if sprites are enabled
        let enabledSprites = spritesForCamera.filter { $0.enable }
        if enabledSprites.count > 0 {
            multiLayer?.hide(layerId: overCameraLayerId, false)
            return true
        } else {
            multiLayer?.hide(layerId: overCameraLayerId, true)
            return false
        }
    }

    /// Enable or disable the drone's stream overlay. The stream overlay should be visible if at least one sprite is
    /// defined and visible.
    ///
    /// - Returns: true if the stream overlay is visible, false otherwise.
    @discardableResult private func showStreamOverlayIfeeded() -> Bool {
        guard let overStreamLayerId = overStreamLayerId else {
            return false
        }
        // show the overlay layer only if sprites are enabled
        let enabledSprites = spritesForStream.filter { $0.enable }
        if enabledSprites.count > 0 {
            multiLayer?.hide(layerId: overStreamLayerId, false)
            return true
        } else {
            multiLayer?.hide(layerId: overStreamLayerId, true)
            return false
        }
    }

    /// Defined the video source to render.
    ///
    /// - Parameter origin: stream to display
    private func applyVideoMode(origin: VideoOrigin) {
        guard let multiLayer = multiLayer else {
            return
        }
        self.gglView?.resetFpsChecker()
        if origin != .phoneCamera {
            // hide the camera layer + overlay
            if let cameraLayerId = cameraLayerId {
                multiLayer.hide(layerId: cameraLayerId, true)
            }
            if let overCameraLayerId = overCameraLayerId {
                multiLayer.hide(layerId: overCameraLayerId, true)
            }
            cameraQuad?.enable = false
        }
        if origin != .droneCamera {
            // hide the drone stream layer and its overlay
            if let streamLayerId = streamLayerId {
                multiLayer.hide(layerId: streamLayerId, true)
            }
            if let overStreamLayerId = overStreamLayerId {
                multiLayer.hide(layerId: overStreamLayerId, true)
            }
        }
        switch origin {
        case .none:
            break
        case .phoneCamera:
            cameraQuad?.enable = true
            if let cameraLayerId = cameraLayerId {
                multiLayer.hide(layerId: cameraLayerId, false)
            }
            showCameraOverlayIdNeeded()
        case .droneCamera:
            if let streamLayerId = streamLayerId {
                multiLayer.hide(layerId: streamLayerId, false)
            }
            showStreamOverlayIfeeded()
        }
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        gglView = GGLView(frame: view.frame)
        if let gglView = gglView {
            gglView.translatesAutoresizingMaskIntoConstraints = false
            gglView.backgroundColor = .purple
            gglView.isUserInteractionEnabled = false
            view.addSubview(gglView)
            gglView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            gglView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
            gglView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
            gglView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        }
        setupGGl()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isRenderingOnScreen = true
        setRendering(active: true)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let stream = offScreenStreamRender?.stream as? StreamCore {
            stream.stop()
        }
        isRenderingOnScreen = false
        setRendering(active: false)
    }

    /// Render the drone's stream in the multilayer Frame Buffer Object.
    private func drawTheStream() {
        // copy stream texture in the fbo / layer
        if let streamLayerId = streamLayerId, let offScreenStreamRender = offScreenStreamRender,
            videoOrigin == .droneCamera, let context = gglView?.context {
            EAGLContext.setCurrent(context)
            let textureId = offScreenStreamRender.fbo.fboTexture
            multiLayer?.setTexture(layerId: streamLayerId, texture: textureId)
        }
    }

    /// Render the phone camera's stream in the multilayer Frame Buffer Object.
    private func drawTheCamera() {
        // copy camera texture in the fbo / layer
        if let cameraLayerId = cameraLayerId, videoOrigin == .phoneCamera,
            let cameraQuad = cameraQuad, cameraQuad.newFrameSinceLastDraw == true,
            let context = gglView?.context {
            EAGLContext.setCurrent(context)
            if let frameBufferCamera = multiLayer?.getLayerFrameBuffer(id: cameraLayerId) {
                glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBufferCamera)
                cameraQuad.renderDrawable(frame: CGRect(x: 0, y: 0, width: cameraQuad.renderSize.width,
                                                        height: cameraQuad.renderSize.height))
                glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
                multiLayer?.wasUpdatedSinceLastGetFinal = true
            }
        }
    }

    /// Render the Hud view in the multilayer Frame Buffer Object. This function schedules copies of the hud
    /// The result (an openGl texture) is then applied to the multilayer Frame Buffer Object
    private func activeAutoRefreshHud() {
        let samplingHz = Double(100)
        if let hudView  = hudView, hudLayerId != nil, refreshHudHz > 0, let openGlContext = gglView?.context {
            hudFrequencyController = HudFrequencyController(
                requestedTriggerHz: refreshHudHz, minTriggerHz: minRefreshHudHz, samplingHz: samplingHz)
            hudTimer = GGLTimer(timeInterval: 1.0 / samplingHz, fireQueue: DispatchQueue.main)
            let viewToRender = GGLUtils.getDrawableView(view: hudView) ?? hudView
            hudTimer?.eventHandler = { [weak self] in
                if let self = self, let trigger = self.hudFrequencyController?.trigger(), trigger == true {
                    if self.gglView?.badFps == true {
                        // try to reduce the refresh rate of the hud
                        self.hudFrequencyController?.askReduce = true
                    }
                    if self.hudFrequencyController?.badPerf == true && self.gglView?.badFps == true {
                        // set the low res. This value will definitely be set to true
                        self.hudForceLowRes = true
                    }
                    // about : 'UIGraphicsBeginImageContext'
                    // use the 'UIGraphicsBeginImageContextWithOptions' version in order to get the maximum resolution
                    // for the low res version : UIGraphicsBeginImageContext(view.frame.size)
                    if self.hudForceLowRes {
                        UIGraphicsBeginImageContext(viewToRender.frame.size)
                    } else {
                        UIGraphicsBeginImageContextWithOptions(viewToRender.frame.size, false, 0 )
                    }

                    var image: UIImage?
                    if let context = UIGraphicsGetCurrentContext() {
                        viewToRender.layer.render(in: context)
                        image = UIGraphicsGetImageFromCurrentImageContext()
                    }
                    UIGraphicsEndImageContext()

                    if let hudLayerId = self.hudLayerId, let image = image {
                        EAGLContext.setCurrent(openGlContext)
                        if let cgimage = image.cgImage,
                            let textureInfo = try? GLKTextureLoader.texture(with: cgimage) {
                            var textureId = GLuint()
                            textureId = textureInfo.name
                            self.multiLayer?.setTexture(layerId: hudLayerId, texture: textureId)
                        }
                    }
                }
            }
            hudTimer?.resume()
        }
    }
}

// MARK: - Public Interface
@available(iOS 10.0, *)
extension HmdViewController {

    /// Set the cockpit ressources file.
    ///
    /// - Parameter fileURL: URL for the cockpitGlasses file.
    public func setupCockpitRessources(fileURL: URL) {
        cockpitRessources = CockpitRessources(fileURL: fileURL)
        cockpitName = nil
    }

    /// Gel all available cockpit models. Models are defined in a cockpitGlasses file
    /// (see `setupCockpitRessources(fileURL: URL)`)
    ///
    /// - Returns: all available models. See `setCockpitModel(model: String)`
    public func allCockpitModels() -> [String]? {
        return cockpitRessources?.cockpitNames
    }

    /// Set or update the Cockit Model. Call this function during initialization (viewDidLoad() is a good place).
    /// Subsequently, it is possible to dynamically update the model used.
    ///
    /// - Parameter model: Cockpit Model.
    public func setCockpitModel(model: String) {
        guard model != cockpitName else {
            return
        }
        setRendering(toModel: model)
    }

    /// Set a view as Hud template
    ///
    /// - Parameters:
    ///   - view: the view used to draw the Hud (For better optimization / representation of the view,
    /// design a view with a ratio of 1: 1). Use 'nil' to deactivate the hud rendering.
    ///   - refreshRateHz: refresh Rate in Hertz. (> 0)
    ///   - fallBackMinRefreshRateHz: if this parameter is defined, an automatic framerate reduction mechanism is used
    /// in case of poor performance
    ///
    /// Note: in order to render a spéecific view in `view.subviews`, you can mark the view to render using the Class
    /// `DrawableView`. If no view is a DrawableView in the hierarchy, the `view`is used for rendering.
    public func setViewForHud(view: UIView?, refreshRateHz: Double, fallBackMinRefreshRateHz: Double? = nil) {
        // remove any hud if exists
        hudView = view
        hudTimer = nil
        refreshHudHz = refreshRateHz
        minRefreshHudHz = fallBackMinRefreshRateHz
        if let hudLayerId = hudLayerId {
            // hide the layer if the view is nil (shows otherwise)
            multiLayer?.hide(layerId: hudLayerId, (hudView == nil))
        }
        activeAutoRefreshHud()
    }

    /// Adds a sprite that will be drawn in the phone's camera overlay.
    ///
    /// - Parameter sprite: Sprite to render in the Phone's Camera Overlay
    /// - Returns: true or false if the sprite is added or not.
    @discardableResult public func addCameraSprite(sprite: HmdSprite) -> Bool {
        guard let gglView = gglView else {
            return false
        }
        if spritesForCamera.insert(sprite).inserted {
            sprite.quad.drawableSetupGl(context: gglView.context)
            return true
        } else {
            return false
        }
    }

    /// Adds a sprite that will be drawn in the drone's stream overlay.
    ///
    /// - Parameter sprite: Sprite to render in the stream Overlay
    /// - Returns: true or false if the sprite is added or not.
    @discardableResult public func addStreamSprite(sprite: HmdSprite) -> Bool {
        guard let gglView = gglView else {
            return false
        }
        if spritesForStream.insert(sprite).inserted {
            sprite.quad.drawableSetupGl(context: gglView.context)
            return true
        } else {
            return false
        }
    }

    /// Remove a sprite previously inserted in the camera overlay.
    ///
    /// - Parameter sprite: Existing sprite in the camera Overlay
    public func removeCameraSprite(_ sprite: HmdSprite) {
        spritesForCamera.remove(sprite)
    }

    /// Remove a sprite previously inserted in the drone's stream overlay.
    ///
    /// - Parameter sprite: Existing sprite in the stream Overlay
    public func removeStreamSprite(_ sprite: HmdSprite) {
        spritesForStream.remove(sprite)
    }

    /// The call to this function indicates that the camera overlay has been modified and must be refreshed.
    public func cameraOverlayNeedsRefresh() {
        guard let overCameraLayerId = overCameraLayerId, let cameraQuad = cameraQuad, videoOrigin == .phoneCamera else {
            return
        }
        if showCameraOverlayIdNeeded() {
            if let frameBufferOverlay = multiLayer?.getLayerFrameBuffer(id: overCameraLayerId) {
                glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBufferOverlay)
                // Clear the framebuffer
                glClearColor(0.0, 0.0, 0.0, 0.0)
                glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
                spritesForCamera.forEach {
                    if $0.quad.enable {
                        $0.quad.renderDrawable(frame: CGRect(x: 0, y: 0, width: cameraQuad.renderSize.width,
                                                             height: cameraQuad.renderSize.height))
                    }
                }
                glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
                multiLayer?.wasUpdatedSinceLastGetFinal = true
            }
        }
    }

    /// The call to this function indicates that the stream overlay has been modified and must be refreshed.
    public func streamOverlayNeedsRefresh() {
        guard let overStreamLayerId = overStreamLayerId, videoOrigin == .droneCamera else {
            return
        }
        if showStreamOverlayIfeeded() {
            if let frameBufferOverlay = multiLayer?.getLayerFrameBuffer(id: overStreamLayerId) {
                glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBufferOverlay)
                // Clear the framebuffer
                glClearColor(0.0, 0.0, 0.0, 0.0)
                glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
                spritesForStream.forEach {
                    if $0.quad.enable {
                        $0.quad.renderDrawable(frame: CGRect(x: 0, y: 0, width: fboSize.width, height: fboSize.height))
                    }
                }
                glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
                multiLayer?.wasUpdatedSinceLastGetFinal = true
            }
        }
    }
}

/// Object to control the actual Hud refresh rate. A flag (see the `badPerf` property) indicates if the refresh rate
/// is lower than the desired one.
private struct HudFrequencyController {

    /// Minimum refresh rate of the Hud (Hz). In case of poor performance, the refresh rate can be automatically
    /// reduced, but never below this value.
    let minTriggerHz: Double?
    /// The frequency at which the trigger function will be called
    let samplingHz: Double
    /// The initial refresh rate requested for the hud
    let requestedTriggerHz: Double
    /// if true, the HudFrequencyController will try to reduce the refresh rate
    var askReduce: Bool = false
    /// true or false whether the refresh rate is lower than the desired one.
    var badPerf = false
    /// current targeted refresh rate
    private var activeTriggerHz: Double
    /// Time allocated to analysis the refresh rate
    private let checkPeriodTimeSec = Double(2)
    /// Current time of the analysis
    private var currentCheckPeriod = Double(0)
    /// Number of events (hud refreshing) since the beginning of the analysis
    private var eventsInPeriod = 0
    /// Timestamp of the beginning of the analysis
    private var startDate: Date

    /// Constructor
    ///
    /// - Parameters:
    ///   - requestedTriggerHz: the initial refresh rate requested for the hud (must be > 0)
    ///   - minTriggerHz: minimum refresh rate of the Hud (Hz). In case of poor performance, the refresh rate can be
    /// automatically reduced, but never below this value. (must be > 0)
    ///   - samplingHz: the initial refresh rate requested for the hud (must be > 0)
    init(requestedTriggerHz: Double, minTriggerHz: Double? = nil, samplingHz: Double) {
        self.minTriggerHz = minTriggerHz
        self.samplingHz = samplingHz
        self.requestedTriggerHz = requestedTriggerHz
        self.activeTriggerHz = requestedTriggerHz
        self.startDate = Date()
    }

    mutating func trigger() -> Bool {
        var retValue = false
        currentCheckPeriod += (1 / samplingHz)
        let fireValue =  1 / activeTriggerHz
        let realTime = abs(startDate.timeIntervalSinceNow)

        if (realTime / fireValue).rounded(.towardZero) > Double(eventsInPeriod) {
            eventsInPeriod += 1
            retValue = true
        }
        if realTime >= checkPeriodTimeSec {
            let eventsGoal = checkPeriodTimeSec * activeTriggerHz
            if let minTriggerHz = minTriggerHz, eventsInPeriod < Int(eventsGoal) {
                // check if the delta is over 10%
                if eventsGoal / Double(eventsInPeriod) > 1.1 || askReduce {
                    if activeTriggerHz > minTriggerHz {
                        activeTriggerHz *= 0.5
                        if activeTriggerHz < minTriggerHz {
                            activeTriggerHz = minTriggerHz
                        }
                        ULog.w(.hmdTag, "HMD: FrequencyController - reduce to \(activeTriggerHz) Hz")
                    } else {
                        badPerf = true
                        ULog.w(.hmdTag, "HMD: FrequencyController - Bad Performance limit")
                    }
                }
            }
            askReduce = false
            currentCheckPeriod = 0
            eventsInPeriod = 0
            startDate = Date()
        }
        return retValue
    }
}
