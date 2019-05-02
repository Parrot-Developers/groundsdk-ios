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
import Photos

/// Utility class to add media to platform gallery app (i.e Photo app on iOS)
///
/// During class initialization, the access to the Photo Library will be requested.
public class MediaGalleryAdder: NSObject {

    /// Serial queue to run PHPhotoLibrary requests
    private let queue = DispatchQueue(label: "MediaGalleryAdder")
    /// Album to a  media to
    private var album: PHAssetCollection?

    /// Constructor
    ///
    /// - Note: access to the Photo Library will be requested if needed.
    ///
    /// - Parameter albumName: name of the album to add media to. Album will be create if it doesn't exists. If nil
    ///   don't add media to any album (medias will still be visible in the camera roll).
    public init(albumName: String?) {
        super.init()

        let sem = DispatchSemaphore(value: 0)
        queue.async {
            PHPhotoLibrary.requestAuthorization { _ in
                // request has been answered (positively or negatively), the work in this queue can be continued
                sem.signal()
            }
            // block the media queue, waiting for the authorization answer
            sem.wait()
        }

        if let albumName = albumName {
            queue.async { [weak self] in
                self?.album = self?.getAlbumSync(name: albumName)
            }
        }
    }

    /// Add a media to the photo library
    ///
    /// - Parameters:
    ///   - url: local media url
    ///   - mediaType: media type
    ///   - mediaAddedCb: callback called when the media has been added. This call back is called in the media
    ///                   gallery adder dispatch queue
    public func addMedia(url: URL, mediaType: MediaItem.MediaType,
                         mediaAddedCb: @escaping(_ success: Bool) -> Void) {
        queue.async {
            // strong capture self to ensure MediaGalleryAdder stay alive until add media is executed
            self.addMediaSync(url: url, mediaType: mediaType, mediaAddedCb: mediaAddedCb)
        }
    }

    /// Post a request to get a notification when all pending addMedia have completed
    ///
    /// - Parameter completedCb: callback to call when all pending addMedia have completed
    public func notifyCompleted(completedCb: @escaping () -> Void) {
        // dispatch in media adder serial queue. This will be executed after all task already dispatched in the queue
        // are terminated, i.e after all queued `addMedia` have completed.
        queue.async {
            // call client callbakc in main queue
            DispatchQueue.main.async {
                completedCb()
            }
        }
    }

    /// Gets an album by name synchronously. Called in the media gallery adder dispatch queue.
    ///
    /// - Note: if access to the photo library is not already granted, this function will immediately return a nil
    /// object
    ///
    /// - Parameter name: name of the album to get
    /// - Returns: requested album
    private func getAlbumSync(name: String) -> PHAssetCollection? {
        guard PHPhotoLibrary.authorizationStatus() == .authorized else {
            ULog.e(.coreMediaTag, "Authorization status of PHPhotoLibrary is " +
                "\(PHPhotoLibrary.authorizationStatus()), cannot get album.")
            return nil
        }

        func fetchAlbum() -> PHAssetCollection? {
            let fetchOption = PHFetchOptions()
            fetchOption.predicate = NSPredicate(format: "title = %@", name)
            let collection = PHAssetCollection.fetchAssetCollections(
                with: .album, subtype: .albumRegular, options: fetchOption)
            return collection.firstObject
        }

        var album = fetchAlbum()
        // if not found, try to create it
        if album == nil {
            do {
                try PHPhotoLibrary.shared().performChangesAndWait {
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                }
                album = fetchAlbum()
            } catch let error {
                ULog.w(.coreMediaTag, "Error creating asset collection: \(error).")
            }
        }
        return album
    }

    /// Add a media to the photo gallery synchronously. Called in the media gallery adder dispatch queue.
    ///
    /// - Note: if access to the photo library is not already granted, this function will immediately call
    /// `mediaAddedCb` with `false`.
    ///
    /// - Parameters:
    ///   - url: url of the file to add
    ///   - mediaType: type of media
    ///   - mediaAddedCb: callback called when the media has been added or if there is an error.
    private func addMediaSync(url: URL, mediaType: MediaItem.MediaType,
                              mediaAddedCb: @escaping(_ success: Bool) -> Void) {
        guard PHPhotoLibrary.authorizationStatus() == .authorized else {
            ULog.e(.coreMediaTag, "Authorization status of PHPhotoLibrary is " +
                "\(PHPhotoLibrary.authorizationStatus()), cannot add media.")

            mediaAddedCb(false)
            return
        }

        ULog.d(.coreMediaTag, "adding media \(url.path) to Media Gallery")
        do {
            var success = false
            try PHPhotoLibrary.shared().performChangesAndWait {
                let createMediaRequest: PHAssetChangeRequest?
                switch mediaType {
                case .photo:
                    createMediaRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                case .video:
                    createMediaRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
                if let createMediaRequest = createMediaRequest {
                    if let album = self.album {
                        let assetPlaceholder = createMediaRequest.placeholderForCreatedAsset!
                        let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                        let assets: NSArray = [assetPlaceholder]
                        albumChangeRequest?.addAssets(assets)
                        success = true
                    }
                }
            }
            // call the callback on the media adder queue
            mediaAddedCb(success)
            if success {
                ULog.d(.coreMediaTag, "\(url.path) added successfully")
            } else {
                ULog.w(.coreMediaTag, "Error adding media \(url.path) to Media Gallery")
            }
        } catch let error {
            ULog.w(.coreMediaTag, "Error adding media \(url.path) to Media Gallery: error \(error)")
            // call the callback on the media adder queue
            mediaAddedCb(false)
        }
    }
}
