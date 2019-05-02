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

#import "ArsdkMux.h"
#import "ArsdkCore+Internal.h"
#import "PompBuffer.h"
#import "Logger.h"
#include <libmux.h>

// input stream read size
#define READ_BUFFER_SIZE       65536

extern ULogTag* TAG;

typedef NS_ENUM(NSUInteger, State) {
    Starting,
    Running,
    Failed,
    StopRequested
};


@interface ArsdkMux () <NSStreamDelegate>
@property (nonatomic, weak) id<ArsdkMuxDelegate> delegate;
@property (nonatomic, strong) ArsdkCore* arsdkCore;
@property (atomic) State state;
@property (nonatomic) struct pomp_loop* pomp_loop;
@property (nonatomic, strong) NSThread *streamThread;
@property (nonatomic, strong) PompBufferQueue *bufferQueue;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSRunLoop *runLoop;
@end

@implementation ArsdkMux

/**
 Constructor.

 Mux is created on closed input/output streams. Implementation managed opening the stream, calling muxDidStart
 when streams are successfully open, or call muxDidFail if streams can't be opened, or when stream are closed

 @param delegate: mux delegate
 @param arsdkCore: arsdkCore instance
 @param inputStream: stream to read muxed data from
 @param outputStream: stream to write muxed data to
 @param pomp_loop: arsdk pomp loop
 */
-(instancetype)initWithDelegate:(id<ArsdkMuxDelegate>)delegate
                      arsdkCore:(ArsdkCore*)arsdkCore
                    inputStream:(NSInputStream*)inputStream
                   outputStream:(NSOutputStream*)outputStream
                      pomp_loop:(struct pomp_loop*)pomp_loop {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _arsdkCore = arsdkCore;
        _state = Starting;
        _inputStream = inputStream;
        _outputStream = outputStream;
        _pomp_loop = pomp_loop;
        _bufferQueue = [[PompBufferQueue alloc] init];
        _streamThread = [[NSThread alloc] initWithTarget:self selector:@selector(streamThreadRun) object:nil];
        _streamThread.name = @"ArsdkMux";
        [_streamThread start];
    }
    return self;
}

-(void) close {
    if ( self.state != StopRequested) {
        self.state = StopRequested;
    }
}

#pragma streamThread

/**
 Thread that run the stream runloop
 */
- (void)streamThreadRun {
    self.runLoop = [NSRunLoop currentRunLoop];
    // init and open streams
    [_inputStream setDelegate:self];
    [_inputStream scheduleInRunLoop:self.runLoop forMode:NSDefaultRunLoopMode];
    [_inputStream open];
    [_outputStream setDelegate:self];
    [_outputStream scheduleInRunLoop:self.runLoop forMode:NSDefaultRunLoopMode];
    [_outputStream open];

    // main loop, with timeout
    do {
        [self.runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:ARSDKMUX_LOOP_TIMEOUT]];
    } while(_state == Running);

    // if an error occurs in the "stream events handler" or if a Stop is requested, unref the _mux if necessary
    if (_mux != nil) {
        [_arsdkCore dispatch_sync:^{
            mux_stop(self.mux);
            mux_unref(self.mux);
        }];
        _mux = nil;
    }
    [self cleanUp];
}

/**
 Close streams and remove from runLoop
 */
- (void)cleanUp {
    // cleanup
    [_inputStream close];
    [_inputStream removeFromRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
    [_inputStream setDelegate:nil];
    _inputStream = nil;

    [_outputStream close];
    [_outputStream  removeFromRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
    [_outputStream  setDelegate:nil];
    _outputStream = nil;
}

/**
 handle stream event. Called in the streamThread
 */
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if (eventCode & NSStreamEventErrorOccurred || eventCode & NSStreamEventEndEncountered) {
        // _mux will be unref when exiting the run loop
        [self muxDidFail];
    } else if (eventCode & NSStreamEventOpenCompleted) {
        // open
        if (_mux == nil && _inputStream.streamStatus == NSStreamStatusOpen &&
            _outputStream.streamStatus == NSStreamStatusOpen) {

            struct mux_ops ops;
            memset(&ops, 0, sizeof(ops));
            ops.tx = libmux_mux_ops_tx_callback;
            ops.release = libmux_mux_ops_release_callback;
            ops.userdata = (__bridge_retained void *)self;
            _mux = mux_new(-1, _pomp_loop, &ops, 0);
            if (_mux != nil) {
                [self muxDidStart];
            } else {
                [self muxDidFail];
            }
        }
    } else {
        if (eventCode & NSStreamEventHasBytesAvailable) {
            // read
            if (_mux != nil) {
                [self read];
            }
        }
        if (eventCode & NSStreamEventHasSpaceAvailable) {
            // write
            if (_mux != nil) {
                [self writeNextBuffer];
            }
        }
    }
}

/**
 Notify mux did start
 */
- (void)muxDidStart {
    if (_state != Running) {
        _state = Running;
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.delegate muxDidStart];
        });
    }
}

/**
 Notify mux did fail
 */
- (void)muxDidFail {
    if (_state != Failed) {
        _state = Failed;
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.delegate muxDidFail];
        });
    }
}

/**
 Queue a new buffer and trig write
 */
- (void)queueAndWriteBuffer:(PompBuffer*)buf {
    [_bufferQueue queueBuffer:buf];
    [self writeNextBuffer];
}

/**
 Write the next buffer of the queue
*/
- (void)writeNextBuffer {
    while (_bufferQueue.first != NULL && _outputStream.hasSpaceAvailable) {
        // get first buffer data, compute size to write
        NSData* data = [_bufferQueue.first getAsData];
        NSUInteger pos = _bufferQueue.firstBufOffset;
        NSUInteger len = data.length - pos;

        NSInteger written = [_outputStream write:[data subdataWithRange:NSMakeRange(pos, len)].bytes maxLength:len];
        if (written < 0) {
            // error. Will be handled in the main handle event loop
            return;
        } else {
            if (written != len) {
                _bufferQueue.firstBufOffset += written;
            } else {
                [_bufferQueue dequeue];
            }
        }
    }
}

/**
 Read from the input stream
 */
- (void)read {
    while (_inputStream.hasBytesAvailable) {
        void *data = NULL;
        struct pomp_buffer *buf = pomp_buffer_new_get_data(READ_BUFFER_SIZE, &data);
        NSInteger bytesRead = [_inputStream read:(uint8_t *)data maxLength:READ_BUFFER_SIZE];
        pomp_buffer_set_len(buf, (size_t)bytesRead);
        [_arsdkCore dispatch:^{
            int res = mux_decode(self->_mux, buf);
            if (res != 0) {
                [ULog e:TAG msg:@"ArsdkMux mux_decode %s", strerror(-res)];
            }
            pomp_buffer_unref(buf);
        }];
    }
}

// tx callback - called by the mux when there is data to write to the output stream
// called in the pomp loop thread
static int libmux_mux_ops_tx_callback(struct mux_ctx *ctx, struct pomp_buffer *buf, void *userdata) {
    ArsdkMux *this = (__bridge ArsdkMux *)(userdata);
    [this performSelector:@selector(queueAndWriteBuffer:)
                 onThread:this.streamThread withObject:[[PompBuffer alloc]init:buf] waitUntilDone:NO];
    return 0;
}

static void libmux_mux_ops_release_callback(struct mux_ctx *ctx, void *userdata) {
    (void)(__bridge_transfer ArsdkMux *)userdata;
}

- (void)dealloc
{
    [self cleanUp];
}
@end
