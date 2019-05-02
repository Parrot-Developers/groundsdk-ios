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

/// Media replay stream interface.
@objc(GSMediaReplay)
public protocol MediaReplay: Replay {

    /// Media source being played back.
    var source: MediaReplaySource { get }
}

/// Media replay source interface.
@objc(GSMediaReplaySource)
public protocol MediaReplaySource {
    /// Media unique identifier.
    var mediaUid: String? { get }

    /// Resource unique identifier.
    var resourceUid: String? { get }

    /// Stream track identifier.
    var track: MediaItem.Track { get }
}

/// Media replay source factory.
@objc(GSMediaReplaySourceFactory)
public class MediaReplaySourceFactory: NSObject {

    /// Creates a source for streaming a media resource.
    ///
    /// - Parameters:
    ///    - resource: media resource to stream
    ///    - track: stream track identifier
    /// - Returns: media replay source
    @objc(videoTrackOf:track:)
    public static func videoTrackOf(resource: MediaItem.Resource, track: MediaItem.Track) -> MediaReplaySource {
        return MediaSourceCore(resource: resource as! MediaItemResourceCore, track: track)
    }
}

/// Objective-C wrapper of Ref<MediaReplay>. Required because swift generics can't be used from Objective-C.
/// - Note: This class is for Objective-C only and must not be used in Swift.
@objcMembers
public class GSMediaReplayRef: NSObject {
    /// Wrapper reference.
    private let ref: Ref<MediaReplay>

    /// Referenced media replay stream.
    public var value: MediaReplay? {
        return ref.value
    }

    /// Constructor.
    ///
    /// - Parameter ref: wrapper reference
    init(ref: Ref<MediaReplay>) {
        self.ref = ref
    }
}
