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

/// Video stream backend part.
public protocol StreamServerBackend: class {

    /// Open an internal stream instance.
    ///
    /// - Parameters:
    ///    - url: url of the stream to open
    ///    - track: track of the stream to open
    ///    - listener: listener for stream events
    /// - Returns: a new stream instance on success, otherwise 'nil'
    func openStream(url: String, track: String, listener: SdkCoreStreamListener) -> SdkCoreStream?
}

/// Internal stream server peripheral implementation
public class StreamServerCore: PeripheralCore, StreamServer {

    /// Implementation backend.
    private let backend: StreamServerBackend

    /// Live stream unique instance.
    private var cameraLive: CameraLiveCore?

    /// Open streams (including 'cameraLive').
    private var streams: Set<StreamCore> = []

    /// 'true' when streaming is enabled.
    private var _enabled = false

    /// 'true' when streaming is enabled.
    public var enabled: Bool {
        get {
            return _enabled
        }
        set (enabled) {
            if enabled != _enabled {
                _enabled = enabled
                markChanged()
                if _enabled {
                    resumeLive()
                } else {
                    for stream in streams {
                        stream.interrupt()
                    }
                }
                notifyUpdated()
            }
        }
    }

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: Stream server backend
    public init(store: ComponentStoreCore, backend: StreamServerBackend) {
        self.backend = backend
        super.init(desc: Peripherals.streamServer, store: store)
    }

    public func live(observer: @escaping (CameraLive?) -> Void) -> Ref<CameraLive> {
        return CameraLiveRefCore(observer: observer, stream: getCameraLive())
    }

    public func replay(source: MediaReplaySource, observer: @escaping (MediaReplay?) -> Void) -> Ref<MediaReplay>? {
        return MediaReplayRefCore(observer: observer,
                                  stream: newMediaReplay(source: source as! MediaSourceCore))
    }

    /// Called when the component is unpublished
    override func reset() {
        cameraLive?.releaseStream()
        cameraLive?.unpublish()
        cameraLive = nil
        for stream in streams {
            stream.unpublish()
        }
        streams.removeAll()
    }

    /// Get shared camera live stream
    ///
    /// - Returns: shared camera live stream instance
    func getCameraLive() -> CameraLiveCore {
        if cameraLive == nil {
            cameraLive = CameraLiveCore(server: self)
            streams.insert(cameraLive!)
        }
        return cameraLive!
    }

    /// Create a new media replay stream
    ///
    /// - Parameter resource: media source to be streamed
    /// - Returns: a new media replay stream instance
    func newMediaReplay(source: MediaSourceCore) -> MediaReplayCore {
        return MediaReplayCore(server: self, source: source)
    }

    /// Open an internal stream instance.
    ///
    /// - Parameters:
    ///    - url: url of the stream to open
    ///    - track: track of the stream to open
    ///    - listener: listener for stream events
    /// - Returns: a new stream instance on success, otherwise 'nil'
    func openStream(url: String, track: String, listener: SdkCoreStreamListener) -> SdkCoreStream? {
        return _enabled ? backend.openStream(url: url, track: track, listener: listener) : nil
    }

    /// Register a stream.
    ///
    /// - Parameter stream: stream to register
    func register(stream: StreamCore) {
        streams.insert(stream)
    }

    /// Unregister a stream.
    ///
    /// - Parameter stream: stream to unregister
    func unregister(stream: StreamCore) {
        streams.remove(stream)
    }

    /// Called when a stream has stopped.
    ///
    /// In case all other stream are stopped, resumes interrupted live stream if appropriate.
    ///
    /// - Parameter stream: stream that stopped
    func onStreamStopped(stream: StreamCore) {
        for stream in streams {
            let state = stream.state
            if state != .suspended, state != .stopped {
                return
            }
        }
        resumeLive()
    }

    /// Resume live stream in case it is interrupted
    private func resumeLive() {
        if let stream = cameraLive {
            stream.resume()
        }
    }
}

/// Backend callback methods
extension StreamServerCore {

    /// Updates the streaming enabled flag.
    ///
    /// - Parameter enable: new streaming enabled flag
    /// - Returns: self to allow call chaining
    @discardableResult
    public func update(enable: Bool) -> StreamServerCore {
        if enable != _enabled {
            _enabled = enable
            markChanged()
        }
        return self
    }
}

/// Extension that implements the StreamServer protocol for the Objective-C API
extension StreamServerCore: GSStreamServer {

    public func live(observer: @escaping (CameraLive?) -> Void) -> GSCameraLiveRef {
        return GSCameraLiveRef(ref: live(observer: observer))
    }

    public func replay(source: MediaReplaySource, observer: @escaping (MediaReplay?) -> Void) -> GSMediaReplayRef? {
        let ref: Ref<MediaReplay>? = replay(source: source, observer: observer)
        return ref != nil ? GSMediaReplayRef(ref: ref!) : nil
    }
}
