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
import UIKit
import GLKit

/// View that displays a video stream.
@objcMembers
@objc(GSStreamView)
open class StreamView: GLKView {

    /// Stream scale type.
    public enum ScaleType: Int, CustomStringConvertible {
        /// Scales the stream so that its largest dimension spans the whole view
        /// and its smallest dimension is scaled to maintain the original aspect ratio.
        /// Padding is introduced, if any, rendered according to 'renderingPaddingFill' configuration.
        case fit

        /// Scales the stream so that its smallest dimension spans the whole view
        /// and its largest dimension is scaled to maintain the original aspect ratio and cropped to the render zone.
        /// No padding is introduced.
        case crop

        /// Debug description.
        public var description: String {
            switch self {
            case .fit: return "fit"
            case .crop: return "crop"
            }
        }

        /// Convert ScaleType to GlRenderSinkScaleType.
        var rendererEquivalent: GlRenderSinkScaleType {
            switch self {
            case .fit: return .fit
            case .crop: return .crop
            }
        }
    }

    /// Padding fill mode when scale type is 'ScaleType.fit'.
    public enum PaddingFill: Int, CustomStringConvertible {
        /// Padding is filled with default color.
        case none

        /// Background is filled with a blurred image scaled and cropped to fit the content view.
        case blur_crop

        /// Background filled with an extended and blurred image.
        case blur_extend

        /// Debug description.
        public var description: String {
            switch self {
            case .none: return "none"
            case .blur_crop: return "blur_crop"
            case .blur_extend: return "blur_extend"
            }
        }

        /// Convert PaddingFill to GlRenderSinkPaddingFill.
        var rendererEquivalent: GlRenderSinkPaddingFill {
            switch self {
            case .none: return .none
            case .blur_crop: return .blur_crop
            case .blur_extend: return .blur_extend
            }
        }
    }

    /// Render width.
    private var renderWidth = 0

    /// Render height.
    private var renderHeight = 0

    /// Displayed stream.
    private var stream: Stream?

    /// GL rendering sink obtained from 'stream'.
    private var sink: StreamSink?

    /// GL renderer given by the sink.
    /// `nil` if the rendering sink is not opened and ready to render.
    private var renderer: GlRenderSink?

    /// Listener that will be called when content zone changed.
    /// Parameter zone of the listener represents the new contentZone.
    public var contentZoneListener: ((_ contentZone: CGRect) -> Void)?

    /// Content drawing zone; coordinates are relative to the view.
    public private(set) var contentZone = CGRect() {
        didSet {
            if let contentZoneListener = contentZoneListener, !oldValue.equalTo(contentZone) {
                contentZoneListener(contentZone)
            }
        }
    }

    /// Rendering scale type.
    public var renderingScaleType = ScaleType.fit {
        didSet {
            applyScaleType()
        }
    }

    /// Rendering padding fill mode.
    public var renderingPaddingFill = PaddingFill.blur_extend {
        didSet {
            applyPaddingFill()
        }
    }

    /// Enabling of zebras of overexposure image zones.
    /// 'true' to enable the zebras of overexposure zone.
    public var zebrasEnabled: Bool {
        set {
            _zebrasEnabled = newValue
            applyZebrasEnable()
        }
        get {
            return _zebrasEnabled
        }
    }

    /// Internal enabling of zebras of overexposure image zones.
    /// 'true' to enable the zebras of overexposure zone.
    private var _zebrasEnabled = false

    /// Threshold of overexposure used by zebras, in range [0.0, 1.0].
    /// '0.0' for the maximum of zebras and '1.0' for the minimum.
    ///
    /// Default value is 0,94.
    public var zebrasThreshold = Double(0.94) {
        didSet {
            applyZebrasThreshold()
        }
    }

    /// Enabling of histograms computing.
    /// 'true' to enable the histograms computing.
    ///
    /// Histograms will be received by the call of renderOverlay(OverlayerData).
    public var histogramsEnabled: Bool {
        set {
            _histogramsEnabled = newValue
            applyHistogramsEnable()
        }
        get {
            return _histogramsEnabled
        }
    }

    /// Internal enabling of histograms computing.
    /// 'true' to enable the histograms computing.
    private var _histogramsEnabled = false

    /// Rendering overlayer.
    public weak var overlayer: Overlayer? {
        didSet {
            applyOverlayer()
        }
    }

    /// Rendering texture loader.
    public weak var textureLoader: TextureLoader? {
        didSet {
            if oldValue !== textureLoader {
                applyTextureLoader()
                stopRenderer()
                startRenderer()
            }
        }
    }

    /// Constructor.
    ///
    /// - Parameter frame: view frame
    public override init(frame: CGRect) {
        super.init(frame: frame)
        contextInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        contextInit()
    }

    /// Initializes OpenGL context.
    private func contextInit() {
        context = EAGLContext.init(api: EAGLRenderingAPI.openGLES3)!
        enableSetNeedsDisplay = true
    }

    /// Draws a frame.
    ///
    /// - Parameter rect: portion of the view's bounds that needs to be updated
    override
    open func draw(_ rect: CGRect) {
        super.draw(rect)
        if let renderer = renderer {
            if renderWidth != drawableWidth || renderHeight != drawableHeight {
                /// The render is resized.
                renderWidth = drawableWidth
                renderHeight = drawableHeight
                renderer.renderZone = CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight)
            }
            renderer.renderFrame()
        }
    }

    /// Starts the stream renderer.
    private func startRenderer() {
        if let renderer = renderer {
            bindDrawable()
            renderWidth = drawableWidth
            renderHeight = drawableHeight
            renderer.renderZone = CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight)
            _ = renderer.start()
            self.setNeedsDisplay()
        }
    }

    /// Stops the stream renderer.
    private func stopRenderer() {
        if let renderer = renderer {
            bindDrawable()
            _ = renderer.stop()
            self.setNeedsDisplay()
        }
    }

    /// Applies configured rendering scale type to renderer.
    private func applyScaleType() {
        if let renderer = renderer {
            bindDrawable()
            renderer.scaleType = renderingScaleType.rendererEquivalent
        }
    }

    /// Applies configured rendering padding fill mode to renderer.
    private func applyPaddingFill() {
        if let renderer = renderer {
            bindDrawable()
            renderer.paddingFill = renderingPaddingFill.rendererEquivalent
        }
    }

    /// Applies configured zebras rendering to renderer.
    private func applyZebrasEnable() {
        if let renderer = renderer {
            bindDrawable()
            renderer.zebrasEnabled = _zebrasEnabled
        }
    }

    /// Applies configured zebras threshold to renderer.
    private func applyZebrasThreshold() {
        if let renderer = renderer {
            bindDrawable()
            renderer.zebrasThreshold = zebrasThreshold
        }
    }

    /// Applies configured histograms computation to renderer.
    private func applyHistogramsEnable() {
        if let renderer = renderer {
            bindDrawable()
            renderer.histogramsEnabled = _histogramsEnabled
        }
    }

    /// Applies configured overlayer to renderer.
    private func applyOverlayer() {
        if let renderer = renderer {
            bindDrawable()
            renderer.overlayer = overlayer
        }
    }

    /// Applies configured texture loader to renderer.
    private func applyTextureLoader() {
        if let renderer = renderer {
            bindDrawable()
            renderer.textureLoader = textureLoader
        }
    }

    /// Attaches stream to be rendered.
    /// Client is responsible to detach any stream before the the view is disposed, otherwise, leak may occur.
    ///
    /// - Parameter stream: stream to render, 'nil' to detach stream.
    public func setStream(stream: Stream?) {
        if stream === self.stream {
            return
        }

        if let sink = self.sink {
            sink.close()
            self.sink = nil
        }

        self.stream = stream

        if let stream = self.stream {
            sink = stream.openSink(config: GlRenderSinkCore.Config(listener: self))
        }
    }
}

/// Extension to implement RendererListener protocol.
extension StreamView: GlRenderSinkListener {

    public func onRenderingMayStart(renderer: GlRenderSink) {
        self.renderer = renderer
        applyScaleType()
        applyPaddingFill()
        applyZebrasEnable()
        applyZebrasThreshold()
        applyHistogramsEnable()
        applyTextureLoader()
        applyOverlayer()

        startRenderer()
    }

    public func onRenderingMustStop(renderer: GlRenderSink) {
        stopRenderer()
        self.renderer = nil
    }

    public func onFrameReady(renderer: GlRenderSink) {
        setNeedsDisplay()
    }

    public func onContentZoneChange(contentZone: CGRect) {
        self.contentZone = contentZone
    }
}
