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
#import "ArsdkCore+Stream.h"
#import "ArsdkCore+Source.h"

@interface ArsdkStream()

/**
 Create a native video stream.

 @param arsdkCore: Arsdk controller
 @param deviceHandle: device handle
 @param url: stream url
 @param track: name of the track of the stream
 @param listener: a listener that will be called when events happen on the stream
 */
- (instancetype _Nullable)initWithArsdkCore:(ArsdkCore * _Nonnull)arsdkCore
                               deviceHandle:(short)deviceHandle
                                        url:(NSString * _Nonnull)url
                                      track:(NSString * _Nullable)track
                                   listener:(id<SdkCoreStreamListener> _Nonnull)listener;

@end

@implementation ArsdkStream

- (instancetype _Nullable)initWithArsdkCore:(ArsdkCore * _Nonnull)arsdkCore
                               deviceHandle:(short)deviceHandle
                                        url:(NSString * _Nonnull)url
                                      track:(NSString * _Nullable)track
                                   listener:(id<SdkCoreStreamListener> _Nonnull)listener {
    ArsdkSource *source = [[ArsdkSource alloc] initWithArsdkCore:arsdkCore deviceHandle:deviceHandle url:url];
    return [super initWithPompLoopUtil:[arsdkCore pompLoopUtil] source:source track:track listener:listener];
}

@end

@implementation ArsdkCore (Stream)

- (ArsdkStream* _Nonnull)createVideoStream:(int16_t)handle
                                       url:(NSString * _Nonnull)url
                                     track:(NSString * _Nullable)track
                                  listener:(id<SdkCoreStreamListener> _Nonnull)listener {
    [self assertCallerThread];
    return [[ArsdkStream alloc] initWithArsdkCore:self deviceHandle:handle url:url track:track listener:listener];
}

@end
