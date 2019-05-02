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
import XCTest

@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting
import Photos

class ArsdkMediaStoreHttpTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var mediaStore: MediaStore?
    var mediaStoreRef: Ref<MediaStore>?
    var storeChangeCnt = 0
    var changeCnt = 0
    var changeDownloadedCnt = 0
    var transiantStateTester: (() -> Void)?

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice(
            "123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        mediaStoreRef = drone.getPeripheral(Peripherals.mediaStore) { [unowned self] mediaStore in
            self.mediaStore = mediaStore
            self.storeChangeCnt += 1
        }
        storeChangeCnt = 0
        changeCnt = 0
        changeDownloadedCnt = 0
    }

    override func tearDown() {
        assertThat(httpSession.tasks, empty())
        super.tearDown()
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(mediaStore, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(mediaStore, `is`(present()))
        assertThat(storeChangeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(mediaStore, `is`(nilValue()))
        assertThat(storeChangeCnt, `is`(2))
    }

    func testIndexingState() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(mediaStore!.indexingState, `is`(.unavailable))
        assertThat(storeChangeCnt, `is`(1))

        // Mock reception of indexing state indexing
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mediastoreStateEncoder(state: .indexing))
        assertThat(mediaStore!.indexingState, `is`(.indexing))
        assertThat(storeChangeCnt, `is`(2))

        // Mock reception of indexing state indexed
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mediastoreStateEncoder(state: .indexed))
        assertThat(mediaStore!.indexingState, `is`(.indexed))
        assertThat(storeChangeCnt, `is`(3))

        // Mock reception of indexing state unavailable
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.mediastoreStateEncoder(state: .notAvailable))
        assertThat(mediaStore!.indexingState, `is`(.unavailable))
        assertThat(storeChangeCnt, `is`(4))
    }

    func testPhotoVideoCount() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(mediaStore!.photoMediaCount, `is`(0))
        assertThat(mediaStore!.videoMediaCount, `is`(0))
        assertThat(mediaStore!.photoResourceCount, `is`(0))
        assertThat(mediaStore!.videoResourceCount, `is`(0))
        assertThat(storeChangeCnt, `is`(1))

        // Mock reception of media storage counts
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.mediastoreCountersEncoder(
                videoMediaCount: 1, photoMediaCount: 2, videoResourceCount: 3, photoResourceCount: 4))

        assertThat(mediaStore!.videoMediaCount, `is`(1))
        assertThat(mediaStore!.photoMediaCount, `is`(2))
        assertThat(mediaStore!.videoResourceCount, `is`(3))
        assertThat(mediaStore!.photoResourceCount, `is`(4))
        assertThat(storeChangeCnt, `is`(2))
    }

    func testBrowse() {
        connect(drone: drone, handle: 1)

        var mediaList: [MediaItem]?
        let mediaListRef = mediaStore!.newList { list in
            self.changeCnt += 1
            mediaList = list
        }

        var task = httpSession.popLastTask() as? MockDataTask

        assertThat(changeCnt, `is`(0))
        assertThat(mediaList, nilValue())
        assertThat(mediaListRef.value, nilValue())
        assertThat(task, present())

        // mock answer from low-level
        task?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))

        assertThat(changeCnt, `is`(1))
        assertThat(mediaList, presentAnd(hasCount(2)))

        // check media items (verify converted enum types)
        let media1 = mediaList![0]
        assertThat(media1.name, `is`("media1"))
        assertThat(media1.type, `is`(.video))
        assertThat(media1.photoMode, nilValue())
        assertThat(media1.resources, containsInAnyOrder(
            allOf(has(format: .jpg), has(size: 1073741824), has(duration: nil)),
            allOf(has(format: .mp4), has(size: 4294967296), has(duration: 12))))

        let media2 = mediaList![1]
        assertThat(media2.name, `is`("media2"))
        assertThat(media2.type, `is`(.photo))
        assertThat(media2.photoMode, `is`(.single))
        assertThat(media2.resources, contains(allOf(has(format: .dng), has(size: 858993472))))

        // test list is reloaded on websocket update notification
        webSocket.sessions["/api/v1/media/notifications"]?.webSocketSessionDidReceiveMessage(
            mediaAddedEvent.data(using: .utf8)!
        )

        // check list has been reloaded
        task = httpSession.popLastTask() as? MockDataTask
        assertThat(task, present())
        task?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))
        assertThat(changeCnt, `is`(2))
    }

    func testBrowseThermal() {
        connect(drone: drone, handle: 1)

        var mediaList: [MediaItem]?
        let mediaListRef = mediaStore!.newList { list in
            self.changeCnt += 1
            mediaList = list
        }

        var task = httpSession.popLastTask() as? MockDataTask

        assertThat(changeCnt, `is`(0))
        assertThat(mediaList, nilValue())
        assertThat(mediaListRef.value, nilValue())
        assertThat(task, present())

        // mock answer from low-level
        task?.mockCompletionSuccess(data: browseResponseThermal.data(using: .utf8))

        assertThat(changeCnt, `is`(1))
        assertThat(mediaList, presentAnd(hasCount(2)))

        // check media items (verify converted enum types)
        // This first media is .thermal
        let media1 = mediaList![0]
        assertThat(media1.name, `is`("media1"))
        assertThat(media1.type, `is`(.video))
        assertThat(media1, has(metadataType: .thermal))
        assertThat(media1.photoMode, nilValue())
        assertThat(media1.resources, containsInAnyOrder(
            allOf(has(format: .mp4), has(metadataType: .thermal))))

        // This second media is not .thermal
        let metadataEmptySet = Set<MediaItem.MetadataType>()
        let media2 = mediaList![1]
        assertThat(media2.name, `is`("media2"))
        assertThat(media2.type, `is`(.video))
        assertThat(media2.metadataTypes, `is`(metadataEmptySet))
        assertThat(media2.resources, containsInAnyOrder(
            allOf(has(format: .mp4), hasEmptyMetadataType())))

        // test list is reloaded on websocket update notification
        webSocket.sessions["/api/v1/media/notifications"]?.webSocketSessionDidReceiveMessage(
            mediaAddedEvent.data(using: .utf8)!
        )

        // check list has been reloaded
        task = httpSession.popLastTask() as? MockDataTask
        assertThat(task, present())
        task?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))
        assertThat(changeCnt, `is`(2))
    }

    func testBrowseError() {
        connect(drone: drone, handle: 1)

        var mediaList: [MediaItem]?
        let mediaListRef = mediaStore!.newList { list in
            self.changeCnt += 1
            mediaList = list
        }

        let task = httpSession.popLastTask() as? MockDataTask

        assertThat(changeCnt, `is`(0))
        assertThat(mediaList, nilValue())
        assertThat(mediaListRef.value, nilValue())
        assertThat(task, present())

        // mock answer from low-level
        task?.mockCompletionFail(statusCode: 404)

        assertThat(changeCnt, `is`(1))
        assertThat(mediaListRef.value, presentAnd(empty()))
    }

    func testDownloadMediaThumbnail() {
        var thumbnailImg: UIImage?
        let testImg = UIImage(named: "testImg", in: Bundle(for: ArsdkMediaStoreHttpTests.self), compatibleWith: nil)!
        let jpgRepresentation = testImg.jpegData(compressionQuality: 1.0)

        connect(drone: drone, handle: 1)

        // populate list
        let mediaListRef: Ref<[MediaItem]>! = mediaStore!.newList { _ in }
        let browseTask = httpSession.popLastTask() as? MockDataTask
        browseTask?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))

        let downloadThumbnailRef = mediaStore!.newThumbnailDownloader(media: mediaListRef.value![0]) { thumbnail in
            self.changeCnt += 1
            thumbnailImg = thumbnail
        }
        let fetchThumbnailTask = httpSession.popLastTask() as? MockDataTask

        assertThat(changeCnt, `is`(0))
        assertThat(fetchThumbnailTask, present())
        assertThat(fetchThumbnailTask?.request.url?.absoluteString, presentAnd(hasSuffix("/data/thumb/10000001.JPG")))

        fetchThumbnailTask?.mockCompletionSuccess(data: jpgRepresentation)
        assertThat(changeCnt, `is`(1))
        assertThat(downloadThumbnailRef.value, present())
        assertThat(thumbnailImg, present())
        // TODO: the following tests fail, see why and correct it.
        // Both are trying to test that the thumbnail image matches the expected image.
        /*let expectedImage = UIImage(data: jpgRepresentation)!
         assertThat(thumbnailImg, presentAnd(`is`(expectedImage)))
         assertThat(UIImageJPEGRepresentation(thumbnailImg!, 1.0), presentAnd(`is`(jpgRepresentation)))*/
    }

    func testDownloadMediaThumbnailError() {
        connect(drone: drone, handle: 1)

        // populate list
        let mediaListRef: Ref<[MediaItem]>! = mediaStore!.newList { _ in }
        let browseTask = httpSession.popLastTask() as? MockDataTask
        browseTask?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))

        let downloadThumbnailRef = mediaStore!.newThumbnailDownloader(media: mediaListRef.value![0]) { _ in
            self.changeCnt += 1
        }
        let fetchThumbnailTask = httpSession.popLastTask() as? MockDataTask

        assertThat(changeCnt, `is`(0))
        assertThat(fetchThumbnailTask, present())
        fetchThumbnailTask?.mockCompletionFail(statusCode: 404)

        assertThat(changeCnt, `is`(1))
        assertThat(downloadThumbnailRef.value, nilValue())
    }

    func testDownloadResourceThumbnail() {
        var thumbnailImg: UIImage?
        let testImg = UIImage(named: "testImg", in: Bundle(for: ArsdkMediaStoreHttpTests.self), compatibleWith: nil)!
        let jpgRepresentation = testImg.jpegData(compressionQuality: 1.0)!

        connect(drone: drone, handle: 1)

        // populate list
        let mediaListRef: Ref<[MediaItem]>! = mediaStore!.newList { _ in }
        let browseTask = httpSession.popLastTask() as? MockDataTask
        browseTask?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))

        let resource = mediaListRef.value![0].resources[1]
        let downloadThumbnailRef = mediaStore!.newThumbnailDownloader(resource: resource) { thumbnail in
            self.changeCnt += 1
            thumbnailImg = thumbnail
        }
        let fetchThumbnailTask = httpSession.popLastTask() as? MockDataTask

        assertThat(changeCnt, `is`(0))
        assertThat(fetchThumbnailTask, present())
        assertThat(fetchThumbnailTask?.request.url?.absoluteString, presentAnd(hasSuffix("/data/thumb/10000002.JPG")))

        fetchThumbnailTask?.mockCompletionSuccess(data: jpgRepresentation)
        assertThat(changeCnt, `is`(1))
        assertThat(downloadThumbnailRef.value, present())
        assertThat(thumbnailImg, present())
        // TODO: the following tests fail, see why and correct it.
        // Both are trying to test that the thumbnail image matches the expected image.
        /*let expectedImage = UIImage(data: jpgRepresentation)!
         assertThat(thumbnailImg, presentAnd(`is`(expectedImage)))
         assertThat(UIImageJPEGRepresentation(thumbnailImg!, 1.0), presentAnd(`is`(jpgRepresentation)))*/
    }

    func testDownload() {
        connect(drone: drone, handle: 1)

        // populate list
        let mediaListRef: Ref<[MediaItem]>! = mediaStore!.newList { _ in }
        let browseTask = httpSession.popLastTask() as? MockDataTask
        browseTask?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))

        let resources = MediaResourceListFactory.listWith(allOf: mediaListRef.value!)
        let downloadRef = mediaStore!.newDownloader(mediaResources: resources, destination: .tmp) { downloader in
            if downloader?.status == .fileDownloaded {
                self.changeDownloadedCnt += 1
            }
            self.changeCnt += 1
            if let transiantStateTester = self.transiantStateTester {
                transiantStateTester()
                self.transiantStateTester = nil
            }
        }
        var downloadTask = httpSession.popLastTask() as? MockDownloadTask
        assertThat(changeDownloadedCnt, `is`(0))
        assertThat(changeCnt, `is`(1))
        // expect download of the first resource of the first media
        assertThat(downloadRef.value, presentAnd(allOf(
            has(totalMediaCount: 2), has(currentMediaCount: 1),
            has(totalResourceCount: 3), has(currentResourceCount: 1),
            has(currentFileProgress: 0), has(totalProgress: 0),
            has(fileUrl: nil),
            has(status: .running))))
        assertThat(downloadRef.value!.currentMedia, presentAnd(has(uid: "media1")))

        // 50% progress on the first resource
        downloadTask?.mock(progress: 50)
        assertThat(changeCnt, `is`(2))
        assertThat(downloadRef.value, presentAnd(allOf(
            has(totalMediaCount: 2), has(currentMediaCount: 1),
            has(totalResourceCount: 3), has(currentResourceCount: 1),
            has(currentFileProgress: 0.5), has(totalProgress: (4294967296/2.0)/(4294967296 + 1073741824 + 858993472)),
            has(fileUrl: nil),
            has(status: .running))))
        assertThat(downloadRef.value!.currentMedia, presentAnd(has(uid: "media1")))

        var localFile = URL(string: "file://tmp/file1")
        // mock reception of media completion result, fileDownloaded
        transiantStateTester = {
            assertThat(downloadRef.value, presentAnd(allOf(
                has(totalMediaCount: 2), has(currentMediaCount: 1),
                has(totalResourceCount: 3), has(currentResourceCount: 1),
                has(currentFileProgress: 1.0), has(totalProgress: (4294967296)/(4294967296 + 1073741824 + 858993472)),
                has(fileUrl: localFile),
                has(status: .fileDownloaded))))
            assertThat(self.changeCnt, `is`(3))
            assertThat(downloadRef.value!.currentMedia, presentAnd(has(uid: "media1")))
        }
        // first resource completed
        downloadTask?.mockCompletionSuccess(localFileUrl: localFile)
        assertThat(changeCnt, `is`(4))
        assertThat(downloadRef.value, presentAnd(allOf(
            has(totalMediaCount: 2), has(currentMediaCount: 1),
            has(totalResourceCount: 3), has(currentResourceCount: 2),
            has(currentFileProgress: 0.0), has(totalProgress: (4294967296)/(4294967296 + 1073741824 + 858993472)),
            has(fileUrl: nil),
            has(status: .running))))
        assertThat(changeDownloadedCnt, `is`(1))
        assertThat(downloadRef.value!.currentMedia, presentAnd(has(uid: "media1")))

        downloadTask = httpSession.popLastTask() as? MockDownloadTask
        // 2nd resource completed
        // mock reception of media completion result, fileDownloaded
        transiantStateTester = {
            assertThat(downloadRef.value, presentAnd(allOf(
                has(totalMediaCount: 2), has(currentMediaCount: 1),
                has(totalResourceCount: 3), has(currentResourceCount: 2),
                has(currentFileProgress: 1.0),
                has(totalProgress: (4294967296 + 1073741824)/(4294967296 + 1073741824 + 858993472)),
                has(fileUrl: localFile!),
                has(status: .fileDownloaded))))
            assertThat(self.changeCnt, `is`(5))
            assertThat(downloadRef.value!.currentMedia, presentAnd(has(uid: "media1")))
        }
        localFile = URL(string: "file://tmp/file2")
        downloadTask?.mockCompletionSuccess(localFileUrl: localFile)
        assertThat(downloadRef.value!.currentMedia, presentAnd(has(uid: "media2")))
        assertThat(changeCnt, `is`(6))
        assertThat(downloadRef.value, presentAnd(allOf(
            has(totalMediaCount: 2), has(currentMediaCount: 2),
            has(totalResourceCount: 3), has(currentResourceCount: 3),
            has(currentFileProgress: 0.0),
            has(totalProgress: (4294967296 + 1073741824)/(4294967296 + 1073741824 + 858993472)),
            has(fileUrl: nil),
            has(status: .running))))
        assertThat(changeDownloadedCnt, `is`(2))
        assertThat(downloadRef.value!.currentMedia, presentAnd(has(uid: "media2")))

        localFile = URL(string: "file://tmp/file3")
        downloadTask = httpSession.popLastTask() as? MockDownloadTask
        // last resource completed
        transiantStateTester = {
            assertThat(downloadRef.value, presentAnd(allOf(
                has(totalMediaCount: 2), has(currentMediaCount: 2),
                has(totalResourceCount: 3), has(currentResourceCount: 3),
                has(currentFileProgress: 1.0), has(totalProgress: 1.0),
                has(fileUrl: localFile!),
                has(status: .fileDownloaded))))
            assertThat(self.changeCnt, `is`(7))
            assertThat(downloadRef.value!.currentMedia, presentAnd(has(uid: "media2")))
        }

        downloadTask?.mockCompletionSuccess(localFileUrl: localFile)
        assertThat(changeCnt, `is`(8))
        assertThat(downloadRef.value, presentAnd(allOf(
            has(totalMediaCount: 2), has(currentMediaCount: 2),
            has(totalResourceCount: 3), has(currentResourceCount: 3),
            has(currentFileProgress: 1.0), has(totalProgress: 1.0),
            has(fileUrl: nil),
            has(status: .complete))))
        assertThat(changeDownloadedCnt, `is`(3))
        assertThat(downloadRef.value!.currentMedia, nilValue())
    }

    func testDownloadCancel() {
        connect(drone: drone, handle: 1)

        // populate list
        let mediaListRef: Ref<[MediaItem]>! = mediaStore!.newList { _ in }
        let browseTask = httpSession.popLastTask() as? MockDataTask
        browseTask?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))

        let resources = MediaResourceListFactory.listWith(allOf: mediaListRef.value!)
        var downloadRef: Ref<MediaDownloader>? =
            mediaStore!.newDownloader(mediaResources: resources, destination: .tmp) { _ in
                self.changeCnt += 1
        }
        let downloadTask = httpSession.popLastTask() as? MockDownloadTask

        assertThat(changeCnt, `is`(1))
        // expect download of the first resource of the first media
        assertThat(downloadRef?.value, presentAnd(allOf(
            has(totalMediaCount: 2), has(currentMediaCount: 1),
            has(totalResourceCount: 3), has(currentResourceCount: 1),
            has(currentFileProgress: 0), has(totalProgress: 0),
            has(status: .running))))

        // 50% progress on the first media
        downloadTask?.mock(progress: 50)
        assertThat(changeCnt, `is`(2))
        assertThat(downloadRef?.value, presentAnd(allOf(
            has(totalMediaCount: 2), has(currentMediaCount: 1),
            has(totalResourceCount: 3), has(currentResourceCount: 1),
            has(currentFileProgress: 0.5), has(totalProgress: (4294967296/2.0)/(4294967296 + 1073741824 + 858993472)),
            has(status: .running))))

        // release the download ref, that should cancel the download
        downloadRef = nil

        assertThat(downloadTask!.cancelCalls, `is`(1))
        assertThat(changeCnt, `is`(2))

        downloadTask?.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))

        // the other resources should not be downloaded, this will be tested in the teardown code
    }

    func testDownloadError() {
        connect(drone: drone, handle: 1)

        // populate list
        let mediaListRef: Ref<[MediaItem]>! = mediaStore!.newList { _ in }
        let browseTask = httpSession.popLastTask() as? MockDataTask
        browseTask?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))

        let resources = MediaResourceListFactory.listWith(allOf: mediaListRef.value!)
        let downloadRef = mediaStore!.newDownloader(mediaResources: resources, destination: .tmp) { _ in
            self.changeCnt += 1
        }
        let downloadTask = httpSession.popLastTask() as? MockDownloadTask

        // expect download of the first resource of the first media
        assertThat(changeCnt, `is`(1))
        assertThat(downloadTask, present())
        assertThat(downloadRef.value, presentAnd(allOf(
            has(totalMediaCount: 2), has(currentMediaCount: 1),
            has(totalResourceCount: 3), has(currentResourceCount: 1),
            has(currentFileProgress: 0), has(totalProgress: 0),
            has(status: .running))))

        downloadTask?.mockCompletionFail(statusCode: 404)
        assertThat(changeCnt, `is`(2))
        assertThat(downloadRef.value, presentAnd(allOf(
            has(totalMediaCount: 2), has(currentMediaCount: 1),
            has(totalResourceCount: 3), has(currentResourceCount: 1),
            has(currentFileProgress: 0.0), has(totalProgress: 0.0),
            has(status: .error))))
    }

    func testDeleteMedia() {
        connect(drone: drone, handle: 1)

        // populate list
        let mediaListRef: Ref<[MediaItem]>! = mediaStore!.newList { _ in }
        let browseTask = httpSession.popLastTask() as? MockDataTask
        browseTask?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))

        var deleterRef: Ref<MediaDeleter>! = mediaStore!.newDeleter(medias: mediaListRef.value!) { _ in
            self.changeCnt += 1
        }
        var deleteTask = httpSession.popLastTask() as? MockDataTask

        assertThat(changeCnt, `is`(1))
        assertThat(deleteTask, present())
        assertThat(deleterRef.value, presentAnd(allOf(has(currentCount: 0), has(totalCount: 2), has(status: .running))))

        deleteTask?.mockCompletionSuccess(data: nil)
        assertThat(changeCnt, `is`(2))
        assertThat(deleterRef.value, presentAnd(allOf(has(currentCount: 1), has(totalCount: 2), has(status: .running))))

        deleteTask = httpSession.popLastTask() as? MockDataTask
        assertThat(deleteTask, present())

        deleteTask?.mockCompletionSuccess(data: nil)
        assertThat(changeCnt, `is`(3))
        assertThat(deleterRef.value, presentAnd(allOf(
            has(currentCount: 2), has(totalCount: 2), has(status: .complete))))

        deleterRef = nil
    }

    func testDeleteMediaResources() {
        connect(drone: drone, handle: 1)
        // populate list
        let mediaListRef: Ref<[MediaItem]>! = mediaStore!.newList { _ in }
        let browseTask = httpSession.popLastTask() as? MockDataTask
        browseTask?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))

        let deleteList = MediaResourceListFactory.emptyList()
        // add resource 1 of media 1
        let media1 = mediaListRef.value![0]
        deleteList.add(media: media1, resource: media1.resources[0])
        // add all resources of media 2
        let media2 = mediaListRef.value![1]
        deleteList.add(media: media2)

        var deleterRef: Ref<MediaDeleter>! = mediaStore!.newDeleter(mediaResources: deleteList) { _ in
            self.changeCnt += 1
        }

        // first task is a delete media
        var deleteTask = httpSession.popLastTask() as? MockDataTask
        assertThat(changeCnt, `is`(1))
        assertThat(deleteTask, present())
        let url1 = NSURLComponents(url: deleteTask!.request.url!, resolvingAgainstBaseURL: false)
        assertThat(url1?.path, presentAnd(`is`("/api/v1/media/resources/100000010001.MP4")))
        assertThat(deleterRef.value, presentAnd(allOf(has(currentCount: 0), has(totalCount: 2), has(status: .running))))

        deleteTask?.mockCompletionSuccess(data: nil)
        assertThat(changeCnt, `is`(2))
        assertThat(deleterRef.value, presentAnd(allOf(has(currentCount: 1), has(totalCount: 2), has(status: .running))))

        // 2nd task is a delete resource
        deleteTask = httpSession.popLastTask() as? MockDataTask
        assertThat(deleteTask, present())
        let url2 = NSURLComponents(url: deleteTask!.request.url!, resolvingAgainstBaseURL: false)
        assertThat(url2?.path, presentAnd(`is`("/api/v1/media/medias/media2")))

        deleteTask?.mockCompletionSuccess(data: nil)
        assertThat(changeCnt, `is`(3))
        assertThat(deleterRef.value, presentAnd(allOf(
            has(currentCount: 2), has(totalCount: 2), has(status: .complete))))

        deleterRef = nil
    }

    func testDeleteError() {
        connect(drone: drone, handle: 1)

        // populate list
        let mediaListRef: Ref<[MediaItem]>! = mediaStore!.newList { _ in }
        let browseTask = httpSession.popLastTask() as? MockDataTask
        browseTask?.mockCompletionSuccess(data: browseResponse.data(using: .utf8))

        var deleterRef: Ref<MediaDeleter>! = mediaStore!.newDeleter(medias: mediaListRef.value!) { _ in
            self.changeCnt += 1
        }
        let deleteTask = httpSession.popLastTask() as? MockDataTask

        assertThat(changeCnt, `is`(1))
        assertThat(deleteTask, present())
        assertThat(deleterRef.value, presentAnd(allOf(has(currentCount: 0), has(totalCount: 2), has(status: .running))))

        deleteTask?.mockCompletionFail(statusCode: 404)

        assertThat(changeCnt, `is`(2))
        assertThat(deleterRef.value, presentAnd(allOf(has(currentCount: 1), has(totalCount: 2), has(status: .error))))

        deleterRef = nil
    }

    func testDeleteAll() {
        var deleter: AllMediasDeleter?
        connect(drone: drone, handle: 1)

        var deleterRef: Ref<AllMediasDeleter>! = mediaStore!.newAllMediasDeleter { deleterObj in
            self.changeCnt += 1
            deleter = deleterObj

        }
        let deleteTask = httpSession.popLastTask() as? MockDataTask

        assertThat(changeCnt, `is`(1))
        assertThat(deleterRef, present())
        assertThat(deleteTask, present())
        assertThat(deleter?.status, presentAnd(`is`(.running)))

        deleteTask?.mockCompletionSuccess(data: nil)
        assertThat(changeCnt, `is`(2))
        assertThat(deleter?.status, presentAnd(`is`(.complete)))

        deleterRef = nil
    }

    func testDeleteAllError() {
        var deleter: AllMediasDeleter?
        connect(drone: drone, handle: 1)

        var deleterRef: Ref<AllMediasDeleter>! = mediaStore!.newAllMediasDeleter { deleterObj in
            self.changeCnt += 1
            deleter = deleterObj

        }
        let deleteTask = httpSession.popLastTask() as? MockDataTask

        assertThat(changeCnt, `is`(1))
        assertThat(deleterRef, present())
        assertThat(deleteTask, present())
        assertThat(deleter?.status, presentAnd(`is`(.running)))

        deleteTask?.mockCompletionFail(statusCode: 400)
        assertThat(changeCnt, `is`(2))
        assertThat(deleter?.status, presentAnd(`is`(.error)))

        deleterRef = nil
    }

    /// This json response gives 2 medias.
    /// - a video and has a size of 300 bytes. It has 2 resources:
    ///    - a video resource, of 200 bytes, mp4 format.
    ///    - a photo resource, of 100 bytes, jpg format
    /// - a photo of a 100 bytes. This media only has one resource:
    ///    - a photo resource, of 100 bytes, jpg format
    private let browseResponse = """
    [
        {
            "datetime": "20180616T141516+0100",
            "gps": {
              "altitude": 10.4,
              "latitude": 20.0,
              "longitude": 30.0
            },
            "thermal": false,
            "size": 300,
            "media_id": "media1",
            "thumbnail": "/data/thumb/10000001.JPG",
            "resources": [
              {
                "format": "MP4",
                "height": 720,
                "media_id": "10000001",
                "datetime": "20180616T141516+0100",
                "resource_id": "100000010001.MP4",
                "size": 4294967296,
                "duration": 12000,
                "type": "VIDEO",
                "url": "/data/media/100000010001.MP4",
                "thumbnail": "/data/thumb/10000001.JPG",
                "width": 1024
              },
              {
                "format": "JPG",
                "height": 720,
                "media_id": "10000001",
                "datetime": "20180616T141516+0100",
                "resource_id": "100000010001.JPG",
                "size": 1073741824,
                "type": "PHOTO",
                "url": "/data/media/100000010001.JPG",
                "thumbnail": "/data/thumb/10000002.JPG",
                "width": 1024
              }
            ],
            "run_id": "F9A5BFD1CE90DF37669BF11B01932F55",
            "type": "VIDEO"
          },
          {
            "datetime": "20180118T171351+0200",
            "gps": {
              "altitude": 500,
              "latitude": 500,
              "longitude": 500
            },
            "photo_mode": "SINGLE",
            "size": 100,
            "media_id": "media2",
            "resources": [
              {
                "format": "DNG",
                "height": 0,
                "media_id": "10000019",
                "datetime": "20180118T171351+0200",
                "resource_id": "100000190025.DNG",
                "size": 858993472,
                "type": "PHOTO",
                "url": "/data/media/100000190025.DNG",
                "width": 0
              }
            ],
            "run_id": "00000000000000000000000000000000",
            "type": "PHOTO"
          }
    ]
    """

    /// This json response gives 2 medias.
    /// - a thermal video with a size of 200 bytes. It has 1 resource:
    ///    - a thermal video resource, of 200 bytes, mp4 format.
    /// - a non thermal video with a size of 200 bytes. It has 1 resource:
    ///    - a non thermal video resource, of 200 bytes, mp4 format.
    private let browseResponseThermal = """
    [
        {
            "datetime": "20180616T141516+0100",
            "gps": {
              "altitude": 10.4,
              "latitude": 20.0,
              "longitude": 30.0
            },
            "size": 300,
            "media_id": "media1",
            "thumbnail": "/data/thumb/10000001.JPG",
            "thermal": true,
            "resources": [
              {
                "format": "MP4",
                "height": 720,
                "media_id": "10000001",
                "datetime": "20180616T141516+0100",
                "resource_id": "100000010001.MP4",
                "size": 4294967296,
                "duration": 12000,
                "type": "VIDEO",
                "url": "/data/media/100000010001.MP4",
                "thumbnail": "/data/thumb/10000001.JPG",
                "width": 1024,
                "thermal": true
              }
            ],
            "run_id": "F9A5BFD1CE90DF37669BF11B01932F55",
            "type": "VIDEO"
          },
          {
            "datetime": "20180616T141517+0100",
            "gps": {
              "altitude": 10.4,
              "latitude": 20.0,
              "longitude": 30.0
            },
            "size": 200,
            "media_id": "media2",
            "thumbnail": "/data/thumb/10000002.JPG",
            "thermal": false,
            "resources": [
              {
                "format": "MP4",
                "height": 720,
                "media_id": "10000001",
                "datetime": "20180616T141517+0100",
                "resource_id": "100000010002.MP4",
                "size": 4294967296,
                "duration": 12000,
                "type": "VIDEO",
                "url": "/data/media/100000010002.MP4",
                "thumbnail": "/data/thumb/10000002.JPG",
                "width": 1024
              }
            ],
            "run_id": "F9A5BFD1CE90DF37669BF11B01932F56",
            "type": "VIDEO"
          }
    ]
    """

    private let mediaAddedEvent = """
    {
        "name": "media_created",
        "data": {}
    }
    """
}
