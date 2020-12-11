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

import GLKit

/// Subclass of GLKView. Used in the HMDViewController. This view has an autoRefresh mechanism and is able to render
/// a list of GGLDrawable objects (The GGLDrawable protocol describes an OpenGL rendering object, with the
/// initialization of the vertexes that compose it)
internal class GGLView: GLKView {

    /// Closure called when a draw occurs.
    public var willDraw: (() -> Void)?
    /// Closure called when the draw ends.
    public var didDraw: (() -> Void)?
    /// Disables or not the draw and suspends the autorefresh mechanism.
    public var enabled = true {
        didSet {
            if oldValue != enabled {
                if enabled {
                    gglTimer?.resume()
                } else {
                    gglTimer?.suspend()
                }
            }
        }
    }
    /// Allows to define the refresh rate of the view (a setNeedDisplay will be called automatically for each frame).
    /// Expressed in frames per second.
    public var autoRefreshFps: Int = 0 {
        didSet {
            resetFpsChecker()
            switch autoRefreshFps {
            case let value where value <= 0:
                autoRefreshFps = 0
                self.gglTimer = nil
            default:
                self.gglTimer = GGLTimer(timeInterval: 1.0 / Double(autoRefreshFps))
                gglTimer?.eventHandler = { [weak self] in
                    self?.setNeedsDisplay() }
                gglTimer?.resume()
            }
        }
    }
    /// true if the view fails to maintain autoRefreshFps frames per seconds (+/- 10% error)
    public private(set) var badFps = false

    private var drawableObjects = [GGLDrawable]()
    private var gglTimer: GGLTimer?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        contextInit()
    }
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        contextInit()
    }

    /// Add a GGLDrawable object in the list of objects to render
    ///
    /// - Parameter drawable: drawable object
    public func addDrawable(_ drawable: GGLDrawable) {
        if !drawable.isGlReady {
            drawable.drawableSetupGl(context: context)
        }
        drawableObjects.append(drawable)
    }

    /// Remove any GGLDrawable object in the list of objects to render
    ///
    public func removeDrawables() {
        drawableObjects.removeAll()
    }

    private func contextInit() {
        context = EAGLContext.init(api: EAGLRenderingAPI.openGLES3)!
        contentScaleFactor = UIScreen.main.scale
        self.drawableMultisample = .multisample4X
        self.drawableColorFormat = .RGBA8888
        self.drawableStencilFormat = .formatNone
        enableSetNeedsDisplay = true
        isOpaque = true
    }
    private var controlFpsDate: Date?
    private var fpsCount = 0

    /// Reset the Fps preformance checker
    public func resetFpsChecker() {
        controlFpsDate = nil
    }

    override func draw(_ rect: CGRect) {
        guard enabled else {
            resetFpsChecker()
            return
        }
        if autoRefreshFps > 0 {
            fpsCount += 1
            if let controlFpsDate = controlFpsDate {
                let ellapsedTime = abs(controlFpsDate.timeIntervalSinceNow)
                if ellapsedTime > 1.0 {
                    let fps = Double(fpsCount) / ellapsedTime
                    // check if the framerate is correct within 10%
                    if Double(autoRefreshFps) / fps >= 1.1 {
                        badFps = true
                    } else {
                        badFps = false
                    }
                    resetFpsChecker()
                }
            } else {
                controlFpsDate = Date()
                fpsCount = 1
            }
        }
        EAGLContext.setCurrent(context)
        bindDrawable()
        // executes the willDraw closure if any. If this closure returns false, the draw cycle is interrupted
        if let willDraw = willDraw {
            willDraw()
        }
        bindDrawable()
        let scale = UIScreen.main.scale
        let boundsScaled = CGRect(x: rect.origin.x * scale, y: rect.origin.y * scale,
                                  width: rect.size.width * scale, height: rect.size.height * scale)
        // Clear the framebuffer
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))
        // Draw all drawable objects (if they are `enable` and and correctly initialized at the OpenGl level)
        for drawable in drawableObjects {
            if drawable.enable && drawable.isGlReady {
                drawable.renderDrawable(frame: boundsScaled)
            }
        }
        // executes the didDraw closure if any
        if let didDraw = didDraw {
            didDraw()
        }
    }
}
