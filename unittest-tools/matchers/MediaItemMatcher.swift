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

import GroundSdk
import CoreLocation

func has(uid: String) -> Matcher<MediaItem> {
    return Matcher("uid = \(uid)") { $0.uid == uid }
}

func has(name: String) -> Matcher<MediaItem> {
    return Matcher("name = \(name)") { $0.name == name }
}

func has(type: MediaItem.MediaType) -> Matcher<MediaItem> {
    return Matcher("type = \(type)") { $0.type == type }
}

func has(runUid: String) -> Matcher<MediaItem> {
    return Matcher("runUid = \(runUid)") { $0.runUid == runUid }
}

func has(creationDate: Date) -> Matcher<MediaItem> {
    return Matcher("creationDate = \(creationDate)") { $0.creationDate == creationDate }
}

func has(photoMode: MediaItem.PhotoMode?) -> Matcher<MediaItem> {
    return Matcher("photoMode = \(String(describing: photoMode))") { $0.photoMode == photoMode }
}

func has(panoramaType: MediaItem.PanoramaType?) -> Matcher<MediaItem> {
    return Matcher("panoramaType = \(String(describing: panoramaType))") { $0.panoramaType == panoramaType }
}

func has(metadataType: MediaItem.MetadataType) -> Matcher<MediaItem> {
    return Matcher("metadataType = \(metadataType)") { $0.metadataTypes.contains(metadataType) }
}

// MediaItem.Resource

func has(format: MediaItem.Format) -> Matcher<MediaItem.Resource> {
    return Matcher("format = \(format)") { $0.format == format }
}

func has(size: Int) -> Matcher<MediaItem.Resource> {
    return Matcher("size = \(size)") { $0.size == size }
}

func has(duration: TimeInterval?) -> Matcher<MediaItem.Resource> {
    return Matcher("duration = \(String(describing: duration))") { $0.duration == duration }
}

func has(location: CLLocation) -> Matcher<MediaItem.Resource> {
    return Matcher("location = \(location)") { $0.location == location }
}

func has(creationDate: Date) -> Matcher<MediaItem.Resource> {
    return Matcher("creationDate = \(creationDate)") { $0.creationDate == creationDate }
}

func has(metadataType: MediaItem.MetadataType) -> Matcher<MediaItem.Resource> {
    return Matcher("metadataType = \(metadataType)") { $0.metadataTypes.contains(metadataType) }
}

func hasEmptyMetadataType() -> Matcher<MediaItem.Resource> {
    return Matcher("hasEmptyMetadataType") { $0.metadataTypes.isEmpty }
}
