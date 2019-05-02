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

/// Internal YuvSink implementation.
public class YuvSinkCore: SinkCore {

    /// YUV sink configuration.
    public class Config: SinkCoreConfig {

        /// Queue into which callback are dispatched listener.
        public private(set) var queue: DispatchQueue

        /// Sink listener.
        public private(set) weak var listener: YuvSinkListener?

        /// Constructor
        ///
        /// - Parameters:
        ///    - queue: queue into which callback are dispatched
        ///    - listener: sink listener
        public init(queue: DispatchQueue, listener: YuvSinkListener) {
            self.queue = queue
            self.listener = listener
        }

        public func openSink(stream: StreamCore) -> SinkCore {
            return YuvSinkCore(stream: stream, config: self)
        }
    }

    /// Sink config.
    private let config: Config

    /// Stream backend, 'nil' if the stream is not opened.
    private weak var sdkCoreStream: SdkCoreStream?

    /// Sink backend.
    private var sdkCoreSink: SdkCoreSink?

    /// Listener notified of stream YUV media availability.
    private var mediaListener: YuvMediaListener!

    /// Constructor
    ///
    /// - Parameters:
    ///    - stream: sink's stream
    ///    - config: configuration
    public init(stream: StreamCore, config: Config) {
        self.config = config
        super.init(streamCore: stream)
        sdkCoreSink = SdkCoreSink(queueSize: 1,
                                  policy: .dropEldest,
                                  format: .unspecified,
                                  listener: self)
        mediaListener = YuvMediaListener(sinkCore: self)
    }

    /// Create a YUV sink configuration.
    ///
    /// - Parameters:
    ///    - queue: queue into which callback are dispatched
    ///    - listener: sink listener
    /// - Returns: the YUV sink configuration
    public static func config(queue: DispatchQueue, listener: YuvSinkListener) -> StreamSinkConfig {
        return YuvSinkCore.Config(queue: queue, listener: listener)
    }

    override public func close() {
        sdkCoreSink?.stop()
        sdkCoreSink = nil
        super.close()
    }

    override func onSdkCoreStreamAvailable(stream: SdkCoreStream) {
        sdkCoreStream = stream
        streamCore.subscribeToMedia(listener: mediaListener, mediaType: .yuv)
    }

    override func onSdkCoreStreamUnavailable() {
        sdkCoreStream = nil
        sdkCoreSink?.stop()
        streamCore.unsubscribeFromMedia(listener: mediaListener, mediaType: .yuv)
    }

    ///  YUV media listener implementation.
    private class YuvMediaListener: MediaListener {

        /// YUV sink core instance.
        private unowned let sinkCore: YuvSinkCore

        override func onMediaAvailable(mediaInfo: SdkCoreMediaInfo) {
            sinkCore.config.queue.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.sinkCore.config.listener?.didStart(sink: self.sinkCore)
            }
            if let sdkCoreSink = sinkCore.sdkCoreSink {
                sinkCore.sdkCoreStream?.start(sdkCoreSink, mediaId: UInt32(mediaInfo.mediaId))
            }
        }

        override func onMediaUnavailable() {
            sinkCore.sdkCoreSink?.stop()
        }

        /// Constructor
        ///
        /// - Parameter sinkCore: YUV sink core
        init(sinkCore: YuvSinkCore) {
            self.sinkCore = sinkCore
        }
    }
}

/// Extension to listen to internal sink events.
extension YuvSinkCore: SdkCoreSinkListener {

    public func onFrame(_ frame: SdkCoreFrame) {
        config.queue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.config.listener?.frameReady(sink: self, frame: frame)
        }
    }

    public func onStop() {
        config.queue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.config.listener?.didStop(sink: self)
        }
    }
}
