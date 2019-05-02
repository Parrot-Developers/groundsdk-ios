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

/// MediaDownloader Reference implementation
class MediaDownloaderRefCore: Ref<MediaDownloader> {

    /// Media store instance
    private let mediaStore: MediaStoreCore
    /// number of media to download
    private let total: Int
    /// active delete request
    private var request: CancelableTaskCore?

    /// Constructor
    ///
    /// - Parameters:
    ///   - mediaStore: media store instance
    ///   - mediaResources: media resources to download
    ///   - destination: download destination
    ///   - observer: observer notified of download progress
    init(mediaStore: MediaStoreCore, mediaResources: MediaResourceListCore, destination: DownloadDestination,
         observer: @escaping Observer) {
        self.mediaStore = mediaStore
        self.total = 0
        super.init(observer: observer)
        self.request = mediaStore.backend
            .download(mediaResources: mediaResources, destination: destination) { [weak self] mediaDownloader in
                // weak self in case backend call callback after cancelling request
                self?.update(newValue: mediaDownloader)
        }
    }

    /// destructor
    deinit {
        if let request = request {
            request.cancel()
        }
    }
}
