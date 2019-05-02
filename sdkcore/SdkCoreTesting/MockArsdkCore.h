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
#import <SdkCore/Arsdk.h>
#import <XCTest/XCTest.h>
#import "Expectation.h"

struct arsdk_cmd;

@interface MockArsdkStream : ArsdkStream

@property (nonatomic, strong) id<SdkCoreStreamListener> _Nonnull listener;
@property (nonatomic) int32_t openCnt;
@property (nonatomic) int32_t playCnt;
@property (nonatomic) int32_t pauseCnt;
@property (nonatomic) int32_t closeCnt;

- (void) mockStreamOpen;
- (void) mockStreamPlayState:(int64_t)duration
                    position:(int64_t)position
                       speed:(double)speed
                   timestamp:(NSTimeInterval)timestamp;
- (void) mockStreamClosing:(SdkCoreStreamCloseReason)reason;
- (void) mockStreamClose:(SdkCoreStreamCloseReason)reason;

@end

@interface MockArsdkCore : ArsdkCore

@property (nonatomic, strong) XCTestCase * _Nonnull testCase;
@property (nonatomic, strong) NSString * _Nullable latestFtpUploadedFilePath;

- (void)addDevice:(NSString* _Nonnull)uid type:(NSInteger)type backendType:(ArsdkBackendType)backendType
             name:(NSString* _Nonnull)name handle:(int16_t)handle;

- (void)removeDevice:(int16_t)handle;

- (void)deviceConnecting:(int16_t)handle;

- (void)deviceConnected:(int16_t)handle;

- (void)deviceDisconnected:(int16_t)handle removing:(BOOL)removing;

- (void)deviceConnectingCancel:(int16_t)handle reason:(ArsdkConnCancelReason)reason removing:(BOOL)removing;

- (void)deviceLinkStatusChanged:(int16_t)handle status:(NSInteger)status;

- (void)mockNonAckLoop:(int16_t)handle noAckType:(ArsdkNoAckCmdType)noAckType inFile:(NSString* _Nonnull)file
                atLine:(NSUInteger)line;

- (void)onCommandReceived:(int16_t)handle encoder:(int (^ _Nonnull)(struct arsdk_cmd * _Nonnull))encoder;

- (void)expect:(Expectation* _Nonnull)expectation;

- (void)assertNoExpectationInFile:(NSString* _Nonnull)file atLine:(NSUInteger)line;

- (MockArsdkStream * _Nullable)getVideoStream;

@end


@interface MockMediaListRequest: ArsdkRequest
@property (nonatomic, strong) ArsdkMediaListCompletion _Nonnull completionBlock;
@end

@interface MockMediaDownloadThumbnailRequest: ArsdkRequest
@property (nonatomic, strong) ArsdkMediaDownloadThumbnailCompletion _Nonnull completionBlock;
@end

@interface MockMediaDownloadRequest: ArsdkRequest
@property (nonatomic, strong) ArsdkMediaDownloadProgress _Nonnull progressBlock;
@property (nonatomic, strong) ArsdkMediaDownloadCompletion _Nonnull completionBlock;
@end

@interface MockMediaDeleteRequest: ArsdkRequest
@property (nonatomic, strong) ArsdkMediaDeleteCompletion _Nonnull completionBlock;
@end

@interface MockUpdateRequest: ArsdkRequest
@property (nonatomic, strong) ArsdkUpdateProgress _Nonnull progressBlock;
@property (nonatomic, strong) ArsdkUpdateCompletion _Nonnull completionBlock;
@end

@interface MockFtpUploadRequest: ArsdkRequest
@property (nonatomic, strong) ArsdkFtpRequestProgress _Nonnull progressBlock;
@property (nonatomic, strong) ArsdkFtpRequestCompletion _Nonnull completionBlock;
@end

@interface MockCrashmlDownloadRequest: ArsdkRequest
@property (nonatomic, strong) ArsdkCrashmlDownloadProgress _Nonnull progressBlock;
@property (nonatomic, strong) ArsdkCrashmlDownloadCompletion _Nonnull completionBlock;
@end

@interface MockFlightLogDownloadRequest: ArsdkRequest
@property (nonatomic, strong) ArsdkFlightLogDownloadProgress _Nonnull progressBlock;
@property (nonatomic, strong) ArsdkFlightLogDownloadCompletion _Nonnull completionBlock;
@end

@interface MockArsdkMediaResource: NSObject
@property (nonatomic) NSString *_Nonnull uid;
@property (nonatomic) ArsdkMediaResourceFormat format;
@property (nonatomic) size_t size;
- (instancetype _Nonnull)initWithUid:(NSString *_Nonnull)uid format:(ArsdkMediaResourceFormat)format size:(size_t)size;
@end

@interface MockArsdkMedia: NSObject <ArsdkMedia>
@property (nonatomic) NSString * _Nonnull name;
@property (nonatomic) ArsdkMediaType type;
@property (nonatomic) NSString * _Nonnull runUid;
@property (nonatomic) NSDate * _Nonnull creationDate;
@property (nonatomic) NSArray<MockArsdkMediaResource*> * _Nonnull resources;
@end

@interface MockArsdkMediaList : NSObject <ArsdkMediaList>
@property (nonatomic) int pos;
@property (nonatomic) NSArray<MockArsdkMedia*> * _Nonnull list;
- (instancetype _Nullable)initWithList:(NSArray<MockArsdkMedia*> * _Nonnull)list;
@end
