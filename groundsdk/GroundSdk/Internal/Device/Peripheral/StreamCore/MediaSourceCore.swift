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

/// Core class for media replay source.
public class MediaSourceCore: MediaReplaySource {
    public var track: MediaItem.Track

    public var mediaUid: String?

    public var resourceUid: String?

    /// url to play
    public var streamUrl: String?

    /// Name of the track of the stream
    public var streamTrackName: String?

    /// Constructor
    ///
    /// - Parameters:
    ///    - resource: resource to be played
    ///    - track: track to select
    init(resource: MediaItemResourceCore, track: MediaItem.Track) {
        self.mediaUid = resource.media?.uid
        self.streamTrackName = resource.getStreamTrackIdFor(track: track)
        self.streamUrl = resource.streamUrl
        self.track = track
        self.resourceUid = resource.uid
    }

    func openStream(server: StreamServerCore, listener: SdkCoreStreamListener) -> SdkCoreStream? {
        if let streamUrl = streamUrl, let streamTrackName = streamTrackName {
            return server.openStream(url: streamUrl, track: streamTrackName, listener: listener)
        }
        return nil
    }

}
