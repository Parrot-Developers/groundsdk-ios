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

/// Rendering scale type.
public enum GlRenderSinkScaleType: Int, CustomStringConvertible {
    /// Fit rendering zone.
    case fit
    /// Crop video to preserve aspect ratio.
    case crop

    /// Debug description.
    public var description: String {
        switch self {
        case .fit: return "fit"
        case .crop: return "crop"
        }
    }
}

/// Rendering padding mode.
public enum GlRenderSinkPaddingFill: Int, CustomStringConvertible {
    /// No padding.
    case none
    /// Fill with a blur of a cropped image.
    case blur_crop
    /// Fill with a blur of an extended image.
    case blur_extend

    /// Debug description.
    public var description: String {
        switch self {
        case .none: return "none"
        case .blur_crop: return "blur_crop"
        case .blur_extend: return "blur_extend"
        }
    }
}

/// GlRenderSink listener.
public protocol GlRenderSinkListener: class {

    /// Called when the renderer is ready to be started.
    ///
    /// - Parameter renderer: the renderer
    func onRenderingMayStart(renderer: GlRenderSink)

    /// Called when the renderer has to be stopped.
    ///
    /// - Parameter renderer: the renderer
    func onRenderingMustStop(renderer: GlRenderSink)

    /// Called when the renderer is ready to render a frame.
    ///
    /// - Parameter renderer: the renderer
    func onFrameReady(renderer: GlRenderSink)

    /// Called when the content zone has changed
    ///
    /// - Parameter contentZone: new content zone
    func onContentZoneChange(contentZone: CGRect)
}

/// A sink that allows stream video to be rendered on a GL view.
public protocol GlRenderSink: StreamSink {

    /// Rendering area.
    var renderZone: CGRect { get set }

    /// Rendering scale type.
    var scaleType: GlRenderSinkScaleType { get set }

    /// Rendering padding mode.
    var paddingFill: GlRenderSinkPaddingFill { get set }

    /// Whether zebras are enabled.
    var zebrasEnabled: Bool { get set }

    /// Zebras overexposure threshold, from 0.0 to 1.0.
    var zebrasThreshold: Double { get set }

    /// Texture loader to render custom GL texture.
    var textureLoader: TextureLoader? { get set }

    /// Whether histograms are enabled.
    var histogramsEnabled: Bool { get set }

    /// Listener for overlay rendering.
    /// Deprecated: use `overlayer2` instead.
    var overlayer: Overlayer? { get set }

    /// Listener for overlay rendering.
    var overlayer2: Overlayer2? { get set }

    /// Start renderer.
    ///
    /// - Returns: 'true' on success, 'false' otherwise
    func start() -> Bool

    /// Stop renderer.
    ///
    /// - Returns: 'true' on success, 'false' otherwise
    func stop() -> Bool

    /// Render a frame.
    func renderFrame()

    /// Create a new GlRenderSink configuration.
    ///
    /// - Parameter listener: listener notified of sink events
    /// - Returns: a new GlRenderSink configuration
    func config(listener: GlRenderSinkListener) -> StreamSinkConfig
}
