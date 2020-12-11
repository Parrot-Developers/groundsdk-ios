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

/// The GGLDrawable protocol describes an OpenGL rendering object, with the initialization of the vertexes that
/// compose it
protocol GGLDrawable: class {
    /// True or False depending on whether the object is drawn when rendering.
    var enable: Bool { get set }

    /// true or false whether the object is initialized (a GGLview will not draw this object if the value is false)
    var isGlReady: Bool { get set }
    /// Current OpenGl context
    var currentContext: EAGLContext? { get set }

    /// GGLVertex array
    var vertices: [GGLVertex] { get }
    /// Vertex indices describing triangles
    var indices: [GLubyte] { get }

    /// element buffer object
    var ebo: GLuint { get set }
    /// vertex buffer object
    var vbo: GLuint { get set }
    /// vertex array object
    var vao: GLuint { get set }
    /// texture buffer object
    var text: GLuint { get set }

    /// Setup specific OpenGl elements.
    ///
    /// Note: The protocol provides a `drawableSetupGl()` default function. This function setup the Data,
    /// VirtualBufferObject and ElementBufferObject. The `drawableWillSetupGl ()` is called inside the drawableSetupGl()
    /// function. You can implement this function and use it to setup specifics elements.
    ///
    /// - Parameter context: Current OpenGL context
    func drawableWillSetupGl(_ context: EAGLContext)

    /// Setup specific OpenGl elements.
    ///
    /// Note: The protocol provides a `drawableSetupGl()` default function. This function setup the Data,
    /// VirtualBufferObject and ElementBufferObject. The `drawableDidSetupGl ()` is called inside the drawableSetupGl()
    /// function. You can implement this function and use it to setup specifics elements.
    ///
    /// - Parameter context: Current OpenGL context
    func drawableDidSetupGl(_ context: EAGLContext)

    /// TearDown specific OpenGl elements.
    ///
    /// Note: The protocol provides a `drawableTearDownGl()` default function. This function TearDown the Data,
    /// VirtualBufferObject and ElementBufferObject. The `drawableWillTearDownGl ()` is called inside the
    /// drawableTearDownGl() function. You can implement this function and use it to tearDown specifics elements.
    ///
    /// - Parameter context: Current OpenGL context
    func drawableWillTearDownGl(_ context: EAGLContext)

    /// TearDown specific OpenGl elements.
    ///
    /// Note: The protocol provides a `drawableTearDownGl()` default function. This function TearDown the Data,
    /// VirtualBufferObject and ElementBufferObject. The `drawableDidTearDownGl ()` is called inside the
    /// drawableTearDownGl() function. You can implement this function and use it to tearDown specifics elements.
    ///
    /// - Parameter context: Current OpenGL context
    func drawableDidTearDownGl(_ context: EAGLContext)

    /// Setup OpenGl elements.
    ///
    /// Note: The protocol provides a `drawableSetupGl()` default function. This function setup the Data,
    /// VirtualBufferObject and ElementBufferObject. The `drawableWillSetupGl (context)`
    /// and `drawableDidSetupGl (context)` will be called in order to add specific configurations for the object that
    /// implements the GGLDRawable protocol.
    ///
    /// - Parameter context: Current OpenGL context
    func drawableSetupGl(context: EAGLContext)

    /// TearDown OpenGl elements.
    ///
    /// Note: The protocol provides a `drawableTearDownGl()` default function. This function clean the Data,
    /// VirtualBufferObject and ElementBufferObject. The `drawableWillTearDown(context)` and
    /// `drawableWillTearDown(context)` will be called in order to add specific cleans.
    func drawableTearDownGl()

    /// Setup the Data, VirtualBufferObject and ElementBufferObject (all buffer are unbind after executing the function)
    ///
    /// Note: The GL context must be set before calling this function. The protocol provides a default function.
    func setupVboEbo ()

    /// Draw triangles
    ///
    /// Note: The GL context must be set before calling this function. The protocol provides a default function.
    func drawTriangles()

    /// Rendering of the object.
    ///
    /// Note: The GL context must be set before calling this function.
    func renderDrawable(frame: CGRect)

    /// Clean all Data, VBO and EBO
    ///
    /// Note: The GL context must be set before calling this function. The protocol provides a default function, and
    /// this function is called by tearDownGl
    func tearDownVboEbo ()
}

// MARK: - GGLDrawable extention - Default implementations
extension GGLDrawable {

    // implementations can implement these function for specific setup / tearDown
    func drawableWillSetupGl(_ context: EAGLContext) {}
    func drawableDidSetupGl(_ context: EAGLContext) {}
    func drawableWillTearDownGl(_ context: EAGLContext) {}
    func drawableDidTearDownGl(_ context: EAGLContext) {}

    func drawableSetupGl(context: EAGLContext) {
        guard !isGlReady else {
            return
        }
        currentContext = context
        EAGLContext.setCurrent(context)
        drawableWillSetupGl(context)
        setupVboEbo()
        drawableDidSetupGl(context)
        isGlReady = true
    }

    func drawableTearDownGl() {
        isGlReady = false
        if let context = currentContext {
            EAGLContext.setCurrent(context)
            drawableWillTearDownGl(context)
            tearDownVboEbo()
            // clean program if any
            if let self = self as? GGLShaderLoader {
                self.tearDownProgram()
            }
            drawableDidTearDownGl(context)
            currentContext = nil
            EAGLContext.setCurrent(nil)
        }
    }

    func setupVboEbo () {
        // ---- Vertex Array Bind
        glGenVertexArraysOES(1, &vao)
        glBindVertexArrayOES(vao)
        // Creating VBO Buffers
        glGenBuffers(1, &vbo)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        glBufferData(GLenum(GL_ARRAY_BUFFER),
                     vertices.size(),
                     vertices,
                     GLenum(GL_STATIC_DRAW))

        glEnableVertexAttribArray(GGLVertexAttribPosition)
        glVertexAttribPointer(GGLVertexAttribPosition,
                              GLint(GGLVertexNumberOfCoordinates),
                              GLenum(GL_FLOAT),
                              GLboolean(UInt8(GL_FALSE)),
                              GLsizei(GGLVertexSize),
                              nil)

        glEnableVertexAttribArray(GGLVertexAttribTexCoord0)
        glVertexAttribPointer(GGLVertexAttribTexCoord0,
                              2,
                              GLenum(GL_FLOAT),
                              GLboolean(UInt8(GL_FALSE)),
                              GLsizei(GGLVertexSize),
                              GGLVertexuvOffsetPointer)

        // Creating EBO Buffers. This will OpenGL what vertices to draw and in what order.
        glGenBuffers(1, &ebo)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), ebo)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
                     indices.size(),
                     indices,
                     GLenum(GL_STATIC_DRAW))

        // Unbind (detach) buffers.
        glBindVertexArrayOES(0)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
    }

    func drawTriangles() {
        glBindVertexArrayOES(vao)
        glDrawElements(GLenum(GL_TRIANGLE_STRIP),
                       GLsizei(indices.count),
                       GLenum(GL_UNSIGNED_BYTE),
                       nil)
        glBindVertexArrayOES(0)
    }

    func tearDownVboEbo() {
        if vao != 0 {
            glDeleteVertexArrays(1, &vao)
            vao = 0
        }
        if vbo != 0 {
            glDeleteBuffers(1, &vbo)
            vbo = 0
        }
        if ebo != 0 {
            glDeleteBuffers(1, &ebo)
            ebo = 0
        }
    }
}

/// Array extension
extension Array {
    /// Computes the array's number of bytes
    ///
    /// - Returns: array's number of bytes
    func size() -> Int {
        return MemoryLayout<Element>.stride * self.count
    }
}
