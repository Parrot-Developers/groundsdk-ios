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

/// Core class for Replay.
public class ReplayCore: StreamCore, Replay {

    /// Current playback state.
    public var playState: ReplayPlayState = .none

    /// Playback duration, in milliseconds.
    private var _duration: Int64 = 0

    /// Playback duration, in seconds.
    public var duration: TimeInterval {
        return TimeInterval(Double(_duration) / 1000.0)
    }

    /// Current playback position, in milliseconds.
    public var _position: Int64 = 0

    /// Current playback position, in seconds.
    public var position: TimeInterval {
        var estimatedPosition = TimeInterval(Double(_position) / 1000.0)
        if playState == .playing {
            let timeDiff = ProcessInfo.processInfo.systemUptime - timestamp
            estimatedPosition += timeDiff
        }
        return min(estimatedPosition, duration)
    }

    /// Playback state collection time, based on time provided by 'ProcessInfo.processInfo.systemUptime'.
    private var timestamp: TimeInterval = 0

    public func play() -> Bool {
        return playState != .playing
            && (position < duration || state != .started)
            && queueCommand(command: .play)
    }

    public func pause() -> Bool {
        return playState != .paused && queueCommand(command: .pause)
    }

    public func seekTo(position: TimeInterval) -> Bool {
        return queueCommand(command: .seekTo(Int(position * 1000)))
    }

    public override func stop() {
        super.stop()
    }

    override func onPlaybackStateChanged(duration: Int64, position: Int64, speed: Double, timestamp: TimeInterval) {
        self.timestamp = timestamp
        update(duration: duration)
        _position = min(position, duration)
        update(playState: speed != 0 ? .playing : .paused)
    }

    override func onStop() {
        super.onStop()
        timestamp = 0
        _position = 0
        playState = .none
    }

    override func executeCommand(stream: SdkCoreStream, command: Command) {
        switch command {
        case .play:
            stream.play()
        case .pause:
            stream.pause()
        case .seekTo(let position):
            stream.seek(to: Int32(position))
        }
    }
}

extension ReplayCore {

    /// Updates current playback state.
    ///
    /// - Parameter state: new playback state
    /// - Returns: self to allow call chaining
    @discardableResult
    public func update(playState: ReplayPlayState) -> ReplayCore {
        if playState != self.playState {
            self.playState = playState
            changed = true
        }
        return self
    }

    /// Updates playback duration.
    ///
    /// - Parameter duration: new playback duration, in milliseconds
    /// - Returns: self to allow call chaining
    @discardableResult
    public func update(duration: Int64) -> ReplayCore {
        if duration != _duration {
            _duration = duration
            changed = true
        }
        return self
    }
}
