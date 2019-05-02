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

/// Core implementation of CameraRecordingProgress
class CameraRecordingStateCore: CameraRecordingState, CustomDebugStringConvertible {

    /// current camera recording function state
    var functionState = CameraRecordingFunctionState.unavailable

    /// Recording start time, when functionState is `started`
    var startTime: Date?

    /// media id, when latestEvent is `stopped` or one of the error state
    var mediaId: String?

    /// gets current recording duration, return 0 when recording is not running
    func getDuration() -> TimeInterval {
        if let startTime = startTime {
            return Date().timeIntervalSince(startTime)
        }
        return 0
    }

    /// Called by the backend, update latest event and media id
    ///
    /// - Parameters:
    ///   - functionState: new function state
    ///   - startTime recording start time when event is `started`
    ///   - mediaId: media id. Only when event is `stopped`
    /// - Returns: true if the setting has been changed, false else
    func update(functionState: CameraRecordingFunctionState, startTime: Date? = nil, mediaId: String? = nil) -> Bool {
        var changed = false
        if functionState != self.functionState {
            if functionState != self.functionState {
                self.functionState = functionState
                changed = true
            }
        }
        if functionState != .unavailable {
            if mediaId != nil && mediaId != self.mediaId {
                self.mediaId = mediaId
                changed = true
            }
        } else {
            if mediaId != nil {
                self.mediaId = nil
                changed = true
            }
        }
        if functionState == .started {
            if let startTime = startTime, startTime != self.startTime {
                self.startTime = startTime
                changed = true
            }
        } else if self.startTime != nil {
            self.startTime = nil
            changed = true
        }
        return changed
    }

    /// Debug description
    var debugDescription: String {
        return "functionState: \(functionState) startTime: \(startTime?.description ?? "nil") " +
                "mediaId: \(mediaId ?? "nil")"
    }
}
