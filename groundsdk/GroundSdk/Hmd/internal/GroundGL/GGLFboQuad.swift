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

/// OpenGl object in order to render a texture handled in a Frame Buffer Obejct
class GGLFboQuad: GGLFbo, GGLDrawable {

    var currentContext: EAGLContext?

    /// OpenGl coordinates where the texture is drawn
    public var posXY = CGPoint(x: 0, y: 0)

    // GGLDrawable concordance
    var isGlReady =  false
    var enable = false
    var vertices: [GGLVertex] = [GGLVertex(x: 1, y: 1, z: 0, u: 1, v: 0),
                                 GGLVertex(x: 1, y: -1, z: 0, u: 1, v: 1),
                                 GGLVertex(x: -1, y: -1, z: 0, u: 0, v: 1),
                                 GGLVertex(x: -1, y: 1, z: 0, u: 0, v: 0)]
    var indices: [GLubyte] = [0, 1, 2, 3, 0, 1]
    var ebo = GLuint()
    var vbo = GLuint()
    var vao = GLuint()
    var text = GLuint()

    /// Texture from the FBO
    private var textureInfo: GLKTextureInfo!

    /// Render effect
    private var effect = GLKBaseEffect()

    // GGLDrawable protocol
    func drawableWillSetupGl(_ context: EAGLContext) {
        effect = GLKBaseEffect()

        let cgiImage = UIImage(named: "ghost")!.cgImage
        if let textureInfo = try? GLKTextureLoader.texture(with: cgiImage!) {
            effect.texture2d0.name = textureInfo.name
            effect.texture2d0.enabled = GLboolean(UInt8(GL_TRUE))
        }
    }

    func renderDrawable(frame: CGRect) {
        // Clear the framebuffer
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        let screenScale = CGFloat(UIScreen.main.scale)
        glViewport(
            GLint(posXY.x), GLint(posXY.y), GLsizei(frame.size.width * screenScale),
            GLsizei(frame.size.height * screenScale))
        effect.prepareToDraw()
        drawTriangles()
        glViewport(0, 0, 0, 0)
    }

    deinit {
        drawableTearDownGl()
    }
}
