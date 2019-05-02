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

#import <Foundation/Foundation.h>

/** Media type. */
typedef NS_ENUM(NSInteger, SdkCoreMediaType) {
    /** Undefined media type */
    SdkCoreMediaTypeUnkown = 0,
    /** H264 video media */
    SdkCoreMediaTypeH264 = 1,
    /** YUV video media */
    SdkCoreMediaTypeYuv = 2
};

/** Information upon a media supported by a stream. */
@interface SdkCoreMediaInfo: NSObject

/** Media unique identifier. */
@property (readonly, nonatomic, assign) long mediaId;
/** Media type. */
@property (readonly, nonatomic, assign) SdkCoreMediaType type;

/**
 Create a media info instance from Pdraw media info.

 @param mediaInfo: media info.
 */
+ (SdkCoreMediaInfo * _Nullable)createFromPdrawMediaInfo:(/*struct pdraw_media_info* */void * _Nonnull)mediaInfo;

/**
 Constructor

 @param mediaId: Media unique identifier.
*/
- (instancetype _Nonnull)initWithMediaId:(long)mediaId;

/**
 Create a media info.

 @param mediaId: Media unique identifier.
 @param type:Media type.
 */
- (instancetype _Nonnull)initWithMediaId:(long)mediaId type:(SdkCoreMediaType)type;

@end

/** Information upon a video media supported by a stream. */
@interface SdkCoreVideoInfo: SdkCoreMediaInfo

/** Video media source. */
@property (readonly, nonatomic, assign) int source;
/** Video width, in pixels. */
@property (readonly, nonatomic, assign) int width;
/** Video height, in pixels. */
@property (readonly, nonatomic, assign) int height;

@end

/** Information upon an H.264 video media supported by a stream. */
@interface SdkCoreH264Info: SdkCoreVideoInfo
@end

/** Information upon a YUV video media supported by a stream. */
@interface SdkCoreYuvInfo: SdkCoreVideoInfo
@end
