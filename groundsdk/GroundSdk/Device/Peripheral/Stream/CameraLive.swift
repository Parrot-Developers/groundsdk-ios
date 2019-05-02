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

/// Camera live stream playback state.
@objc(GSCameraLivePlayState)
public enum CameraLivePlayState: Int, CustomStringConvertible {
    /// Stream is 'State.stopped'.
    case none

    /// Stream is either 'State.starting' or 'State.suspended' in which case this indicates
    /// that playback will start once the stream is started, or 'State.started' in which case
    /// this indicates that playback is currently ongoing.
    case playing

    /// Stream is either 'State.starting' or 'State.suspended' in which case this indicates
    /// that playback will pause once the stream is started, or 'State.started' in which case
    /// this indicates that playback is currently paused.
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

/// Camera live stream interface.
/// Provides control over the drone camera live stream, allowing to pause, resume or stop playback.
/// There is only one instance of this interface that is shared amongst all clients that have an open
/// reference on this stream.
///
/// This stream supports 'suspended' state. When it is started and gets interrupted because another stream starts,
/// or because streaming gets disabled globally, it moves to the 'suspended' state.
/// Once the interruption stops, or streaming gets enabled, it is resumed in the state it was before suspension.
/// Also, this implies that this stream can be started even while streaming is globally disabled. In such case,
/// it will move to the 'suspended' state until either it is stopped by client request, or streaming gets enabled.
@objc(GSCameraLive)
public protocol CameraLive: Stream {

    /// Current playback state.
    var playState: CameraLivePlayState { get }

    /// Requests playback to start.
    ///
    /// The stream is started if necessary.
    ///
    /// - Returns: 'true' if playback request was sent, otherwise 'false'
    func play() -> Bool

    /// Requests playback to pause.
    ///
    /// The stream is started if necessary.
    ///
    /// - Returns: 'true' if playback request was sent, otherwise 'false'
    func pause() -> Bool

    /// Stop the stream.
    func stop()
}

/// Objective-C wrapper of Ref<CameraLive>. Required because swift generics can't be used from Objective-C.
/// - Note: This class is for Objective-C only and must not be used in Swift.
@objcMembers
public class GSCameraLiveRef: NSObject {
    /// Wrapper reference.
    private let ref: Ref<CameraLive>

    /// Referenced camera live stream.
    public var value: CameraLive? {
        return ref.value
    }

    /// Constructor.
    ///
    /// - Parameter ref: wrapper reference
    init(ref: Ref<CameraLive>) {
        self.ref = ref
    }
}
