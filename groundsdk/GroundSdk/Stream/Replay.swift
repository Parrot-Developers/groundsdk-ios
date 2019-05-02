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

/// Replay stream playback state.
@objc(GSReplayPlayState)
public enum ReplayPlayState: Int, CustomStringConvertible {
    /// Stream is 'State.stopped'.
    case none

    /// Stream is either 'State.starting' in which case this indicates that playback will start once
    /// the stream is started, or 'State.started' in which case this indicates that playback is currently ongoing.
    case playing

    /// Stream is either 'State.starting' in which case this indicates that playback will pause once
    /// the stream is started, or 'State.started' in which case this indicates that playback is currently paused.
    case paused

    /// Debug description.
    public var description: String {
        switch self {
        case .none:
            return "none"
        case .playing:
            return "playing"
        case .paused:
            return "paused"
        }
    }
}

/// Base replay stream interface.
@objc(GSReplay)
public protocol Replay: Stream {

    /// Current playback state.
    var playState: ReplayPlayState { get }

    /// Request playback to start.
    ///
    /// The stream is started if necessary.
    ///
    /// - Returns: 'true' if playback request was sent, otherwise 'false'
    func play() -> Bool

    /// Request playback to pause.
    ///
    /// The stream is started if necessary.
    ///
    /// - Returns: 'true' if playback request was sent, otherwise 'false'
    func pause() -> Bool

    /// Stop the stream.
    func stop()

    /// Request playback position change.
    ///
    /// - Parameter position: time position to seek to, in seconds
    /// - Returns: 'true' if seek request was sent, otherwise 'false'
    func seekTo(position: TimeInterval) -> Bool

    /// Total playback duration, in seconds.
    var duration: TimeInterval { get }

    /// Current playback time position, in seconds
    ///
    /// - Note: Position changes are NOT notified through any registered observer of that stream.
    /// The application may poll this value at the appropriate rate, depending on its use case.
    var position: TimeInterval { get }
}
