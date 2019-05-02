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

/// GL texture dimensions specification.
@objc(GSTextureSpec)
public class TextureSpec: NSObject {

    /// Texture width in pixels, '0' if not specified.
    public let width: Int

    /// Texture height in pixels, '0' if not specified.
    public let height: Int

    /// Texture aspect ratio width, '0' if not specified.
    public let ratioNumerator: Int

    /// Texture aspect ratio height, '0' if not specified.
    public let ratioDenominator: Int

    /// Request a GL texture with some dimensions as the source.
    public static let sourceDimensions = TextureSpec(width: 0, ratioNumerator: 0, ratioDenominator: 0)

    /// Request a GL texture with 4/3 aspect ratio.
    public static let aspectRatio43 = TextureSpec(width: 0, ratioNumerator: 4, ratioDenominator: 3)

    /// Request a GL texture with 16/9 aspect ratio.
    public static let aspectRatio169 = TextureSpec(width: 0, ratioNumerator: 16, ratioDenominator: 9)

    /// Requests a GL texture with specific dimensions.
    ///
    /// - Parameters:
    ///   - width: texture width
    ///   - height: texture height
    /// - Returns: a new TextureSpec instance
    public static func fixedSize(width: Int, height: Int) -> TextureSpec {
        return TextureSpec(width: width, ratioNumerator: width, ratioDenominator: height)
    }

    /// Requests a GL texture with specific aspect ratio.
    ///
    /// - Parameters:
    ///   - ratioNumerator: texture aspect ratio numerator value
    ///   - ratioDenominator: texture aspect ration denominator value
    /// - Returns: a new TextureSpec instance
    public static func fixedAspectRatio(ratioNumerator: Int, ratioDenominator: Int) -> TextureSpec {
        return TextureSpec(width: 0, ratioNumerator: ratioNumerator, ratioDenominator: ratioDenominator)
    }

    /// Requests a GL texture with specific aspect ratio.
    ///
    /// - Parameters:
    ///   - width: texture width, in pixels
    /// - Returns: a new TextureSpec instance
    public static func sourceAspectRatio(width: Int) -> TextureSpec {
        return TextureSpec(width: width, ratioNumerator: 0, ratioDenominator: 0)
    }

    /// Constructor.
    ///
    /// - Parameters:
    ///   - width: texture width, in pixels, '0' if unspecified
    ///   - ratioNumerator: texture aspect ratio numerator, '0' if unspecified
    ///   - ratioDenominator: texture aspect ratio denominator, '0' if unspecified
    private init(width: Int, ratioNumerator: Int, ratioDenominator: Int) {
        var ratioNumerator = ratioNumerator
        var ratioDenominator = ratioDenominator
        if ratioNumerator != 0, ratioDenominator != 0 {
            let gcd = Int.gcd(ratioNumerator, ratioDenominator)
            if gcd > 0 {
                ratioNumerator /= gcd
                ratioDenominator /= gcd
            }
        }
        self.width = width
        self.ratioNumerator = ratioNumerator
        self.ratioDenominator = ratioDenominator
        self.height = ratioNumerator == 0 ? 0 : (width * ratioDenominator / ratioNumerator)
    }
}

/// Texture loader data.
@objc(GSTextureLoaderFrame)
public protocol TextureLoaderFrame {

    /// Handle on the frame.
    var frame: UnsafeRawPointer? {get}

    /// Handle on the frame user data.
    var userData: UnsafeRawPointer? {get}

    /// Length of the frame user data.
    var userDataLen: Int {get}

    /// Handle on the session metadata
    var sessionMetadata: UnsafeRawPointer? {get}
}

/// Listener for rendering stream frames.
///
/// Such a listener can be passed to a 'StreamView' by setting 'StreamView.textureLoader'.
@objc(GSTextureLoader)
public protocol TextureLoader: class {

    /// Texture specification.
    var textureSpec: TextureSpec {get}

    /// Called to render a custom GL texture.
    ///
    /// - Parameters:
    ///   - width: texture width
    ///   - height: texture height
    ///   - frame: frame data
    /// - Returns: 'true' on success, otherwise 'false'
    func loadTexture(width: Int, height: Int, frame: TextureLoaderFrame?) -> Bool
}
