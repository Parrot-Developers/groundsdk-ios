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
import CoreLocation

/// Rest api to get/delete media through an http server.
class MediaRestApi {

    /// Drone server
    private let server: DroneServer

    /// Base address to access the media api
    private let baseApi = "/api/v1/media"

    /// Constructor
    ///
    /// - Parameter server: the drone server from which medias should be accessed
    init(server: DroneServer) {
        self.server = server
    }

    /// Get the list of all medias on the drone
    ///
    /// - Parameters:
    ///   - runId: run id to filter the list with. If nil (default value), list won't be filtered.
    ///   - completion: the completion callback (called on the main thread)
    ///   - mediaList: list of medias on the drone
    /// - Returns: the request
    func getMediaList(
        runId: String? = nil,
        completion: @escaping (_ mediaList: [MediaItemCore]?) -> Void) -> CancelableCore {
        return server.getData(api: "\(baseApi)/medias") { result, data in
            switch result {
            case .success:
                // listing medias is successful
                if let data = data {
                    let decoder = JSONDecoder()
                    // need to override the way date are parsed because default format is iso8601 extended
                    decoder.dateDecodingStrategy = .formatted(.iso8601Base)
                    do {
                        let mediaList = try decoder.decode([Media].self, from: data)
                        // transform the json object media list into a `MediaItemCore` list
                        let medias = mediaList.map { MediaItemCore.from(httpMedia: $0) }.compactMap { $0 }
                        completion(medias)
                    } catch let error {
                        ULog.w(.mediaTag, "Failed to decode data \(String(data: data, encoding: .utf8) ?? ""): " +
                            error.localizedDescription)
                        completion(nil)
                    }
                }
            default:
                completion(nil)
            }
        }
    }

    /// Fetch the thumbnail of a given media.
    ///
    /// - Parameters:
    ///   - media: the media for which the thumbnail should be fetched
    ///   - completion: the completion callback (called on the main thread)
    ///   - data: Data of the thumbnail image. Nil if an error occurred.
    /// - Returns: the request
    func fetchThumbnail(_ media: MediaItemCore, completion: @escaping (_ data: Data?) -> Void) -> CancelableCore? {
        if let httpMedia = media.backendData as? Media, let thumbnailUrlStr = httpMedia.thumbnailUrlStr {
            return fetchThumbnail(at: thumbnailUrlStr, completion: completion)
        }
        return nil
    }

    /// Fetch the thumbnail of a given resource.
    ///
    /// - Parameters:
    ///   - resource: the resource for which the thumbnail should be fetched
    ///   - completion: the completion callback (called on the main thread)
    ///   - data: Data of the thumbnail image. Nil if an error occurred.
    /// - Returns: the request
    func fetchThumbnail(
        _ resource: MediaItemResourceCore, completion: @escaping (_ data: Data?) -> Void) -> CancelableCore? {

        if let httpResource = resource.backendData as? MediaResource,
            let thumbnailUrlStr = httpResource.thumbnailUrlStr {

            return fetchThumbnail(at: thumbnailUrlStr, completion: completion)
        }
        return nil
    }

    /// Fetch the thumbnail at a given url
    ///
    /// - Parameters:
    ///   - urlStr: the url as string
    ///   - completion: the completion callback (called on the main thread)
    /// - Returns: the request
    private func fetchThumbnail(at urlStr: String, completion: @escaping (_ data: Data?) -> Void) -> CancelableCore {
        return server.getData(api: urlStr) { result, data in
            switch result {
            case .success:
                completion(data)
            default:
                completion(nil)
            }
        }
    }

    /// Download a resource
    ///
    /// - Parameters:
    ///   - resource: the resource to download
    ///   - destDirectoryPath: the directory path where the resource should be stored
    ///   - progress: progress callback
    ///   - progressValue: the progress value, from 0 to 100.
    ///   - completion: completion callback
    ///   - fileUrl: the url of the file. Nil if an error occurred.
    /// - Returns: the request
    func download(
        resource: MediaItemResourceCore, destDirectoryPath: String,
        progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ fileUrl: URL?) -> Void) -> CancelableCore? {

        if let httpResource = resource.backendData as? MediaResource {
            return server.downloadFile(
                api: httpResource.urlStr,
                destination: URL(fileURLWithPath: destDirectoryPath)
                    .appendingPathComponent(httpResource.resId),
                progress: progress,
                completion: { _, localFileUrl in
                    completion(localFileUrl)
            })
        }
        return nil
    }

    /// Delete a given media on the device
    ///
    /// - Parameters:
    ///   - media: the media to delete
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: whether the delete task was successful or not
    /// - Returns: the request
    func deleteMedia(_ media: MediaItemCore, completion: @escaping (_ success: Bool) -> Void) -> CancelableCore {
        return server.delete(api: "\(baseApi)/medias/\(media.uid)") { result in
            switch result {
            case .success:
                completion(true)
            default:
                completion(false)
            }
        }
    }

    /// Delete a given media resource on the device
    ///
    /// - Parameters:
    ///   - resource: the resource to delete
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: whether the delete task was successful or not
    /// - Returns: the request
   func deleteResource(_ resource: MediaItemResourceCore, completion: @escaping (_ success: Bool) -> Void)
        -> CancelableCore? {
            if let httpResource = resource.backendData as? MediaResource {
                return server.delete(api: "\(baseApi)/resources/\(httpResource.resId)") { result in
                    switch result {
                    case .success:
                        completion(true)
                    default:
                        completion(false)
                    }
                }
            } else {
                return nil
            }
    }

    /// Delete all medias on the device
    ///
    /// - Parameters:
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: whether the delete task was successful or not
    /// - Returns: the request
    func deleteAllMedias(completion: @escaping (_ success: Bool) -> Void) -> CancelableCore {
        return server.delete(api: "\(baseApi)/medias") { result in
            switch result {
            case .success:
                completion(true)
            default:
                completion(false)
            }
        }
    }

    /// An object representing the media as the REST api describes it.
    /// This object has all the field of the json object given by the REST api.
    fileprivate struct Media: Decodable {
        enum CodingKeys: String, CodingKey {
            case mediaId = "media_id"
            case type
            case date = "datetime"
            case size
            case duration
            case runId = "run_id"
            case thumbnailUrlStr = "thumbnail"
            case streamUrlStr = "replay_url"
            case location = "gps"
            case photoMode = "photo_mode"
            case panoramaType = "panorama_type"
            case resources
            case expectedCount = "expected_count"
            case thermal
        }

        /// Media id
        let mediaId: String
        /// Media type
        let type: MediaType
        /// Media date
        let date: Date
        /// Media size in bytes
        let size: Int64
        /// Media duration in ms
        let duration: Int64?
        /// Run id
        let runId: String
        /// Thumbnail url as string
        let thumbnailUrlStr: String?
        /// Stream url as string
        let streamUrlStr: String?
        /// Media location
        let location: Location?
        /// Photo Mode
        let photoMode: PhotoMode?
        /// Panorama type
        let panoramaType: PanoramaType?
        /// Resources of the media
        let resources: [MediaResource]
        /// Expected number of resources in the media
        let expectedCount: UInt64?
        /// `true` when the media contains thermal metadata, `false` otherwise
        let thermal: Bool?
    }

    /// MediaTypes as described by the REST api.
    fileprivate enum MediaType: String, Decodable {
        case photo = "PHOTO"
        case video = "VIDEO"
    }

    /// Media resource as described by the REST api.
    fileprivate struct MediaResource: Decodable {
        enum CodingKeys: String, CodingKey {
            case resId = "resource_id"
            case type
            case format
            case date = "datetime"
            case size
            case duration
            case urlStr = "url"
            case thumbnailUrlStr = "thumbnail"
            case streamUrlStr = "replay_url"
            case location = "gps"
            case width
            case height
            case thermal
        }

        /// Resource id
        let resId: String
        /// Type
        let type: ResourceType
        /// Format
        let format: ResourceFormat
        /// Resource date
        let date: Date
        /// Size in bytes
        let size: UInt64
        /// Resource duration in ms (for video)
        let duration: UInt64?
        /// Url of the resource
        let urlStr: String
        /// Thumbnail url of the resource as string
        let thumbnailUrlStr: String?
        /// Stream url as string
        let streamUrlStr: String?
        /// Location of the resource
        let location: Location?
        /// width of the resource
        let width: Int
        /// height of the resource
        let height: Int
        /// `true` when the ressource contains thermal metadata, `false` otherwise
        let thermal: Bool?
    }

    /// Resource type as described by the REST api
    fileprivate enum ResourceType: String, Decodable {
        case photo = "PHOTO"
        case video = "VIDEO"
    }

    /// Resource format as described by the REST api
    fileprivate enum ResourceFormat: String, Decodable {
        case jpg = "JPG"
        case dng = "DNG"
        case mp4 = "MP4"
    }

    /// Location as described by the REST api
    fileprivate struct Location: Decodable {
        let latitude: Double
        let longitude: Double
        let altitude: Double
    }

    /// Photo mode as described by the REST api
    fileprivate enum PhotoMode: String, Decodable {
        case single = "SINGLE"
        case bracketing = "BRACKETING"
        case burst = "BURST"
        case panorama = "PANORAMA"
        case timeLapse = "TIMELAPSE"
        case gpsLapse = "GPSLAPSE"
    }

    /// Panorama Type as described by the REST api
    fileprivate enum PanoramaType: String, Decodable {
        case horizontal_180 = "HORIZONTAL_180"
        case vertical_180 = "VERTICAL_180"
        case spherical = "SPHERICAL"
    }
}

/// Extension of MediaItemCore that adds creation from http media objects
fileprivate extension MediaItemCore {
    /// Creates a media from an http media
    ///
    /// - Parameter httpMedia: the http media
    /// - Returns: a media if the http media is compatible with the MediaItem declaration
    static func from(httpMedia: MediaRestApi.Media) -> MediaItemCore? {
        if let type = typeMapper.map(from: httpMedia.type) {
            var resources: [Resource] = []
            httpMedia.resources.forEach {
                if let resource = MediaItemResourceCore.from(httpResource: $0) {
                    resources.append(resource)
                }
            }
            let photoMode = httpMedia.photoMode != nil ? photoModeMapper.map(from: httpMedia.photoMode!) : nil

            let panoramaType = httpMedia.panoramaType != nil
                                ? panoramaTypeMapper.map(from: httpMedia.panoramaType!) : nil
            let metadataTypes: Set<MetadataType> = httpMedia.thermal == true ? [.thermal] : []
            return MediaItemCore(
                uid: httpMedia.mediaId, name: httpMedia.mediaId, type: type, runUid: httpMedia.runId,
                creationDate: httpMedia.date, expectedCount: httpMedia.expectedCount,
                photoMode: photoMode, panoramaType: panoramaType, streamUrl: httpMedia.streamUrlStr,
                resources: resources, backendData: httpMedia, metadataTypes: metadataTypes)
        }
        return nil
    }

    /// Mapper that maps media type from the REST api to the `MediaItem.MediaType`
    static let typeMapper = Mapper<MediaRestApi.MediaType, MediaItem.MediaType>([
        .photo: .photo,
        .video: .video])

    /// Mapper that maps photo mode from the REST api to the `MediaItem.PhotoMode`
    static let photoModeMapper = Mapper<MediaRestApi.PhotoMode, MediaItem.PhotoMode>([
        .single: .single,
        .bracketing: .bracketing,
        .burst: .burst,
        .panorama: .panorama,
        .timeLapse: .timeLapse,
        .gpsLapse: .gpsLapse])

    /// Mapper that maps panorama type from the REST api to the `MediaItem.PanoramaType`
    static let panoramaTypeMapper = Mapper<MediaRestApi.PanoramaType, MediaItem.PanoramaType>([
        .horizontal_180: .horizontal_180,
        .vertical_180: .vertical_180,
        .spherical: .spherical])
}

/// Extension of MediaItemResourceCore that adds creation from http resource objects
fileprivate extension MediaItemResourceCore {
    /// Creates a resource from an http resource
    ///
    /// - Parameter httpResource: the http resource
    /// - Returns: a resource if the http resource is compatible with the MediaItemResource declaration
    static func from(httpResource: MediaRestApi.MediaResource) -> MediaItemResourceCore? {
        if let format = formatMapper.map(from: httpResource.format) {
            let duration = httpResource.duration.flatMap {Double($0)/1000}
            var location: CLLocation?
            if httpResource.location != nil {
                let location2D = CLLocationCoordinate2DMake(httpResource.location!.latitude,
                                                            httpResource.location!.longitude)
                if CLLocationCoordinate2DIsValid(location2D) {
                    location = CLLocation(coordinate: location2D, altitude: httpResource.location!.altitude,
                                          horizontalAccuracy: -1,
                                          verticalAccuracy: -1, timestamp: httpResource.date)
                }
            }
            let metadataTypes: Set<MediaItem.MetadataType> = httpResource.thermal == true ? [.thermal] : []
            return MediaItemResourceCore(
                uid: httpResource.resId, format: format, size: httpResource.size, duration: duration,
                streamUrl: httpResource.streamUrlStr, backendData: httpResource, location: location,
                creationDate: httpResource.date, metadataTypes: metadataTypes)
        }
        return nil
    }

    /// Mapper that maps resource format from the REST api to the `MediaItem.Format`
    static let formatMapper = Mapper<MediaRestApi.ResourceFormat, MediaItem.Format>([
        .jpg: .jpg,
        .dng: .dng,
        .mp4: .mp4])
}
