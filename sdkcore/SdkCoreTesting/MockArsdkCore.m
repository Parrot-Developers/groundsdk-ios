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

#import "MockArsdkCore.h"
#import <arsdkctrl/arsdkctrl.h>

@interface Device : NSObject
@property (nonatomic) NSString* uid;
@property (nonatomic) int type;
@property (nonatomic) ArsdkBackendType backendType;
@property (nonatomic) id<ArsdkCoreDeviceListener> deviceListener;
@property (nonatomic, strong) NSArray<NoAckStorage*> *_Nullable registeredEncoders;
@property (nonatomic) BOOL noAckCommandLoopExists;
@end

@implementation MockArsdkStream

- (instancetype)initWithListener:(id<SdkCoreStreamListener> _Nonnull)listener {
    self = [super init];
    if (self) {
        _listener = listener;
        _openCnt = 0;
        _playCnt = 0;
        _pauseCnt = 0;
        _closeCnt = 0;
    }
    return self;
}

-(void)open {
    _openCnt += 1;
}

-(void)play {
    _playCnt += 1;
}

-(void)pause {
    _pauseCnt += 1;
}

- (void)close:(SdkCoreStreamCloseReason)reason {
    _closeCnt += 1;
}

-(void)mockStreamOpen {
    [_listener streamDidOpen:self];
}

-(void)mockStreamPlayState:(int64_t)duration
                  position:(int64_t)position
                     speed:(double)speed
                 timestamp:(NSTimeInterval)timestamp {
    [_listener streamPlaybackStateDidChange:self duration:duration position:position speed:speed timestamp:timestamp];
}

-(void)mockStreamClosing:(SdkCoreStreamCloseReason)reason {
    [_listener streamDidClosing:self reason:reason];
}

-(void)mockStreamClose:(SdkCoreStreamCloseReason)reason {
    [_listener streamDidClose:self reason:reason];
}

@end

@interface MockMediaListRequest ()
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                       completion:(ArsdkMediaListCompletion)completionBlock;
@end

@implementation MockMediaListRequest
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                       completion:(ArsdkMediaListCompletion)completionBlock {
    self = [super init];
    if (self) {
        _completionBlock = completionBlock;
    }
    return self;
}
@end

@interface MockMediaDownloadThumbnailRequest ()
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                       completion:(ArsdkMediaDownloadThumbnailCompletion)completionBlock;
@end

@implementation MockMediaDownloadThumbnailRequest
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                       completion:(ArsdkMediaDownloadThumbnailCompletion)completionBlock {
    self = [super init];
    if (self) {
        _completionBlock = completionBlock;
    }
    return self;
}
@end

@interface MockMediaDownloadRequest ()
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                         progress:(ArsdkMediaDownloadProgress)progressBlock
                       completion:(ArsdkMediaDownloadCompletion)completionBlock;
@end

@implementation MockMediaDownloadRequest
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                         progress:(ArsdkMediaDownloadProgress)progressBlock
                       completion:(ArsdkMediaDownloadCompletion)completionBlock {
    self = [super init];
    if (self) {
        _progressBlock = progressBlock;
        _completionBlock = completionBlock;
    }
    return self;
}
@end

@interface MockMediaDeleteRequest()
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                       completion:(ArsdkMediaDeleteCompletion)completionBlock;
@end

@implementation MockMediaDeleteRequest
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                       completion:(ArsdkMediaDeleteCompletion)completionBlock {
    self = [super init];
    if (self) {
        _completionBlock = completionBlock;
    }
    return self;
}
@end

@interface MockUpdateRequest ()
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                         progress:(ArsdkUpdateProgress)progressBlock
                       completion:(ArsdkUpdateCompletion)completionBlock;
@end

@implementation MockUpdateRequest
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                         progress:(ArsdkUpdateProgress)progressBlock
                       completion:(ArsdkUpdateCompletion)completionBlock {
    self = [super init];
    if (self) {
        _progressBlock = progressBlock;
        _completionBlock = completionBlock;
    }
    return self;
}
@end

@interface MockFtpUploadRequest ()
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                         progress:(ArsdkFtpRequestProgress)progressBlock
                       completion:(ArsdkFtpRequestCompletion)completionBlock;
@end

@implementation MockFtpUploadRequest
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                         progress:(ArsdkFtpRequestProgress)progressBlock
                       completion:(ArsdkFtpRequestCompletion)completionBlock {
    self = [super init];
    if (self) {
        _progressBlock = progressBlock;
        _completionBlock = completionBlock;
    }
    return self;
}
@end

@interface MockCrashmlDownloadRequest ()
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                         progress:(ArsdkCrashmlDownloadProgress)progressBlock
                       completion:(ArsdkCrashmlDownloadCompletion)completionBlock;
@end

@implementation MockCrashmlDownloadRequest
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                         progress:(ArsdkCrashmlDownloadProgress)progressBlock
                       completion:(ArsdkCrashmlDownloadCompletion)completionBlock {
    self = [super init];
    if (self) {
        _progressBlock = progressBlock;
        _completionBlock = completionBlock;
    }
    return self;
}
@end

@interface MockFlightLogDownloadRequest ()
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                         progress:(ArsdkFlightLogDownloadProgress)progressBlock
                       completion:(ArsdkFlightLogDownloadCompletion)completionBlock;
@end

@implementation MockFlightLogDownloadRequest
- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                         progress:(ArsdkFlightLogDownloadProgress)progressBlock
                       completion:(ArsdkFlightLogDownloadCompletion)completionBlock {
    self = [super init];
    if (self) {
        _progressBlock = progressBlock;
        _completionBlock = completionBlock;
    }
    return self;
}
@end

@interface MockArsdkCore (XCTestCase)
@end

@interface MockArsdkCore ()

@property (nonatomic, weak) id<ArsdkCoreListener> listener;

// Devices by handle
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, Device*>* devices;

// Queue as array. Elements enter at index 0. Come out at index count - 1.
@property (nonatomic, strong) NSMutableArray* expectQueue;

@property (nonatomic, strong) MockArsdkStream* _Nullable stream;

@end

@implementation MockArsdkCore

/**
 Constructor

 @param backendControllers: array of ArsdkBackendController to use
 @param listener: listener notified when devices are added and removed
 */
- (instancetype)initWithBackendControllers:(NSArray *)backendControllers
                                  listener:(id<ArsdkCoreListener>)listener
                      controllerDescriptor:(NSString* _Nonnull)controllerDescriptor
                         controllerVersion:(NSString* _Nonnull)controllerVersion {
    self = [super initWithBackendControllers:backendControllers listener:listener
                        controllerDescriptor:controllerDescriptor controllerVersion:controllerVersion];
    if (self) {
        _listener = listener;
        _devices = [NSMutableDictionary dictionary];
        _expectQueue = [NSMutableArray array];
    }
    return self;
}

/**
 Start the backend controllers and run the loop
 */
- (void)start {
    [_expectQueue removeAllObjects];
    [_devices removeAllObjects];
}

/**
 Stop the loop and the backend controllers
 */
- (void)stop {
    [self assertNoExpectationInFile:@__FILE__ atLine:__LINE__];
}

/**
 Connect to a device

 @param handle: the handle of the device
 @param deviceListener: listener notified when device connection changes and recevied commands.
 Retained until callback disconnected or canceled is called
*/
- (void)connectDevice:(int16_t)handle deviceListener:(id<ArsdkCoreDeviceListener>)deviceListener {
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionConnect andDeviceHandle:handle inTestCase:_testCase];
    [_expectQueue removeLastObject];
    Device* device = [_devices objectForKey: [NSNumber numberWithShort:handle]];
    device.deviceListener = deviceListener;
    [_devices setObject:device forKey:[NSNumber numberWithShort:handle]];
}

/**
 Disconnect from a device

 The callback given in the connectDevice method will be called to notify about disconnection
 */
- (void)disconnectDevice:(int16_t)handle {
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionDisconnect andDeviceHandle:handle inTestCase:_testCase];
    [_expectQueue removeLastObject];
}

/**
 Send a command to a device.

 Command must have been allocated on the heap. This method take ownership of the command.

 @param handle: device handle to which send the command
 @param encoder: command encoder of the command to send
 */
- (void)sendCommand:(int16_t)handle encoder:(int(^)(struct arsdk_cmd*)) __attribute__((noescape)) encoder {
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionCommand andDeviceHandle:handle inTestCase:_testCase];

    struct arsdk_cmd command;
    encoder(&command);
    CommandExpectation* cmdsExpectation = (CommandExpectation*)expectation;
    [cmdsExpectation assertCommand:&command inTestCase:_testCase];
    if (cmdsExpectation.expectedCmds.count == 0) {
        [_expectQueue removeLastObject];
    }
 }

- (void)createTcpProxy:(int16_t)handle deviceType:(NSInteger)deviceType port:(uint16_t)port
            completion:(ArsdkTcpProxyCreationCompletion)completion {
    completion(nil, @"mockAddress", 80);
}

/**
 Create the noAck command loop.

 Some commands, like piloting commands, are sent at regular period. This method create a loop object
 (see NoAckCommandLoop) in charge to initiate the loop.
 The loop timer is not activated in this method. The timer will be activated when commands will be added (see
 `setNoAckCommands` method)

 @param handle device handle to which send the command
 @param period piloting commead send period in ms
 */
- (void)createNoAckCmdLoop:(int16_t)handle periodMs:(int)period {
    [_devices objectForKey:[NSNumber numberWithShort:handle]].noAckCommandLoopExists = YES;
    [_devices objectForKey:[NSNumber numberWithShort:handle]].registeredEncoders = nil;
}

- (void)setNoAckCommands:(NSArray<NoAckStorage *> *_Nullable)encoders handle:(short)handle {
    // if the commandLoop is not created, the new list is ignored (simulating the "real" behavior of the CommandLoop)
    if ([_devices objectForKey:[NSNumber numberWithShort:handle]].noAckCommandLoopExists) {
        [_devices objectForKey:[NSNumber numberWithShort:handle]].registeredEncoders = encoders;
    }
}

/**
 Stop piloting command loop
 */
- (void)deleteNoAckCmdLoop:(int16_t)handle  {
    [_devices objectForKey:[NSNumber numberWithShort:handle]].noAckCommandLoopExists = NO;
    [_devices objectForKey:[NSNumber numberWithShort:handle]].registeredEncoders = nil;
}

#pragma mark - Stream

- (ArsdkStream* _Nonnull)createVideoStream:(int16_t)handle
                                       url:(NSString *)url
                                     track:(NSString *)track
                                  listener:(id<SdkCoreStreamListener> _Nonnull)listener {
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionStreamCreate andDeviceHandle:handle inTestCase:_testCase];
    [_expectQueue removeLastObject];

    _stream = [[MockArsdkStream alloc] initWithListener:listener];
    return _stream;
}

-(MockArsdkStream *)getVideoStream {
    return _stream;
}


#pragma mark - Media

/** List medias */
- (ArsdkRequest*)listMedia:(int16_t)handle
                deviceType:(NSInteger)deviceType
                completion:(ArsdkMediaListCompletion)completionBlock {

    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionMediaList andDeviceHandle:handle inTestCase:_testCase];
    ((MediaListExpectation*)expectation).completion = completionBlock;
    [_expectQueue removeLastObject];
    return [[MockMediaListRequest alloc] initWithArsdkCore:self completion:completionBlock];
}

/** Media Download thumbnail */
- (ArsdkRequest*)downloadMediaThumnail:(int16_t)handle
                            deviceType:(NSInteger)deviceType
                                 media:(id<ArsdkMedia>)media
                            completion:(ArsdkMediaDownloadThumbnailCompletion)completionBlock {
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionMediaDownloadThumbnail andDeviceHandle:handle inTestCase:_testCase];
    MediaDownloadThumbnailExpectation* downloadThumbnailExpectation = (MediaDownloadThumbnailExpectation*)expectation;
    [downloadThumbnailExpectation assertMedia:media inTestCase:_testCase];
    downloadThumbnailExpectation.completion = completionBlock;
    [_expectQueue removeLastObject];
    return [[MockMediaDownloadThumbnailRequest alloc] initWithArsdkCore:self completion:completionBlock];
}

/** Media Download */
- (ArsdkRequest * _Nonnull)downloadMedia:(int16_t)handle
                              deviceType:(NSInteger)deviceType
                                   media:(id<ArsdkMedia>)media
                                  format:(ArsdkMediaResourceFormat)format
                       destDirectoryPath:(NSString * _Nonnull)destDirectoryPath
                                progress:(ArsdkMediaDownloadProgress)progressBlock
                              completion:(ArsdkMediaDownloadCompletion)completionBlock {
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionMediaDownload andDeviceHandle:handle inTestCase:_testCase];
    MediaDownloadExpectation* downloadExpectation = (MediaDownloadExpectation*)expectation;
    [downloadExpectation assertMedia:media andFormat:format inTestCase:_testCase];
    downloadExpectation.progress = progressBlock;
    downloadExpectation.completion = completionBlock;
    [_expectQueue removeLastObject];
    return [[MockMediaDownloadRequest alloc] initWithArsdkCore:self progress:progressBlock completion:completionBlock];
}

/** Delete media */
- (ArsdkRequest*)deleteMedia:(int16_t)handle
                  deviceType:(NSInteger)deviceType
                       media:(id<ArsdkMedia>)media
                  completion:(ArsdkMediaDeleteCompletion)completionBlock {
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionMediaDelete andDeviceHandle:handle inTestCase:_testCase];
    MediaDeleteExpectation* deleteExpectation = (MediaDeleteExpectation*)expectation;
    [deleteExpectation assertMedia:media inTestCase:_testCase];
    deleteExpectation.completion = completionBlock;
    [_expectQueue removeLastObject];
    return [[MockMediaDeleteRequest alloc] initWithArsdkCore:self completion:completionBlock];
}

#pragma mark Update

- (ArsdkRequest *)updateFirwmare:(int16_t)handle
                      deviceType:(NSInteger)deviceType
                            file:(NSString *)filepath
                        progress:(ArsdkUpdateProgress)progressBlock
                      completion:(ArsdkUpdateCompletion)completionBlock {
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionUpdate andDeviceHandle:handle inTestCase:_testCase];
    UpdateExpectation* updateExpectation = (UpdateExpectation*)expectation;
    [updateExpectation assertFirmware:filepath inTestCase:_testCase];
    updateExpectation.progress = progressBlock;
    updateExpectation.completion = completionBlock;
    [_expectQueue removeLastObject];
    return [[MockUpdateRequest alloc] initWithArsdkCore:self progress:progressBlock completion:completionBlock];
}

#pragma mark FtpUpload

- (ArsdkRequest *)ftpUpload:(int16_t)handle
                 deviceType:(NSInteger)deviceType
                 serverType:(ArsdkFtpServerType)serverType
                    srcPath:(NSString *)srcPath
                     dstPth:(NSString *)dstPath
                   progress:(ArsdkFtpRequestProgress)progressBlock
                 completion:(ArsdkFtpRequestCompletion)completionBlock {
    _latestFtpUploadedFilePath = dstPath;
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionFtpUpload andDeviceHandle:handle inTestCase:_testCase];
    FtpUploadExpectation* ftpUploadExpectation = (FtpUploadExpectation*)expectation;
    [ftpUploadExpectation assertSrcPath:srcPath dstPath:dstPath inTestCase:_testCase];
    ftpUploadExpectation.progress = progressBlock;
    ftpUploadExpectation.completion = completionBlock;
    [_expectQueue removeLastObject];
    return [[MockFtpUploadRequest alloc] initWithArsdkCore:self progress:progressBlock completion:completionBlock];
}

#pragma mark Crashml

- (ArsdkRequest * _Nonnull)downloadCrashml:(int16_t)handle
                                deviceType:(NSInteger)deviceType
                                      path:(NSString*)path
                                  progress:(ArsdkCrashmlDownloadProgress)progressBlock
                                completion:(ArsdkCrashmlDownloadCompletion)completionBlock {
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionCrashmlDownload andDeviceHandle:handle inTestCase:_testCase];
    CrashmlDownloadExpectation* downloadExpectation = (CrashmlDownloadExpectation*)expectation;
    downloadExpectation.progress = progressBlock;
    downloadExpectation.completion = completionBlock;
    [_expectQueue removeLastObject];
    return [[MockCrashmlDownloadRequest alloc] initWithArsdkCore: self
                                                        progress: progressBlock
                                                      completion: completionBlock];
}

#pragma mark FlightLog
- (ArsdkRequest * _Nonnull)downloadFlightLog:(int16_t)handle
                                deviceType:(NSInteger)deviceType
                                      path:(NSString*)path
                                  progress:(ArsdkFlightLogDownloadProgress)progressBlock
                                completion:(ArsdkFlightLogDownloadCompletion)completionBlock {
    Expectation *expectation = [self peekExpectQueue];
    [expectation assertAction:ExpectationActionFlightLogDownload andDeviceHandle:handle inTestCase:_testCase];
    FlightLogDownloadExpectation* downloadExpectation = (FlightLogDownloadExpectation*)expectation;
    downloadExpectation.progress = progressBlock;
    downloadExpectation.completion = completionBlock;
    [_expectQueue removeLastObject];
    return [[MockFlightLogDownloadRequest alloc] initWithArsdkCore: self
                                                          progress: progressBlock
                                                        completion: completionBlock];
}


#pragma mark -

- (void)addDevice:(NSString*)uid type:(NSInteger)type backendType:(ArsdkBackendType)backendType
             name:(NSString*)name handle:(int16_t)handle {
    Device* device = [[Device alloc] init];
    device.uid = uid;
    device.type = (int)type;
    device.backendType = backendType;
    [_devices setObject:device forKey:[NSNumber numberWithShort:handle]];
    [_listener onDeviceAdded:uid type:type backendType:backendType name:name
                         api:ArsdkApiCapabilitiesFull handle:handle];
}

- (void)removeDevice:(int16_t)handle {
    Device* device = [_devices objectForKey:[NSNumber numberWithShort:handle]];
    if (device) {
        [_listener onDeviceRemoved:device.uid type:device.type backendType:device.backendType handle:handle];
    }
}

- (void)deviceConnecting:(int16_t)handle {
    [[_devices objectForKey:[NSNumber numberWithShort:handle]].deviceListener onConnecting];
}

- (void)deviceConnected:(int16_t)handle {
    [[_devices objectForKey:[NSNumber numberWithShort:handle]].deviceListener
     onConnectedWithApi:ArsdkApiCapabilitiesFull];
}

- (void)deviceDisconnected:(int16_t)handle removing:(BOOL)removing {
    [[_devices objectForKey:[NSNumber numberWithShort:handle]].deviceListener onDisconnected:removing];
}

- (void)deviceConnectingCancel:(int16_t)handle reason:(ArsdkConnCancelReason)reason removing:(BOOL)removing {
    [[_devices objectForKey:[NSNumber numberWithShort:handle]].deviceListener
     onConnectionCancel:reason removing:removing];
}

- (void)deviceLinkStatusChanged:(int16_t)handle status:(NSInteger)status {
    [[_devices objectForKey:[NSNumber numberWithShort:handle]].deviceListener  onLinkDown];
}

- (void)onCommandReceived:(int16_t)handle encoder:(int (^)(struct arsdk_cmd *))encoder {
    struct arsdk_cmd* command = calloc(1, sizeof(*command));
    int res = encoder(command);
    if (res == 0) {
        [[_devices objectForKey:[NSNumber numberWithShort:handle]].deviceListener onCommandReceived:command];
    }
}

- (void)mockNonAckLoop:(int16_t)handle noAckType:(ArsdkNoAckCmdType)noAckType inFile:(NSString*)file
                atLine:(NSUInteger)line {
    if ([[_devices objectForKey:[NSNumber numberWithShort:handle]] noAckCommandLoopExists] == NO) {
        [_testCase recordFailureWithDescription:@"non ack loop not started" inFile:file atLine:line expected:NO];
        return;
    }

    BOOL found = NO;
    for (NoAckStorage *noAckStorage
         in [[_devices objectForKey:[NSNumber numberWithShort:handle]] registeredEncoders]) {

        if (noAckStorage.type == noAckType) {
            found = YES;
            struct arsdk_cmd command;
            ArsdkCommandEncoder encoder = noAckStorage.encoderBlock();
            if (encoder) {
                Expectation *expectation = [self peekExpectQueueInFile:file atLine:line];
                [expectation assertAction:ExpectationActionCommand andDeviceHandle:handle inTestCase:_testCase];
                CommandExpectation* commandExpectation = (CommandExpectation*)expectation;

                encoder(&command);
                [commandExpectation assertCommand:&command inTestCase:_testCase];
                [_expectQueue removeLastObject];
            }
        }
    }
    if (!found) {
        NSString* error = [NSString stringWithFormat:@"expect %@, but did not find any matching no-ack commands",
                           self.description];
        [_testCase recordFailureWithDescription:error inFile:file atLine:line expected:YES];
    }
}

- (void)assertNoExpectationInFile:(NSString*)file atLine:(NSUInteger)line {
    [_expectQueue enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString* msg = [NSString stringWithFormat:@"pending expectation: %@", obj];
        [self->_testCase recordFailureWithDescription:msg inFile:file atLine:line expected:NO];
    }];
}

- (void)expect:(Expectation*)expectation {
    [_expectQueue insertObject:expectation atIndex:0];
}

- (Expectation*)peekExpectQueue {
    return [self peekExpectQueueInFile:@__FILE__ atLine:__LINE__];
}

- (Expectation*)peekExpectQueueInFile:(NSString*)file atLine:(NSUInteger)line {
    Expectation *expectation = _expectQueue.lastObject;
    if (expectation == NULL) {
        [_testCase recordFailureWithDescription:@"No pending expectation" inFile:file atLine:line expected:NO];
    }
    return expectation;
}

@end

@implementation Device
@end

@implementation MockArsdkMediaResource
- (instancetype _Nonnull)initWithUid:(NSString *_Nonnull)uid format:(ArsdkMediaResourceFormat)format size:(size_t)size {
    self = [super init];
    if (self) {
        _uid = uid;
        _format = format;
        _size = size;
    }
    return self;
}
@end

@implementation MockArsdkMedia
- (ArsdkMediaType) getType {
    return _type;
}
- (NSString * _Nonnull) getName {
    return _name;
}
- (NSString * _Nonnull) getRunUid {
    return _runUid;
}
- (NSDate * _Nonnull) getCreationDate {
    return _creationDate;

}
- (void)iterateResources:(__attribute__((noescape)) void(^ _Nonnull)(NSString *resourceUid,
                                                                     ArsdkMediaResourceFormat format,
                                                                     size_t size))block {
    for (MockArsdkMediaResource* resource in _resources) {
        block(resource.uid, resource.format, resource.size);
    }
}

@end

@implementation MockArsdkMediaList
- (instancetype _Nullable)initWithList:(NSArray<MockArsdkMedia*> * _Nonnull)list {
    self = [super init];
    if (self) {
        _pos = 0;
        _list = list;
    }
    return self;
}

- (id<ArsdkMedia>)next {
    MockArsdkMedia* res = nil;
    if (_pos < _list.count) {
        res = _list[_pos];
        _pos++;
    }
    return res;
}

@end
