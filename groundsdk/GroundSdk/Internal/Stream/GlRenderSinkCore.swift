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

/// Core class for GlRenderSink.
public class GlRenderSinkCore: SinkCore, GlRenderSink {

    /// Sink configuration.
    public class Config: SinkCoreConfig {

        /// Renderer listener.
        public weak var listener: GlRenderSinkListener?

        /// Constructor
        ///
        /// - Parameter listener: renderer listener
        public init(listener: GlRenderSinkListener) {
            self.listener = listener
        }

        public func openSink(stream: StreamCore) -> SinkCore {
            return GlRenderSinkCore(streamCore: stream, config: self)
        }
    }

    /// Sink config.
    private let config: Config

    /// Rendered stream.
    private weak var sdkCoreStream: SdkCoreStream?

    /// Internal renderer.
    private var sdkCoreRenderer: SdkCoreRenderer?

    /// Rendering area.
    public var renderZone: CGRect = CGRect() {
        didSet {
            if let renderer = sdkCoreRenderer {
                renderer.setRenderZone(renderZone)
            }
        }
    }

    /// Rendering scale type.
    public var scaleType: GlRenderSinkScaleType = .fit {
        didSet {
            if let renderer = sdkCoreRenderer {
                let fillMode = fillModeFrom(scaleType: scaleType, paddingFill: paddingFill)
                renderer.setFillMode(fillMode)
            }
        }
    }

    /// Rendering padding mode.
    public var paddingFill: GlRenderSinkPaddingFill = .none {
        didSet {
            if let renderer = sdkCoreRenderer {
                let fillMode = fillModeFrom(scaleType: scaleType, paddingFill: paddingFill)
                renderer.setFillMode(fillMode)
            }
        }
    }

    /// Whether zebras are enabled.
    public var zebrasEnabled: Bool = false {
        didSet {
            if let renderer = sdkCoreRenderer {
                renderer.enableZebras(zebrasEnabled)
            }
        }
    }

    /// Zebras overexposure threshold, from 0.0 to 1.0.
    public var zebrasThreshold: Double = 0 {
        didSet {
            if let renderer = sdkCoreRenderer {
                renderer.setZebrasThreshold(Float(zebrasThreshold))
            }
        }
    }

    /// Whether histograms are enabled.
    public var histogramsEnabled: Bool = false {
        didSet {
            if let renderer = sdkCoreRenderer {
                renderer.enableHistograms(histogramsEnabled)
            }
        }
    }

    /// Texture loader to render custom GL texture.
    public weak var textureLoader: TextureLoader?

    /// Texture frame.
    private var textureFrame: TextureLoaderFrameCore

    /// Texture frame backend.
    private var textureFrameBackend = TextureLoaderFrameBackendCore()

    /// Listener for overlay rendering.
    /// Deprecated: use `overlayer2` instead.
    public var overlayer: Overlayer? {
        didSet {
            if overlayer == nil {
                overlayer2 = nil
            } else {
                overlayer2 = self
            }
        }
    }

    /// Listener for overlay rendering.
    public var overlayer2: Overlayer2?

    /// Overlay context.
    private var overlayContext: OverlayContextCore?

    /// Overlay context backend.
    private var overlayContextBackend: OverlayContextBackendCore?

    /// Constructor.
    ///
    /// - Parameters:
    ///    - streamCore: sink's stream
    ///    - config: sink configuration
    public init(streamCore: StreamCore, config: Config) {
        self.config = config
        textureFrame = TextureLoaderFrameCore(backend: textureFrameBackend)
        super.init(streamCore: streamCore)
    }

    /// Start renderer.
    ///
    /// - Returns: 'true' on success, 'false' otherwise
    public func start() -> Bool {
        if sdkCoreRenderer != nil {
            return false
        }
        guard let stream = sdkCoreStream else {
            return false
        }
        let fillMode = fillModeFrom(scaleType: scaleType, paddingFill: paddingFill)
        let textureWidth = textureLoader != nil ? textureLoader!.textureSpec.width : 0
        let textureDarWidth = textureLoader != nil ? textureLoader!.textureSpec.ratioNumerator : 0
        let textureDarHeight = textureLoader != nil ? textureLoader!.textureSpec.ratioDenominator : 0
        sdkCoreRenderer = stream.startRenderer(renderZone: renderZone, fillMode: fillMode,
                                               zebrasEnabled: zebrasEnabled, zebrasThreshold: Float(zebrasThreshold),
                                               textureWidth: Int32(textureWidth),
                                               textureDarWidth: Int32(textureDarWidth),
                                               textureDarHeight: Int32(textureDarHeight),
                                               textureLoaderlistener: textureLoader != nil ? self : nil,
                                               histogramsEnabled: histogramsEnabled, overlayListener: self,
                                               listener: self )
        return sdkCoreRenderer != nil
    }

    /// Stop renderer.
    ///
    /// - Returns: 'true' on success, 'false' otherwise
    public func stop() -> Bool {
        if let renderer = sdkCoreRenderer {
            renderer.stop()
            sdkCoreRenderer = nil
            return true
        }
        return false
    }

    /// Render a frame.
    public func renderFrame() {
        if let renderer = sdkCoreRenderer {
            renderer.renderFrame()
        }
    }

    public func config(listener: GlRenderSinkListener) -> StreamSinkConfig {
        return Config(listener: listener)
    }

    override func onSdkCoreStreamAvailable(stream: SdkCoreStream) {
        sdkCoreStream = stream
        config.listener?.onRenderingMayStart(renderer: self)
    }

    override func onSdkCoreStreamUnavailable() {
        sdkCoreStream = nil
        config.listener?.onRenderingMustStop(renderer: self)
    }
}

/// Extension to convert old `Overlayer` to `Overlayer2`.
extension GlRenderSinkCore: Overlayer2 {
    public func overlay(overlayContext: OverlayContext) {
        overlayer?.overlay(renderPos: overlayContext.renderZoneHandle, contentPos: overlayContext.contentZoneHandle,
                           histogram: overlayContext.histogram)
    }
}

/// Extension to convert rendering scale type and padding mode to SdkCoreStreamRenderingFillMode.
extension GlRenderSinkCore {

    /// Convert rendering scale type and padding mode to SdkCoreStreamRenderingFillMode.
    ///
    /// - Parameters:
    ///    - scaleType: rendering scale type
    ///    - paddingFill: rendering padding mode
    /// - Returns: SdkCoreStreamRenderingFillMode equivalent
    func fillModeFrom(scaleType: GlRenderSinkScaleType, paddingFill: GlRenderSinkPaddingFill)
        -> SdkCoreStreamRenderingFillMode {
            switch scaleType {
            case .fit:
                switch paddingFill {
                case .none:
                    return .fit
                case .blur_crop:
                    return .fitPadBlurCrop
                case .blur_extend:
                    return .fitPadBlurExtend
                }
            case .crop:
                return .crop
            }
    }
}

/// Implementation of renderer listener protocol.
extension GlRenderSinkCore: SdkCoreRendererListener {

    public func onFrameReady() {
        config.listener?.onFrameReady(renderer: self)
    }

    public func contentZoneDidUpdate(_ zone: CGRect) {
        config.listener?.onContentZoneChange(contentZone: zone)
    }
}

/// Implementation of texture loader listener protocol.
extension GlRenderSinkCore: SdkCoreTextureLoaderListener {

    public func loadTexture(_ width: Int32, height: Int32, frame: SdkCoreTextureLoaderFrame) -> Bool {
        if let textureLoader = textureLoader {
            textureFrameBackend.data = frame
            return textureLoader.loadTexture(width: Int(width), height: Int(height), frame: textureFrame)
        }
        return false
    }
}

/// Implementation of overlay rendering listener protocol.
extension GlRenderSinkCore: SdkCoreRendererOverlayListener {

    public func overlay(_ context: SdkCoreOverlayContext) {

        if let overlayer = overlayer2 {
            if let overlayContextBackend = overlayContextBackend {
                overlayContextBackend.data = context
            } else {
                let backend = OverlayContextBackendCore(coreContext: context)
                overlayContextBackend = backend
                overlayContext = OverlayContextCore(backend: backend)
            }

            if let overlayContext = overlayContext {
                overlayer.overlay(overlayContext: overlayContext)
            }
        }
    }
}
/// TextureLoaderFrame backend implementation.
class TextureLoaderFrameBackendCore: TextureLoaderFrameBackend {

    /// Texture loader data core.
    var data: SdkCoreTextureLoaderFrame?

    var frame: UnsafeRawPointer? {
        if let data = data {
            return data.frame
        } else {
            return nil
        }
    }

    var userData: UnsafeRawPointer? {
        if let data = data {
            return data.userData
        } else {
            return nil
        }
    }

    var userDataLen: Int {
        if let data = data {
            return data.userDataLen
        } else {
            return 0
        }
    }
}

/// Histogram backend implementation.
class HistogramBackendCore: HistogramBackend {

    /// Histogram core
    var data: SdkCoreHistogram?

    var histogramRed: [Float32]? {
        if let histogram = data?.histogramRed, let len = data?.histogramRedLen {
            return Array(UnsafeBufferPointer(start: histogram, count: len))
        } else {
            return nil
        }
    }

    var histogramGreen: [Float32]? {
        if let histogram = data?.histogramGreen, let len = data?.histogramGreenLen {
            return Array(UnsafeBufferPointer(start: histogram, count: len))
        } else {
            return nil
        }
    }

    var histogramBlue: [Float32]? {
        if let histogram = data?.histogramBlue, let len = data?.histogramBlueLen {
            return Array(UnsafeBufferPointer(start: histogram, count: len))
        } else {
            return nil
        }
    }

    var histogramLuma: [Float32]? {
        if let histogram = data?.histogramLuma, let len = data?.histogramLumaLen {
            return Array(UnsafeBufferPointer(start: histogram, count: len))
        } else {
            return nil
        }
    }
}

/// Overlay context backend implementation.
class OverlayContextBackendCore: OverlayContextBackend {

    /// Overlay context core
    var data: SdkCoreOverlayContext {
        didSet {
            histogramBackend.data = data.histogram
        }
    }

    /// Histogram backend.
    private var histogramBackend = HistogramBackendCore()

    /// Histogram core.
    private var histogramCore: HistogramCore

    /// Area where the frame was rendered (including any padding introduced by scaling).
    var renderZone: CGRect {
        return data.renderZone
    }

    /// Render zone handle; pointer of const struct pdraw_rect.
    var renderZoneHandle: UnsafeRawPointer {
        return data.renderZoneHandle
    }

    /// Area where frame content was rendered (excluding any padding introduced by scaling).
    var contentZone: CGRect {
        return data.contentZone
    }

    /// Content zone handle; pointer of const struct pdraw_rect.
    var contentZoneHandle: UnsafeRawPointer {
        return data.contentZoneHandle
    }

    /// Session info handle; pointer of const struct pdraw_session_info.
    var sessionInfoHandle: UnsafeRawPointer {
        return data.sessionInfoHandle
    }

    /// Session metadata handle; pointer of const struct vmeta_session.
    var sessionMetadataHandle: UnsafeRawPointer {
        return data.sessionMetadataHandle
    }

    /// Session metadata handle; pointer of const struct vmeta_session.
    var frameMetadataHandle: UnsafeRawPointer? {
        return data.frameMetadataHandle
    }

    /// Histogram.
    var histogram: Histogram? {
        return histogramCore
    }

    init(coreContext: SdkCoreOverlayContext) {
        data = coreContext
        histogramCore = HistogramCore(backend: histogramBackend)
    }
}
