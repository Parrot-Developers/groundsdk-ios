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
#import "SdkCore+Renderer.h"
#import "Logger.h"
#import <pdraw/pdraw.h>

/** common loging tag */
extern ULogTag *TAG;

/** Static transition flags setup. */
#define TRANSITION_FLAGS \
PDRAW_VIDEO_RENDERER_TRANSITION_FLAG_RECONFIGURE \
| PDRAW_VIDEO_RENDERER_TRANSITION_FLAG_TIMEOUT \
| PDRAW_VIDEO_RENDERER_TRANSITION_FLAG_PHOTO_TRIGGER

/** Data relative to texture loading. */
@interface SdkCoreTextureLoaderFrame()
/** Handle on the frame. */
@property (nonatomic, assign) const void * _Nonnull frame;
/** Handle on the frame user data. */
@property (nonatomic, assign) const void * _Nullable userData;
/** Length of the frame user data. */
@property (nonatomic, assign) size_t userDataLen;
/** Handle on the session metadata. */
@property (nonatomic, assign) const void * _Nonnull sessionMetadata;
@end

@interface SdkCoreHistogram()
/** Histogram channel red. */
@property (nonatomic) const float * _Nullable histogramRed;
/** Length of histogram channel red. */
@property (nonatomic) size_t histogramRedLen;
/** Histogram channel green. */
@property (nonatomic) const float * _Nullable histogramGreen;
/** Length of histogram channel green. */
@property (nonatomic) size_t histogramGreenLen;
/** Histogram channel blue. */
@property (nonatomic) const float * _Nullable histogramBlue;
/** Length of histogram channel blue. */
@property (nonatomic) size_t histogramBlueLen;
/** Histogram channel luma. */
@property (nonatomic) const float * _Nullable histogramLuma;
/** Length of histogram channel luma. */
@property (nonatomic) size_t histogramLumaLen;
@end

@interface SdkCoreRenderer()
@property (nonatomic) id<SdkCoreRendererListener>listener;
@property (nonatomic, assign) struct pdraw *pdraw;
@property (nonatomic, assign) struct pdraw_video_renderer *pdrawRenderer;
/** Content zone, relative to the renderer zone */
@property (nonatomic) CGRect contentZone;
/** Content zone, relative to the renderer zone. Only used in the render thread. */
@property (nonatomic) CGRect contentZoneTmp;
@property (nonatomic) id<SdkCoreTextureLoaderListener>textureLoaderListener;
@property (nonatomic) id<SdkCoreRendererOverlayListener>overlayListener;

@end

static void render_ready_cb(struct pdraw *pdraw,
                            struct pdraw_video_renderer *renderer, void *userdata)
{
    SdkCoreRenderer *this = (__bridge SdkCoreRenderer *)userdata;

    dispatch_async(dispatch_get_main_queue(), ^{
        [this.listener onFrameReady];
    });
}

static int load_texture_cb(struct pdraw *pdraw,
                           struct pdraw_video_renderer *renderer,
                           unsigned int texture_width,
                           unsigned int texture_height,
                           const struct pdraw_session_info *session_info,
                           const struct vmeta_session *session_meta,
                           const struct pdraw_video_frame *frame,
                           const void *frame_userdata,
                           size_t frame_userdata_len,
                           void *userdata)
{
    SdkCoreRenderer *this = (__bridge SdkCoreRenderer *)(userdata);
    if (this == nil ||
        this.textureLoaderListener == nil ||
        renderer == NULL ||
        session_info == NULL ||
        session_meta == NULL ||
        frame == NULL) {
        return  -EINVAL;
    }
    
    SdkCoreTextureLoaderFrame *data = [[SdkCoreTextureLoaderFrame alloc] init];
    [data setFrame: frame];
    [data setUserData: frame_userdata];
    [data setUserDataLen: frame_userdata_len];
    [data setSessionMetadata: session_meta];

    return [this.textureLoaderListener loadTexture:texture_width height:texture_height frame:data] == YES ? 0 : -EIO;
}

static void render_overlay_cb(struct pdraw *pdraw,
                              struct pdraw_video_renderer *renderer,
                              const struct pdraw_rect *render_pos,
                              const struct pdraw_rect *content_pos,
                              const float *view_mat,
                              const float *proj_mat,
                              const struct pdraw_session_info *session_info,
                              const struct vmeta_session *session_meta,
                              const struct vmeta_frame *frame_meta,
                              const struct pdraw_video_frame_extra *frame_extra,
                              void *userdata)
{
    SdkCoreRenderer *this = (__bridge SdkCoreRenderer *)(userdata);
    if (this == nil ||
        render_pos == NULL ||
        content_pos == NULL ||
        frame_extra == NULL) {
        // invalid parameters
        return;
    }

    SdkCoreHistogram *histogram = [[SdkCoreHistogram alloc] init];

    if (frame_extra->histogram_len[PDRAW_HISTOGRAM_CHANNEL_RED] > 0) {
        [histogram setHistogramRed:frame_extra->histogram[PDRAW_HISTOGRAM_CHANNEL_RED]];
        [histogram setHistogramRedLen:frame_extra->histogram_len[PDRAW_HISTOGRAM_CHANNEL_RED]];
    } else {
        [histogram setHistogramRed:nil];
        [histogram setHistogramRedLen:0];
    }

    if (frame_extra->histogram_len[PDRAW_HISTOGRAM_CHANNEL_GREEN] > 0) {
        [histogram setHistogramGreen:frame_extra->histogram[PDRAW_HISTOGRAM_CHANNEL_GREEN]];
        [histogram setHistogramGreenLen:frame_extra->histogram_len[PDRAW_HISTOGRAM_CHANNEL_GREEN]];
    } else {
        [histogram setHistogramGreen:nil];
        [histogram setHistogramGreenLen:0];
    }

    if (frame_extra->histogram_len[PDRAW_HISTOGRAM_CHANNEL_BLUE] > 0) {
        [histogram setHistogramBlue:frame_extra->histogram[PDRAW_HISTOGRAM_CHANNEL_BLUE]];
        [histogram setHistogramBlueLen:frame_extra->histogram_len[PDRAW_HISTOGRAM_CHANNEL_BLUE]];
    } else {
        [histogram setHistogramBlue:nil];
        [histogram setHistogramBlueLen:0];
    }

    if (frame_extra->histogram_len[PDRAW_HISTOGRAM_CHANNEL_LUMA] > 0) {
        [histogram setHistogramLuma:frame_extra->histogram[PDRAW_HISTOGRAM_CHANNEL_LUMA]];
        [histogram setHistogramLumaLen:frame_extra->histogram_len[PDRAW_HISTOGRAM_CHANNEL_LUMA]];
    } else {
        [histogram setHistogramLuma:nil];
        [histogram setHistogramLumaLen:0];
    }

    if (this.overlayListener != nil) {
        [this.overlayListener overlay:render_pos contentPos:content_pos histogram:histogram];
    }
}


@implementation SdkCoreRenderer

- (instancetype _Nullable)initWithPdraw:(/*struct pdraw **/void * _Nonnull)pdraw
                                   zone:(CGRect)renderZone
                               fillMode:(SdkCoreStreamRenderingFillMode)fillMode
                          zebrasEnabled:(BOOL)zebrasEnabled zebrasThreshold:(float)zebrasThreshold
                           textureWidth:(int)textureWidth textureDarWidth:(int)textureDarWidth textureDarHeight:(int)textureDarHeight
                  textureLoaderlistener:(id<SdkCoreTextureLoaderListener>)textureLoaderlistener
                      histogramsEnabled:(BOOL)histogramsEnabled
                        overlayListener:(id<SdkCoreRendererOverlayListener> _Nonnull)overlayListener
                               listener:(id<SdkCoreRendererListener> _Nonnull)listener {
    self = [super init];
    if (self) {
        self.listener = listener;
        self.textureLoaderListener = textureLoaderlistener;
        self.overlayListener = overlayListener;
        self.pdraw = pdraw;
        self.pdrawRenderer = NULL;

        struct pdraw_video_renderer_params params = {
            .enable_hmd_distortion_correction = 0,
            .fill_mode = (int)fillMode,
            .enable_overexposure_zebras = zebrasEnabled ? 1 : 0,
            .overexposure_zebras_threshold = zebrasThreshold,
            .enable_histograms = histogramsEnabled ? 1 : 0,
            .enable_transition_flags = TRANSITION_FLAGS,
        };

        struct pdraw_video_renderer_cbs pdrawCbs = {
            .render_ready = &render_ready_cb,
            .render_overlay = &render_overlay_cb,
        };

        if (textureLoaderlistener != nil) {
            pdrawCbs.load_texture = &load_texture_cb;
            params.video_texture_width = textureWidth;
            params.video_texture_dar_width = textureDarWidth;
            params.video_texture_dar_height = textureDarHeight;
        }

        struct pdraw_rect size = {
            .x = renderZone.origin.x,
            .y = renderZone.origin.y,
            .width = renderZone.size.width,
            .height = renderZone.size.height,
        };

        int res = pdraw_start_video_renderer(_pdraw, &size, &params, &pdrawCbs, (__bridge void*)self,
                &_pdrawRenderer);
        if (res < 0) {
            [ULog e:TAG msg:@"SdkCoreRenderer pdraw_start_video_renderer failed:%s", strerror(-res)];
        }
    }
    return self;
}

- (void)stop {
    if (_pdrawRenderer == nil) {
        [ULog e:TAG msg:@"SdkCoreRenderer stop: renderer not opened"];
        return;
    }
    int res = pdraw_stop_video_renderer(_pdraw, _pdrawRenderer);
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreRenderer pdraw_stop_video_renderer failed: %s", strerror(-res)];
        return;
    }
    _pdrawRenderer = nil;
}

- (void)renderFrame {
    if (_pdrawRenderer == nil) {
        [ULog e:TAG msg:@"SdkCoreRenderer renderFrame: renderer not opened"];
        return;
    }

    struct pdraw_rect pos;

    int res = pdraw_render_video(_pdraw, _pdrawRenderer, &pos);
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreRenderer pdraw_render_video failed: %s", strerror(-res)];
        return;
    }

    if (_contentZoneTmp.origin.x != pos.x || _contentZoneTmp.origin.y != pos.y ||
        _contentZoneTmp.size.width != pos.width || _contentZoneTmp.size.height != pos.height) {
        _contentZoneTmp.origin.x = pos.x;
        _contentZoneTmp.origin.y = pos.y;
        _contentZoneTmp.size.width = pos.width;
        _contentZoneTmp.size.height = pos.height;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setContentZone: self.contentZoneTmp];
            [self.listener contentZoneDidUpdate: [self contentZone]];
        });
    }
}

- (void)setFillMode:(SdkCoreStreamRenderingFillMode)mode {
    if (_pdrawRenderer == nil) {
        [ULog e:TAG msg:@"SdkCoreRenderer setFillMode: renderer not opened"];
        return;
    }

    int res;
    struct pdraw_video_renderer_params params;
    res = pdraw_get_video_renderer_params(_pdraw, _pdrawRenderer, &params);
    if (res < 0) {
        [ULog e:TAG msg:@"pdraw_get_video_renderer_params failed: %s", strerror(-res)];
        return;
    }

    params.fill_mode = (enum pdraw_video_renderer_fill_mode) mode;
    res = pdraw_set_video_renderer_params(_pdraw, _pdrawRenderer, &params);
    if (res < 0) {
        [ULog e:TAG msg:@"pdraw_set_video_renderer_params failed: %s", strerror(-res)];
    }
}

- (void)setRenderZone:(CGRect)renderZone {
    if (_pdrawRenderer == nil) {
        [ULog e:TAG msg:@"SdkCoreRenderer setRenderZone: renderer not opened"];
        return;
    }

    struct pdraw_rect size = {
        .x = renderZone.origin.x,
        .y = renderZone.origin.y,
        .width = renderZone.size.width,
        .height = renderZone.size.height,
    };
    
    int res = pdraw_resize_video_renderer(_pdraw, _pdrawRenderer, &size);
    if (res < 0) {
        [ULog e:TAG msg:@"pdraw_resize_video_renderer failed: %s", strerror(-res)];
        return;
    }
}

- (void)enableZebras:(BOOL)enabled {
    if (_pdrawRenderer == nil) {
        [ULog e:TAG msg:@"SdkCoreRenderer enableZebras: renderer not opened"];
        return;
    }

    int res;
    struct pdraw_video_renderer_params params;
    res = pdraw_get_video_renderer_params(_pdraw, _pdrawRenderer, &params);
    if (res < 0) {
        [ULog e:TAG msg:@"pdraw_get_video_renderer_params failed: %s", strerror(-res)];
        return;
    }

    params.enable_overexposure_zebras = enabled ? 1 : 0;
    res = pdraw_set_video_renderer_params(_pdraw, _pdrawRenderer, &params);
    if (res < 0) {
        [ULog e:TAG msg:@"pdraw_set_video_renderer_params failed: %s", strerror(-res)];
    }
}

- (void)setZebrasThreshold:(float)threshold {
    if (_pdrawRenderer == nil) {
        [ULog e:TAG msg:@"SdkCoreRenderer setZebrasThreshold: renderer not opened"];
        return;
    }

    int res;
    struct pdraw_video_renderer_params params;
    res = pdraw_get_video_renderer_params(_pdraw, _pdrawRenderer, &params);
    if (res < 0) {
        [ULog e:TAG msg:@"pdraw_get_video_renderer_params failed: %s", strerror(-res)];
        return;
    }

    params.overexposure_zebras_threshold = threshold;
    res = pdraw_set_video_renderer_params(_pdraw, _pdrawRenderer, &params);
    if (res < 0) {
        [ULog e:TAG msg:@"pdraw_set_video_renderer_params failed: %s", strerror(-res)];
    }
}

- (void)enableHistograms:(BOOL)enabled {
    if (_pdrawRenderer == nil) {
        [ULog e:TAG msg:@"SdkCoreRenderer enableHistograms: renderer not opened"];
        return;
    }

    int res;
    struct pdraw_video_renderer_params params;
    res = pdraw_get_video_renderer_params(_pdraw, _pdrawRenderer, &params);
    if (res < 0) {
        [ULog e:TAG msg:@"pdraw_get_video_renderer_params failed: %s", strerror(-res)];
        return;
    }

    params.enable_histograms = enabled ? 1 : 0;
    res = pdraw_set_video_renderer_params(_pdraw, _pdrawRenderer, &params);
    if (res < 0) {
        [ULog e:TAG msg:@"pdraw_set_video_renderer_params failed: %s", strerror(-res)];
    }
}
@end

@implementation SdkCoreTextureLoaderFrame
@end

@implementation SdkCoreHistogram
@end
