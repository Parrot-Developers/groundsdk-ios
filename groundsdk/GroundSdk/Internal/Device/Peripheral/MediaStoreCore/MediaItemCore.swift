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
import CoreLocation

/// Add an opaque reference to backend media in media item
public class MediaItemCore: MediaItem {

    /// Backend data
    public let backendData: Any?

    /// Url used to stream the media from the device, or nil if not available
    let streamUrl: String?

    /// Constructor
    ///
    /// - Parameters:
    ///   - uid: media unique identifier
    ///   - name: media name
    ///   - type: media type
    ///   - runUid: unique identifier of the run for this media
    ///   - creationDate: media creation date
    ///   - expectedCount: expected number of resources in the media
    ///   - photoMode: photo mode of the media (if available and media is a photo else nil)
    ///   - panoramaType: panorama type
    ///   - streamUrl: url used to stream the media from the device (if available and media is a video else nil)
    ///   - resources: available resources, by format
    ///   - backendData: backend media data
    ///   - metadataTypes: set of 'MetadataType' available in this media
    public init(uid: String, name: String, type: MediaType, runUid: String, creationDate: Date, expectedCount: UInt64?,
                photoMode: MediaItem.PhotoMode?, panoramaType: PanoramaType?, streamUrl: String? = nil,
                resources: [Resource], backendData: Any? = nil, metadataTypes: Set<MetadataType> = Set()) {
        self.streamUrl = streamUrl
        self.backendData = backendData

        super.init(uid: uid, name: name, type: type, runUid: runUid, creationDate: creationDate,
                   expectedCount: expectedCount, photoMode: photoMode, panoramaType: panoramaType,
                   resources: resources, metadataTypes: metadataTypes)
        resources.forEach { ($0 as! MediaItemResourceCore).media = self }
    }
}

/// MediaItem.Resource implementation. Add `core` public constructor
public class MediaItemResourceCore: MediaItem.Resource {

    /// Media owning this resource
    fileprivate(set) public weak var media: MediaItemCore?

    /// Url used to stream the resource from the device, or nil if not available
    let streamUrl: String?

    /// List of available tracks for a resource
    var tracks: [MediaItem.Track: String]

    /// Backend data
    public let backendData: Any?

    /// Constructor
    ///
    /// - Parameters:
    ///   - uid: unique identifier
    ///   - format: resource format
    ///   - size: resource data size
    ///   - duration: resource duration for video
    ///   - streamUrl: url used to stream the media from the device (if available and media is a video, `nil` otherwise)
    ///   - backendData: backend data
    ///   - location: resource creation location, may be nil if unavailable
    ///   - creationDate: media creation date
    ///   - metadataTypes: set of 'MediaItem.MetadataType' available in this ressource
    public init(uid: String, format: MediaItem.Format, size: UInt64, duration: TimeInterval? = nil,
                streamUrl: String? = nil, backendData: Any? = nil, location: CLLocation?, creationDate: Date,
                metadataTypes: Set<MediaItem.MetadataType> = Set()) {
        self.streamUrl = streamUrl
        self.backendData = backendData
        self.tracks = [:]

        if streamUrl != nil {
            self.tracks[.defaultVideo] = StreamCore.TRACK_DEFAULT_VIDEO
            if metadataTypes.contains(.thermal) {
                self.tracks[.thermalUnblended] = StreamCore.TRACK_THERMAL_VIDEO
            }
        }
        super.init(uid: uid, format: format, size: size, duration: duration, location: location,
                   creationDate: creationDate, metadataTypes: metadataTypes)
    }

    /// Get available tracks for media
    ///
    /// - Returns: tracks for current media if it exists
    override public func getAvailableTracks() -> Set<MediaItem.Track>? {
        return tracks.isEmpty ? nil : Set(tracks.keys)
    }

    /// Get track id for track
    ///
    /// - Parameter track: media item track
    /// - Returns: track id if exists
    public func getStreamTrackIdFor(track: MediaItem.Track) -> String? {
        if !tracks.isEmpty, let value = tracks[track] {
            return value
        }
        return nil
    }
}
