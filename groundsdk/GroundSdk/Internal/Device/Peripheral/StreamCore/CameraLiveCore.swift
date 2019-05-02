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

/// Core class for CameraLive.
public class CameraLiveCore: StreamCore, CameraLive {

    /// Stream server managing the stream.
    private unowned let server: StreamServerCore

    /// Current camera live playback state.
    public var playState: CameraLivePlayState = .none

    /// Constructor
    ///
    /// - Parameter server: stream server
    public init(server: StreamServerCore) {
        self.server = server
        super.init()
        self.server.register(stream: self)
    }

    public func play() -> Bool {
        return playState != .playing && queueCommand(command: .play)
    }

    public func pause() -> Bool {
        return playState != .paused && queueCommand(command: .pause)
    }

    public override func stop() {
        super.stop()
    }

    override func openStream(listener: SdkCoreStreamListener) -> SdkCoreStream? {
        return server.openStream(url: "live", track: StreamCore.TRACK_DEFAULT_VIDEO, listener: listener)
    }

    override func onSuspension(suspendedCommand: Command?) -> Bool {
        if let command = suspendedCommand {
            switch command {
            case .play:
                update(playState: .playing)
            case .pause:
                update(playState: .paused)
            default:
                break
            }
        }
        return true
    }

    override func onStop() {
        update(playState: .none)
        server.onStreamStopped(stream: self)
    }

    override func onRelease() {
        server.unregister(stream: self)
    }

    override func onPlaybackStateChanged(duration: Int64, position: Int64, speed: Double, timestamp: TimeInterval) {
        update(playState: speed != 0 ? .playing : .paused)
    }

    /// Resume live stream if interrupted.
    func resume() {
        queueCommand(command: nil)
    }

    override func executeCommand(stream: SdkCoreStream, command: Command) {
        switch command {
        case .play:
            stream.play()
        case .pause:
            stream.pause()
        default:
            ULog.w(.streamTag, "Unsupported command.")
        }
    }
}

extension CameraLiveCore {

    /// Updates current playback state.
    ///
    /// - Parameter state: new playback state
    /// - Returns: self to allow call chaining
    @discardableResult
    public func update(playState: CameraLivePlayState) -> CameraLiveCore {
        if playState != self.playState {
            self.playState = playState
            changed = true
        }
        return self
    }
}
