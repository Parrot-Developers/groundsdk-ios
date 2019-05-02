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

#import "SdkCore+MediaInfo.h"
#import "Logger.h"
#import <pdraw/pdraw.h>

/** Common loging tag. */
extern ULogTag *TAG;

/** Information upon a media supported by a stream. */
@interface SdkCoreMediaInfo()
{
    @protected
    long _mediaId;
}
/** Media unique identifier. */
@property (nonatomic, assign) long mediaId;
/** Media type. */
@property (nonatomic, assign) SdkCoreMediaType type;
@end

/** Information upon a video media supported by a stream. */
@interface SdkCoreVideoInfo()
/** Video media source. */
@property (nonatomic, assign) int source;
/** Video width, in pixels. */
@property (nonatomic, assign) int width;
/** Video height, in pixels. */
@property (nonatomic, assign) int height;
@end

@implementation SdkCoreMediaInfo

+ (SdkCoreMediaInfo * _Nullable)createFromPdrawMediaInfo:(/*struct pdraw_media_info* */void * _Nonnull)pMediaInfo {
    struct pdraw_media_info* mediaInfo = pMediaInfo;
    SdkCoreMediaInfo *sdkCoreMediaInfo;

    if (mediaInfo->type != PDRAW_MEDIA_TYPE_VIDEO) {
        [ULog i:TAG msg:@"Unsupported media type: %d", mediaInfo->type];
        sdkCoreMediaInfo = nil;
    } else if (mediaInfo->video.format == PDRAW_VIDEO_MEDIA_FORMAT_H264) {
        SdkCoreH264Info *info = [[SdkCoreH264Info alloc] init];
        [info setMediaId: mediaInfo->id];
        [info setType: SdkCoreMediaTypeH264];
        [info setSource: mediaInfo->video.type];
        [info setWidth: mediaInfo->video.h264.width];
        [info setHeight: mediaInfo->video.h264.height];
        sdkCoreMediaInfo = info;
    } else if (mediaInfo->video.format == PDRAW_VIDEO_MEDIA_FORMAT_YUV) {
        SdkCoreYuvInfo *info = [[SdkCoreYuvInfo alloc] init];
        [info setMediaId: mediaInfo->id];
        [info setType: SdkCoreMediaTypeYuv];
        [info setSource: mediaInfo->video.type];
        [info setWidth: mediaInfo->video.yuv.width];
        [info setHeight: mediaInfo->video.yuv.height];
        sdkCoreMediaInfo = info;
    }

    return sdkCoreMediaInfo;
}

- (instancetype _Nonnull)initWithMediaId:(long)mediaId {
    self = [super init];
    if (self) {
        _mediaId = mediaId;
        _type = SdkCoreMediaTypeUnkown;
    }
    return self;
}

- (instancetype _Nonnull)initWithMediaId:(long)mediaId
                                    type:(SdkCoreMediaType)type {
    self = [super init];
    if (self) {
        _mediaId = mediaId;
        _type = type;
    }
    return self;
}

@end

@implementation SdkCoreVideoInfo
@end

@implementation SdkCoreH264Info

- (instancetype _Nonnull)initWithMediaId:(long)mediaId {
    return [super initWithMediaId:mediaId type:SdkCoreMediaTypeH264];
}

@end

@implementation SdkCoreYuvInfo

- (instancetype _Nonnull)initWithMediaId:(long)mediaId {
    return [super initWithMediaId:mediaId type:SdkCoreMediaTypeYuv];
}

@end
