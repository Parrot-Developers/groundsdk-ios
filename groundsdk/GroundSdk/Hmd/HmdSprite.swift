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

/// Class for creating sprites from an image. The sprites are meant to be rendered (OpenGl) in the HMD overlays.
public class HmdSprite: Hashable {

    /// true or false whether the sprite is visible.
    public var enable: Bool {
        get {
            return quad.enable
        }
        set(newValue) {
            quad.enable = newValue
        }
    }

    /// The current position for the sprite (x,y coords. 0,0 is the lower left corner)
    public var currentPosition: CGPoint {
        get {
            return quad.posXY
        }
        set(newPosition) {
            quad.posXY = newPosition
        }
    }

    /// The size of the sprite. This size is the real pixel size in the OpenGl context
    public var displaySize: CGSize { return quad.displaySize }

    /// The name of the image (see `ìnit`)
    private let imageName: String

    /// The GGLQuad used to render the sprite.
    internal var quad: GGLTexturedQuad

    /// Private Constructor for a sprite
    ///
    /// - Parameters:
    ///   - imageName: The name of the image.
    ///   - texturedQuead: The quad used to render the image
    private init(imageName: String, texturedQuead: GGLTexturedQuad) {
        self.imageName = imageName
        self.quad = texturedQuead
    }

    /// Constructor for a sprite
    ///
    /// - Parameters:
    ///   - imageName: The name of the image. For images in asset catalogs, specify the name of the image asset.
    /// For PNG image files, specify the filename without the filename extension. For all other image file formats,
    /// include the filename extension in the name.
    ///   - scale: scale factor for the sprite (default is 1)
    ///
    /// - Returns: nil if the sprite can not be created
    convenience public init?(imageName: String, scale: CGFloat = 1) {
        do {
            let quad = try GGLTexturedQuad(imageName: imageName, scale: scale)
            self.init(imageName: imageName, texturedQuead: quad)
        } catch {
            return nil
        }
    }

    /// Constructor for a sprite
    ///
    /// - Parameters:
    ///   - imageName: The name of the image. For images in asset catalogs, specify the name of the image asset.
    /// For PNG image files, specify the filename without the filename extension. For all other image file formats,
    /// include the filename extension in the name.
    ///   - size: Size used to render the image (overrides the image's size)
    ///
    /// - Returns: nil if the sprite can not be created
    convenience public init?(imageName: String, size: CGSize) {
        guard let image = UIImage(named: imageName) else {
            return nil
        }
        do {
            let quad = try GGLTexturedQuad(image: image, size: size)
            self.init(imageName: imageName, texturedQuead: quad)
        } catch {
            return nil
        }
    }

    public static func == (lhs: HmdSprite, rhs: HmdSprite) -> Bool {
        return lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(imageName)
    }
}
