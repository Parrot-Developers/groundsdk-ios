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

import XCTest
@testable import GroundSdk

/// Test MediaStore peripheral
class MediaStoreTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: MediaStoreCore!
    private var backend: Backend!

    var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = MediaStoreCore(
            store: store!, thumbnailCache: MediaStoreThumbnailCacheCore(mediaStoreBackend: backend, size: 0),
            backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.mediaStore), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.mediaStore), nilValue())
    }

    func testIndexingState() {
        impl.publish()
        var cnt = 0
        let mediaStore = store.get(Peripherals.mediaStore)!
        _ = store.register(desc: Peripherals.mediaStore) {
            cnt += 1
        }

        // check initial value
        assertThat(mediaStore.indexingState, `is`(.unavailable))
        assertThat(cnt, `is`(0))

        // mock update
        impl.update(indexingState: .indexed).notifyUpdated()
        assertThat(mediaStore.indexingState, `is`(.indexed))
        assertThat(cnt, `is`(1))

        // mock updating with same value
        impl.update(indexingState: .indexed).notifyUpdated()
        assertThat(mediaStore.indexingState, `is`(.indexed))
        assertThat(cnt, `is`(1))
    }

    func testPhotoVideoCount() {
        impl.publish()
        var cnt = 0
        let mediaStore = store.get(Peripherals.mediaStore)!
        _ = store.register(desc: Peripherals.mediaStore) {
            cnt += 1
        }
        assertThat(cnt, `is`(0))
        assertThat(mediaStore.photoMediaCount, `is`(0))
        assertThat(mediaStore.videoMediaCount, `is`(0))
        assertThat(mediaStore.photoResourceCount, `is`(0))
        assertThat(mediaStore.videoResourceCount, `is`(0))

        impl.update(photoMediaCount: 3).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(mediaStore.photoMediaCount, `is`(3))
        assertThat(mediaStore.videoMediaCount, `is`(0))
        assertThat(mediaStore.photoResourceCount, `is`(0))
        assertThat(mediaStore.videoResourceCount, `is`(0))

        impl.update(photoResourceCount: 4).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(mediaStore.photoMediaCount, `is`(3))
        assertThat(mediaStore.videoMediaCount, `is`(0))
        assertThat(mediaStore.photoResourceCount, `is`(4))
        assertThat(mediaStore.videoResourceCount, `is`(0))

        impl.update(videoResourceCount: 5).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(mediaStore.photoMediaCount, `is`(3))
        assertThat(mediaStore.videoMediaCount, `is`(0))
        assertThat(mediaStore.photoResourceCount, `is`(4))
        assertThat(mediaStore.videoResourceCount, `is`(5))

        impl.update(videoMediaCount: 10).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(mediaStore.photoMediaCount, `is`(3))
        assertThat(mediaStore.videoMediaCount, `is`(10))
        assertThat(mediaStore.photoResourceCount, `is`(4))
        assertThat(mediaStore.videoResourceCount, `is`(5))

        // update with same values
        impl.update(videoMediaCount: 10).update(videoResourceCount: 5).update(photoResourceCount: 4)
            .update(photoMediaCount: 3).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(mediaStore.photoMediaCount, `is`(3))
        assertThat(mediaStore.videoMediaCount, `is`(10))
        assertThat(mediaStore.photoResourceCount, `is`(4))
        assertThat(mediaStore.videoResourceCount, `is`(5))
    }

    func testMediaList() {
        impl.publish()
        var cnt = 0
        var mediaList: [MediaItem]?
        let mediaStore = store.get(Peripherals.mediaStore)!
        _ = store.register(desc: Peripherals.mediaStore) {
        }

        // request
        var request: Ref<[MediaItem]>! = mediaStore.newList { medias in
            mediaList = medias
            cnt += 1
        }
        assertThat(backend.browseCnt, `is`(1))
        assertThat(backend.watchingCnt, `is`(1))
        assertThat(request, present())

        // backend completion
        var backendList = [
            MediaItemCore(
                uid: "1", name: "media1", type: .photo, runUid: "r1",
                creationDate: dateFormatter.date(from: "2016-01-02")!, expectedCount: nil,
                photoMode: .burst, panoramaType: nil,
                resources: [], backendData: "A"),
            MediaItemCore(
                uid: "2", name: "media2", type: .video, runUid: "r2",
                creationDate: dateFormatter.date(from: "2016-03-04")!, expectedCount: nil,
                photoMode: nil, panoramaType: nil,
                streamUrl: "replay/media2", resources: [], backendData: "B")]

        backend.browseCompletion!(backendList)
        assertThat(cnt, `is`(1))
        assertThat(mediaList, presentAnd(hasCount(2)))
        assertThat(mediaList, presentAnd(contains(`is`(backendList[0]), `is`(backendList[1]))))
        // notify content changed
        impl.markContentChanged().notifyUpdated()
        // check list has been reloaded
        assertThat(backend.browseCnt, `is`(2))

        backendList.append(MediaItemCore(
            uid: "3", name: "media3", type: .photo, runUid: "r3",
            creationDate: dateFormatter.date(from: "2016-05-06")!, expectedCount: nil, photoMode: .single,
            panoramaType: nil, resources: [], backendData: "C"))

        backend.browseCompletion!(backendList)
        assertThat(cnt, `is`(2))
        assertThat(mediaList, presentAnd(hasCount(3)))
        assertThat(mediaList, presentAnd(contains(`is`(backendList[0]), `is`(backendList[1]), `is`(backendList[2]))))

        // test cancel
        request = nil
        assertThat(backend.watchingCnt, `is`(0))

        backend.browseCompletion!(backendList)
        // notify content changed, should not trig a browse request
        impl.markContentChanged().notifyUpdated()
        assertThat(backend.browseCnt, `is`(2))
    }

    func testThumbnail() {
        let testImg = UIImage(named: "testImg", in: Bundle(for: MediaStoreTests.self), compatibleWith: nil)!

        impl.publish()
        var image: UIImage?
        let mediaStore = store.get(Peripherals.mediaStore)!
        _ = store.register(desc: Peripherals.mediaStore) {
        }

        let mediaItem = MediaItemCore(
            uid: "1", name: "media1", type: .photo, runUid: "r1",
            creationDate: dateFormatter.date(from: "2016-01-02")!, expectedCount: nil, photoMode: .single,
            panoramaType: nil, resources: [], backendData: "A")
        var request: Ref<UIImage>! = mediaStore.newThumbnailDownloader(media: mediaItem) {
            image = $0
        }
        assertThat(request, present())
        assertThat(backend.downloadThumbnailCnt, `is`(1))

        backend.downloadThumbnailCompletion!(testImg.pngData())
        // just check image is not nil
        assertThat(image, present())

        // check cancel
        image = nil
        request = mediaStore.newThumbnailDownloader(media: mediaItem) {
            image = $0
        }
        assertThat(request, present())
        assertThat(backend.downloadThumbnailCnt, `is`(2))

        request = nil
        backend.downloadThumbnailCompletion!(testImg.pngData())
        assertThat(image, `is`(nilValue()))
    }

    func testDownload() {
        impl.publish()
        var mediaDownloader: MediaDownloader?
        let mediaStore = store.get(Peripherals.mediaStore)!
        _ = store.register(desc: Peripherals.mediaStore) {
        }

        let medias = [
            MediaItemCore(
                uid: "1", name: "media1", type: .photo, runUid: "r1",
                creationDate: dateFormatter.date(from: "2016-01-02")!, expectedCount: nil, photoMode: .single,
                panoramaType: nil, resources: [MediaItemResourceCore(uid: "1-1", format: .jpg, size: 20, location: nil,
                                                                     creationDate: Date()),
                                               MediaItemResourceCore(uid: "1-2", format: .dng, size: 100,
                                                                     location: nil, creationDate: Date())],
                backendData: "A"),
            MediaItemCore(
                uid: "2", name: "media2", type: .video, runUid: "r2",
                creationDate: dateFormatter.date(from: "2016-03-04")!, expectedCount: nil, photoMode: nil,
                panoramaType: nil, streamUrl: "replay/media2",
                resources: [MediaItemResourceCore(uid: "2-1", format: .mp4, size: 1000, location: nil,
                                                  creationDate: Date())],
                backendData: "B")]

        var request: Ref<MediaDownloader>? = mediaStore.newDownloader(
            mediaResources: MediaResourceListFactory.listWith(allOf: medias), destination: .tmp) { downloader in
            mediaDownloader = downloader
        }
        assertThat(request, present())

        assertThat(backend.downloadCnt, `is`(1))
        backend.downloadProgress!(MediaDownloader(
            totalMedia: 2, countMedia: 1, totalResources: 3, countResources: 2,
            currentFileProgress: 75.0, progress: 50.0, status: .running))

        assertThat(mediaDownloader, presentAnd(allOf(
            has(totalMediaCount: 2), has(currentMediaCount: 1),
            has(totalResourceCount: 3), has(currentResourceCount: 2),
            has(currentFileProgress: 75.0), has(totalProgress: 50.0),
            has(status: .running))))

        request = nil
    }

    func testDelete() {
        impl.publish()
        var mediaDeleter: MediaDeleter?
        let mediaStore = store.get(Peripherals.mediaStore)!
        _ = store.register(desc: Peripherals.mediaStore) {
        }

        let medias = [
            MediaItemCore(
                uid: "1", name: "media1", type: .photo, runUid: "r1",
                creationDate: dateFormatter.date(from: "2016-01-02")!, expectedCount: nil,
                photoMode: .single, panoramaType: nil, resources: [], backendData: "A"),
            MediaItemCore(
                uid: "2", name: "media2", type: .video, runUid: "r2",
                creationDate: dateFormatter.date(from: "2016-03-04")!, expectedCount: nil,
                photoMode: nil, panoramaType: nil, streamUrl: "replay/media2", resources: [], backendData: "B")]

        var request: Ref<MediaDeleter>! = mediaStore.newDeleter(medias: medias) { deleter in
            mediaDeleter = deleter
        }
        assertThat(request, present())

        assertThat(backend.deleteCnt, `is`(1))
        // progress
        backend.deleteProgress!(MediaDeleter(totalCount: 2, currentCount: 1, status: .running))
        assertThat(mediaDeleter, presentAnd(allOf(has(currentCount: 1), has(totalCount: 2), has(status: .running))))

        request = nil
    }

    func testDeleteAll() {
        var changeCnt = 0
        impl.publish()
        var mediaDeleter: AllMediasDeleter?
        let mediaStore = store.get(Peripherals.mediaStore)!
        _ = store.register(desc: Peripherals.mediaStore) {
        }

        var request: Ref<AllMediasDeleter>! = mediaStore.newAllMediasDeleter { deleter in
            mediaDeleter = deleter
            changeCnt += 1
        }
        assertThat(request, present())
        assertThat(changeCnt, `is`(0))
        assertThat(backend.allDeleteCnt, `is`(1))

        // progress
        backend.allDeleteProgress!(AllMediasDeleterCore(status: .running))
        assertThat(mediaDeleter?.status, presentAnd(`is`(.running)))
        assertThat(changeCnt, `is`(1))
        assertThat(backend.allDeleteCnt, `is`(1))

        backend.allDeleteProgress!(AllMediasDeleterCore(status: .complete))
        assertThat(mediaDeleter?.status, presentAnd(`is`(.complete)))
        assertThat(changeCnt, `is`(2))
        assertThat(backend.allDeleteCnt, `is`(1))

        request = nil
    }
}

private class Backend: MediaStoreBackend {
    var watchingCnt = 0

    var browseCnt = 0
    var browseCompletion: (([MediaItemCore]) -> Void)?

    var downloadThumbnailCnt = 0
    var downloadThumbnailCompletion: ((Data?) -> Void)?

    var downloadCnt = 0
    var downloadProgress: ((MediaDownloader) -> Void)?

    var deleteCnt = 0
    var deleteProgress: ((MediaDeleter) -> Void)?

    var allDeleteCnt = 0
    var allDeleteProgress: ((AllMediasDeleter) -> Void)?

    func startWatchingContentChanges() {
        watchingCnt += 1
    }

    func stopWatchingContentChanges() {
        watchingCnt -= 1
    }

    public func browse(completion: @escaping ([MediaItemCore]) -> Void) -> CancelableCore? {
        browseCnt += 1
        browseCompletion = completion
        return CancelableTaskCore()
    }

    func downloadThumbnail(for owner: MediaStoreThumbnailCacheCore.ThumbnailOwner,
                           completion: @escaping (Data?) -> Void) -> CancelableCore? {
        downloadThumbnailCnt += 1
        downloadThumbnailCompletion = completion
        return CancelableTaskCore()
    }

    public func download(mediaResources: MediaResourceListCore, destination: DownloadDestination,
                         progress: @escaping (MediaDownloader) -> Void) -> CancelableTaskCore? {
        downloadCnt += 1
        downloadProgress = progress
        return CancelableTaskCore()
    }

    public func delete(medias: [MediaItemCore], progress: @escaping (MediaDeleter) -> Void) -> CancelableTaskCore? {
        deleteCnt += 1
        deleteProgress = progress
        return CancelableTaskCore()
    }

    func delete(mediaResources: MediaResourceListCore, progress: @escaping (MediaDeleter) -> Void)
        -> CancelableTaskCore? {
            deleteCnt += 1
            deleteProgress = progress
           return CancelableTaskCore()
    }

    func deleteAll(progress: @escaping (AllMediasDeleter) -> Void) -> CancelableTaskCore? {
        allDeleteCnt += 1
        allDeleteProgress = progress
        return CancelableTaskCore()
    }
}
