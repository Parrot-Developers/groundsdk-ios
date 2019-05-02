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
import GroundSdk

/// 4Mb thumbnail cache
private let thumbnailCacheSize = 4 * 1024 * 1024

/// Media store delegate
protocol MediaStoreDelegate: class {

    /// Media store instance
    var mediaStore: MediaStoreCore! { get set }

    /// Configure the delegate
    func configure()

    /// Reset the delegate
    func reset()

    /// Start watching media store content.
    ///
    /// When content watching is started, backend must call `mediaStore.markContentChanged()` when the content of
    /// the media store changes.
    func startWatchingContentChanges()

    /// Stop watching media store content.
    func stopWatchingContentChanges()

    /// Get the list of the medias on the drone
    ///
    /// - Parameters:
    ///   - completion: closure that will be called when browsing did finish
    ///   - medias: list of the medias available on the device
    /// - Returns: a request that can be canceled
    func browse(completion: @escaping (_ medias: [MediaItemCore]) -> Void) -> CancelableCore?

    /// Download the thumbnail of a given media.
    ///
    /// - Parameters:
    ///   - owner: owner of the thumbnail to fetch
    ///   - completion: closure that will be called when download is done
    ///   - thumbnailData: the data of the thumbnail image
    /// - Returns: a request that can be canceled
    func downloadThumbnail(for owner: MediaStoreThumbnailCacheCore.ThumbnailOwner,
                           completion: @escaping (_ thumbnailData: Data?) -> Void) -> CancelableCore?
    /// Download a resource
    ///
    /// - Parameters:
    ///   - resource: resource to download
    ///   - destDirectoryPath: download destination path
    ///   - progress: progress callback
    ///   - progressValue: the progress value, from 0 to 100
    ///   - completion: completion callback
    ///   - fileUrl: the url of the downloaded file. Nil if an error occurred.
    /// - Returns: a request that can be canceled
    func download(
        resource: MediaItemResourceCore, destDirectoryPath: String,
        progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ fileUrl: URL?) -> Void) -> CancelableCore?

    /// Delete a media
    ///
    /// - Parameters:
    ///   - media: the media to delete
    ///   - completion: completion callback
    ///   - success: whether the deletion was successful or not
    /// - Returns: a request that can be canceled
    func delete(media: MediaItemCore, completion: @escaping (_ success: Bool) -> Void) -> CancelableCore?

    /// Delete a media resource
    ///
    /// - Parameters:
    ///   - resource: the resource to delete
    ///   - completion: completion callback
    ///   - success: whether the deletion was successful or not
    /// - Returns: a request that can be canceled
    func delete(resource: MediaItemResourceCore, completion: @escaping (_ success: Bool) -> Void) -> CancelableCore?

    /// Delete all medias
    ///
    /// - Parameters:
    ///   - completion: completion callback
    ///   - success: whether the deletion was successful or not
    /// - Returns: a request that can be canceled
    func deleteAll(completion: @escaping (_ success: Bool) -> Void) -> CancelableCore?

    /// Informs the delegate that a command has been received
    ///
    /// - Parameter command: the command received
    func didReceiveCommand(_ command: OpaquePointer)
}
// swiftlint:enable class_delegate_protocol

/// Media store peripheral controller that does access the media through http
class HttpMediaStore: ArsdkMediaStore {
    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    init(deviceController: DeviceController) {
        super.init(deviceController: deviceController,
                   delegate: HttpMediaStoreDelegate(deviceController: deviceController))
    }
}

/// Media Store peripheral controller
///
/// This class is abstract. See `FtpMediaStore` or `HttpMediaStore` to create actual instances of this class.
class ArsdkMediaStore: DeviceComponentController {

    /// Media store component
    private var mediaStore: MediaStoreCore!

    // swiftlint:disable weak_delegate
    /// The media store delegate.
    private let delegate: MediaStoreDelegate
    // swiftlint:enable weak_delegate

    /// Constructor
    ///
    /// Visibility is fileprivate to force creation from `FtpMediaStore` or `HttpMediaStore`.
    ///
    /// - Parameters:
    ///   - deviceController: device controller owning this component controller (weak)
    ///   - delegate: media access delegate
    fileprivate init(deviceController: DeviceController, delegate: MediaStoreDelegate) {
        self.delegate = delegate
        super.init(deviceController: deviceController)
        mediaStore = MediaStoreCore(
            store: deviceController.device.peripheralStore,
            thumbnailCache: MediaStoreThumbnailCacheCore(mediaStoreBackend: self, size: thumbnailCacheSize),
            backend: self)
        self.delegate.mediaStore = mediaStore
    }

    /// Drone is connected
    override func didConnect() {
        delegate.configure()
        mediaStore.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        mediaStore.unpublish()
        delegate.reset()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        delegate.didReceiveCommand(command)
    }
}

/// MediaStore backend implementation
extension ArsdkMediaStore: MediaStoreBackend {

    /// Start watching media store content.
    ///
    /// When content watching is started, backend must call `markContentChanged()` when the content of
    /// the media store changes.
    func startWatchingContentChanges() {
        delegate.startWatchingContentChanges()
    }

    /// Stop watching media store content.
    func stopWatchingContentChanges() {
        delegate.stopWatchingContentChanges()
    }

    /// Browse medias.
    ///
    /// - Parameter completion: closure called when the request is terminated
    /// - Returns: browse request, or nil if there is an error
    public func browse(completion: @escaping ([MediaItemCore]) -> Void) -> CancelableCore? {
        return delegate.browse(completion: completion)
    }

    /// Download a thumbnail
    ///
    /// - Parameters:
    ///   - owner: owner to download the thumbnail for
    ///   - completion: closure called when the thumbnail has been downloaded or if there is an error.
    ///   - thumbnailData: downloaded thumbnail data, nil if there is a error
    /// - Returns: download thumbnail request, or nil if the request can't be send
    public func downloadThumbnail(for owner: MediaStoreThumbnailCacheCore.ThumbnailOwner,
                                  completion: @escaping (_ thumbnailData: Data?) -> Void) -> CancelableCore? {
        return delegate.downloadThumbnail(for: owner, completion: completion)
    }

    /// Download a list of media resources
    ///
    /// - Parameters:
    ///   - mediaResources: media resources to download
    ///   - destination: download destination
    ///   - progress: progress callback
    /// - Returns: download task, or nil if the request can't be send
    public func download(mediaResources: MediaResourceListCore, destination: DownloadDestination,
                         progress: @escaping (MediaDownloader) -> Void) -> CancelableTaskCore? {

        let destDirectoryPath: String
        switch destination {
        case .document(let directoryName):
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            if let directoryName = directoryName {
                destDirectoryPath = documentPath.appendingPathComponent(directoryName).path
            } else {
                destDirectoryPath = documentPath.path
            }
        case .directory(let path):
            destDirectoryPath = path
        default:
            destDirectoryPath = NSTemporaryDirectory()
        }
        do {
            try FileManager.default.createDirectory(atPath: destDirectoryPath,
                                                    withIntermediateDirectories: true, attributes: nil)
        } catch let err {
            ULog.e(.ctrlTag, "ArsdkMediaStore: error creating download media directory \(err)")
            return nil
        }

        // init MediaGalleryAdder if target is .mediaGallery
        let galleryAdder: MediaGalleryAdder?
        if case .mediaGallery(let albumName) = destination {
            galleryAdder = MediaGalleryAdder(albumName: albumName)
        } else {
            galleryAdder = nil
        }
        // init resource iterator
        let resourcesIterator = mediaResources.makeIterator()
        // create result request
        let task = CancelableTaskCore()

        /// Notify progress with current file progress
        ///
        /// - Parameter percent: current file download %
        func notifyProgress(percent: Float, currentMedia: MediaItem) {
            progress(MediaDownloaderCore(
                mediaResourceListIterator: resourcesIterator, currentFileProgress: percent / 100,
                status: .running, currentMedia: currentMedia))
        }

        /// Notify progress completion with fileUrl
        func notifyProgressCompletion(currentMedia: MediaItem, fileUrl: URL) {
            progress(MediaDownloaderCore(
                mediaResourceListIterator: resourcesIterator, currentFileProgress: 1.0, status: .fileDownloaded,
                currentMedia: currentMedia, fileUrl: fileUrl))
        }

        /// Notify progress with an error
        func notifyProgressError(currentMedia: MediaItem) {
            progress(MediaDownloaderCore(
                mediaResourceListIterator: resourcesIterator, currentFileProgress: 0.0,
                status: .error, currentMedia: currentMedia))
        }

        /// Notify download terminated
        func notifyProgressTerminated() {
            progress(MediaDownloaderCore(
                mediaResourceListIterator: resourcesIterator, currentFileProgress: 1.0, status: .complete))
        }

        /// Process downloaded resource
        ///
        /// - Parameters:
        ///   - media: downloaded media
        ///   - filePath: local media resource path
        func processDownloadedResource(media: MediaItem, fileUrl: URL) {
            ULog.d(.ctrlTag, "media \(fileUrl.path) downloaded")
            if let galleryAdder = galleryAdder {
                galleryAdder.addMedia(url: fileUrl, mediaType: media.type) { _ in
                    do {
                        try FileManager.default.removeItem(at: fileUrl)
                    } catch let err {
                        ULog.e(.ctrlTag, "Error adding item to gallery \(err)")
                    }
                }
            }
        }

        /// Download the next media resource in the iterator
        func downloadNextResource() {
            guard !task.canceled else {
                // don't do anything if the request has been canceled
                return
            }

            // Move to next resource
            if let mediaResource = resourcesIterator.next() {
                // request download
                let req = delegate.download(
                    resource: mediaResource.resource, destDirectoryPath: destDirectoryPath,
                    progress: { percent in notifyProgress(percent: Float(percent), currentMedia: mediaResource.media) },
                    completion: { fileUrl in
                        task.request = nil
                        if let fileUrl = fileUrl {
                            processDownloadedResource(media: mediaResource.media, fileUrl: fileUrl)
                            notifyProgressCompletion(currentMedia: mediaResource.media, fileUrl: fileUrl)
                            downloadNextResource()
                        } else if !task.canceled {
                            ULog.w(.ctrlTag, "Error downloading \(String(describing: fileUrl?.path))")
                            notifyProgressError(currentMedia: mediaResource.media)
                        }
                })
                // request created, update client request and notify progress
                if let req = req {
                    // store current low level request to cancel
                    task.request = req
                    // progress for the new resource
                    notifyProgress(percent: 0, currentMedia: mediaResource.media)
                } else {
                    // error sending request
                    ULog.d(.ctrlTag, "media download error sending request, skipping media")
                    notifyProgressError(currentMedia: mediaResource.media)
                }
            } else {
                // no more resources to download
                if let galleryAdder = galleryAdder {
                    ULog.d(.ctrlTag, "media download terminated, waiting for media gallery completion ")
                    galleryAdder.notifyCompleted {
                        ULog.d(.ctrlTag, "media gallery update terminated")
                        notifyProgressTerminated()
                    }
                } else {
                    ULog.d(.ctrlTag, "media download terminated")
                    notifyProgressTerminated()
                }
            }
        }

        // start download with the first resource
        downloadNextResource()
        return task
    }

    /// Delete medias resources
    ///
    /// - Parameters:
    ///   - mediaResources: list of media resources to delete
    ///   - progress: progress closure called after each deleted files
    /// - Returns: delete request, or nil if the request can't be send
    func delete(mediaResources: MediaResourceListCore,
                progress: @escaping (MediaDeleter) -> Void) -> CancelableTaskCore? {
        // forward declare completion, as it's used in itself
        var completion: ((Bool) -> Void)!
        let entryIterator = mediaResources.makeIterator()
        let task = CancelableTaskCore()

        func deleteNext() {
            guard !task.canceled else {
                // don't do anything if the request has been canceled
                return
            }
            // move to next media or resource
            if let entry = entryIterator.nextMediaOrResource() {
                if let resource = entry.resource {
                    task.request = delegate.delete(resource: resource, completion: completion)
                } else {
                    task.request = delegate.delete(media: entry.media, completion: completion)
                }
                progress(MediaDeleterCore(mediaResourceListIterator: entryIterator, status: .running))
            } else {
                progress(MediaDeleterCore(mediaResourceListIterator: entryIterator, status: .complete))
            }
        }

        completion = { success in
            if success {
                deleteNext()
            } else {
                progress(MediaDeleterCore(mediaResourceListIterator: entryIterator, status: .error))
            }
        }

        // trig first delete
        deleteNext()

        return task
    }

    func deleteAll(progress: @escaping (AllMediasDeleter) -> Void) -> CancelableTaskCore? {
        let task = CancelableTaskCore()
        progress(AllMediasDeleterCore(status: .running))
        task.request = self.delegate.deleteAll { success in
            let status: MediaTaskStatus = success ? .complete : .error
            progress(AllMediasDeleterCore(status: status))
        }

        return task
    }
}
