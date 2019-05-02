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

/// Allows to receive notification upon a stream's media info availability changes.
class MediaListener: NSObject {

    /// Called back when the required media becomes available.
    ///
    /// - Parameter mediaInfo: info upon available media
    func onMediaAvailable(mediaInfo: SdkCoreMediaInfo) {}

    /// Called back when the required media becomes unavailable.
    func onMediaUnavailable() {}
}

/// Bookkeeping of available media kinds on a stream and allows to subscribe to such media availability events.
class MediaRegistry {

    /// Media info, by media id.
    var medias = [Int: SdkCoreMediaInfo]()

    /// Media listeners
    var listeners = [SdkCoreMediaType: Set<MediaListener>]()

    /// Add a media.
    ///
    /// Only one media of each kind may be registered at any time. In case a media of the same kind is already
    /// registered, then it is removed, subscribed listeners being notified of that event, and finally the new media
    /// is added.
    ///
    /// Subscribed listeners are notified that a new media is available.
    ///
    /// - Parameter info: information on the added media
    func addMedia(info: SdkCoreMediaInfo) {
        for media in medias where media.value.type == info.type {
            medias.removeValue(forKey: media.key)
            notifyMediaUnavailable(info: media.value)
        }
        medias[info.mediaId] = info
        notifyMediaAvailable(info: info)
    }

     /// Remove a media.
     ///
     /// Subscribed listener are notified that the media is not available anymore.
     ///
     /// - Parameter info: information on the removed media
    func removeMedia<MediaInfo: SdkCoreMediaInfo>(info: MediaInfo) {
        if medias.removeValue(forKey: info.mediaId) != nil {
            notifyMediaUnavailable(info: info)
        }
    }

    /// Register a media kind listener.
    ///
    /// In case a media of the requested kind is available when this method is called,
    /// 'MediaListener.onMediaAvailable()' is called immediately.
    ///
    /// - Parameters:
    ///    - listener: listener notified of media availability changes
    ///    - mediaType: type of media to listen
    func registerListener(listener: MediaListener, mediaType: SdkCoreMediaType) {
        var typeListeners = listeners[mediaType]
        if typeListeners == nil {
            typeListeners = Set<MediaListener>()
        }
        _ = typeListeners?.insert(listener)
        listeners[mediaType] = typeListeners
        for media in medias where media.value.type == mediaType {
            listener.onMediaAvailable(mediaInfo: media.value)
        }
    }

    /// Unregister a media listener.
    ///
    /// - Parameters:
    ///    - listener: listener to unregister
    ///    - mediaType: type of media that was listened
    func unregisterListener(listener: MediaListener, mediaType: SdkCoreMediaType) {
        var typeListeners = listeners[mediaType]
        if typeListeners != nil {
            typeListeners?.remove(listener)
            listeners[mediaType] = typeListeners
        }
    }

    /// Notify subscribed listeners that a media is available.
    ///
    /// - Parameter info: information on the available media
    private func notifyMediaAvailable(info: SdkCoreMediaInfo) {
        if let typeListeners = listeners[info.type] {
            for listener in typeListeners {
                listener.onMediaAvailable(mediaInfo: info)
            }
        }
    }

    /// Notify subscribed listeners that a media is unavailable.
    ///
    /// - Parameter info: information on the unavailable media
    private func notifyMediaUnavailable(info: SdkCoreMediaInfo) {
        if let typeListeners = listeners[info.type] {
            for listener in typeListeners {
                listener.onMediaUnavailable()
            }
        }
    }
}
