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
#import "ArsdkCore.h"

// main loop timeout. Also define connection timeout. In seconds
#define ARSDKMUX_LOOP_TIMEOUT       1

struct arsdk_ctrl;
struct mux_ctx;
struct pomp_loop;

/**
 Delegate called when the mux start/stop
 */
@protocol ArsdkMuxDelegate
- (void)muxDidStart;
- (void)muxDidFail;
@end

/**
 * Wrapper on native mux.
 */
@interface ArsdkMux : NSObject

/** native mux context */
@property (nonatomic, assign, readonly) struct mux_ctx* mux;
/** mux input stream */
@property (nonatomic, strong, readonly) NSInputStream *inputStream;
/** mux output stream */
@property (nonatomic, strong, readonly) NSOutputStream *outputStream;

/**
 Constructor.

 Mux is created on closed input/output streams. Implementation open booth streams, calling muxDidStart
 when streams are successfully opened, or call muxDidFail if streams can't be opened, or when streams are closed

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
                      pomp_loop:(struct pomp_loop*)pomp_loop;

-(void) close;

@end
