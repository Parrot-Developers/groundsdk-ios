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

/// Core implementation of CameraPhotoProgress
class CameraPhotoStateCore: CameraPhotoState, CustomDebugStringConvertible {

    /// latest progress event
    var functionState = CameraPhotoFunctionState.unavailable

    /// Number of photo taken in the session (useful for burst and hyperlapse)
    var photoCount = 0

    /// media id, when latestEvent is `photoSaved`
    var mediaId: String?

    /// Called by the backend, update photo count if state is taking_photo
    ///
    /// - Parameters:
    ///   - photoCount: number of photo taken. Only when event is `taking_photo`
    /// - Returns: true if the setting has been changed, false else
    func update(photoCount: Int) -> Bool {
        var changed = false
        if functionState == .started && self.photoCount != photoCount {
            self.photoCount = photoCount
            changed = true
        }
        return changed
    }

    /// Called by the backend, update latest event and media id
    ///
    /// - Parameters:
    ///   - functionState: new function state
    ///   - photoCount: number of photo taken. Only when event is `taking_photo`
    ///   - mediaId: media id. Only when event is `photo_saved`
    /// - Returns: true if the setting has been changed, false else
    func update(functionState: CameraPhotoFunctionState, photoCount: Int? = nil, mediaId: String? = nil) -> Bool {
        var changed = false
        if functionState != self.functionState {
            self.functionState = functionState
            changed = true
        }
        if functionState != .unavailable {
            if mediaId != nil && mediaId != self.mediaId {
                self.mediaId = mediaId
                changed = true
            }
        } else {
            if self.mediaId != nil {
                self.mediaId = nil
                changed = true
            }
        }
        if functionState == .started {
            if let photoCount = photoCount, photoCount != self.photoCount {
                self.photoCount = photoCount
                changed = true
            }
        } else if self.photoCount != 0 {
            self.photoCount = 0
            changed = true
        }
        return changed
    }

    /// Debug description
    var debugDescription: String {
        return "functionState: \(functionState) photoCount: \(photoCount) mediaId: \(mediaId ?? "nil")"
    }
}
