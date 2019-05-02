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

#import "SdkCore+Stream.h"
#import "Logger.h"
#import <pdraw/pdraw.h>

/** common loging tag */
extern ULogTag *TAG;

/** Stream internal state */
typedef NS_ENUM(NSInteger, SdkCoreStreamState) {
    /** Stream has not been opened yet */
    SdkCoreStreamStateIdle = 0,
    /** Stream open has been requested */
    SdkCoreStreamStateOpening = 1,
    /** Stream is open, playback control is available */
    SdkCoreStreamStateOpen = 2,
    /** Stream is closed, cannot be used any further */
    SdkCoreStreamStateClosed = 3,
};

/** Pdraw state */
typedef NS_ENUM(NSInteger, SdkCorePdrawState) {
    /** Initial state, stream is closed */
    SdkCorePdrawStateClosed = 0,
    /** Stream is opening, pdraw open_* has been called */
    SdkCorePdrawStateOpening = 1,
    /** Stream is opened, pdraw open_resp success + ready_to_play == 1 */
    SdkCorePdrawStateOpen = 2,
    /** Stream is closing, pdraw close has been called */
    SdkCorePdrawStateClosing = 3,
};

@interface SdkCoreStream()

/** Listener for stream events */
@property (nonatomic) id<SdkCoreStreamListener> _Nonnull listener;
/** Stream source */
@property (nonatomic, strong) id<SdkCoreSource> _Nonnull source;
/** Dispatch queue running the pomp loop */
@property (nonatomic, weak) PompLoopUtil * pompLoopUtil;
/** Pdraw handle */
@property (nonatomic, assign) struct pdraw * _Nullable pdraw;
/** Pdraw state */
@property (nonatomic, assign) SdkCorePdrawState pdrawState;
/** Stream state */
@property (nonatomic, assign) SdkCoreStreamState state;
/** Stream close reason */
@property (nonatomic, assign) SdkCoreStreamCloseReason closeReason;
/** Stream duration, in milliseconds, 0 when irrelevant */
@property (nonatomic, assign) int64_t duration;
/** Stream position, in milliseconds */
@property (nonatomic, assign) int64_t position;
/** Playback speed (multiplier), 0 when paused */
@property (nonatomic, assign) double speed;

@property (nonatomic, strong) NSString * _Nullable track;

- (void) closeStream;

- (void) streamOpened;
- (void) streamPlaybackStateChanged;
- (void) streamClosing;
- (void) streamClosed;
- (void) mediaAdded:(const struct pdraw_media_info*)info;
- (void) mediaRemoved:(const struct pdraw_media_info*)info;

- (int) createPdraw;
- (void) destroyPdraw;
@end

/**
 Stream open callback.
 @param pdraw: Pdraw handle.
 @param status: 0 on success, a negative error code otherwise.
 @param userdata: SdkCoreStream instance.
 */
static void pdraw_open_response(struct pdraw *pdraw, int status, void *userdata) {
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return;
    }

    if (status == 0) {
        if (this.pdrawState != SdkCorePdrawStateOpening) {
            [ULog d:TAG msg:@"pdraw_open_response received while pdraw state: %d", this.pdrawState];
        }
        return;
    }
    [ULog e:TAG msg:@"pdraw_open_response error status: %d", status];
    if (this.pdrawState == SdkCorePdrawStateOpening) {
        this.pdrawState = SdkCorePdrawStateClosing;
        [this streamClosing];
    }
    if (this.pdrawState == SdkCorePdrawStateClosing) {
        this.pdrawState = SdkCorePdrawStateClosed;
        [this streamClosed];
    }
}

/**
 Stream close request callback.
 @param pdraw: Pdraw handle.
 @param status: 0 on success, a negative error code otherwise.
 @param userdata: SdkCoreStream instance.
 */
static void pdraw_close_response(struct pdraw *pdraw, int status, void *userdata) {
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return;
    }

    if (status != 0) {
        [ULog e:TAG msg:@"pdraw_close_response error status: %d", status];
        return;
    }
    if (this.pdrawState != SdkCorePdrawStateClosing) {
        // do nothing
        return;
    }
    this.pdrawState = SdkCorePdrawStateClosed;
    [this streamClosed];
}

/**
 Stream error callback.
 @param pdraw: Pdraw handle.
 @param userdata: SdkCoreStream instance.
 */
static void pdraw_error(struct pdraw *pdraw, void *userdata) {
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return;
    }

    [ULog e:TAG msg:@"pdraw_error unrecoverable error"];
    if ((this.pdrawState != SdkCorePdrawStateOpen)
        && (this.pdrawState != SdkCorePdrawStateOpening)) {
        // do nothing
        return;
    }
    [this closeStream];
}

/**
 Stream track select callback.
 @param pdraw: Pdraw handle.
 @param medias: availabled tracks.
 @param count: number of availabled tracks.
 @param userdata: SdkCoreStream instance.
 @return selected track id, 0 to select default track, a negative error code otherwise.
 */
static int pdraw_media_select(struct pdraw *pdraw, const struct pdraw_demuxer_media *medias,  size_t count,
                              void *userdata) {
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return -EINVAL;
    }

    if ((this.track == nil) || ([this.track isEqualToString:@""])) {
         return 0;  // let PDRAW select default track if possible
    }

    // select thermal video track if available
    for (int i =0; i < count; i++) {
        if ([this.track isEqualToString:[NSString stringWithUTF8String:medias[i].name]]) {
            [ULog d:TAG msg:@"pdraw_media_select found: %s, id: %d", medias[i].name, medias[i].media_id];
            return medias[i].media_id;
        }
    }
    [ULog d:TAG msg:@"pdraw_media_select play default track"];
    return 0; // let pdraw play the default track
}

/**
 Stream availabiliy callback.
 @param pdraw: Pdraw handle.
 @param ready: 1 when playback is available, 0 otherwise.
 @param userdata: SdkCoreStream instance.
 */
static void pdraw_ready_to_play(struct pdraw *pdraw, int ready, void *userdata) {
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return;
    }

    if (ready) {
        if (this.pdrawState == SdkCorePdrawStateOpening) {
            this.pdrawState = SdkCorePdrawStateOpen;

            this.duration = pdraw_get_duration(pdraw) / 1000;
            this.position = 0;
            this.speed = 0;
            [this streamOpened];
            [this streamPlaybackStateChanged];
        }
    } else if (this.pdrawState == SdkCorePdrawStateOpen) {
        [this closeStream];
    }
}

/**
 Playback end of range callback.
 @param pdraw: Pdraw handle.
 @param timestamp: stream position.
 @param userdata: SdkCoreStream instance.
 */
static void pdraw_end_of_range(struct pdraw *pdraw, uint64_t timestamp, void *userdata) {
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return;
    }

    this.position = this.duration;
    this.speed = 0;
    [this streamPlaybackStateChanged];
}

/**
 Playback play request callback.
 @param pdraw: Pdraw handle.
 @param status: 0 on success, a negative error code otherwise.
 @param timestamp: stream position.
 @param speed: speed
 @param userdata: SdkCoreStream instance.
 */
static void pdraw_play_response(struct pdraw *pdraw, int status, uint64_t timestamp, float speed, void *userdata) {
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return;
    }

    if (status != 0) {
        [ULog e:TAG msg:@"pdraw_play_response error status: %d", status];
        return;
    }
    if (this.pdrawState != SdkCorePdrawStateOpen) {
        // do nothing
        return;
    }
    this.position = timestamp / 1000;
    this.speed = 1;
    [this streamPlaybackStateChanged];
}

/**
 Playback pause request callback.
 @param pdraw: Pdraw handle.
 @param status: 0 on success, a negative error code otherwise.
 @param timestamp: stream position.
 @param userdata: SdkCoreStream instance.
 */
static void pdraw_pause_response(struct pdraw *pdraw, int status, uint64_t timestamp, void *userdata) {
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return;
    }

    if (status != 0) {
        [ULog e:TAG msg:@"pdraw_pause_response error status: %d", status];
        return;
    }
    if (this.pdrawState != SdkCorePdrawStateOpen) {
        // do nothing
        return;
    }
    this.position = timestamp / 1000;
    this.speed = 0;
    [this streamPlaybackStateChanged];
}

/**
 Playback seek request callback.
 @param pdraw: Pdraw handle.
 @param status: 0 on success, a negative error code otherwise.
 @param timestamp: stream position.
 @param speed: speed.
 @param userdata: SdkCoreStream instance.
 */
static void pdraw_seek_response(struct pdraw *pdraw, int status, uint64_t timestamp, float speed, void *userdata) {
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return;
    }

    if (status != 0) {
        [ULog e:TAG msg:@"pdraw_seek_response error status: %d", status];
        return;
    }
    if (this.pdrawState != SdkCorePdrawStateOpen) {
        // do nothing
        return;
    }
    this.position = timestamp / 1000;
    [this streamPlaybackStateChanged];
}

/**
 Media added callback.
 @param pdraw: Pdraw handle.
 @param info: added media info.
 @param userdata: SdkCoreStream instance.
 */
static void pdraw_media_added(struct pdraw *pdraw, const struct pdraw_media_info *info, void *userdata)
{
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return;
    }

    if (info == nil) {
        [ULog e:TAG msg:@"pdraw_media_added invalid parameter"];
        return;
    }

    [this mediaAdded:info];
}

/**
 Media removed callback.
 @param pdraw: Pdraw handle.
 @param info: removed media info.
 @param userdata: SdkCoreStream instance.
 */
static void pdraw_media_removed(struct pdraw *pdraw, const struct pdraw_media_info *info, void *userdata)
{
    SdkCoreStream *this = (__bridge SdkCoreStream *)(userdata);
    if (this == nil) {
        return;
    }

    if (info == nil) {
        [ULog e:TAG msg:@"pdraw_media_removed invalid parameter"];
        return;
    }

    [this mediaRemoved:info];
}

/** Pdraw callbacks */
static const struct pdraw_cbs s_pdraw_cbs = {
    .open_resp = &pdraw_open_response,
    .close_resp = &pdraw_close_response,
    .unrecoverable_error = &pdraw_error,
    .select_demuxer_media = &pdraw_media_select,
    .ready_to_play = &pdraw_ready_to_play,
    .end_of_range = &pdraw_end_of_range,
    .play_resp = &pdraw_play_response,
    .pause_resp = &pdraw_pause_response,
    .seek_resp = &pdraw_seek_response,
    .media_added = &pdraw_media_added,
    .media_removed = &pdraw_media_removed,
    .socket_created = NULL
};

@implementation SdkCoreStream

/** Destroy pdraw instance. */
- (void) destroyPdraw {
    [_source close];
    if (_pdraw != NULL) {
        pdraw_destroy(_pdraw);
        _pdraw = NULL;
    }
    _pdrawState = SdkCorePdrawStateClosed;
}

/**
 Create a pdraw instance and open the stream.
 */
- (int) createPdraw {
    self.pdrawState = SdkCorePdrawStateClosed;

    int res = pdraw_new([_pompLoopUtil internalPompLoop], &s_pdraw_cbs, (__bridge void*)self, &_pdraw);
    if (res < 0) {
        [ULog e:TAG msg:@"pdraw_new failed: %s", strerror(-res)];
        return res;
    }

    self.pdrawState = SdkCorePdrawStateOpening;
    res = [_source open:_pdraw];

    if (res != 0) {
        [self destroyPdraw];
    }

    return res;
}

- (instancetype _Nullable)initWithPompLoopUtil:(PompLoopUtil * _Nonnull)pompLoopUtil
                                        source:(id<SdkCoreSource> _Nonnull)source
                                         track:(NSString * _Nullable)track
                                      listener:(id<SdkCoreStreamListener> _Nonnull)listener {
    self = [super init];
    if (self) {
        self.pompLoopUtil = pompLoopUtil;
        self.listener = listener;
        self.source = source;
        self.pdraw = NULL;
        self.pdrawState = SdkCorePdrawStateClosed;
        self.state = SdkCoreStreamStateIdle;
        self.closeReason = SdkCoreStreamCloseNone;
        self.duration = 0;
        self.position = 0;
        self.speed = 0;
        self.track = track;
   }
    return self;
}

/** Create pdraw instance and open the stream. */
- (void) open {
    if (_state != SdkCoreStreamStateIdle) {
        [ULog e:TAG msg:@"SdkCoreStream open failed, invalid state: %ld", (long)_state];
        return;
    }
    _state = SdkCoreStreamStateOpening;
    [_pompLoopUtil dispatch:^{
        NSAssert(self.pdraw == NULL, @"invalid state: %ld", (long)self.state);
        int res = [self createPdraw];
        if (res < 0) {
            [ULog e:TAG msg:@"SdkCoreStream createPdraw failed: %s", strerror(-res)];
            [self streamClosing];
            [self streamClosed];
        }
    }];
}

/** Close the stream. */
- (void) closeStream {
    if (self.pdraw == nil) {
        return;
    }
    if ((self.pdrawState != SdkCorePdrawStateOpen)
        && (self.pdrawState != SdkCorePdrawStateOpening)) {
        return;
    }

    int res = pdraw_close(self.pdraw);
    if (res < 0) {
        [ULog e:TAG msg:@"SdkCoreStream pdraw_close failed: %s", strerror(-res)];
    } else {
        self.pdrawState = SdkCorePdrawStateClosing;
        [self streamClosing];
    }
}

/** Play the stream. */
- (void) play {
    [_pompLoopUtil dispatch:^{
        int res = pdraw_play(self.pdraw);
        if (res < 0) {
            [ULog e:TAG msg:@"SdkCoreStream pdraw_play failed: %s", strerror(-res)];
        }
    }];
}

/** Pause the stream. */
- (void) pause {
    [_pompLoopUtil dispatch:^{
        int res = pdraw_pause(self.pdraw);
        if (res < 0) {
            [ULog e:TAG msg:@"SdkCoreStream pdraw_pause failed: %s", strerror(-res)];
        }
    }];
}

/**
 Change current time position in the stream.

 @param position: time position, in milliseconds.
 */
- (void)seekTo:(int)position {
    [_pompLoopUtil dispatch:^{
        int res = pdraw_seek_to(self.pdraw, position*1000, true);
        if (res < 0) {
            [ULog e:TAG msg:@"SdkCoreStream pdraw_seek_to failed: %s", strerror(-res)];
        }
    }];
}


/**
 Close the stream.

 @param reason: reason why the stream is closed.
 */
- (void) close:(SdkCoreStreamCloseReason)reason {
    switch (_state) {
        case SdkCoreStreamStateIdle:
            _state = SdkCoreStreamStateClosed;
            [_listener streamDidClosing:self reason:reason];
            [_listener streamDidClose:self reason:reason];
            break;
        case SdkCoreStreamStateClosed:
            [ULog e:TAG msg:@"SdkCoreStream close, invalid state SdkCoreStreamStateClosed"];
            break;
        case SdkCoreStreamStateOpen:
        case SdkCoreStreamStateOpening:
            _state = SdkCoreStreamStateClosed;
            [_pompLoopUtil dispatch:^{
                if (self.pdraw != nil && self.closeReason == SdkCoreStreamCloseNone) {
                    self.closeReason = reason;
                    [self closeStream];
                }
            }];
            break;
    }
}

/**
 Start renderer.
 Must be called in the GL thread.

 @param renderZone: rendering area.
 @param fillMode: rendering fill mode.
 @param zebrasEnabled: 'true' to enable the zebras of overexposure zone.
 @param zebrasThreshold: threshold of overexposure used by zebras, used by zebras, in range [0.0, 1.0].
                         '0.0' for the maximum of zebras and '1.0' for the minimum.
 @param textureWidth: texture width in pixels, unused if 'textureLoaderlistener' is nil.
 @param textureDarWidth: texture aspect ratio width, unused if 'textureLoaderlistener' is nil.
 @param textureDarHeight: texture aspect ratio height, unused if 'textureLoaderlistener' is nil.
 @param textureLoaderlistener: texture loader listener.
 @param histogramsEnabled: 'true' to enable histograms computation.
 @param overlayListener: overlay rendering listener.
 @param listener: renderer listener.
 */
- (SdkCoreRenderer* _Nullable)startRendererWithZone:(CGRect)renderZone
                                           fillMode:(SdkCoreStreamRenderingFillMode)fillMode
                                      zebrasEnabled:(BOOL)zebrasEnabled zebrasThreshold:(float)zebrasThreshold
                                       textureWidth:(int)textureWidth
                                    textureDarWidth:(int)textureDarWidth textureDarHeight:(int)textureDarHeight
                              textureLoaderlistener:(id<SdkCoreTextureLoaderListener> _Nullable)textureLoaderlistener
                                  histogramsEnabled:(BOOL)histogramsEnabled
                                    overlayListener:(id<SdkCoreRendererOverlayListener> _Nonnull)overlayListener
                                           listener:(id<SdkCoreRendererListener> _Nonnull)listener {
    //syncro
    return [[SdkCoreRenderer alloc] initWithPdraw: _pdraw
                                             zone:renderZone
                                         fillMode:fillMode
                                    zebrasEnabled:zebrasEnabled zebrasThreshold:zebrasThreshold
                                     textureWidth:(int)textureWidth textureDarWidth:(int)textureDarWidth textureDarHeight:(int)textureDarHeight
                            textureLoaderlistener:textureLoaderlistener
                                histogramsEnabled:histogramsEnabled overlayListener:overlayListener
                                         listener:listener];
}

/**
 Starts stream sink.

 Must be called on main thread. Stream must be opened.

 @param sink:    sink to start
 @param mediaId: identifies the stream media to deliver to the sink
 */
- (void) startSink:(SdkCoreSink * _Nonnull) sink mediaId:(UInt32)mediaId {
    if (_state != SdkCoreStreamStateOpen) {
        [ULog e:TAG msg:@"SdkCoreStream startSink: Stream not open"];
        return;
    }
    [sink start:_pdraw pomp:_pompLoopUtil mediaId:mediaId];
}

/**
 Called when the stream has been opened.

 Send notification to listener and update stream duration.
 */
- (void) streamOpened {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.state = SdkCoreStreamStateOpen;
        [self.listener streamDidOpen:self];
    });
}

/**
 Called when the stream playback state changed.
 
 Send notification to listener.
 */
- (void) streamPlaybackStateChanged {
    NSTimeInterval timestamp = [[NSProcessInfo processInfo] systemUptime];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.state = SdkCoreStreamStateOpen;
        [self.listener streamPlaybackStateDidChange:self
                                           duration:self->_duration
                                           position:self->_position
                                              speed:self->_speed
                                          timestamp:timestamp];
    });
}

/**
 Called when the stream is closing.

 Send notification to listener.
 */
- (void) streamClosing {
    if (self.closeReason == SdkCoreStreamCloseNone) {
        self.closeReason = SdkCoreStreamCloseInternal;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.state = SdkCoreStreamStateClosed;
        [self.listener streamDidClosing:self reason:self.closeReason];
    });
}

/**
 Called when the stream has been closed.

 Destroy pdraw and send notification to listener.
 */
- (void) streamClosed {
    // cleanup pdraw
    [self destroyPdraw];

    if (self.closeReason == SdkCoreStreamCloseNone) {
        self.closeReason = SdkCoreStreamCloseInternal;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.state = SdkCoreStreamStateClosed;
        [self.listener streamDidClose:self reason:self.closeReason];
    });
}

- (void) mediaAdded:(const struct pdraw_media_info*)info {
    SdkCoreMediaInfo* mediaInfo = [SdkCoreMediaInfo createFromPdrawMediaInfo:(void*)info];
    if (mediaInfo != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.listener mediaAdded:self mediaInfo:mediaInfo];
        });
    }
}

- (void) mediaRemoved:(const struct pdraw_media_info*)info {
    SdkCoreMediaInfo* mediaInfo = [SdkCoreMediaInfo createFromPdrawMediaInfo:(void*)info];
    if (mediaInfo != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.listener mediaRemoved:self mediaInfo:mediaInfo];
        });
    }
}

@end
