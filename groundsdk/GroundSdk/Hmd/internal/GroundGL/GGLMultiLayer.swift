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

import Foundation
import GLKit

/// Object allowing the composition of different layers in a final layer. Each Layer can be rendered separately,
/// enabled or disabled.
class GGLMultiLayer {

    typealias LayerId = Int

    private enum Aspect {
        case fill
        case fit
    }

    private enum LayerType {
        case framebuffer(GGLFbo)
        case externalTexture(size: CGSize, autorelease: Bool)
    }

    private class Layer {
        let type: LayerType
        var hidden: Bool
        var drawSize: CGSize!
        var newTexture = false
        var externalTextureId = GLuint() {
            didSet {
                switch type {
                case .externalTexture(_, let autoRelease):
                    if autoRelease {
                        var idToRemove = oldValue
                        if idToRemove != 0 {
                            glDeleteTextures(1, &idToRemove)
                        }
                    }
                default:
                    break
                }
                newTexture = true
            }
        }

        var textureId: GLuint {
            switch type {
            case .framebuffer(let fbo):
                return fbo.fboTexture
            case .externalTexture:
                return externalTextureId
            }
        }

        private var quadDrawingLayer: GGLTexturedQuad
        private var scaleOrigin: CGFloat
        fileprivate var zoom = CGFloat(1) {
            didSet {
                if oldValue != zoom {
                    setDrawSize()
                }
            }
        }

        init(type: LayerType, quad: GGLTexturedQuad, scale: CGFloat) {
            self.type = type
            self.quadDrawingLayer = quad
            hidden = true
            self.scaleOrigin = scale
            setDrawSize()
            switch type {
            // when we use a fbo, the texture will be allways the same. We set the texture once.
            case .framebuffer(let fbo):
                quadDrawingLayer.updateTextureName(textId: fbo.fboTexture)
            default :
                break
            }
        }

        private func setDrawSize() {
            switch type {
            case .framebuffer(let fbo):
                drawSize = CGSize(width: fbo.size.width * scaleOrigin * zoom,
                                  height: fbo.size.height * scaleOrigin * zoom)
            case .externalTexture(let size, _):
                drawSize = CGSize(width: size.width * scaleOrigin * zoom, height: size.height * scaleOrigin * zoom)
            }
            quadDrawingLayer.scale = scaleOrigin * zoom
        }

        func renderLayer(renderSize: CGSize) {
            // center
            let pos = CGPoint(x: (renderSize.width - drawSize.width) / 2,
                              y: (renderSize.height - drawSize.height) / 2)
            quadDrawingLayer.posXY = pos
            switch type {
            case .framebuffer:
                // nothing todo, the texture id was setted in the constructor.
                break
            case .externalTexture:
                if newTexture {
                    quadDrawingLayer.updateTextureName(textId: externalTextureId)
                    newTexture = false
                }
            }
            quadDrawingLayer.renderDrawable(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: renderSize))
        }

        deinit {
            if externalTextureId != 0 {
                switch type {
                case .externalTexture(_, let autoRelease):
                    if autoRelease {
                        glDeleteTextures(1, &externalTextureId)
                    }
                default:
                    break
                }
            }
        }
    }

    private var countId: LayerId = 0
    private var layers = [LayerId: Layer]()

    let renderSize: CGSize

    private var context: EAGLContext
    private var finalFbo: GGLFbo

    var wasUpdatedSinceLastGetFinal: Bool = true

    init?(context: EAGLContext, renderSize: CGSize) {
        self.renderSize = renderSize
        self.context = context
        if let finalFbo = GGLFbo(context: context, size: renderSize) {
            self.finalFbo = finalFbo
        } else {
            return nil
        }
    }

    func addExternalTextureLayer(size: CGSize, flip: Bool = false, autorelease: Bool =  true) -> LayerId? {
        return addLayer(type: .externalTexture(size: size, autorelease: autorelease), flip: flip)
    }

    func addFrameBufferLayer(size: CGSize, flip: Bool = false) -> LayerId? {
        guard let newFbo = GGLFbo(context: context, size: size) else {
            return nil
        }
        return addLayer(type: .framebuffer(newFbo), flip: flip)
    }

    private func addLayer(type: LayerType, flip: Bool) -> LayerId? {

        let size: CGSize

        switch type {
        case .framebuffer(let fbo):
            size = fbo.size
        case .externalTexture(let textureSize, _):
            size = textureSize
        }

        guard let newQuad = try? GGLTexturedQuad(size: size, forceFlip: flip) else {
                return nil
        }
        newQuad.drawableSetupGl(context: context)
        let scaleFactor = computeScaleFactor(aspect: .fit, fromSize: size, toSize: renderSize)
        newQuad.enable = true

        countId += 1

        layers[countId] = Layer(type: type, quad: newQuad, scale: scaleFactor)
        return countId
    }

    func setTexture(layerId: LayerId, texture: GLuint) {
        if let layer = layers[layerId] {
            switch layer.type {
            case .externalTexture:
                layer.externalTextureId = texture
                wasUpdatedSinceLastGetFinal = true
            default:
                break
            }
        }
    }

    func hide(layerId: LayerId, _ hide: Bool) {
        if let layer = layers[layerId], layer.hidden != hide {
            layer.hidden = hide
            wasUpdatedSinceLastGetFinal = true
        }
    }

    func getLayerFrameBuffer(id: LayerId) -> GLuint {
        if let layer = layers[id] {
            switch layer.type {
            case .framebuffer(let fbo):
                return fbo.framebuffer
            case .externalTexture:
                return 0
            }
        } else {
            return 0
        }
    }

    func setZoomForLayer(id: LayerId, zoom: CGFloat) {
        if let fboLayer = layers[id] {
            fboLayer.zoom = zoom
        }
    }

    func setLayersNeedsRefresh() {
        wasUpdatedSinceLastGetFinal = true
    }

    func getFinalFboTexture() -> GLuint {
        if wasUpdatedSinceLastGetFinal {
            renderAllLayersInFinalTexture()
            wasUpdatedSinceLastGetFinal = false
        }
        return finalFbo.fboTexture
    }

    private func renderAllLayersInFinalTexture() {
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.finalFbo.framebuffer)
        // Clear the framebuffer
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))

        layers.sorted { $0.0 < $1.0 }.forEach { (_, layer) in
            if layer.hidden == false {
                layer.renderLayer(renderSize: renderSize)
            }
        }

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
    }

    private func computeScaleFactor(aspect: Aspect, fromSize: CGSize, toSize: CGSize) -> CGFloat {
        let renderAspect = toSize.width / toSize.height
        let fromAspect = fromSize.width / fromSize.height
        let scaleFactor: CGFloat
        switch aspect {
        case .fit:
            if renderAspect > fromAspect {
                scaleFactor = toSize.height / fromSize.height
            } else {
                scaleFactor = toSize.width / fromSize.width
            }
        case .fill:
            if renderAspect < fromAspect {
                scaleFactor = toSize.height / fromSize.height
            } else {
                scaleFactor = toSize.width / fromSize.width
            }
        }
        return scaleFactor
    }
}
