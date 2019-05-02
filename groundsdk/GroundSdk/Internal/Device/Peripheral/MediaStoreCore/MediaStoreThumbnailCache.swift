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
import UIKit

/// Media store thumbnail cache
public class MediaStoreThumbnailCacheCore {
    /// Owner of the thumbnail
    public enum ThumbnailOwner {
        /// The thumbnail belongs to a media
        case media(MediaItemCore)
        /// The thumbnail belongs to a resource
        case resource(MediaItemCore, MediaItemResourceCore)

        /// Unique identifier of the owner.
        /// This identifier is only unique for a given drone.
        var uid: String {
            switch self {
            case .media(let media): return media.uid
            case .resource(let media, let resource): return media.uid + resource.uid
            }
        }
    }

    /// A request for a thumbnail
    class ThumbnailRequest {
        /// cache instance
        private weak var cache: MediaStoreThumbnailCacheCore?
        /// uid of the requested thumbnail media
        fileprivate let mediaUid: String
        /// callback
        fileprivate let loadedCallback: (UIImage?) -> Void

        /// Constructor
        ///
        /// - Parameters:
        ///   - cache: cache instance
        ///   - mediaUid: uid of the requested thumbnail media
        ///   - loadedCallback: callback
        init(cache: MediaStoreThumbnailCacheCore, mediaUid: String, loadedCallback: @escaping (UIImage?) -> Void) {
            self.cache = cache
            self.mediaUid = mediaUid
            self.loadedCallback = loadedCallback
        }

        /// Cancel the requests
        func cancel() {
            cache?.cancelRequest(self)
        }
    }

    /// Cache entry
    private enum CacheEntry {
        /// a cached image
        case image(mediaUid: String, imageData: Data?)
        /// an active request, i.e a request with client waiting callback call
        case activeRequest(downloadRequest: LinkedListNode<ThumbnailOwner>, requests: [ThumbnailRequest])
        /// a background request: client did request the thumbnail but canceled it
        case backgroundRequest(thumbnailOwner: ThumbnailOwner)
    }

    /// Media store backend instance
    private unowned let mediaStoreBackend: MediaStoreBackend
    /// Cache, by media uid
    private var cache = [String: LinkedListNode<CacheEntry>]()
    /// List of cache entries, by usage order
    private let cacheLru = LinkedList<CacheEntry>()
    /// Cache maximum size
    private let maxSize: Int
    /// Cache total size
    private var totalSize = 0

    /// Pending download requests
    private let downloadRequests = LinkedList<ThumbnailOwner>()
    /// Current download requests
    private var currentDownloadRequest: CancelableCore?

    /// Constructor
    ///
    /// - Parameters:
    ///   - mediaStoreBackend: media store backend
    ///   - size: maximum cache size
    public init(mediaStoreBackend: MediaStoreBackend, size: Int) {
        self.mediaStoreBackend = mediaStoreBackend
        self.maxSize = size
    }

    /// Clear cache content, stop all pending requests
    func clear() {
        currentDownloadRequest?.cancel()
        downloadRequests.reset()
        cacheLru.reset()
        cache.removeAll()
        totalSize = 0
    }

    /// Get a thumbnail
    ///
    /// - Parameters:
    ///   - owner: owner to get the thumbnail for
    ///   - loadedCallback: callback called when the thumbnail has been downloaded, called immediately if the thumbnail
    ///     is already cached
    /// - Returns: request that can be cancel if the image is not in the cache
    func getThumbnail(for owner: ThumbnailOwner, loadedCallback: @escaping (UIImage?) -> Void) -> ThumbnailRequest? {
        // thumbnail returned to caller
        var request: ThumbnailRequest?
        // check if there is a node in the cache
        var node = cache[owner.uid]
        if let node = node {
            // existing node, unlink it
            cacheLru.remove(node)
            switch node.content! {
            case .activeRequest(let downloadRequest, let requests):
                ULog.d(.coreMediaTag, "getThumbnail, adding callback to activeRequest \(owner.uid)")
                // active request add new client reference
                request = ThumbnailRequest(cache: self, mediaUid: downloadRequest.content!.uid,
                                           loadedCallback: loadedCallback)
                node.content = .activeRequest(downloadRequest: downloadRequest, requests: requests + [request!])
            case .backgroundRequest(let owner):
                // background request: change it to active
                ULog.d(.coreMediaTag, "getThumbnail, activate background request \(owner.uid)")
                let downloadRequest = queueDownload(thumbnailOwner: owner)
                request = ThumbnailRequest(cache: self, mediaUid: owner.uid, loadedCallback: loadedCallback)
                node.content = .activeRequest(downloadRequest: downloadRequest, requests: [request!])
            case .image(_, let thumbnailData):
                // existing image data, call the loaded callback now
                if let thumbnailData = thumbnailData {
                    loadedCallback(UIImage(data: thumbnailData))
                } else {
                    loadedCallback(nil)
                }
            }
        } else {
            // create a new node and queue download
            ULog.d(.coreMediaTag, "getThumbnail, create new activeRequest \(owner.uid)")
            request = ThumbnailRequest(cache: self, mediaUid: owner.uid, loadedCallback: loadedCallback)
            let downloadRequest = queueDownload(thumbnailOwner: owner)
            node = LinkedListNode<CacheEntry>(
                content: .activeRequest(downloadRequest: downloadRequest, requests: [request!]))
            cache[owner.uid] = node
            // create a new download request
        }
        // move to the top of the lru
        cacheLru.push(node!)
        return request
    }

    /// Cancel a thumbnail request
    ///
    /// - Parameter request: request to cancel
    private func cancelRequest(_ request: ThumbnailRequest) {
        if let node = cache[request.mediaUid] {
            if case .activeRequest(let downloadRequest, let requests) = node.content! {
                let newRequests = requests.filter({$0 !== request})
                if newRequests.isEmpty {
                    ULog.d(.coreMediaTag, "dequeue download thumbnail request \(downloadRequest.content!.uid)")
                    dequeueDownload(downloadNode: downloadRequest)
                    node.content = .backgroundRequest(thumbnailOwner: downloadRequest.content!)
                } else {
                    node.content = .activeRequest(downloadRequest: downloadRequest, requests: newRequests)
                }
            }
        }
    }

    /// Queue a thumbnail download request
    ///
    /// - Parameter thumbnailOwner: owner to download the thumbnail for
    /// - Returns: node added to the downloadRequests queue
    private func queueDownload(thumbnailOwner: ThumbnailOwner) -> LinkedListNode<ThumbnailOwner> {
        ULog.d(.coreMediaTag, "queue download thumbnail request \(thumbnailOwner.uid)")
        let downloadRequest = LinkedListNode(content: thumbnailOwner)
        downloadRequests.queue(downloadRequest)
        // kick off download state machine if not active
        downloadNextThumbnail()
        return downloadRequest
    }

    /// Dequeue a download request
    ///
    /// - Parameter downloadNode: download request note to dequeue
    private func dequeueDownload(downloadNode: LinkedListNode<ThumbnailOwner>) {
        ULog.d(.coreMediaTag, "dequeueDownload download thumbnail request \(downloadNode.content!.uid)")
        downloadRequests.remove(downloadNode)
    }

    /// Send the request to download the next thumbnail if there are no active request
    private func downloadNextThumbnail() {
        if currentDownloadRequest == nil {
            if let downloadRequest = downloadRequests.pop() {
                ULog.d(.coreMediaTag, "downloading thumbnail \(downloadRequest.content!.uid)")
                currentDownloadRequest = mediaStoreBackend
                    .downloadThumbnail(for: downloadRequest.content!) { [unowned self] thumbnailData in
                        self.insertThumbnailInCache(
                            mediaUid: downloadRequest.content!.uid, thumbnailData: thumbnailData)
                        self.currentDownloadRequest = nil
                        self.downloadNextThumbnail()
                }
            }
        }
    }

    /// Insert a downloaded thumbnail into the cache
    ///
    /// - Parameters:
    ///   - mediaUid: uid of the media
    ///   - thumbnailData: thumbnail data
    private func insertThumbnailInCache(mediaUid: String, thumbnailData: Data?) {
        if let node = cache[mediaUid] {
            if case .activeRequest(_, let requests) = node.content! {
                let image: UIImage?
                if let thumbnailData = thumbnailData {
                    image = UIImage(data: thumbnailData)
                } else {
                    image = nil
                }
                requests.forEach { $0.loadedCallback(image) }
            }
            node.content = .image(mediaUid: mediaUid, imageData: thumbnailData)
            totalSize += thumbnailData?.count ?? 0
            ULog.d(.coreMediaTag, "caching thumbnail cacheSize:\(totalSize) \(mediaUid)")
        }
        if totalSize > maxSize {
            cleanOldEntries()
        }
    }

    /// Remove old cache entries until the cache is lower that it's maximum size
    private func cleanOldEntries() {
        cacheLru.reverseWalk { node in
            switch node.content! {
            case .image(let mediaUid, let thumbnailData):
                if let thumbnailData = thumbnailData {
                    cache[mediaUid] = nil
                    totalSize -= thumbnailData.count
                    cacheLru.remove(node)
                    ULog.d(.coreMediaTag, "removing thumbnail cacheSize: \(totalSize) \(mediaUid)")
                }
            case .backgroundRequest(let media):
                cache[media.uid] = nil
                cacheLru.remove(node)
                ULog.d(.coreMediaTag, "removing background thumbnail request cacheSize: \(totalSize) \(media.uid)")
            default:
                break
            }
            return totalSize > maxSize
        }
    }
}
