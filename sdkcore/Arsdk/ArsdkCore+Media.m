//    Copyright (C) 2019 Parrot Drones SAS
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

#import "ArsdkCore.h"
#import "ArsdkCore+Internal.h"
#import "ArsdkCore+Media.h"
#import "Logger.h"
#import <arsdkctrl/arsdkctrl.h>

/** common loging tag */
extern ULogTag *TAG;

#pragma mark - ArsdkMedia

/** Wrapper around arsdk_media */
@interface ArsdkMedia : NSObject <ArsdkMedia>
@property (nonatomic) struct arsdk_media * _Nonnull media;
- (instancetype _Nullable)initWithMedia:(struct arsdk_media* _Nonnull)media;
@end

@implementation ArsdkMedia

- (instancetype _Nullable)initWithMedia:(struct arsdk_media* _Nonnull)media {
    self = [super init];
    if (self) {
        _media = media;
        arsdk_media_ref(_media);
    }
    return self;
}

- (void)dealloc {
    arsdk_media_unref(_media);
}

- (ArsdkMediaType) getType {
    return (ArsdkMediaType)arsdk_media_get_type(_media);
}

- (NSString * _Nonnull) getName {
    return [NSString stringWithUTF8String:arsdk_media_get_name(_media)];
}

- (NSString * _Nonnull) getRunUid {
    const char * runId = arsdk_media_get_runid(_media);
    if (runId) {
        return [NSString stringWithUTF8String:runId];
    } else {
        return @"";
    }
}

- (NSDate * _Nonnull) getCreationDate {
    const struct tm *t_info = arsdk_media_get_date(_media);
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:mktime((struct tm*)t_info)];
    return date;
}

- (void)iterateResources:(__attribute__((noescape)) void(^)(NSString *resourceUid, ArsdkMediaResourceFormat format,
                                                            size_t size))block {
    struct arsdk_media_res *res = arsdk_media_next_res(_media, NULL);
    while (res) {
        if (arsdk_media_res_get_type(res) != ARSDK_MEDIA_RES_TYPE_THUMBNAIL) {
            NSString *resourceUid = [NSString stringWithUTF8String:arsdk_media_res_get_name(res)];
            ArsdkMediaResourceFormat format = (ArsdkMediaResourceFormat)arsdk_media_res_get_fmt(res);
            size_t size = arsdk_media_res_get_size(res);
            block(resourceUid, format, size);
        }
        res = arsdk_media_next_res(_media, res);
    }
}
@end

#pragma mark - ArsdkMediaList

/** Wrapper around arsdk_media_list */
@interface ArsdkMediaList : NSObject <ArsdkMediaList>
@property (nonatomic) struct arsdk_media_list *list;
@property (nonatomic) struct arsdk_media *currentMedia;
- (instancetype _Nullable)initWithResponseList:(struct arsdk_media_list* _Nonnull)list;
@end

@implementation ArsdkMediaList

- (instancetype _Nullable)initWithResponseList:(struct arsdk_media_list* _Nonnull)list {
    self = [super init];
    if (self) {
        _list = list;
        arsdk_media_list_ref(_list);
    }
    return self;
}

- (void)dealloc {
    arsdk_media_list_unref(_list);
}

- (ArsdkMedia*)next {
    _currentMedia = arsdk_media_list_next_media(_list, _currentMedia);
    if (_currentMedia) {
        return [[ArsdkMedia alloc] initWithMedia:_currentMedia];
    }
    return NULL;
}
@end

#pragma mark - arsdk_media_helpers

static struct arsdk_media_itf *get_media_itf(struct arsdk_ctrl *ctrl, short device_handle) {
    struct arsdk_device *device = arsdk_ctrl_get_device(ctrl, device_handle);
    if (device ==  NULL) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_ctrl_get_device: device not found"];
        return NULL;
    }
    struct arsdk_media_itf *media_itf = NULL;
    int res = arsdk_device_get_media_itf(device, &media_itf);
    if (res < 0) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_device_get_media_itf: %s", strerror(-res)];
        return NULL;
    }
    return media_itf;
}

static struct arsdk_media_res *get_resource_of_type(struct arsdk_media* media, enum arsdk_media_res_type type) {
    struct arsdk_media_res *res = arsdk_media_next_res(media, NULL);
    do {
        if (arsdk_media_res_get_type(res) == type) {
            return res;
        }
        res = arsdk_media_next_res(media, res);
    } while (res != NULL);
    return NULL;
}

static struct arsdk_media_res *get_resource_of_format(struct arsdk_media* media, enum arsdk_media_res_format fomat) {
    struct arsdk_media_res *res = arsdk_media_next_res(media, NULL);
    do {
        if (arsdk_media_res_get_fmt(res) == fomat) {
            return res;
        }
        res = arsdk_media_next_res(media, res);
    } while (res != NULL);
    return NULL;
}

#pragma mark - ListRequest

@interface ListRequest : ArsdkRequest
@property (nonatomic, readonly) ArsdkMediaListCompletion completionBlock;
@property (nonatomic) struct arsdk_media_req_list* request;
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                            types:(uint32_t)types
                       completion:(ArsdkMediaListCompletion)completionBlock;
@end

@implementation ListRequest

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                            types:(uint32_t)types
                       completion:(ArsdkMediaListCompletion)completionBlock {
    self = [super initWithArsdkCore:arsdkCore];
    if (self) {
        _completionBlock = completionBlock;
        // switch to arsdk thread (i.e pomp_loop thread)
        [self.arsdkCore dispatch:^{
            // ignore request if already canceled
            if (self.canceled) {
                return;
            }

            struct arsdk_media_itf *media_itf = get_media_itf(self.arsdkCore.ctrl, deviceHandle);
            if (media_itf == NULL) {
                goto failed;
            }
            struct arsdk_media_req_list_cbs cbs;
            memset(&cbs, 0, sizeof(cbs));
            cbs.userdata = (__bridge_retained void *)self;
            cbs.complete = &request_list_completed;

            int res = arsdk_media_itf_create_req_list(media_itf, &cbs, types,
                                                      (enum arsdk_device_type)deviceType, &self->_request);
            if (res < 0) {
                [ULog e:TAG msg:@"ListRequest arsdk_media_request_list: %s", strerror(-res)];
                goto failed;
            }
            return;

        failed:
            // failure, complete with error
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_completionBlock(ArsdkMediaStatusFailed, nil);
            });
        }];
    }
    return self;
}

-(void)cancel {
    [super cancel];
    [self.arsdkCore dispatch:^{
        if (self->_request) {
            arsdk_media_req_list_cancel(self->_request);
        }
    }];
}

static void request_list_completed(struct arsdk_media_itf *itf, struct arsdk_media_req_list *req,
                                   enum arsdk_media_req_status status, int error, void *userdata) {
    ListRequest* request = (__bridge_transfer ListRequest*)(userdata);
    ArsdkMediaList* mediaList = NULL;
    struct arsdk_media_list *list = arsdk_media_req_list_get_result(req);
    if (list) {
        mediaList = [[ArsdkMediaList alloc]initWithResponseList:list];
    }
    request->_request = NULL;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!request.canceled) {
            request.completionBlock((ArsdkMediaStatus)status, mediaList);
        }
    });
}
@end

#pragma mark - DownloadThumbnailRequest

@interface DownloadThumbnailRequest : ArsdkRequest
@property (nonatomic, readonly) ArsdkMediaDownloadThumbnailCompletion completionBlock;
@property (nonatomic) struct arsdk_media_req_download* request;
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                            media:(struct arsdk_media*)media
                       completion:(ArsdkMediaDownloadThumbnailCompletion)completionBlock;

@end

@implementation DownloadThumbnailRequest

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                            media:(struct arsdk_media*)media
                       completion:(ArsdkMediaDownloadThumbnailCompletion)completionBlock {
    self = [super initWithArsdkCore:arsdkCore];
    if (self) {
        _completionBlock = completionBlock;
        // ref media used in dispatch block
        arsdk_media_ref(media);
        // switch to arsdk thread (i.e pomp_loop thread)
        [arsdkCore dispatch:^{
            // ignore request if already canceled
            if (self.canceled) {
                arsdk_media_unref(media);
                return;
            }

            struct arsdk_media_itf *media_itf = get_media_itf(self.arsdkCore.ctrl, deviceHandle);
            if (media_itf == NULL) {
                goto failed;
            }

            struct arsdk_media_res* resource = get_resource_of_type(media, ARSDK_MEDIA_RES_TYPE_THUMBNAIL);
            if (resource == NULL) {
                goto failed;
            }

            struct arsdk_media_req_download_cbs cbs;
            memset(&cbs, 0, sizeof(cbs));
            cbs.userdata = (__bridge_retained void *)self;
            cbs.progress = &download_thumbnail_progress;
            cbs.complete = &download_thumbnail_completed;
            int res = arsdk_media_itf_create_req_download(media_itf, &cbs, arsdk_media_res_get_uri(resource),
                                                          NULL, (enum arsdk_device_type)deviceType, 0, &self->_request);
            if (res < 0) {
                [ULog e:TAG msg:@"DownloadThumbnailRequest arsdk_media_req_list: %s", strerror(-res)];
                goto failed;
            }
            arsdk_media_unref(media);
            return;

        failed:
            arsdk_media_unref(media);
            // failure, complete with error
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_completionBlock(ArsdkMediaStatusFailed, nil);
            });
        }];
    }
    return self;
}

-(void)cancel {
    [super cancel];
    [self.arsdkCore dispatch:^{
        if (self->_request) {
            arsdk_media_req_download_cancel(self->_request);
        }
    }];
}

static void download_thumbnail_progress(struct arsdk_media_itf *itf, struct arsdk_media_req_download *req,
                                        float percent, void *userdata) {
}

static void download_thumbnail_completed(struct arsdk_media_itf *itf, struct arsdk_media_req_download *req,
                                         enum arsdk_media_req_status status, int error, void *userdata) {
    DownloadThumbnailRequest* request = (__bridge_transfer DownloadThumbnailRequest*)(userdata);
    NSData* thumbnailData = NULL;
    if (status == ARSDK_MEDIA_REQ_STATUS_OK) {
        struct pomp_buffer* buf = arsdk_media_req_download_get_buffer(request->_request);
        if (buf) {
            const void *data = NULL;
            size_t len = 0;
            int res = pomp_buffer_get_cdata(buf, &data, &len, NULL);
            if (res != 0) {
                [ULog e:TAG msg:@"PompBuffer pomp_buffer_get_cdata %s", strerror(-res)];
            } else {
                thumbnailData = [[NSData alloc] initWithBytesNoCopy:(void*)data length:len
                                                        deallocator:^(void *bytes, NSUInteger length) {
                                                            pomp_buffer_unref(buf);
                                                        }];
                if (thumbnailData) {
                    pomp_buffer_ref(buf);
                }
            }
        }
    }
    request->_request = NULL;
    dispatch_async(dispatch_get_main_queue(), ^{
        request.completionBlock((ArsdkMediaStatus)status, thumbnailData);
    });
}

@end

#pragma mark - DownloadMediaRequest

@interface DownloadMediaRequest : ArsdkRequest
@property (nonatomic, readonly) ArsdkMediaDownloadProgress progressBlock;
@property (nonatomic, readonly) ArsdkMediaDownloadCompletion completionBlock;
@property (nonatomic) struct arsdk_media_req_download* request;
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                            media:(struct arsdk_media*)media
                           format:(enum arsdk_media_res_format)fomat
                destDirectoryPath:(NSString * _Nonnull)destDirectoryPath
                         progress:(ArsdkMediaDownloadProgress)progressBlock
                       completion:(ArsdkMediaDownloadCompletion)completionBlock;

@end

@implementation DownloadMediaRequest

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                            media:(struct arsdk_media*)media
                           format:(enum arsdk_media_res_format)fomat
                destDirectoryPath:(NSString * _Nonnull)destDirectoryPath
                         progress:(ArsdkMediaDownloadProgress)progressBlock
                       completion:(ArsdkMediaDownloadCompletion)completionBlock {
    self = [super initWithArsdkCore:arsdkCore];
    if (self) {
        _progressBlock = progressBlock;
        _completionBlock = completionBlock;
        // ref media used in dispatch block
        arsdk_media_ref(media);
        // switch to arsdk thread (i.e pomp_loop thread)
        [arsdkCore dispatch:^{
            // ignore request if already canceled
            if (self.canceled) {
                arsdk_media_unref(media);
                return;
            }

            NSString* targetFile;

            struct arsdk_media_itf *media_itf = get_media_itf(self.arsdkCore.ctrl, deviceHandle);
            if (media_itf == NULL) {
                goto failed;
            }

            struct arsdk_media_res* resource = get_resource_of_format(media, fomat);
            if (resource == NULL) {
                goto failed;
            }


            targetFile = [NSString stringWithFormat:@"%@/%s", destDirectoryPath, arsdk_media_res_get_name(resource)];

            struct arsdk_media_req_download_cbs cbs;
            memset(&cbs, 0, sizeof(cbs));
            cbs.userdata = (__bridge_retained void *)self;
            cbs.progress = &download_progress;
            cbs.complete = &download_completed;
            int res = arsdk_media_itf_create_req_download(media_itf, &cbs, arsdk_media_res_get_uri(resource),
                                                          targetFile.UTF8String, (enum arsdk_device_type)deviceType,
                                                          0, &self->_request);
            if (res < 0) {
                [ULog e:TAG msg:@"DownloadMediaRequest arsdk_media_req_list: %s", strerror(-res)];
                goto failed;
            }
            arsdk_media_unref(media);
            return;

        failed:
            arsdk_media_unref(media);
            // failure, complete with error
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_completionBlock(ArsdkMediaStatusFailed, NULL);
            });
        }];
    }
    return self;
}

-(void)cancel {
    [super cancel];
    [self.arsdkCore dispatch:^{
        if (self->_request) {
            arsdk_media_req_download_cancel(self->_request);
        }
    }];
}

static void download_progress(struct arsdk_media_itf *itf, struct arsdk_media_req_download *req,
                              float percent, void *userdata) {
    DownloadMediaRequest* request = (__bridge DownloadMediaRequest*)(userdata);
    dispatch_async(dispatch_get_main_queue(), ^{
        request.progressBlock(percent);
    });
}

static void download_completed(struct arsdk_media_itf *itf, struct arsdk_media_req_download *req,
                               enum arsdk_media_req_status status, int error, void *userdata) {
    DownloadMediaRequest* request = (__bridge_transfer DownloadMediaRequest*)(userdata);
    NSString* filePath = [NSString stringWithUTF8String:arsdk_media_req_download_get_local_path(req)];
    NSURL *fileUrl = nil;
    if (filePath) {
        fileUrl = [[NSURL alloc] initFileURLWithPath:filePath];
    }
    request->_request = NULL;
    dispatch_async(dispatch_get_main_queue(), ^{
        request.completionBlock((ArsdkMediaStatus)status, fileUrl);
    });
}

@end

#pragma mark - DeleteRequest

@interface DeleteRequest : ArsdkRequest
@property (nonatomic, readonly) ArsdkMediaDeleteCompletion completionBlock;
@property (nonatomic) struct arsdk_media_req_delete* request;

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                            media:(struct arsdk_media*)media
                       completion:(ArsdkMediaDeleteCompletion)completionBlock;
@end

@implementation DeleteRequest

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                            media:(struct arsdk_media*)media
                       completion:(ArsdkMediaDeleteCompletion)completionBlock {
    self = [super initWithArsdkCore:arsdkCore];
    if (self) {
        _completionBlock = completionBlock;
        // ref media used in dispatch block
        arsdk_media_ref(media);
        // switch to arsdk thread (i.e pomp_loop thread)
        [arsdkCore dispatch:^{
            // ignore request if already canceled
            if (self.canceled) {
                arsdk_media_unref(media);
                return;
            }
            struct arsdk_media_itf *media_itf = get_media_itf(self.arsdkCore.ctrl, deviceHandle);
            if (media_itf == NULL) {
                goto failed;
            }

            struct arsdk_media_req_delete_cbs cbs;
            memset(&cbs, 0, sizeof(cbs));
            cbs.userdata = (__bridge_retained void *)self;
            cbs.complete = &arsdk_media_request_delete_completed;
            int res = arsdk_media_itf_create_req_delete(media_itf, &cbs, media, (enum arsdk_device_type)deviceType,
                                                        &self->_request);
            if (res < 0) {
                [ULog e:TAG msg:@"DeleteRequest arsdk_media_delete: %s", strerror(-res)];
                goto failed;
            }
            arsdk_media_unref(media);
            return;

        failed:
            arsdk_media_unref(media);
            // failure, complete with error
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_completionBlock(ArsdkMediaStatusFailed);
            });
        }];
    }
    return self;
}

static void arsdk_media_request_delete_completed(struct arsdk_media_itf *itf, struct arsdk_media_req_delete *req,
                                                 enum arsdk_media_req_status status, int error, void *userdata) {
    DeleteRequest* request = (__bridge_transfer DeleteRequest*)(userdata);
    request->_request = NULL;

    dispatch_async(dispatch_get_main_queue(), ^{
        request.completionBlock((ArsdkMediaStatus)status);
    });
}
@end

#pragma mark - ArsdkCore

@implementation ArsdkCore (Media)

/** List medias */
- (ArsdkRequest*)listMedia:(int16_t)handle
                deviceType:(NSInteger)deviceType
                completion:(ArsdkMediaListCompletion)completionBlock {
    [self assertCallerThread];
    return [[ListRequest alloc] initWithArsdkCore:self
                                     deviceHandle:handle
                                       deviceType:(int)deviceType
                                            types:ARSDK_MEDIA_TYPE_ALL
                                       completion:completionBlock];
}

/** Download thumbnail */
- (ArsdkRequest*)downloadMediaThumnail:(int16_t)handle
                            deviceType:(NSInteger)deviceType
                                 media:(id<ArsdkMedia>)media
                            completion:(ArsdkMediaDownloadThumbnailCompletion)completionBlock {
    [self assertCallerThread];
    NSAssert([media isKindOfClass:[ArsdkMedia class]], @"invalid media instance");
    ArsdkMedia* arsdkMedia = (ArsdkMedia*)media;
    return [[DownloadThumbnailRequest alloc] initWithArsdkCore:self
                                                  deviceHandle:handle
                                                    deviceType:(int)deviceType
                                                         media:arsdkMedia.media
                                                    completion:completionBlock];
}

/** Download media */
- (ArsdkRequest * _Nonnull)downloadMedia:(int16_t)handle
                              deviceType:(NSInteger)deviceType
                                   media:(id<ArsdkMedia>)media
                                  format:(ArsdkMediaResourceFormat)format
                       destDirectoryPath:(NSString * _Nonnull)destDirectoryPath
                                progress:(ArsdkMediaDownloadProgress)progressBlock
                              completion:(ArsdkMediaDownloadCompletion)completionBlock
{
    [self assertCallerThread];
    NSAssert([media isKindOfClass:[ArsdkMedia class]], @"invalid media instance");
    ArsdkMedia* arsdkMedia = (ArsdkMedia*)media;
    return [[DownloadMediaRequest alloc] initWithArsdkCore:self
                                              deviceHandle:handle
                                                deviceType:(int)deviceType
                                                     media:arsdkMedia.media
                                                    format:(enum arsdk_media_res_format)format
                                         destDirectoryPath:destDirectoryPath
                                                  progress:progressBlock
                                                completion:completionBlock];
}

/** Delete media */
- (ArsdkRequest*)deleteMedia:(int16_t)handle
                  deviceType:(NSInteger)deviceType
                       media:(id<ArsdkMedia>)media
                  completion:(ArsdkMediaDeleteCompletion)completionBlock {
    [self assertCallerThread];
    NSAssert([media isKindOfClass:[ArsdkMedia class]], @"invalid media instance");
    ArsdkMedia* arsdkMedia = (ArsdkMedia*)media;
    return [[DeleteRequest alloc] initWithArsdkCore:self
                                       deviceHandle:handle
                                         deviceType:(int)deviceType
                                              media:arsdkMedia.media
                                         completion:completionBlock];
}

@end

