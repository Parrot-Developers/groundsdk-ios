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

/// Object handling a Texture Frame Buffer Object intended for offscreen rendering
public class GGLFbo {

    private var depthRenderbuffer = GLuint()

    /// Texture of the Frame Buffer Object
    public private(set) var fboTexture = GLuint()
    /// Framebuffer Id
    public private(set) var framebuffer = GLuint()
    /// Size required of the Frame Buffer
    public private(set) var size: CGSize
    /// OpenGl context associated
    public private(set) var context: EAGLContext?

    /// Constructor
    /// Creates on Object handling a Texture Frame Buffer Object intended for offscreen rendering.
    ///
    /// Note: returns nil if the FBO can not be created
    ///
    /// - Parameters:
    ///   - context: current OpenGl context
    ///   - size: size required for the Frame Buffer Object
    ///   - depthRender: true to create a depth or depth/stencil renderbuffer, allocate storage for it,
    /// and attach it to the framebuffer’s depth attachment point.
    init? (context: EAGLContext, size: CGSize, depthRender: Bool = false) {
        self.context = context
        self.size = size
        EAGLContext.setCurrent(context)
        if createOffScreenFramebuffer(depthRender: depthRender) == false {
            return nil
        }
    }

    /// Creating Offscreen Framebuffer Objects
    /// A framebuffer intended for offscreen rendering allocates all of its attachments as OpenGL ES renderbuffers.
    /// The function allocates a framebuffer object with color and depth attachments.
    ///
    /// - Parameters:
    ///   - depthRender: true to create a depth or depth/stencil renderbuffer, allocate storage for it,
    /// and attach it to the framebuffer’s depth attachment point. false otherwise.
    /// - Returns: return true if the FBO is created (false otherwise). See `framefuffer` and `fboTexture` properties.
    private func createOffScreenFramebuffer(depthRender: Bool) -> Bool {

        let success: Bool

        //Create the framebuffer and bind it.
        let width = GLsizei(size.width)
        let height = GLsizei(size.height)

        glGenFramebuffers(1, &framebuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)

        // create the texture FBO
        glGenTextures(1, &fboTexture)
        glBindTexture(GLenum(GL_TEXTURE_2D), fboTexture)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexImage2D(
            GLenum(GL_TEXTURE_2D), 0, GL_RGBA8, width, height, 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), nil)
        glFramebufferTexture2D(
            GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D), fboTexture, 0)

        // Create a depth or depth/stencil renderbuffer, allocate storage for it,
        // and attach it to the framebuffer’s depth attachment point.
        if depthRender {
            glGenRenderbuffers(1, &depthRenderbuffer)
            glBindRenderbuffer(GLenum(GL_RENDERBUFFER), depthRenderbuffer)
            glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT16), width, height)
            glFramebufferRenderbuffer(GLenum(
                GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), GLenum(GL_RENDERBUFFER), depthRenderbuffer)
        }

        // Test the framebuffer for completeness.
        // This test only needs to be performed when the framebuffer’s configuration changes.
        let status = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
        if status != GL_FRAMEBUFFER_COMPLETE {
            ULog.e(.hmdTag, "ERROR - failed to make complete framebuffer object \(status)")
            success = false
        } else {
            success = true
        }
        // After drawing to an offscreen renderbuffer, you can return its contents to the CPU for further processing
        // using the glReadPixels function.
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        return success
    }

    deinit {
        EAGLContext.setCurrent(context)
        if framebuffer != 0 {
            glDeleteFramebuffers(1, &framebuffer)
        }
        if depthRenderbuffer != 0 {
            glDeleteRenderbuffers(1, &depthRenderbuffer)
        }
        if fboTexture != 0 {
            glDeleteTextures(1, &fboTexture)
        }
    }
}
