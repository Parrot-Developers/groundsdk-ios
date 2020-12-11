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

/// OpenGl to draw an image. The image can be a file defined in the `init()` or an OpenGl texture set in the object
/// after the initialization phase.
class GGLTexturedQuad: GGLDrawable {

    public var scale = CGFloat(1.0)
    public var posXY = CGPoint(x: 0, y: 0)
    public var displaySize: CGSize {
        return CGSize(width: CGFloat(textureWidth) * scale, height: CGFloat(textureHeight) * scale)
    }
    public var modelviewMatrix: GLKMatrix4 {
        get {
            return effect.transform.modelviewMatrix
        }
        set {
            effect.transform.modelviewMatrix = newValue
        }
    }

    private enum QuadSource {
        case fromImage
        case fromExternalTexture
    }

    // GGLDrawable concordance
    var isGlReady =  false
    var currentContext: EAGLContext?
    var enable = false
    var vertices: [GGLVertex]
    var indices: [GLubyte] = [0, 1, 2, 3, 0, 1]
    var ebo = GLuint()
    var vbo = GLuint()
    var vao = GLuint()
    var text = GLuint()

    private var source: QuadSource

    // image
    var name = ""
    private var cgiImage: CGImage?

    // external texture
    private var externalTextureName = GLuint()

    // Effect
    lazy private var effect = GLKBaseEffect()
    // Texture
    private var textureInfo: GLKTextureInfo?
    private let textureWidth: GLfloat
    private let textureHeight: GLfloat

    let useOrthoProjection: Bool

    /// Constructor
    ///
    /// - Parameters:
    ///   - image: the image to display.
    ///   - size: size of the texture. If an image is specified in the 'image' parameter and the size parameter is not
    /// used, the image's size will be used.
    ///   - orthoProjection: true if the render uses an orthogonal projection, false to render in a viewport.
    ///      Default value is true.
    ///   - scale: scale factor to apply to the texture. Default is 1.0.
    ///   - forceFlip: true in order to flip the final render, false otherwise.
    /// - Throws: Throws an error if no image was found
    init(image: UIImage? = nil, size: CGSize? = nil, orthoProjection: Bool = false, scale: CGFloat = 1.0,
         forceFlip: Bool? = nil) throws {

        let initSize: CGSize

        if let image = image {
            // Init with image
            source = .fromImage
            guard let cgiImage = image.cgImage else {
                ULog.e(.hmdTag, "ERROR - GGLTexturedQuad: no image")
                throw (GGLError.noImage)
            }
            self.cgiImage = cgiImage
            if let size = size {
                initSize = size
            } else {
                initSize = CGSize(width: cgiImage.width, height: cgiImage.height)
            }
        } else {
            source = .fromExternalTexture
            // Init with size
            if let size = size {
                initSize = size
            } else {
                throw (GGLError.noSize)
            }
        }

        self.useOrthoProjection = orthoProjection
        self.scale = scale
        textureWidth = GLfloat(initSize.width)
        textureHeight = GLfloat(initSize.height)

        // affects vertices
        let screenScale = GLfloat(UIScreen.main.scale)
        let isFlip: Bool
        if let forceFlip = forceFlip {
            isFlip = forceFlip
        } else {
            isFlip = (source == .fromImage)
        }
        let flipValue = isFlip ? GLfloat(-1.0) : GLfloat(1.0)
        let width = textureWidth * GLfloat(scale)
        let height = textureHeight * GLfloat(scale)
        let left = orthoProjection ? width / -screenScale : -1
        let right = orthoProjection ? width / screenScale : 1
        let top = (orthoProjection ? height / screenScale : 1) * flipValue
        let bottom = (orthoProjection ? height / -screenScale : -1) * flipValue

        vertices = [
            GGLVertex(x: right, y: bottom, z: 0, u: 1, v: 0),
            GGLVertex(x: right, y: top, z: 0, u: 1, v: 1),
            GGLVertex(x: left, y: top, z: 0, u: 0, v: 1),
            GGLVertex(x: left, y: bottom, z: 0, u: 0, v: 0)]
    }

    /// Convenience constructor (with image file name)
    ///
    /// - Parameters:
    ///   - imageName: the name of the image. For images in asset catalogs, specify the name of the asset.
    ///   For PNG image files, specify the filename without the filename extension. For all other image file formats,
    ///   include the filename extension in the name.
    ///   - orthoProjection: true if the render uses an orthogonal projection, false to render in a viewport.
    ///      Default value is true.
    ///   - scale: scale factor to apply to the texture. Default is 1.0.
    ///   - forceFlip: true in order to flip the final render, false otherwise.
    /// - Throws: Throws an error if no image was found
    convenience init(imageName: String, orthoProjection: Bool = false, scale: CGFloat = 1.0,
                     forceFlip: Bool? = nil) throws {
        guard let image = UIImage(named: imageName) else {
            throw (GGLError.noImage)
        }
        try self.init(image: image, size: nil, orthoProjection: orthoProjection, scale: scale, forceFlip: forceFlip)
    }

    func updateTextureName(textId: GLuint) {
        guard source == .fromExternalTexture else {
            return
        }
        if externalTextureName != textId {
            externalTextureName = textId
            effect.texture2d0.name = externalTextureName
            effect.texture2d0.enabled = GLboolean(UInt8(GL_TRUE))
        }
    }

    private func setupGl() {
        switch source {
        case .fromImage:
            if let cgiImage = cgiImage {
                textureInfo = try? GLKTextureLoader.texture(with: cgiImage)
                if let textureInfo = textureInfo {
                    effect.texture2d0.name = textureInfo.name
                    effect.texture2d0.enabled = GLboolean(UInt8(GL_TRUE))
                }
            }
        case .fromExternalTexture:
            break
        }
    }

    // GGLDrawable protocol
    func drawableWillSetupGl(_ context: EAGLContext) {
        setupGl()
    }

    func renderDrawable(frame: CGRect) {
        if source == .fromExternalTexture && externalTextureName == 0 {
            return
        }

        if !useOrthoProjection {
            let width = GLsizei(CGFloat(textureWidth) * scale)
            let height = GLsizei(CGFloat(textureHeight) * scale)
            glViewport(GLint(posXY.x), GLint(posXY.y), width, height)
        } else {
            glViewport(0, 0, GLsizei(frame.size.width), GLsizei(frame.size.height))
            effect.transform.projectionMatrix = GLKMatrix4MakeOrtho(
                0, Float(frame.size.width), 0, Float(frame.size.height), 0, 1)
        }
        effect.prepareToDraw()
        drawTriangles()
    }

    private func deleteTexture() {
        effect.texture2d0.enabled = GLboolean(UInt8(GL_FALSE))
        switch source {
        case .fromImage:
            var idTexture = effect.texture2d0.name
            glDeleteTextures(1, &idTexture)
        case .fromExternalTexture:
            if externalTextureName != 0 {
                glDeleteTextures(1, &externalTextureName)
                externalTextureName = 0
            }
        }
    }

    deinit {
        EAGLContext.setCurrent(currentContext)
        deleteTexture()
        drawableTearDownGl()
    }
}
