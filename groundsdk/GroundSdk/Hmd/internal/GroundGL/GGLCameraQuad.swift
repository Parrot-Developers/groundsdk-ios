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
import UIKit
import AVFoundation
import CoreVideo.CVOpenGLESTextureCache

/// An OpenGl rendering object specialized in rendering the frames of the phone's camera
class  GGLCameraQuad: NSObject, GGLDrawable, GGLShaderLoader, AVCaptureVideoDataOutputSampleBufferDelegate {

    public private(set) var fov: Double = 0
    public private(set) var newFrameSinceLastDraw = false

    private (set) var renderSize: CGSize = {
            return CGSize(width: UIScreen.main.scale * 960, height: UIScreen.main.scale * 540)
    }()

    /// true or false if a frame is ready to be rendered
    private (set) var isFrameReady = false
    private var lastPixelBuffer: CVImageBuffer?

    // Uniform index.
    private let UNIFORM_Y = 0
    private let UNIFORM_UV = 1
    private let NUM_UNIFORMS = 2
    private var uniforms: [GLint] = [0, 0]

    // Video Texture
    private var _textureWidth: CGFloat = 0.0
    private var _textureHeight: CGFloat = 0.0
    private var _videoTextureCache: CVOpenGLESTextureCache?
    private var _lumaTexture: CVOpenGLESTexture?
    private var _chromaTexture: CVOpenGLESTexture?
    // AV Session
    private var _sessionPreset: AVCaptureSession.Preset = .iFrame960x540
    private var _session: AVCaptureSession?

    // ProgramId (GGLShaderLoader protocol)
    var programId: GLuint

    // (GGLFrawable concordance)
    var currentContext: EAGLContext?
    var isGlReady =  false
    var enable = false {
        didSet {
            if enable != oldValue {
                if oldValue == true {
                    tearDownAVCapture()
                } else if currentContext != nil {
                    // AV Capture ON
                    setupAVCapture(currentContext!)
                }
            }
        }
    }
    var vertices: [GGLVertex]
    var indices: [GLubyte] = [0, 1, 2, 3, 0, 1]
    var ebo = GLuint()
    var vbo = GLuint()
    var vao = GLuint()
    var text = GLuint()

    /// constructor
    ///
    override init() {
        // affects vertices
        let left = GLfloat(1)
        let right = GLfloat(-1)
        let top = GLfloat(1)
        let bottom = GLfloat(-1)

        vertices = [
            GGLVertex(x: right, y: bottom, z: 0, u: 1, v: 0),
            GGLVertex(x: right, y: top, z: 0, u: 1, v: 1),
            GGLVertex(x: left, y: top, z: 0, u: 0, v: 1),
            GGLVertex(x: left, y: bottom, z: 0, u: 0, v: 0)]

        programId = GLuint(0)
        super.init()
    }

    /// Deinit
    deinit {
        drawableTearDownGl()
    }

    func update(renderSize: CGSize) {
        if renderSize != self.renderSize {
            EAGLContext.setCurrent(currentContext)
            self.renderSize = renderSize
            updateTexCoordAspect()
            setupBuffers()
        }
    }

    private func updateTexCoordAspect () {

        guard _textureWidth != 0 && _textureHeight != 0 && renderSize.height != 0 && renderSize.width != 0 else {
            return
        }

        let renderAspect = renderSize.width / renderSize.height
        let textureAspect = _textureWidth / _textureHeight

        let scaleFactor: CGFloat
        if renderAspect < textureAspect {
            scaleFactor = renderSize.height / _textureHeight
        } else {
            scaleFactor = renderSize.width / _textureWidth
        }

        let textureFitWidth = _textureWidth * scaleFactor
        let textureFitHeight = _textureHeight * scaleFactor

        let left: CGFloat
        let right: CGFloat
        let top: CGFloat
        let bottom: CGFloat
        let leftNorm: CGFloat
        let rightNorm: CGFloat
        let topNorm: CGFloat
        let bottomNorm: CGFloat

        left = (textureFitWidth - renderSize.width ) / 2.0
        right = left + renderSize.width
        bottom = (textureFitHeight - renderSize.height ) / 2.0
        top = bottom + renderSize.height

        // Normalization
        let divNormWidth = textureFitWidth
        let divNormHeight = textureFitHeight
        // Width Normalization
        leftNorm = left / divNormWidth
        rightNorm = right / divNormWidth
        // top Normalization
        topNorm = top / divNormHeight
        bottomNorm = bottom / divNormHeight

        let h = GLfloat(topNorm)
        let w = GLfloat(rightNorm)
        let oriH = GLfloat(bottomNorm)
        let oriW = GLfloat(leftNorm)

        vertices = [
            GGLVertex(x: GLfloat(1), y: GLfloat(1), z: 0, u: w, v: oriH),
            GGLVertex(x: GLfloat(1), y: GLfloat(-1), z: 0, u: w, v: h),
            GGLVertex(x: GLfloat(-1), y: GLfloat(1), z: 0, u: oriW, v: oriH),
            GGLVertex(x: GLfloat(-1), y: GLfloat(-1), z: 0, u: oriW, v: h)]
    }

    private func cleanUpTextures() {
        if _lumaTexture != nil {
            _lumaTexture = nil
        }
        if _chromaTexture != nil {
            _chromaTexture = nil
        }
        // Periodic texture cache flush every frame
        if let videoTextureCache = _videoTextureCache {
            CVOpenGLESTextureCacheFlush(videoTextureCache, 0)
        }
    }
}

// MARK: - AV Capture - AVCaptureVideoDataOutputSampleBufferDelegate
extension GGLCameraQuad {

    private func setupAVCapture(_ context: EAGLContext) {

        // Create CVOpenGLESTextureCacheRef for optimal CVImageBufferRef to GLES texture conversion.
        if _videoTextureCache == nil {
            let err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, context, nil, &_videoTextureCache)
            if err != 0 {
                ULog.e(.hmdTag, "Error at CVOpenGLESTextureCacheCreate \(err)")
                return
            }
        }

        if let session = _session {
            session.startRunning()
            return
        }

        // Setup Capture Session.
        _session = AVCaptureSession()
        _session?.beginConfiguration()
        // Set preset session size.
        _session?.sessionPreset = _sessionPreset
        // Create a video device and input from that Device. Add the input to the capture session.
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            // delete the session, in order to avoid future actions on it
            _session = nil
            return
        }
        fov = Double(videoDevice.activeFormat.videoFieldOfView)
        // Add the device to the session.
        if let input: AVCaptureDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) {
            _session?.addInput(input)
            // Create the output for the capture session.
            let dataOutput = AVCaptureVideoDataOutput()
            dataOutput.alwaysDiscardsLateVideoFrames = true // Probably want to set this to NO when recording
            // Set to YUV420.
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as NSString:
                NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)] as [String: Any]

            // Set dispatch to be on the main thread so OpenGL can do things with the data
            dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
            _session?.addOutput(dataOutput)
            _session?.commitConfiguration()
            _session?.startRunning()
        } else {
            // delete the session, in order to avoid future actions on it
            _session = nil
        }
    }

    private func tearDownAVCapture() {
        if _session?.isRunning == true {
            // always test 'isRunning' before a stop (iOS may crash)
            _session?.stopRunning()
        }
        isFrameReady = false
        cleanUpTextures()
    }

    // AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            ULog.e(.hmdTag, "ERROR: pixelBuffer cannot be retrieved")
            return
        }
        guard _videoTextureCache != nil else {
            ULog.e(.hmdTag, "No video texture cache")
            return
        }

        if connection.isVideoOrientationSupported {
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                if connection.videoOrientation != .landscapeRight {
                    connection.videoOrientation = .landscapeRight
                }
            case .landscapeRight:
                if connection.videoOrientation != .landscapeLeft {
                    connection.videoOrientation = .landscapeLeft
                }
            default:
                break
            }
        }

        newFrameSinceLastDraw = true

        lastPixelBuffer = pixelBuffer
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // release _lumaTexture and _chromaTexture
        // CVOpenGLESTextureCacheFlush
        // CVOpenGLESTextureCacheCreateTextureFromImage will create GLES texture (in the render function)
        self.cleanUpTextures()

        if CGFloat(width) != _textureWidth || CGFloat(height) != _textureHeight {
            // New size -> change ratio for Aspect Fill
            _textureWidth = CGFloat(width)
            _textureHeight = CGFloat(height)
            updateTexCoordAspect()
            setupBuffers()
        }
        isFrameReady = true
    }

    private func setupBuffers() {
        guard isGlReady else {
            return
        }
        tearDownVboEbo()
        setupVboEbo()
    }

    private func centerVideoRect(normalizedSize: CGSize) -> CGRect {
        var borderWidth = CGFloat(0)
        var borderHeight = CGFloat(0)

        if normalizedSize.width < 1.0 {
            borderWidth = (1.0 - normalizedSize.width) * 0.5
        }
        if normalizedSize.height < 1.0 {
            borderHeight = (1.0 - normalizedSize.height) * 0.5
        }
        return CGRect(x: borderWidth, y: borderHeight, width: normalizedSize.width, height: normalizedSize.height)
    }

}

// MARK: - GGLDrawable concordance
extension GGLCameraQuad {
    func drawableDidSetupGl(_ context: EAGLContext) {
        // load shaders
        loadShaders(vshName: "streamShader", fshName: "streamShader") { _ in
            // Bind attribute locations.
            // This needs to be done prior to linking.
            glBindAttribLocation(programId, GLuint(GGLVertexAttribPosition), "position")
            glBindAttribLocation(programId, GLuint(GGLVertexAttribTexCoord0), "texCoord")
        }
        // Get uniform locations.
        uniforms[UNIFORM_Y] = glGetUniformLocation(programId, "SamplerY")
        uniforms[UNIFORM_UV] = glGetUniformLocation(programId, "SamplerUV")
        // use program
        glUseProgram(programId)
        glUniform1i(uniforms[UNIFORM_Y], 0)
        glUniform1i(uniforms[UNIFORM_UV], 1)
        // AV Capture ON
        if enable {
            setupAVCapture(context)
        }
    }

    func renderDrawable(frame: CGRect) {
        newFrameSinceLastDraw = false
        glViewport(0, 0, GLsizei(frame.size.width), GLsizei(frame.size.height))
        if isFrameReady {
            if renderSize != frame.size {
                renderSize = frame.size
                updateTexCoordAspect()
            }
            glUseProgram(programId)
            if _lumaTexture == nil || _chromaTexture == nil {
                var err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                       _videoTextureCache!,
                                                                       lastPixelBuffer!,
                                                                       nil,
                                                                       GLenum(GL_TEXTURE_2D),
                                                                       GL_R8,
                                                                       GLsizei(_textureWidth),
                                                                       GLsizei(_textureHeight),
                                                                       GLenum(GL_RED),
                                                                       GLenum(GL_UNSIGNED_BYTE),
                                                                       0,
                                                                       &_lumaTexture)
                if err != 0 {
                    ULog.e(.hmdTag, "Error at CVOpenGLESTextureCacheCreateTextureFromImage luma \(err)")
                    return
                }
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                   _videoTextureCache!,
                                                                   lastPixelBuffer!,
                                                                   nil,
                                                                   GLenum(GL_TEXTURE_2D),
                                                                   GL_RG8,
                                                                   GLsizei(_textureWidth/2),
                                                                   GLsizei(_textureHeight/2),
                                                                   GLenum(GL_RG),
                                                                   GLenum(GL_UNSIGNED_BYTE),
                                                                   1,
                                                                   &_chromaTexture)
                if err != 0 {
                    ULog.e(.hmdTag, "Error at CVOpenGLESTextureCacheCreateTextureFromImage chroma \(err)")
                }
            }

            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture!), CVOpenGLESTextureGetName(_lumaTexture!))
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))

            glActiveTexture(GLenum(GL_TEXTURE1))
            glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture!), CVOpenGLESTextureGetName(_chromaTexture!))
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))

            drawTriangles()
            glUseProgram(0)
            glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture!), 0)
            glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture!), 0)
        }
    }

    func drawableWillTearDownGl(_ context: EAGLContext) {
        tearDownAVCapture()
    }
}
