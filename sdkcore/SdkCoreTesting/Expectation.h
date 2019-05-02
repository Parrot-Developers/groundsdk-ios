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
#import <XCTest/XCTest.h>
#import "ExpectedCmd.h"

struct arsdk_cmd;

typedef NS_ENUM(NSInteger, ExpectationAction) {
    ExpectationActionConnect,
    ExpectationActionDisconnect,
    ExpectationActionCommand,
    ExpectationActionMediaList,
    ExpectationActionMediaDownloadThumbnail,
    ExpectationActionMediaDownload,
    ExpectationActionMediaDelete,
    ExpectationActionUpdate,
    ExpectationActionFtpUpload,
    ExpectationActionCrashmlDownload,
    ExpectationActionFlightLogDownload,
    ExpectationActionStreamCreate,
    ExpectationActionStream
};

@interface Expectation : NSObject

@property (nonatomic, assign, readonly) ExpectationAction action;
@property (nonatomic, assign, readonly) int16_t handle;
@property (nonatomic, strong, readonly) NSString* _Nonnull file;
@property (nonatomic, assign, readonly) NSUInteger line;;

- (instancetype _Nonnull)initWithAction:(ExpectationAction)action
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
- (instancetype _Nonnull)initWithAction:(ExpectationAction)action
                        andDeviceHandle:(int16_t)handle
                                    inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
- (void)assertAction:(ExpectationAction)action
     andDeviceHandle:(int16_t)handle
          inTestCase:(XCTestCase* _Nonnull)testCase;
@end

@interface ConnectExpectation : Expectation
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
@end

@interface DisconnectExpectation : Expectation
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
@end

@interface CommandExpectation : Expectation
@property (nonatomic, strong, readonly) NSMutableSet<ExpectedCmd*>* _Nonnull expectedCmds;
@property (nonatomic, assign, readonly) BOOL checkParams;
- (instancetype _Nonnull )initWithHandle:(int16_t)handle
                            expectedCmds:(NSSet<ExpectedCmd*>* _Nonnull)expectedCmds
                             checkParams:(BOOL)checkParams
                                  inFile:(NSString* _Nonnull)file
                                  atLine:(NSUInteger)line;
- (BOOL)matchCommand:(struct arsdk_cmd* _Nonnull)command;
- (NSString* _Nonnull)description;
- (void)assertCommand:(struct arsdk_cmd* _Nonnull)command
           inTestCase:(XCTestCase* _Nonnull)testCase;
@end

@interface MediaListExpectation : Expectation
@property (nonatomic) ArsdkMediaListCompletion _Nonnull completion;
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                   inFile:(NSString* _Nonnull)file
                                   atLine:(NSUInteger)line;
@end

@interface MediaExpectation : Expectation
@property (nonatomic) _Nonnull id <ArsdkMedia> media;
- (instancetype _Nonnull)initWithAction:(ExpectationAction)action
                        andDeviceHandle:(int16_t)handle
                               andMedia:(_Nonnull id <ArsdkMedia>)media
                                   inFile:(NSString* _Nonnull)file
                                   atLine:(NSUInteger)line;
- (BOOL)matchMedia:(_Nonnull id<ArsdkMedia>)media;
- (NSString* _Nonnull)description;
- (void)assertMedia:(_Nonnull id<ArsdkMedia>)media
         inTestCase:(XCTestCase* _Nonnull)testCase;
@end

@interface MediaDownloadThumbnailExpectation : MediaExpectation
@property (nonatomic) ArsdkMediaDownloadThumbnailCompletion _Nonnull completion;
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                               andMedia:(_Nonnull id <ArsdkMedia>)media
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
@end

@interface MediaDownloadExpectation : MediaExpectation
@property (nonatomic) ArsdkMediaResourceFormat format;
@property (nonatomic) ArsdkMediaDownloadProgress _Nonnull progress;
@property (nonatomic) ArsdkMediaDownloadCompletion _Nonnull completion;
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                               andMedia:(_Nonnull id <ArsdkMedia>)media
                              andFormat:(ArsdkMediaResourceFormat)format
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
- (BOOL)matchMedia:(_Nonnull id<ArsdkMedia>)media andFormat:(ArsdkMediaResourceFormat)format;
- (NSString* _Nonnull)description;
- (void)assertMedia:(_Nonnull id<ArsdkMedia>)media
          andFormat:(ArsdkMediaResourceFormat)format
         inTestCase:(XCTestCase* _Nonnull)testCase;
@end

@interface MediaDeleteExpectation : MediaExpectation
@property (nonatomic) ArsdkMediaDeleteCompletion _Nonnull completion;
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                               andMedia:(_Nonnull id <ArsdkMedia>)media
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
@end

@interface UpdateExpectation : Expectation
@property (nonatomic) NSString * _Nonnull fwPath;
@property (nonatomic) ArsdkUpdateProgress _Nonnull progress;
@property (nonatomic) ArsdkUpdateCompletion _Nonnull completion;
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                            andFirmware:(NSString* _Nonnull)filepath
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
- (BOOL)matchFirmware:(NSString* _Nonnull)filepath;
- (NSString* _Nonnull)description;
- (void)assertFirmware:(NSString* _Nonnull)filepath
         inTestCase:(XCTestCase* _Nonnull)testCase;
@end

@interface FtpUploadExpectation : Expectation
@property (nonatomic) NSString * _Nonnull srcPath;
@property (nonatomic) NSString * _Nullable  dstPath;
@property (nonatomic) ArsdkFtpRequestProgress _Nonnull progress;
@property (nonatomic) ArsdkFtpRequestCompletion _Nonnull completion;
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                srcPath:(NSString* _Nonnull)srcPath
                                dstPath:(NSString* _Nullable)dstPath
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
- (BOOL)matchSrcPath:(NSString* _Nonnull)srcPath
            dstPath:(NSString* _Nullable)dstPath;
- (NSString* _Nonnull)description;
- (void)assertSrcPath:(NSString* _Nonnull)srcPath
             dstPath:(NSString* _Nullable)dstPath
            inTestCase:(XCTestCase* _Nonnull)testCase;
@end

@interface CrashmlDownloadExpectation : Expectation
@property (nonatomic) ArsdkCrashmlDownloadProgress _Nonnull progress;
@property (nonatomic) ArsdkCrashmlDownloadCompletion _Nonnull completion;
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
@end

@interface FlightLogDownloadExpectation : Expectation
@property (nonatomic) ArsdkFlightLogDownloadProgress _Nonnull progress;
@property (nonatomic) ArsdkFlightLogDownloadCompletion _Nonnull completion;
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
@end

@interface StreamCreateExpectation : Expectation
- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line;
@end
