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

#include <video-buffers/vbuf_generic.h>
#import "SdkCore+Frame.h"
#import "Logger.h"
#import <pdraw/pdraw.h>

/** Common loging tag. */
extern ULogTag *TAG;


/** Generic malloc/free vbuf_buffer callbacks. Initialized once upon load. */
static struct vbuf_cbs s_vbuf_generic_cbs;

/**
 * Initializes s_vbuf_generic_cbs.
 * Called once at library load time.
 */
__attribute__((constructor))
static void init_vbuf_generic_cbs()
{
    if (s_vbuf_generic_cbs.alloc != NULL) {
        [ULog e:TAG msg:@"SdkCoreFrame init_vbuf_generic_cbs failed %d",-EINVAL];
        return;
    }

    int res = vbuf_generic_get_cbs(&s_vbuf_generic_cbs);

    if (s_vbuf_generic_cbs.alloc == NULL) {
        [ULog e:TAG msg:@"SdkCoreFrame init_vbuf_generic_cbs failed %d", res];
        return;
    }
}

@interface SdkCoreFrame()
/** Video buffer containing actual frame data. Unreferenced upon destroy. */
@property (nonatomic, assign) struct vbuf_buffer *vbuf;
/** Key to PDRAW metadata in vbuf. */
@property (nonatomic, assign) void * _Nullable metaKey;

@property (nonatomic, assign) const uint8_t * _Nullable data;
@property (nonatomic, assign) ssize_t len;
@property (nonatomic, assign) void * _Nullable pdrawFrame;
@end


@implementation SdkCoreFrame

- (instancetype _Nullable)initWithCopy:(void * _Nonnull)src metaKey:(void * _Nonnull)metaKey {
    struct vbuf_buffer *srcbuff = (struct vbuf_buffer *)src;
    self = [super init];
    if (self) {

        // obtain original data pointer
        const uint8_t *src_data = vbuf_get_cdata(srcbuff);
        if (src_data == NULL) {
            [ULog e:TAG msg:@"SdkCoreFrame vbuf_get_cdata failed"];
            return nil;
        }

        // obtain original metadata
        struct pdraw_video_frame *src_frame = NULL;
        int res = vbuf_metadata_get(srcbuff, metaKey, NULL, NULL,
                                    (uint8_t **) &src_frame);
        if (res < 0) {
            [ULog e:TAG msg:@"SdkCoreFrame (original metadata) vbuf_metadata_get failed %d", res];
            return nil;
        }

        // create copy buffer
        struct vbuf_buffer *vbuf = NULL;
        res = vbuf_new(0, 0, &s_vbuf_generic_cbs, NULL, &vbuf);
        if (vbuf == NULL) {
            [ULog e:TAG msg:@"SdkCoreFrame vbuf_new failed %d", res];
            return nil;
        }
        self.vbuf = vbuf;

        // copy buffer
        res = vbuf_copy(srcbuff, self.vbuf);
        if (res < 0) {
            [ULog e:TAG msg:@"SdkCoreFrame vbuf_copy failed %d", res];
            goto err_unref_copy;
        }

        // obtain copy metadata
        struct pdraw_video_frame *copy_frame = NULL;
        res = vbuf_metadata_get(self.vbuf, metaKey, NULL, NULL,
                                (uint8_t **) &copy_frame);
        if (res < 0 || copy_frame == NULL) {
            [ULog e:TAG msg:@"SdkCoreFrame (copy metadata) vbuf_metadata_get failed : %d copy_frame: %p", res, copy_frame];
            goto err_unref_copy;
        }

        /* fix metadata plane pointers for YUV frames */
        if (src_frame->format == PDRAW_VIDEO_MEDIA_FORMAT_YUV) {
            /* obtain copy data pointer */
            const uint8_t *copy_data = vbuf_get_cdata(self.vbuf);

            /* fix 3 planes offsets */
            for (int i = 0; i < 3; i++) {
                copy_frame->yuv.plane[i] =
                copy_data + (src_frame->yuv.plane[i] - src_data);
            }
        }

        self.metaKey = metaKey;
        self.data = vbuf_get_cdata(self.vbuf);
        self.len = vbuf_get_size(self.vbuf);
        self.pdrawFrame = (void *)copy_frame;

    }
    return self;

err_unref_copy:
    vbuf_unref(self.vbuf);
    self.vbuf = NULL;

    return nil;
}

- (void)dealloc {
    if (_vbuf != NULL) {
        vbuf_unref(_vbuf);
    }
}

@end
