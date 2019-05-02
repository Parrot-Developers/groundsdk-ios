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

#import "SdkCore+Frame.h"
#import "PompLoopUtil.h"
#import "SdkCore+Sink.h"
#import "Logger.h"
#import <pdraw/pdraw.h>

/** Common loging tag. */
extern ULogTag *TAG;

@interface SdkCoreSink()
/** Listener for sink events */
@property (nonatomic) id<SdkCoreSinkListener>listener;

/** PDRAW sink; non NULL iff sink is started. */
@property (nonatomic, assign) struct pdraw_video_sink *psink;
/** PDRAW instance that controls sink. */
@property (nonatomic, assign) struct pdraw *pdraw;

@property (nonatomic) unsigned int queueSize;
@property (nonatomic) SdkCoreSinkQueueFullPolicy queuePolicy;
@property (nonatomic) SdkCoreSinkFrameFormat frameFormat;

/** Frame queue. */
@property (nonatomic, assign) struct vbuf_queue *queue;
/** Pomp event notified when frames are pushed into queue. */
@property (nonatomic, assign) struct pomp_evt *event;
/** Dispatch queue running the pomp loop */
@property (nonatomic, weak) PompLoopUtil *pompLoopUtil;

- (void)receivedFrameBuffer:(struct vbuf_buffer * _Nonnull)buffer;

@end


/**
 Called back when a new frame has been pushed in the sink's queue.

 @param fd: fd of the pomp_evt that triggered this callback
 @param revents: events that occurred
 @param userdata: sdkcore_sink instance
 */
static void pdraw_queue_push(int fd, uint32_t revents, void *userdata)
{
    SdkCoreSink *this = (__bridge SdkCoreSink *)(userdata);
    if (this.psink == NULL) {
        [ULog e:TAG msg:@"SdkCoreSink pdraw_queue_push failed: %d", -EPROTO];
    }

    int res = pomp_evt_clear(this.event);
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreSink pomp_evt_clear failed: %d", res];
    }

    struct vbuf_buffer *buffer = NULL;
    res = vbuf_queue_pop(this.queue, 0, &buffer);
    if (res < 0 || buffer == NULL) {
        [ULog e:TAG msg:@"SdkCoreSink vbuf_queue_pop failed: %d", res];
        return;
    }

    [this receivedFrameBuffer:buffer];

    res = vbuf_unref(buffer);
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreSink vbuf_unref failed: %d", res];
    }
}

/**
 Called back when PDRAW requests that all outstanding buffers be unreferenced
 and the sink's queue be flushed.

 @param pdraw: PDRAW instance
 @param sink: PDRAW sink instance
 @param userdata: sdkcore_sink instance
 */
static void pdraw_flush(struct pdraw *pdraw, struct pdraw_video_sink *sink,
                        void *userdata)
{
    SdkCoreSink *this = (__bridge SdkCoreSink *)(userdata);

    int res = vbuf_queue_flush(this.queue);
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreSink vbuf_queue_flush failed: %d", res];
    }

    res = pdraw_video_sink_queue_flushed(pdraw, sink);
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreSink pdraw_video_sink_queue_flushed failed: %d", res];
    }
}

@implementation SdkCoreSink

- (instancetype _Nullable)initWithQueueSize:(unsigned int)queueSize
                                     policy:(SdkCoreSinkQueueFullPolicy)policy
                                     format:(SdkCoreSinkFrameFormat)format
                                   listener:(id<SdkCoreSinkListener> _Nonnull)listener {
    self = [super init];
    if (self) {
        self.queueSize = queueSize;
        self.queuePolicy = policy;
        self.frameFormat = format;

        self.listener = listener;
    }
    return self;
}

- (void)start:(/*struct pdraw **/void *  _Nonnull)pdraw
         pomp:(PompLoopUtil * _Nonnull)pompLoopUtil
      mediaId:(unsigned int)mediaId {
    NSAssert(_pompLoopUtil == nil, @"Sink already started");

    _pompLoopUtil = pompLoopUtil;

    [_pompLoopUtil dispatch:^{
        int res = [self startInPompWithPdraw:pdraw mediaId:mediaId];
        if (res < 0) {
            [ULog e:TAG msg:@"SdkCoreSink startInPompWithPdraw failed: %d", res];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.pompLoopUtil = nil;
                [self.listener onStop];
            });
        }
    }];
}

/**
 Starts the sink. Must be called in the pomp loop

 @param pdraw:   pdraw instance that will deliver frames to the sink
 @param mediaId: identifies the stream media to be delivered to the sink
 */
- (int)startInPompWithPdraw:(struct pdraw *)pdraw mediaId:(unsigned int)mediaId {

    struct pdraw_video_sink_cbs cbs = {
        .flush = pdraw_flush
    };

    struct pdraw_video_sink_params params = {
        .queue_max_count = _queueSize,
    };

    switch (_frameFormat) {
        case SdkCoreSinkFrameFormatH264Avcc:
            params.required_format = PDRAW_H264_FORMAT_AVCC;
            break;
        case SdkCoreSinkFrameFormatH264ByteStream:
            params.required_format = PDRAW_H264_FORMAT_BYTE_STREAM;
            break;
        default:
            params.required_format = PDRAW_H264_FORMAT_UNKNOWN;
            break;
    }

    switch (_queuePolicy) {
        case SdkCoreSinkQueueFullPolicyDropEldest:
            params.queue_drop_when_full = 1;
            break;
        case SdkCoreSinkQueueFullPolicyDropNew:
            params.queue_drop_when_full = 0;
            break;
        default:
            [ULog e:TAG msg:@"SdkCoreSink bad policy: %d", (int)_queuePolicy];
            return -EINVAL;
    }

    _pdraw = pdraw;

    int res = pdraw_start_video_sink(_pdraw, mediaId, &params,
                                     &cbs, (__bridge void*)self, &_psink);
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreSink pdraw_start_video_sink failed: %d", res];
        goto err_cleanup;
    }

    _queue = pdraw_get_video_sink_queue(_pdraw, _psink);
    res = _queue ? 0 : -ENOTSUP;
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreSink pdraw_get_video_sink_queue failed: %d", res];
        goto err_stop_sink;
    }

    _event = vbuf_queue_get_evt(_queue);
    res = _event ? 0 : -ENOTSUP;
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreSink vbuf_queue_get_evt failed: %d", res];
        goto err_stop_sink;
    }

    intptr_t fd = pomp_evt_get_fd(_event);
    res = (int)fd;
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreSink pomp_evt_get_fd failed: %d", res];
        goto err_stop_sink;
    }

    res = pomp_loop_add([_pompLoopUtil internalPompLoop], (int)fd, POMP_FD_EVENT_IN, pdraw_queue_push, (__bridge void*)self);
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreSink pomp_loop_add failed: %d", res];
        goto err_stop_sink;
    }

    return 0;

err_stop_sink:
    res = pdraw_stop_video_sink(_pdraw, _psink);
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreStream pdraw_stop_video_sink failed: %d", res];
    }
err_cleanup:
    _event = NULL;
    _queue = NULL;
    _psink = NULL;
    _pdraw = pdraw;

    return res;
}

- (void)stop {
    if(_pompLoopUtil == nil) {
        [ULog w:TAG msg:@"SdkCoreSink sink already stopped"];
        return;
    }

    PompLoopUtil *pompLoopUtil = _pompLoopUtil;
    _pompLoopUtil = nil;
    [self.listener onStop];
    [pompLoopUtil dispatch:^{
        int res = pdraw_stop_video_sink(self.pdraw, self.psink);
        if (res < 0) {
            [ULog e:TAG msg:@"SdkCoreSink pdraw_stop_video_sink failed: %d", res];
            return;
        }

        [ULog d:TAG msg:@"Sink %p STOP [pdraw: %p]", self, self.pdraw];

        self.psink = NULL;

        intptr_t fd = pomp_evt_get_fd(self.event);
        if (fd >= 0) {
            int res = (pomp_loop_remove([pompLoopUtil internalPompLoop], (int)fd));
            if (res < 0) {
                [ULog e:TAG msg:@"SdkCoreSink pomp_loop_remove failed: %d", res];
            }
        } else {
            [ULog e:TAG msg:@"SdkCoreSink bad fd: %ld", fd];
            return;
        }

        self.event = NULL;
        self.queue = NULL;
        self.pdraw = nil;
    }];
}

- (void)resynchronize {
    NSAssert(_pompLoopUtil != nil, @"Sink stopped");

    [_pompLoopUtil dispatch:^{
        int res = pdraw_resync_video_sink(self.pdraw, self.psink);
        if (res < 0) {
            [ULog e:TAG msg:@"SdkCoreSink pdraw_resync_video_sink failed: %d", res];
        }
    }];
}

/**
 Called when a new frame is received.
 Called in the Pomp thread

 @param buffer: recevied frame.
 */
- (void)receivedFrameBuffer:(struct vbuf_buffer * _Nonnull)buffer {
    SdkCoreFrame *frame = [[SdkCoreFrame alloc] initWithCopy:buffer metaKey:_psink];

    if (frame == nil) {
        [ULog e:TAG msg:@"SdkCoreSink receivedFrameBuffer failed: %d", -ENOMEM];
        return;
    }

    [self.listener onFrame: frame];
}

@end
