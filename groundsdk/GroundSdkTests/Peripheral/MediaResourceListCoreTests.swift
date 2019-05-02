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
import CoreLocation

@testable import GroundSdk

class MediaResourceListCoreTests: XCTestCase {

    private var medias: [MediaItemCore]!

    var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 20.5, longitude: 2.6), altitude: 100,
                              horizontalAccuracy: -1, verticalAccuracy: -1, timestamp: Date())

    override func setUp() {
        super.setUp()
        medias = [
            MediaItemCore(
                uid: "1", name: "media1", type: .photo, runUid: "r1",
                creationDate: dateFormatter.date(from: "2016-01-02")!, expectedCount: nil, photoMode: .single,
                panoramaType: nil, resources: [MediaItemResourceCore(uid: "1-1", format: .jpg, size: 20, location: nil,
                                                                     creationDate: Date()),
                        MediaItemResourceCore(uid: "1-2", format: .dng, size: 100, location: nil, creationDate: Date()
                    )], backendData: "A"),
            MediaItemCore(
                uid: "2", name: "media2", type: .video, runUid: "r2",
                creationDate: dateFormatter.date(from: "2016-03-04")!, expectedCount: nil, photoMode: nil,
                panoramaType: nil, streamUrl: "replay/media2",
                resources: [MediaItemResourceCore(uid: "2-1", format: .mp4, size: 1000, streamUrl: "replay/res2-1",
                            location: nil, creationDate: Date())],
                backendData: "B"),
            MediaItemCore(
                uid: "3", name: "media3", type: .photo, runUid: "r2",
                creationDate: dateFormatter.date(from: "2003-03-03")!, expectedCount: nil, photoMode: .burst,
                panoramaType: nil, resources: [MediaItemResourceCore(uid: "3-1", format: .jpg, size: 30,
                                                                     location: nil, creationDate: Date())],
                backendData: "C"),
            MediaItemCore(
                uid: "4", name: "media4", type: .photo, runUid: "r2",
                creationDate: dateFormatter.date(from: "2004-04-04")!, expectedCount: nil, photoMode: .bracketing,
                panoramaType: nil, resources: [MediaItemResourceCore(uid: "4-1", format: .dng, size: 200,
                                                                     location: nil, creationDate: Date())],
                backendData: "D"),
            MediaItemCore(
                uid: "5", name: "media5", type: .photo, runUid: "r2",
                creationDate: dateFormatter.date(from: "2004-04-04")!, expectedCount: 1, photoMode: .panorama,
                panoramaType: .spherical,
                resources: [MediaItemResourceCore(uid: "5-1", format: .dng, size: 200, location: location,
                                                  creationDate: dateFormatter.date(from: "2004-04-04")!)],
                backendData: "E"),
            MediaItemCore(
                uid: "6", name: "media6", type: .video, runUid: "r2",
                creationDate: dateFormatter.date(from: "2016-03-04")!, expectedCount: nil, photoMode: nil,
                panoramaType: nil, streamUrl: "replay/media6",
                resources: [MediaItemResourceCore(uid: "6-1", format: .mp4,
                                                  size: 1000, duration: nil, streamUrl: "replay/res6-1",
                                                  backendData: nil, location: nil,
                                                  creationDate: dateFormatter.date(from: "2016-03-04")!,
                                                  metadataTypes: Set([.thermal]))],
                backendData: "F")
        ]
    }

    func testListWithAll() {
        let mediaResources = MediaResourceListFactory.listWith(allOf: medias) as? MediaResourceListCore
        assertThat(mediaResources?.mediaResourceList, presentAnd(hasCount(6)))
        assertThat(mediaResources?.mediaResourceList[0].resources, presentAnd(hasCount(2)))
        assertThat(mediaResources?.mediaResourceList[1].resources, presentAnd(hasCount(1)))
        assertThat(mediaResources?.mediaResourceList[2].resources, presentAnd(hasCount(1)))
        assertThat(mediaResources?.mediaResourceList[3].resources, presentAnd(hasCount(1)))
        assertThat(mediaResources?.mediaResourceList[4].resources, presentAnd(hasCount(1)))
        assertThat(mediaResources?.mediaResourceList[5].resources, presentAnd(hasCount(1)))
    }

    func testListWithAllButDng() {
        let mediaResources = MediaResourceListFactory.listWith(allButDngOf: medias) as? MediaResourceListCore
        assertThat(mediaResources?.mediaResourceList, presentAnd(hasCount(4)))
        assertThat(mediaResources?.mediaResourceList[0].resources, presentAnd(hasCount(1)))
        assertThat(mediaResources?.mediaResourceList[1].resources, presentAnd(hasCount(1)))
        assertThat(mediaResources?.mediaResourceList[2].resources, presentAnd(hasCount(1)))
        assertThat(mediaResources?.mediaResourceList[3].resources, presentAnd(hasCount(1)))
    }

    func testIterator() {
        let mediaResources = MediaResourceListFactory.listWith(allOf: medias) as? MediaResourceListCore
        let iterator = mediaResources!.makeIterator()

        var mediaResource = iterator.next()
        assertThat(mediaResource, present())
        if let (media, resource) = mediaResource {
            assertThat(media, has(uid: "1"))
            assertThat(media, has(photoMode: .single))
            assertThat(media, has(panoramaType: nil))
            assertThat(media.expectedCount, nilValue())

            assertThat(media.streamUrl, nilValue())
            assertThat(resource, allOf(has(format: .jpg), has(size: 20)))
            assertThat(resource.getAvailableTracks(), nilValue())
        }

        mediaResource = iterator.next()
        assertThat(mediaResource, present())
        if let (media, resource) = mediaResource {
            assertThat(media, has(uid: "1"))
            assertThat(media, has(photoMode: .single))
            assertThat(media, has(panoramaType: nil))
            assertThat(media.expectedCount, nilValue())
            assertThat(media.streamUrl, nilValue())
            assertThat(resource, allOf(has(format: .dng), has(size: 100)))
            assertThat(resource.getAvailableTracks(), nilValue())
        }

        mediaResource = iterator.next()
        assertThat(mediaResource, present())
        if let (media, resource) = mediaResource {
            assertThat(media, has(uid: "2"))
            assertThat(media, has(photoMode: nil))
            assertThat(media, has(panoramaType: nil))
            assertThat(media.expectedCount, nilValue())
            assertThat(resource, allOf(has(format: .mp4), has(size: 1000)))
            assertThat(resource.getAvailableTracks(), present())
            assertThat(resource.getAvailableTracks()?.contains(.defaultVideo), `is`(true))
            assertThat(resource.getAvailableTracks()?.contains(.thermalUnblended), `is`(false))
        }

        mediaResource = iterator.next()
        assertThat(mediaResource, present())
        if let (media, resource) = mediaResource {
            assertThat(media, has(uid: "3"))
            assertThat(media, has(photoMode: .burst))
            assertThat(media, has(panoramaType: nil))
            assertThat(media.expectedCount, nilValue())
            assertThat(resource, allOf(has(format: .jpg), has(size: 30)))
            assertThat(resource.getAvailableTracks(), nilValue())
        }

        mediaResource = iterator.next()
        assertThat(mediaResource, present())
        if let (media, resource) = mediaResource {
            assertThat(media, has(uid: "4"))
            assertThat(media, has(photoMode: .bracketing))
            assertThat(media, has(panoramaType: nil))
            assertThat(media.expectedCount, nilValue())
            assertThat(resource, allOf(has(format: .dng), has(size: 200)))
            assertThat(resource.getAvailableTracks(), nilValue())
        }

        mediaResource = iterator.next()
        assertThat(mediaResource, present())
        if let (media, resource) = mediaResource {
            assertThat(media, has(uid: "5"))
            assertThat(media, has(photoMode: .panorama))
            assertThat(media, has(panoramaType: .spherical))
            assertThat(media.expectedCount, `is`(1))
            assertThat(resource, allOf(has(format: .dng), has(size: 200), has(location: location),
                                       has(creationDate: dateFormatter.date(from: "2004-04-04")!)))
            assertThat(resource.getAvailableTracks(), nilValue())
        }
        mediaResource = iterator.next()
        assertThat(mediaResource, present())
        if let (media, resource) = mediaResource {
            assertThat(media, has(uid: "6"))
            assertThat(media, has(photoMode: nil))
            assertThat(media, has(panoramaType: nil))
            assertThat(media.expectedCount, nilValue())
            assertThat(resource, allOf(has(format: .mp4), has(size: 1000)))
            assertThat(resource.getAvailableTracks(), present())
            assertThat(resource.getAvailableTracks()?.contains(.defaultVideo), `is`(true))
            assertThat(resource.getAvailableTracks()?.contains(.thermalUnblended), `is`(true))
        }

        mediaResource = iterator.next()

        assertThat(mediaResource, nilValue())
    }
}
