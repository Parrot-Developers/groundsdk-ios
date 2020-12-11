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

/// OpenGl Object that renders a texture with distortion (depending on the type of CockpitGlasses used).
/// This object is used by the HmdViewController class.
class GGLDistortionMesh: GGLDrawable, GGLShaderLoader {

    enum Eye {
        case left
        case right
    }

    var zoomForAspectFit = CGFloat(1)

    let _calibrationPitch = GLfloat(0)

    let cockpitData: CockpitData
    var textureImage = GLuint(0)

    var squarePixelSize: Int {
        if let pixelPerMM = UIScreen.pixelsPerCentimeter {
            return Int(widthSquareMesh * pixelPerMM / CGFloat(10))
        } else {
            return 1280
        }
    }

    // Renderer parameters
    let kInchInMM: CGFloat =  25.4
    let kDefaultScale: GLfloat = 1.0
    let widthSquareMesh: CGFloat

    let calculatedDistScaleFactor: (red: Float, green: Float, blue: Float)

    internal var programId = GLuint()

    private var interpupillaryDistanceMM: CGFloat
    private var betterImmersion = true {
        didSet {
            computeDimensions()
        }
    }

    private var shiftTextureForImmersion = GLfloat(0)
    private var phoneOffsetY = GLfloat(0)
    private var _dpi = CGFloat()
    private var _deviceScale = CGFloat()
    private var _mmWidth = CGFloat()
    private var _mmHeight = CGFloat()
    private var _xScale = GLfloat()
    private var _yScale = GLfloat()
    private var textScale = GLfloat(1)
    private var customVerticalOffset = GLfloat(0)
    private var _screenSize: CGSize {
        let scale = UIScreen.main.nativeScale
        return CGSize(width: UIScreen.main.bounds.size.width * scale, height: UIScreen.main.bounds.size.height * scale)
    }

    // buffers Data
    private var positionData: [GLfloat]
    private var indicesData: [GLuint]
    private var texCoordsData: [GLfloat]
    private var colorData: [GLfloat]?

    // Buffers Ids
    private var positionID = GLuint()
    private var texCoords = GLuint()
    private var colorID = GLuint()
    private var indicesID = GLuint()

    // Program Attributes
    // Attributes
    private var programAttrPosition = GLint()
    private var programAttrTexCoord = GLint()
    private var programAttrColor = GLint()

    // Program Uniforms
    private var programUniformTexture0 = GLint()
    private var programUniformEyeToSourceOffset = GLint()
    private var programUniformEyeToSourceScale = GLint()
    private var programUniformTextureCoordOffset = GLint()
    private var programUniformTextureCoordScale = GLint()
    private var programUniformTextureCoordScaleDistFactor = GLint()
    private var programUniformChromaticAberrationCorrection = GLint()
    private var programUniformLensLimits = GLint()

    // GGLDrawable concordance
    var isGlReady =  false
    var currentContext: EAGLContext?
    var enable = false
    var vertices: [GGLVertex] = [GGLVertex]()
    var indices: [GLubyte] =  [GLubyte]()
    var ebo = GLuint()
    var vbo = GLuint()
    var vao = GLuint()
    var text = GLuint()

    // Constants
    let sizeScreen = CGSize(
        width: UIScreen.main.bounds.width * UIScreen.main.scale,
        height: UIScreen.main.bounds.height * UIScreen.main.scale)
    let halfWidth = (UIScreen.main.bounds.width * UIScreen.main.scale) / 2

    init?(cockpitName: String, cockpitRessources: CockpitRessources) {
        guard let cockpitData = cockpitRessources.getCockpit(name: cockpitName) else {
            return nil
        }
        self.cockpitData = cockpitData
        interpupillaryDistanceMM = cockpitData.defaultInterpupillaryDistanceMM
        positionData = cockpitRessources.getPositions(cockpitName: cockpitName)
        if let max = positionData.max() {
            widthSquareMesh = CGFloat(max * 2)
        } else {
            widthSquareMesh = CGFloat(cockpitData.meshSize)
        }
        indicesData = cockpitRessources.getIndices(cockpitName: cockpitName)
        texCoordsData = cockpitRessources.getTextCoords(cockpitName: cockpitName)
        colorData = cockpitRessources.getColorsFilter(cockpitName: cockpitName)
        calculatedDistScaleFactor = cockpitData.calculatedDistScaleFactor

        _dpi = UIScreen.pixelsPerInch ?? 401
        _deviceScale = UIScreen.main.scale
        /* We downsample to 401 dpi */
        if _dpi > 401.0 {
            _dpi = 401.0
            _deviceScale = 2.0
        } else { /* Dpi is as we expected */
            _deviceScale = 2.0 - (_deviceScale - 2.0)
        }

        _mmWidth = round((_screenSize.width * kInchInMM) / _dpi)
        _mmHeight = round((_screenSize.height * kInchInMM) / _dpi)
        _xScale = GLfloat(2.0 / _mmWidth)
        _yScale = GLfloat(2.0 / _mmHeight)
        textScale =  1

        computeDimensions()
    }

    /// Specify the interpupillar distance
    ///
    /// - Parameter ipd: interpupilalr distance in mm
    func setInterpullarDistance(_ ipd: CGFloat) {
        let newIpd: CGFloat
        let interval = cockpitData.minMaxInterpupillaryDistanceMM
        if interval.contains(ipd) {
            newIpd = ipd
        } else {
            newIpd = ipd < interval.lowerBound ? interval.lowerBound : interval.upperBound
        }
        interpupillaryDistanceMM = newIpd
    }

    /// Specify the vertical offset of the rendering
    ///
    /// - Parameter verticalOffset: vertical Offset to apply  in mm
    func setVerticalOffset(_ verticalOffset: Double) {
        customVerticalOffset = GLfloat(verticalOffset)
    }

    private func computeDimensions() {
        let totalWidth = interpupillaryDistanceMM + widthSquareMesh
        let cropWidth = max(totalWidth - _mmWidth, 0)

        let visibleSquareWidth: CGFloat
        if betterImmersion {
            shiftTextureForImmersion = GLfloat(cropWidth / 2)
            visibleSquareWidth = widthSquareMesh - CGFloat(shiftTextureForImmersion)
        } else {
            shiftTextureForImmersion = 0
            visibleSquareWidth = widthSquareMesh - cropWidth
        }

        let zoomForWidth = (visibleSquareWidth / widthSquareMesh)

        let totalHeight = widthSquareMesh
        let cropHeight = (totalHeight - _mmHeight)
        let visibleSquareHeight = widthSquareMesh - cropHeight
        let zoomForHeight = (visibleSquareHeight / widthSquareMesh)

        if widthSquareMesh < _mmHeight {
            phoneOffsetY = GLfloat((_mmHeight - widthSquareMesh) / 2)
        } else {
            phoneOffsetY = 0
        }

        zoomForAspectFit = min(1, zoomForHeight, zoomForWidth)
    }

    func drawableWillSetupGl(_ context: EAGLContext) {
    }

    // GGLDrawable concordance - define a new setupVboEbo() function
    func setupVboEbo() {
        // Positions
        glGenBuffers(1, &positionID)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), positionID)
        glBufferData(GLenum(GL_ARRAY_BUFFER),
                     positionData.size(),
                     positionData,
                     GLenum(GL_STATIC_DRAW))
        // TEX COORDS
        glGenBuffers(1, &texCoords)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), texCoords)
        glBufferData(GLenum(GL_ARRAY_BUFFER),
                     texCoordsData.size(),
                     texCoordsData,
                     GLenum(GL_STATIC_DRAW))

        // Colors
        if let colorData = colorData {
            glGenBuffers(1, &colorID)
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), colorID)
            glBufferData(GLenum(GL_ARRAY_BUFFER),
                         colorData.size(),
                         colorData,
                         GLenum(GL_STATIC_DRAW))
        }
        /// EBO
        glGenBuffers(1, &indicesID)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indicesID)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
                     indicesData.size(),
                     indicesData,
                     GLenum(GL_STATIC_DRAW))

        // Unbind (detach) buffers.
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
    }

    func drawableDidSetupGl(_ context: EAGLContext) {
        // load shaders
        loadShaders(vshName: "distortionShader", fshName: "distortionShader") { _ in
        }

        glUseProgram(programId)

        // Attributes
        programAttrPosition = glGetAttribLocation(programId, "aPosition")
        programAttrTexCoord = glGetAttribLocation(programId, "aTexCoord")
        programAttrColor = glGetAttribLocation(programId, "aColor")

        // Get uniform locations.
        programUniformTexture0 = glGetUniformLocation(programId, "uTexture0")
        programUniformEyeToSourceOffset = glGetUniformLocation(programId, "uEyeToSourceOffset")
        programUniformEyeToSourceScale = glGetUniformLocation(programId, "uEyeToSourceScale")
        programUniformTextureCoordOffset = glGetUniformLocation(programId, "uTextureCoordOffset")
        programUniformTextureCoordScale = glGetUniformLocation(programId, "uTextureCoordScale")
        programUniformTextureCoordScaleDistFactor = glGetUniformLocation(programId, "uTextureCoordScaleDistFactor")
        programUniformLensLimits = glGetUniformLocation(programId, "uLensLimits")

        glUseProgram(0)
    }

    private func finalizeRender(eye: Eye) {

        let halfIDM = GLfloat(self.interpupillaryDistanceMM / 2)

        /* Use GL_SCISSOR to restrict the clear concerned eye viewport */
        glEnable(GLenum(GL_SCISSOR_TEST))
        glScissor((eye == .left) ? 0 : GLint(halfWidth), 0, GLsizei(halfWidth), GLsizei(sizeScreen.height))

        if eye == .left {
            glClearColor(0.0, 0.0, 0.0, 1.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        }

        /* Render to distortion shader */
        renderWithEye(
            mEyeOffsetX: (eye == .left) ? -GLfloat(halfIDM) : GLfloat(halfIDM), mEyeOffsetY: customVerticalOffset,
            ipdOffset: (eye == .left) ? -shiftTextureForImmersion: shiftTextureForImmersion)

        /* End GL_SCISSOR */
        glDisable(GLenum(GL_SCISSOR_TEST))
    }

    private func renderWithEye(mEyeOffsetX: GLfloat, mEyeOffsetY: GLfloat, ipdOffset: GLfloat) {

        let xOffset = 2.0 * mEyeOffsetX / GLfloat(_mmWidth)

        let yOffset = ((2.0 * mEyeOffsetY) + phoneOffsetY) / GLfloat(_mmHeight)

        /* Uniforms */
        glUniform1i(programUniformTexture0, 0)

        let shiftTexture = ipdOffset / GLfloat(_mmWidth)
        glUniform2f(programUniformTextureCoordOffset, shiftTexture, _calibrationPitch)

        glUniform2f(programUniformTextureCoordScale, kDefaultScale, kDefaultScale)

        glUniform3f(programUniformTextureCoordScaleDistFactor, calculatedDistScaleFactor.red,
                    calculatedDistScaleFactor.green, calculatedDistScaleFactor.blue)

        glUniform2f(programUniformEyeToSourceOffset, xOffset, yOffset)
        glUniform2f(programUniformEyeToSourceScale, _xScale, _yScale)
        glUniform2f(programUniformTextureCoordScale, textScale, textScale)

        /* Draw */
        glDrawElements(GLenum(GL_TRIANGLES), GLsizei(indicesData.count), GLenum(GL_UNSIGNED_INT), nil)
    }

    func renderDrawable(frame: CGRect) {
        guard textureImage != 0, enable == true else {
            return
        }
        /* Beging program */
        glUseProgram(programId)

        /* Texture */
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), textureImage)
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)

        /* Binds */
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indicesID)
        /* Vertices */
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), positionID)
        glVertexAttribPointer(GLuint(programAttrPosition), 2, GLenum(GL_FLOAT), GLboolean(UInt8(GL_FALSE)), 0, nil)
        glEnableVertexAttribArray(GLuint(programAttrPosition))

        /* Color */
        if colorID != 0 {
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), colorID)
        glVertexAttribPointer(GLuint(programAttrColor), 4, GLenum(GL_FLOAT), GLboolean(UInt8(GL_FALSE)), 0, nil)
            glEnableVertexAttribArray(GLuint(programAttrColor))
        } else {
            glDisableVertexAttribArray(GLuint(programAttrColor))
            glVertexAttrib4f(GLuint(programAttrColor), 1, 1, 1, 1)
        }

        /* TexCoords */
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), texCoords)
        glVertexAttribPointer(GLuint(programAttrTexCoord), 2, GLenum(GL_FLOAT), GLboolean(UInt8(GL_FALSE)), 0, nil)
        glEnableVertexAttribArray(GLuint(programAttrTexCoord))

        finalizeRender(eye: .left)
        finalizeRender(eye: .right)

        /* End */
        glDisableVertexAttribArray(GLuint(programAttrPosition))
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        glUseProgram(0)
    }

    func drawableWillTearDownGl(_ context: EAGLContext) {
        // Buffers Ids
        if positionID != 0 {
            glDeleteBuffers(1, &positionID)
            positionID = 0
        }
        if texCoords != 0 {
            glDeleteBuffers(1, &texCoords)
            texCoords = 0
        }
        if colorID != 0 {
            glDeleteBuffers(1, &colorID)
            colorID = 0
        }
        if indicesID != 0 {
            glDeleteBuffers(1, &indicesID)
            indicesID = 0
        }
    }

    deinit {
        drawableTearDownGl()
    }
}
