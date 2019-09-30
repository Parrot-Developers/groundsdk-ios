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

/// The GGLShaderLoader protocol describes an OpenGL object, with the ability to load shaders.
protocol GGLShaderLoader: class {

    // Id of the GL program
    var programId: GLuint {get set}

    /// Load, compile and link shaders
    ///
    /// - Parameters:
    ///   - vshName: Name of the vertex shader file in the main bundle (without the 'vsh' extension).
    ///   - fshName: Name of the fragment shader file in the main bundle (without the 'vsh' extension).
    ///   - bindClosure: closure used to bind elements before linking the program
    /// - Returns: true if success, false otherwise
    func loadShaders(vshName: String, fshName: String, bindClosure: ((_ program: GLuint) -> Void)) -> Bool
}

// MARK: - GGLShaderLoader extention - Default implementations
extension GGLShaderLoader {

    @discardableResult
    func loadShaders(vshName: String, fshName: String, bindClosure:((_ program: GLuint) -> Void) = {_ in }) -> Bool {
        var vertShader: GLuint = 0, fragShader: GLuint = 0

        // Create shader program.
        programId = glCreateProgram()

        // Create and compile vertex shader.
        guard let vertShaderURL = Bundle(for: GroundSdk.self).url(forResource: vshName, withExtension: "vsh"),
            compileShader(&vertShader, type: GLenum(GL_VERTEX_SHADER), url: vertShaderURL) else {
            ULog.e(.hmdTag, "Failed to compile vertex shader \(vshName)")
            return false
        }

        // Create and compile fragment shader.
        guard let fragShaderURL = Bundle(for: GroundSdk.self).url(forResource: fshName, withExtension: "fsh"),
            compileShader(&fragShader, type: GLenum(GL_FRAGMENT_SHADER), url: fragShaderURL) else {
            ULog.e(.hmdTag, "Failed to compile fragment shader \(fshName)")
            return false
        }

        // Attach vertex shader to program.
        glAttachShader(programId, vertShader)

        // Attach fragment shader to program.
        glAttachShader(programId, fragShader)

        // Bind attributes (using the closure parameter)
        // This needs to be done prior to linking.
        bindClosure(programId)

        // Link program.
        guard linkProgram(programId) else {
            ULog.e(.hmdTag, "Failed to link program: \(programId)")

            if vertShader != 0 {
                glDeleteShader(vertShader)
                vertShader = 0
            }
            if fragShader != 0 {
                glDeleteShader(fragShader)
                fragShader = 0
            }
            if programId != 0 {
                glDeleteProgram(programId)
                programId = 0
            }
            return false
        }

        // Release vertex and fragment shaders.
        if vertShader != 0 {
            glDetachShader(programId, vertShader)
            glDeleteShader(vertShader)
        }
        if fragShader != 0 {
            glDetachShader(programId, fragShader)
            glDeleteShader(fragShader)
        }
        return true
    }

    func compileShader(_ shader: UnsafeMutablePointer<GLuint>, type: GLenum, url: URL) -> Bool {
        var status: GLint = 0
        let isOK: Bool

        shader.pointee = glCreateShader(type)

        do {
            var source = try NSString(contentsOfFile: url.path, encoding: String.Encoding.ascii.rawValue)
                .cString(using: String.Encoding.ascii.rawValue)

            glShaderSource(shader.pointee, 1, &source, nil)
            glCompileShader(shader.pointee)
            isOK = true
        } catch {
            isOK = false
        }

        #if DEBUG
        var logLength: GLint = 0
        glGetShaderiv(shader.pointee, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        if logLength > 0 {
            var log: [GLchar] = Array(repeating: 0, count: Int(logLength))
            glGetShaderInfoLog(shader.pointee, logLength, &logLength, &log)
            ULog.d(.hmdTag, "Shader compile log:\n\(String(cString: log))")
        }
        #endif

        glGetShaderiv(shader.pointee, GLenum(GL_COMPILE_STATUS), &status)
        guard status != 0 else {
            glDeleteShader(shader.pointee)
            return false
        }
        return isOK
    }

    func linkProgram(_ prog: GLuint) -> Bool {
        var status: GLint = 0
        glLinkProgram(prog)

        #if DEBUG
        var logLength: GLint = 0
        glGetProgramiv(prog, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        if logLength > 0 {
            var log: [GLchar] = Array(repeating: 0, count: Int(logLength))
            glGetProgramInfoLog(prog, logLength, &logLength, &log)
            ULog.d(.hmdTag, "Program link log:\n\(String(cString: log))")
        }
        #endif

        glGetProgramiv(prog, GLenum(GL_LINK_STATUS), &status)
        return status != 0
    }

    func tearDownProgram () {
        if programId != 0 {
            glDeleteProgram(programId)
            programId = 0
        }
    }
}
