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

class MediaStoreThumbnailCacheTests: XCTestCase {

    private let testImg = UIImage(named: "testImg", in: Bundle(for: MediaStoreTests.self), compatibleWith: nil)!
    private var testImgData: Data!
    private var backend: Backend!
    private var cache: MediaStoreThumbnailCacheCore!
    private var medias: [MediaItemCore]!

    var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    override func setUp() {
        super.setUp()
        testImgData = testImg.pngData()
        medias = [
            MediaItemCore(
                uid: "1", name: "media1", type: .photo, runUid: "r1",
                creationDate: dateFormatter.date(from: "2016-01-02")!, expectedCount: nil, photoMode: .single,
                panoramaType: nil, resources: [MediaItemResourceCore(uid: "1-1", format: .jpg, size: 20, streamUrl: nil,
                                                                     location: nil, creationDate: Date()),
                            MediaItemResourceCore(uid: "1-1", format: .dng, size: 100, streamUrl: nil, location: nil,
                                                  creationDate: Date())],
                backendData: "A"),
            MediaItemCore(
                uid: "2", name: "media2", type: .video, runUid: "r2",
                creationDate: dateFormatter.date(from: "2016-03-04")!, expectedCount: nil, photoMode: nil,
                panoramaType: nil, resources: [MediaItemResourceCore(uid: "2-1", format: .mp4, size: 1000,
                                                                     location: nil, creationDate: Date())],
                backendData: "B"),
            MediaItemCore(
                uid: "3", name: "media3", type: .photo, runUid: "r2",
                creationDate: dateFormatter.date(from: "2003-03-03")!, expectedCount: nil, photoMode: .bracketing,
                panoramaType: nil, resources: [MediaItemResourceCore(uid: "3-1", format: .jpg, size: 30,
                                                                     location: nil, creationDate: Date())],
                backendData: "C"),
            MediaItemCore(
                uid: "4", name: "media4", type: .photo, runUid: "r2",
                creationDate: dateFormatter.date(from: "2004-04-04")!, expectedCount: nil, photoMode: .burst,
                panoramaType: nil, resources: [MediaItemResourceCore(uid: "4-1", format: .dng, size: 200,
                                                                     location: nil, creationDate: Date())],
                backendData: "D"),
            MediaItemCore(
                uid: "5", name: "media5", type: .photo, runUid: "r2",
                creationDate: dateFormatter.date(from: "2004-04-04")!, expectedCount: 1, photoMode: .panorama,
                panoramaType: .spherical, resources: [MediaItemResourceCore(uid: "5-1", format: .dng, size: 200,
                                                                            location: nil, creationDate: Date())],
                backendData: "E")
        ]
        backend = Backend()
        cache = MediaStoreThumbnailCacheCore(mediaStoreBackend: backend, size: 3 * testImgData.count)
    }

    func testBasicGet() {
        var image1: UIImage?
        let req1 = cache.getThumbnail(for: .media(medias[0])) {
            image1 = $0
        }

        assertThat(req1, present())
        // expect a request to load thumbnail
        assertThat(backend.downloadThumbnailCnt, `is`(1))

        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image1, present())
    }

    func testBasicGetWithResource() {
        var image1: UIImage?
        let req1 = cache.getThumbnail(for: .resource(medias[0], medias[0].resources[0] as! MediaItemResourceCore)) {
            image1 = $0
        }

        assertThat(req1, present())
        // expect a request to load thumbnail
        assertThat(backend.downloadThumbnailCnt, `is`(1))

        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image1, present())
    }

    func testBasicGetNotFound() {
        var nilImage = false
        let req1 = cache.getThumbnail(for: .media(medias[0])) {
            nilImage = $0 == nil
        }

        assertThat(req1, present())
        // expect a request to load thumbnail
        assertThat(backend.downloadThumbnailCnt, `is`(1))

        backend.downloadThumbnailCompletion!(nil)
        assertThat(nilImage, `is`(true))
    }

    func testMultipleGet() {
        var image1: UIImage?
        let req1 = cache.getThumbnail(for: .media(medias[0])) { image1 = $0 }
        assertThat(req1, present())
        // expect a request to load thumbnail
        assertThat(backend.downloadThumbnailCnt, `is`(1))

        var image2: UIImage?
        let req2 = cache.getThumbnail(for: .media(medias[0])) { image2 = $0 }
        assertThat(req2, present())
        // should not make a new download request
        assertThat(backend.downloadThumbnailCnt, `is`(1))

        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image1, present())
        assertThat(image2, present())
    }

    func testCancel() {
        var image1: UIImage?
        let req1 = cache.getThumbnail(for: .media(medias[0])) { image1 = $0 }

        assertThat(req1, present())
        // expect a request to load thumbnail
        assertThat(backend.downloadThumbnailCnt, `is`(1))

        // cancel before completion
        req1?.cancel()

        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image1, nilValue())
    }

    func testMultipleGetCancel() {
        var image1: UIImage?
        let req1 = cache.getThumbnail(for: .media(medias[0])) { image1 = $0 }
        assertThat(req1, present())
        // expect a request to load thumbnail
        assertThat(backend.downloadThumbnailCnt, `is`(1))

        var image2: UIImage?
        let req2 = cache.getThumbnail(for: .media(medias[0])) { image2 = $0 }
        assertThat(req2, present())
        // should not make a new download request
        assertThat(backend.downloadThumbnailCnt, `is`(1))

        req1?.cancel()

        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image1, nilValue())
        assertThat(image2, present())
    }

    func testMultipleGetCancelAll() {
        var image1: UIImage?
        let req1 = cache.getThumbnail(for: .media(medias[0])) { image1 = $0 }
        assertThat(req1, present())
        // expect a request to load thumbnail
        assertThat(backend.downloadThumbnailCnt, `is`(1))
        req1?.cancel()

        var image2: UIImage?
        let req2 = cache.getThumbnail(for: .media(medias[0])) { image2 = $0 }
        assertThat(req2, present())
        // should not make a new download request
        assertThat(backend.downloadThumbnailCnt, `is`(1))
        req2?.cancel()

        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image1, nilValue())
        assertThat(image2, nilValue())
    }

    func testGetCached() {
        var image1: UIImage?
        let req1 = cache.getThumbnail(for: .media(medias[0])) { image1 = $0 }

        assertThat(req1, present())
        // expect a request to load thumbnail
        assertThat(backend.downloadThumbnailCnt, `is`(1))
        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image1, present())

        // 2nd request same image
        var image2: UIImage?
        let req2 = cache.getThumbnail(for: .media(medias[0])) { image2 = $0 }
        // should not make a new download request
        assertThat(backend.downloadThumbnailCnt, `is`(1))
        assertThat(req2, nilValue())
        assertThat(image2, present())
    }

    func testMultipleDownload() {
        var image1: UIImage?
        let req1 = cache.getThumbnail(for: .media(medias[0])) { image1 = $0 }
        assertThat(req1, present())
        var image2: UIImage?
        let req2 = cache.getThumbnail(for: .media(medias[1])) { image2 = $0 }
        assertThat(req2, present())
        var image3: UIImage?
        let req3 = cache.getThumbnail(for: .media(medias[2])) { image3 = $0 }
        assertThat(req3, present())

        var image4: UIImage?
        let req4 = cache.getThumbnail(for: .media(medias[3])) { image4 = $0 }
        assertThat(req4, present())

        assertThat(backend.downloadThumbnailCnt, `is`(1))
        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image1, present())

        assertThat(backend.downloadThumbnailCnt, `is`(2))
        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image2, present())

        assertThat(backend.downloadThumbnailCnt, `is`(3))
        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image3, present())

        assertThat(backend.downloadThumbnailCnt, `is`(4))
        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image4, present())

        // req4 should have remove medias[0] thumbnail from the cache
        var image5: UIImage?
        let req5 = cache.getThumbnail(for: .media(medias[0])) { image5 = $0 }
        assertThat(req5, present())
        assertThat(backend.downloadThumbnailCnt, `is`(5))
        backend.downloadThumbnailCompletion!(testImgData)
        assertThat(image5, present())
    }
}

private class Backend: MediaStoreBackend {
    var downloadThumbnailCnt = 0
    var downloadThumbnailCompletion: ((Data?) -> Void)?

    func startWatchingContentChanges() { }

    func stopWatchingContentChanges() { }

    public func browse(completion: @escaping ([MediaItemCore]) -> Void) -> CancelableCore? {
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
        return CancelableTaskCore()
    }

    public func delete(medias: [MediaItemCore], progress: @escaping (MediaDeleter) -> Void) -> CancelableTaskCore? {
        return CancelableTaskCore()
    }

    func delete(mediaResources: MediaResourceListCore, progress: @escaping (MediaDeleter) -> Void)
        -> CancelableTaskCore? {
            return CancelableTaskCore()
    }

    func deleteAll(progress: @escaping (AllMediasDeleter) -> Void) -> CancelableTaskCore? {
        return CancelableTaskCore()
    }
}
