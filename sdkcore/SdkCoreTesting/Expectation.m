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

#import "Expectation.h"
#import "ArsdkCore.h"
#import <XCTest/XCTestCase.h>

static NSString* _Nonnull expectationActionStr(ExpectationAction action) {
    switch (action) {
        case ExpectationActionConnect: return @"Connect";
        case ExpectationActionDisconnect: return @"Disconnect";
        case ExpectationActionCommand:  return @"Command";
        case ExpectationActionMediaList: return @"MediaList";
        case ExpectationActionMediaDownloadThumbnail: return @"MediaDownloadThumbnail";
        case ExpectationActionMediaDownload: return @"MediaDownload";
        case ExpectationActionMediaDelete: return @"MediaDelete";
        case ExpectationActionUpdate: return @"Update";
        case ExpectationActionFtpUpload: return @"FtpUpload";
        case ExpectationActionCrashmlDownload:return @"CrashmlDownload";
        case ExpectationActionFlightLogDownload:return @"FlightLogDownload";
        case ExpectationActionStreamCreate:return @"StreamCreate";
        case ExpectationActionStream:return @"Stream";
    }
    return @"Unknown";
}

@implementation Expectation

- (instancetype)initWithAction:(ExpectationAction)action {
    self = [super init];
    if (self) {
        _action = action;
        _handle = ARSDK_INVALID_DEVICE_HANDLE;
    }
    return self;
}

- (instancetype)initWithAction:(ExpectationAction)action
               andDeviceHandle:(int16_t)handle {
    self = [super init];
    if (self) {
        _action = action;
        _handle = handle;
    }
    return self;
}

- (instancetype)initWithAction:(ExpectationAction)action
                        inFile:(NSString*)file
                        atLine:(NSUInteger)line {
    self = [super init];
    if (self) {
        _action = action;
        _handle = ARSDK_INVALID_DEVICE_HANDLE;
        _file = file;
        _line = line;
    }
    return self;
}

- (instancetype)initWithAction:(ExpectationAction)action
               andDeviceHandle:(int16_t)handle
                          inFile:(NSString*)file
                        atLine:(NSUInteger)line {
    self = [super init];
    if (self) {
        _action = action;
        _handle = handle;
        _file = file;
        _line = line;
    }
    return self;
}

- (void)assertAction:(ExpectationAction)action
     andDeviceHandle:(int16_t)handle
          inTestCase:(XCTestCase* _Nonnull)testCase {
    if (_action != action) {
        NSString* error = [NSString stringWithFormat:@"expected action %@, got %@",
                                expectationActionStr(_action), expectationActionStr(action)];
        [testCase recordFailureWithDescription:error inFile:_file atLine:_line expected:YES];
    } else if (_handle != handle) {
        NSString* error = [NSString stringWithFormat:@"expected device handle %hd, got %hd", _handle, handle];
        [testCase recordFailureWithDescription:error inFile:_file atLine:_line expected:YES];
    }
}
@end

@implementation ConnectExpectation : Expectation

- (instancetype)initWithHandle:(int16_t)handle inFile:(NSString* _Nonnull)file atLine:(NSUInteger)line{
    return [super initWithAction:ExpectationActionConnect andDeviceHandle:handle inFile:file atLine:line];
 }
@end

@implementation DisconnectExpectation : Expectation

- (instancetype)initWithHandle:(int16_t)handle inFile:(NSString* _Nonnull)file atLine:(NSUInteger)line{
    return [super initWithAction:ExpectationActionDisconnect andDeviceHandle:handle inFile:file atLine:line];
}
@end


@implementation CommandExpectation : Expectation

- (instancetype)initWithHandle:(int16_t)handle
                  expectedCmds:(NSSet<ExpectedCmd*>* _Nonnull)expectedCmds
                   checkParams:(BOOL)checkParams
                          inFile:(NSString*)file
                        atLine:(NSUInteger)line {
    self = [super initWithAction:ExpectationActionCommand andDeviceHandle:handle inFile:file atLine:line];
    if (self) {
        _checkParams = checkParams;
        _expectedCmds = expectedCmds.mutableCopy;
    }
    return self;
}

- (BOOL)matchCommand:(struct arsdk_cmd*)command {
    for(ExpectedCmd* expectedCommand in _expectedCmds) {
        if ([expectedCommand match:command checkParams:_checkParams]) {
            [_expectedCmds removeObject:expectedCommand];
            return true;
        }
    }
    return false;
}

- (NSString*)description {
    NSMutableArray<NSString*>* expectedCmsDescription = [NSMutableArray arrayWithCapacity:_expectedCmds.count];
    for(ExpectedCmd* expectedCommand in _expectedCmds) {
        [expectedCmsDescription addObject:[expectedCommand describe]];
    }
    return [NSString stringWithFormat: @"commands %@", expectedCmsDescription];
}

- (void)assertCommand:(struct arsdk_cmd*)command
           inTestCase:(XCTestCase* _Nonnull)testCase {
    if (![self matchCommand:command]) {
        NSString* error = [NSString stringWithFormat:@"expect %@, got %@", self.description,
                           [ArsdkCommand describe:command]];
        [testCase recordFailureWithDescription:error inFile:self.file atLine:self.line expected:YES];
        [_expectedCmds removeAllObjects];
    }
}
@end

@implementation MediaListExpectation
- (instancetype)initWithHandle:(int16_t)handle
                        inFile:(NSString* _Nonnull)file
                        atLine:(NSUInteger)line{
    return [super initWithAction:ExpectationActionMediaList andDeviceHandle:handle inFile:file atLine:line];
}
@end

@implementation MediaExpectation
- (instancetype)initWithAction:(ExpectationAction)action
               andDeviceHandle:(int16_t)handle
                      andMedia:(id<ArsdkMedia>)media
                        inFile:(NSString* _Nonnull)file
                        atLine:(NSUInteger)line{
    self = [super initWithAction:action andDeviceHandle:handle inFile:file atLine:line];
    if (self) {
        _media = media;
    }
    return self;
}

- (BOOL)matchMedia:(_Nonnull id<ArsdkMedia>)media {
    return [_media getName] == [media getName] ;
}

- (NSString* _Nonnull)description {
    return [NSString stringWithFormat: @"media %@", [_media getName]];
}

- (void)assertMedia:(_Nonnull id<ArsdkMedia>)media
         inTestCase:(XCTestCase* _Nonnull)testCase {
    if (![self matchMedia:media]) {
        NSString* error = [NSString stringWithFormat:@"expect %@, got %@", self.description, [media getName]];
        [testCase recordFailureWithDescription:error inFile:self.file atLine:self.line expected:YES];
    }
}
@end


@implementation MediaDownloadThumbnailExpectation
- (instancetype)initWithHandle:(int16_t)handle
                      andMedia:(id<ArsdkMedia>)media
                        inFile:(NSString* _Nonnull)file
                        atLine:(NSUInteger)line {
    return [super initWithAction:ExpectationActionMediaDownloadThumbnail andDeviceHandle:handle andMedia:media
                          inFile:file atLine:line];
}
@end

@implementation MediaDownloadExpectation

- (instancetype)initWithHandle:(int16_t)handle
                      andMedia:(id<ArsdkMedia>)media
                     andFormat:(ArsdkMediaResourceFormat)format
                        inFile:(NSString* _Nonnull)file
                        atLine:(NSUInteger)line {
    self = [super initWithAction:ExpectationActionMediaDownload andDeviceHandle:handle andMedia:media
                          inFile:file atLine:line];
    if (self) {
        _format = format;
    }
    return self;
}

- (BOOL)matchMedia:(_Nonnull id<ArsdkMedia>)media andFormat:(ArsdkMediaResourceFormat)format {
    return [super matchMedia:media] && _format == format;
}

- (NSString* _Nonnull)description {
    return [NSString stringWithFormat: @"%@ format %ld", super.description, (long)_format];
}

- (void)assertMedia:(_Nonnull id<ArsdkMedia>)media
          andFormat:(ArsdkMediaResourceFormat)format
         inTestCase:(XCTestCase* _Nonnull)testCase {
    if (![self matchMedia:media andFormat:format]) {
        NSString* error = [NSString stringWithFormat:@"expect %@, got %@ format %ld ",
                           self.description, media.description, (long)format];
        [testCase recordFailureWithDescription:error inFile:self.file atLine:self.line expected:YES];
    }
}
@end

@implementation MediaDeleteExpectation
- (instancetype)initWithHandle:(int16_t)handle
                      andMedia:(id<ArsdkMedia>)media
                        inFile:(NSString* _Nonnull)file
                        atLine:(NSUInteger)line {
    return [super initWithAction:ExpectationActionMediaDelete andDeviceHandle:handle andMedia:media
                          inFile:file atLine:line];
}
@end

@implementation UpdateExpectation

-(instancetype)initWithHandle:(int16_t)handle
                  andFirmware:(NSString *)filepath
                       inFile:(NSString* _Nonnull)file
                       atLine:(NSUInteger)line {
    self = [super initWithAction:ExpectationActionUpdate andDeviceHandle:handle inFile:file atLine:line];
    if (self) {
        _fwPath = filepath;
    }
    return self;
}

- (BOOL)matchFirmware:(NSString* _Nonnull)filepath {
    return [_fwPath isEqual:filepath];
}

- (NSString* _Nonnull)description {
    return [NSString stringWithFormat: @"fwPath %@", _fwPath];
}

- (void)assertFirmware:(NSString* _Nonnull)filepath
            inTestCase:(XCTestCase* _Nonnull)testCase {
    if (![self matchFirmware:filepath]) {
        NSString* error = [NSString stringWithFormat:@"expect %@, got %@",
                           self.description, filepath];
        [testCase recordFailureWithDescription:error inFile:self.file atLine:self.line expected:YES];
    }
}
@end

@implementation FtpUploadExpectation

- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                srcPath:(NSString* _Nonnull)srcPath
                                dstPath:(NSString* _Nullable)dstPath
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line {

    self = [super initWithAction:ExpectationActionFtpUpload andDeviceHandle:handle inFile:file atLine:line];
    if (self) {
        _srcPath = srcPath;
        _dstPath = dstPath;
    }
    return self;
}

- (BOOL)matchSrcPath:(NSString* _Nonnull)srcPath
            dstPath:(NSString* _Nullable)dstPath {
    return [_srcPath isEqual:srcPath] && (_dstPath == nil || [_dstPath isEqual:dstPath]);
}

- (NSString* _Nonnull)description {
    return [NSString stringWithFormat: @"srcPath: %@ dstPath: %@", _srcPath, _dstPath];
}

- (void)assertSrcPath:(NSString* _Nonnull)srcPath
             dstPath:(NSString* _Nullable)dstPath
           inTestCase:(XCTestCase* _Nonnull)testCase {
    if (![self matchSrcPath:srcPath dstPath:dstPath]) {
        NSString* error = [NSString stringWithFormat:@"expect %@, got srcPath: %@ dstPath: %@",
                           self.description, _srcPath, _dstPath];
        [testCase recordFailureWithDescription:error inFile:self.file atLine:self.line expected:YES];
    }
}
@end

@implementation CrashmlDownloadExpectation

- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line {
    return [super initWithAction:ExpectationActionCrashmlDownload
                 andDeviceHandle:handle
                          inFile:file
                          atLine:line];
}
@end

@implementation FlightLogDownloadExpectation

- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line {
    return [super initWithAction:ExpectationActionFlightLogDownload
                 andDeviceHandle:handle
                          inFile:file
                          atLine:line];
}
@end

@implementation StreamCreateExpectation

- (instancetype _Nonnull)initWithHandle:(int16_t)handle
                                 inFile:(NSString* _Nonnull)file
                                 atLine:(NSUInteger)line {
    return [super initWithAction:ExpectationActionStreamCreate
                 andDeviceHandle:handle
                          inFile:file
                          atLine:line];
}
@end
