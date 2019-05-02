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

/// Implementation of a reference on a list of media items
class MediaListRefCore: Ref<[MediaItem]> {
    /// Media store instance
    private let mediaStore: MediaStoreCore
    /// Media store listener
    private var mediaStoreListener: MediaStoreCore.Listener!
    /// Running media browse request, nil if there are no queries running
    private var request: CancelableCore?

    /// Constructor
    ///
    /// - Parameters:
    ///   - mediaStore: media store instance
    ///   - observer: observer notified when the list changes
    init(mediaStore: MediaStoreCore, observer: @escaping Observer) {
        self.mediaStore = mediaStore
        super.init(observer: observer)
        // register ourself on store change notifications
        mediaStoreListener = mediaStore.register {  [unowned self] in
            // store content changed, update media list
            self.updateMediaList()
        }
        setup(value: nil)
        // send the initial query
        updateMediaList()
    }

    /// destructor
    deinit {
        if let request = request {
            request.cancel()
        }
        mediaStore.unregister(listener: mediaStoreListener)
    }

    /// Send a request to load media list
    private func updateMediaList() {
        if mediaStore.published {
            if request == nil {
                request = mediaStore.backend.browse { [weak self] medias in

                    // weak self in case backend call callback after cancelling request
                    if let `self` = self {
                        `self`.request = nil
                        // copy user data into the new items
                        if let currentList = self.value as? [MediaItemCore] {
                            for media in medias {
                                media.userData = currentList.first(where: {return $0.uid == media.uid})?.userData
                            }
                        }
                        // update the ref with the new list
                        `self`.update(newValue: medias)
                    }
                }
            }
        } else {
            // not published, set the media list to nil
            update(newValue: nil)
        }
    }
}
