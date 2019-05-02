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

class HttpMediaStoreDelegate: NSObject, MediaStoreDelegate {

    private let deviceController: DeviceController
    private var mediaRestApi: MediaRestApi?
    private var mediaWsApi: MediaWsApi?

    var mediaStore: MediaStoreCore!

    init(deviceController: DeviceController) {
        self.deviceController = deviceController
    }

    func configure() {
        if let droneServer = deviceController.droneServer {
            mediaRestApi = MediaRestApi(server: droneServer)
        }
    }

    func reset() {
        mediaRestApi = nil
    }

    func startWatchingContentChanges() {
        if let droneServer = deviceController.droneServer {
            mediaWsApi = MediaWsApi(server: droneServer) { [unowned self] in
                self.mediaStore?.markContentChanged().notifyUpdated()
            }
        }
    }

    func stopWatchingContentChanges() {
        mediaWsApi = nil
    }

    func browse(completion: @escaping ([MediaItemCore]) -> Void) -> CancelableCore? {
        return mediaRestApi?.getMediaList { medias in
            completion(medias ?? [])
        }
    }

    func downloadThumbnail(for owner: MediaStoreThumbnailCacheCore.ThumbnailOwner,
                           completion: @escaping (Data?) -> Void) -> CancelableCore? {
        switch owner {
        case .media(let media):
            return mediaRestApi?.fetchThumbnail(media, completion: completion)
        case .resource(_, let resource):
            return mediaRestApi?.fetchThumbnail(resource, completion: completion)
        }
    }

    func downloadThumbnail(media: MediaItemCore, completion: @escaping (Data?) -> Void) -> CancelableCore? {
        return mediaRestApi?.fetchThumbnail(media, completion: completion)
    }

    func download(resource: MediaItemResourceCore, destDirectoryPath: String,
                  progress: @escaping (_ progressValue: Int) -> Void,
                  completion: @escaping (_ fileUrl: URL?) -> Void) -> CancelableCore? {

        return mediaRestApi?.download(
            resource: resource, destDirectoryPath: destDirectoryPath,
            progress: progress, completion: completion)
    }

    func delete(media: MediaItemCore, completion: @escaping (Bool) -> Void) -> CancelableCore? {
        return mediaRestApi?.deleteMedia(media, completion: completion)
    }

    func delete(resource: MediaItemResourceCore, completion: @escaping (_ success: Bool) -> Void) -> CancelableCore? {
        return mediaRestApi?.deleteResource(resource, completion: completion)
    }

    func deleteAll(completion: @escaping (Bool) -> Void) -> CancelableCore? {
        return mediaRestApi?.deleteAllMedias(completion: completion)
    }

    func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureMediastoreUid {
            ArsdkFeatureMediastore.decode(command, callback: self)
        }
    }
}

extension HttpMediaStoreDelegate: ArsdkFeatureMediastoreCallback {
    func onState(state: ArsdkFeatureMediastoreState) {
        guard let indexingState = MediaStoreIndexingState(fromArsdk: state) else {
            // don't change anything if value is unknown
            ULog.w(.mediaTag, "Unknown indexing state, skipping this event.")
            return
        }

        mediaStore.update(indexingState: indexingState).notifyUpdated()
    }

    func onCounters(videoMediaCount: Int, photoMediaCount: Int, videoResourceCount: Int, photoResourceCount: Int) {
        mediaStore.update(photoMediaCount: photoMediaCount).update(videoMediaCount: videoMediaCount)
            .update(photoResourceCount: photoResourceCount).update(videoResourceCount: videoResourceCount)
            .notifyUpdated()
    }
}

extension MediaStoreIndexingState: ArsdkMappableEnum {

    static let arsdkMapper = Mapper<MediaStoreIndexingState, ArsdkFeatureMediastoreState>([
        .unavailable: .notAvailable,
        .indexing: .indexing,
        .indexed: .indexed])
}
