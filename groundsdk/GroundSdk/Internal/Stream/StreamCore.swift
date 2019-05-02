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

/// Internal Stream implementation.
public class StreamCore: NSObject, Stream {

    /// Track name of default video
    public static let TRACK_DEFAULT_VIDEO: String = "" // or "DefaultVideo"
    /// Track name of thermal video
    public static let TRACK_THERMAL_VIDEO: String = "ParrotThermalVideo"

    /// Listener notified when the stream changes.
    class Listener: NSObject {

        /// Closure called when the stream changes.
        fileprivate let didChange: () -> Void

        /// Closure called to unpublished the stream.
        fileprivate let unpublish: () -> Void

        /// Constructor.
        ///
        /// - Parameters:
        ///    - didChange: closure that should be called when the state changes
        ///    - unpublish: closure that should be called to unpublish the stream
        fileprivate init(didChange: @escaping () -> Void, unpublish: @escaping () -> Void) {
            self.didChange = didChange
            self.unpublish = unpublish
        }
    }

    /// Stream command
    enum Command {
        /// Play stream.
        case play
        /// Pause stream.
        case pause
        /// Seek to time position.
        case seekTo(Int)
    }

    /// Video stream core, nil when closed.
    private var sdkCoreStream: SdkCoreStream?

    /// Media registry
    private var medias = MediaRegistry()

    /// Stream sinks.
    private var sinks: Set<SinkCore> = []

    /// 'true' when 'sdkCoreStream' is completely open.
    private var coreStreamOpen = false

    /// Latest requested command, 'nil' if none.
    private var command: Command?

    /// Current stream state.
    public var state: StreamState = .stopped

    /// Listeners list.
    private var listeners: Set<Listener> = []

    /// Whether this stream has changed.
    var changed = false

    /// 'true' when this stream has been released.
    private var released = false

    /// Destructor.
    deinit {
        listeners.removeAll()
    }

    /// Open a sink on the stream.
    ///
    /// - Parameter config: sink configuration
    /// - Returns: the opened sink
    public func openSink(config: StreamSinkConfig) -> StreamSink {
        let config = config as! SinkCoreConfig
        let sink = config.openSink(stream: self)
        if coreStreamOpen, let sdkCoreStream = sdkCoreStream {
            sink.onSdkCoreStreamAvailable(stream: sdkCoreStream)
        }
        return sink
    }
    public func openYuvSink(queue: DispatchQueue, listener: YuvSinkListener) -> StreamSink {
        return openSink(config: YuvSinkCore.config(queue: queue, listener: listener))
    }

    /// Register a new listener.
    ///
    /// - Parameters:
    ///    - didChange: closure that should be called when the state changes
    ///    - unpublish: closure that should be called to unpublish the stream
    /// - Returns: the created listener
    ///
    /// - Note: the returned listener should be unregistered with unregister()
    func register(didChange: @escaping () -> Void, unpublish: @escaping () -> Void) -> Listener {
        let listener = Listener(didChange: didChange, unpublish: unpublish)
        listeners.insert(listener)
        return listener
    }

    /// Unregister a listener.
    ///
    /// - Parameter listener: listener to unregister
    func unregister(listener: Listener) {
        listeners.remove(listener)
    }

    /// Register a sink.
    ///
    /// - Parameter sink: sink to register
    func register(sink: SinkCore) {
        sinks.insert(sink)
    }

    /// Unregister a sink.
    ///
    /// - Parameter sink: sink to unregister
    func unregister(sink: SinkCore) {
        sinks.remove(sink)
    }

    /// Subscribe to stream media availability changes.
    ///
    /// In case a media of the requested kind is available when this method is called,
    /// 'MediaListener.onMediaAvailable()' is called immediately.
    ///
    /// - Parameters:
    ///    - listener: listener notified of media availability changes
    ///    - mediaType: type of media to listen
    func subscribeToMedia(listener: MediaListener, mediaType: SdkCoreMediaType) {
        medias.registerListener(listener: listener, mediaType: mediaType)
    }

    /// Unsubscribe from stream media availability changes.
    ///
    /// In case a media of the subscribed kind is still available when this method is called,
    /// {@code listener.}{@link MediaListener#onMediaUnavailable()} onMediaUnavailable()} is called immediately.
    ///
    /// - Parameters:
    ///    - listener: listener to unsubscribe
    ///    - mediaType: type of media that was listened
    func unsubscribeFromMedia(listener: MediaListener, mediaType: SdkCoreMediaType) {
        medias.unregisterListener(listener: listener, mediaType: mediaType)
    }

    /// Get number of registered listeners.
    ///
    /// Only for testing purpose.
    ///
    /// - Returns: number of registered listeners
    func countListeners() -> Int {
        return listeners.count
    }

    /// Notifies all observers of stream state change, iff state did change since last call to this method.
    public func notifyUpdated() {
        if changed {
            changed = false
            listeners.forEach {
                $0.didChange()
            }
        }
    }

    /// Unpublish the stream.
    public func unpublish() {
        listeners.forEach {
            $0.unpublish()
        }
    }

    /// Open a new 'SdkCoreStream' for this stream.
    ///
    /// - Parameter listener: listener that will receive stream events
    /// - Returns: a new 'SdkCoreStream' instance on success, otherwise 'nil'
    func openStream(listener: SdkCoreStreamListener) -> SdkCoreStream? {
        fatalError("Subclasses shall implement this method.")
    }

    /// Notifies that this stream is about to be suspended.
    /// Default implementation does not support suspension and returns 'false'.
    ///
    /// - Parameter suspendedCommand: command that will be executed upon resuming, 'nil' if none
    /// - Returns: 'true' to proceed with suspension, 'false' to stop the stream instead
    func onSuspension(suspendedCommand: Command?) -> Bool {
        return false
    }

    /// Notifies that the stream playback stops.
    /// Subclasses may override this method to properly update their own state.
    func onStop() {}

    /// Notifies that the stream has been released.
    /// Subclasses may override this method to properly update their own state.
    func onRelease() {}

    /// Notifies that the stream playback state changed.
    ///
    /// Subclasses may override this method to properly update their own state.
    ///
    /// - Parameters:
    ///    - duration: stream duration, in milliseconds, 0 when irrelevant
    ///    - position: playback position, in milliseconds
    ///    - speed: playback speed (multiplier), 0 when paused
    ///    - timestamp: state collection timestamp, based on time provided by 'ProcessInfo.processInfo.systemUptime'
    func onPlaybackStateChanged(duration: Int64, position: Int64, speed: Double, timestamp: TimeInterval) {}

    /// Queue a playback command for execution on this stream
    ///
    /// - Parameter command: command to execute, 'nil' to re-execute latest command, if any
    /// - Returns: 'true' if the command could be queued, otherwise 'false'
    @discardableResult
    func queueCommand(command: Command?) -> Bool {
        if released {
            ULog.w(.streamTag, "Cannot queue command: stream is closed.")
            return false
        }
        if command != nil {
            self.command = command
        }
        if self.command == nil {
            ULog.w(.streamTag, "Cannot queue command: no command set before starting stream.")
            return false
        }
        if sdkCoreStream == nil {
            sdkCoreStream = openStream(listener: self)
            if sdkCoreStream == nil {
                return trySuspend()
            }
            update(state: .starting)
            notifyUpdated()
        } else if coreStreamOpen {
            executeCommand(stream: sdkCoreStream!, command: command!)
        }
        return true
    }

    /// Execute a command.
    ///
    /// - Parameters:
    ///    - stream: stream on which the command is applied
    ///    - command: command to execute
    func executeCommand(stream: SdkCoreStream, command: Command) {
        preconditionFailure("This method must be overridden")
    }

    /// Interrupt the stream, allowing it (if supported) to be resumed automatically later.
    func interrupt() {
        stop(reason: .interrupted)
    }

    /// Stops the stream.
    public func stop() {
        stop(reason: .userRequested)
    }

    /// Release the stream, stopping it if required.
    ///
    /// Stream must not be used after this method is called.
    func releaseStream() {
        if released {
            ULog.w(.streamTag, "release failed: stream already released.")
            return
        }
        stop(reason: .userRequested)
        released = true
        sinks.removeAll()
        onRelease()
    }

    /// Stops this stream.
    ///
    /// - Parameter reason: reason why the stream is stopped
    private func stop(reason: SdkCoreStreamCloseReason) {
        if released {
            ULog.w(.streamTag, "Cannot stop stream: stream is closed.")
            return
        }
        sdkCoreStream?.close(reason)
        handleSdkCoreStreamClosing(reason: reason)
    }

    /// Called when 'sdkCoreStream' is closing.
    ///
    /// - Returns: reason why the stream is closed
    private func handleSdkCoreStreamClosing(reason: SdkCoreStreamCloseReason) {
        if coreStreamOpen {
            coreStreamOpen = false
            for sink in sinks {
                sink.onSdkCoreStreamUnavailable()
            }
        }
        if reason != .interrupted || command == nil || !trySuspend() {
            command = nil
            update(state: .stopped)
            notifyUpdated()
        }
    }

    /// Called when 'sdkCoreStream' is fully closed.
    func handleSdkCoreStreamClose() {
        sdkCoreStream = nil
    }

    /// Try to move the stream to '.suspended' state in case it supports suspension.
    ///
    /// - Returns: 'true' if the stream could be suspended, otherwise 'false'
    private func trySuspend() -> Bool {
        guard let command = self.command else {
            return false
        }
        if onSuspension(suspendedCommand: command) {
            update(state: .suspended)
            notifyUpdated()
            return true
        }
        return false
    }
}

/// Backend callback methods.
extension StreamCore {

    /// Updates current stream state.
    ///
    /// - Parameter state: new stream state
    /// - Returns: self, to allow call chaining
    @discardableResult
    public func update(state: StreamState) -> StreamCore {
        if state != self.state {
            self.state = state
            changed = true
            if state == .stopped {
                onStop()
            }
        }
        return self
    }
}

/// Implementation of core stream listener.
extension StreamCore: SdkCoreStreamListener {

    public func streamDidOpen(_ sdkCoreStream: SdkCoreStream) {
        if command == nil {
            ULog.e(.streamTag, "No command set before starting stream.")
            return
        }
        coreStreamOpen = true
        for sink in sinks {
            sink.onSdkCoreStreamAvailable(stream: sdkCoreStream)
        }
        executeCommand(stream: sdkCoreStream, command: command!)
        update(state: .started).notifyUpdated()
    }

    public func streamDidClosing(_ sdkCoreStream: SdkCoreStream, reason: SdkCoreStreamCloseReason) {
        if !sdkCoreStream.isEqual(self.sdkCoreStream) { // another stream may have been open in the meantime
            return
        }
        handleSdkCoreStreamClosing(reason: reason)
    }

    public func streamDidClose(_ sdkCoreStream: SdkCoreStream, reason: SdkCoreStreamCloseReason) {
        handleSdkCoreStreamClose()
    }

    public func streamPlaybackStateDidChange(_ stream: SdkCoreStream,
                                             duration: Int64, position: Int64, speed: Double, timestamp: TimeInterval) {
        onPlaybackStateChanged(duration: duration, position: position, speed: speed, timestamp: timestamp)
        update(state: .started)
        notifyUpdated()
    }

    public func mediaAdded(_ stream: SdkCoreStream, mediaInfo: SdkCoreMediaInfo) {
        medias.addMedia(info: mediaInfo)
    }

    public func mediaRemoved(_ stream: SdkCoreStream, mediaInfo: SdkCoreMediaInfo) {
        medias.removeMedia(info: mediaInfo)
    }
}

/// TextureLoaderFrame backend part.
public protocol TextureLoaderFrameBackend: class {
    /// Handle on the frame.
    var frame: UnsafeRawPointer? {get}

    /// Handle on the frame user data.
    var userData: UnsafeRawPointer? {get}

    /// Length of the frame user data.
    var userDataLen: Int {get}
}

/// Internal TextureLoaderFrame implementation.
public class TextureLoaderFrameCore: TextureLoaderFrame {

    /// Implementation backend.
    private let backend: TextureLoaderFrameBackend

    /// Handle on the frame.
    public var frame: UnsafeRawPointer? {
        return backend.frame
    }

    /// Handle on the frame user data.
    public var userData: UnsafeRawPointer? {
        return backend.userData
    }

    /// Length of the frame user data.
    public var userDataLen: Int {
        return backend.userDataLen
    }

    /// Handle on the session metadata
    public var sessionMetadata: UnsafeRawPointer?

    /// Constructor
    ///
    /// - Parameter backend: texture loader frame backend
    public init(backend: TextureLoaderFrameBackend) {
        self.backend = backend
    }
}

/// Histogram backend part.
public protocol HistogramBackend: class {

    /// Histogram channel red.
    var histogramRed: [Float32]? {get}

    /// Histogram channel green.
    var histogramGreen: [Float32]? {get}

    /// Histogram channel blue.
    var histogramBlue: [Float32]? {get}

    /// Histogram channel luma.
    var histogramLuma: [Float32]? {get}
}

/// Internal histogram implementation.
public class HistogramCore: Histogram {

    /// Implementation backend.
    private let backend: HistogramBackend

    /// Histogram channel red.
    public var histogramRed: [Float32]? {
        return backend.histogramRed
    }

    /// Histogram channel green.
    public var histogramGreen: [Float32]? {
        return backend.histogramGreen
    }

    /// Histogram channel blue.
    public var histogramBlue: [Float32]? {
        return backend.histogramBlue
    }

    /// Histogram channel luma.
    public var histogramLuma: [Float32]? {
        return backend.histogramLuma
    }

    /// Constructor
    ///
    /// - Parameter backend: histogram backend
    public init(backend: HistogramBackend) {
        self.backend = backend
    }
}
