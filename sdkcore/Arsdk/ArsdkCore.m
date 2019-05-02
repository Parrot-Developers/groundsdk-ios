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
#import "Logger.h"
#import "ArsdkBackendController.h"
#import "arsdkctrl/arsdkctrl.h"
#import "arsdkctrl/internal/arsdkctrl_internal.h"
#import "PompLoopUtil.h"

/** common loging tag */
ULogTag *TAG;

ArsdkCmdLog arsdkCoreCmdLogLevel = ArsdkCmdLogNone;

@interface ArsdkCore ()
/** Array of managed backend controllers */
@property (nonatomic, strong) NSArray* backendControllers;
/** Listener notified of added/removed devices */
@property (nonatomic, weak) id<ArsdkCoreListener> listener;
/** Thread that called init, used to check methods are called in the same thread */
@property (nonatomic, strong) NSThread *callerThread;
/** PompLoop Util for ArsdkCore */
@property (nonatomic, strong) PompLoopUtil *pompLoopUtil;
@end

/** pomp loop queue identifier */
static const void *const kLooperQueueIdentifier = &kLooperQueueIdentifier;

@implementation ArsdkCore

+ (void)initialize {
    TAG = [[ULogTag alloc] initWithName:@"arsdk.ctrl"];
}

/**
 Constructor
 */
// TODO: give the queue user wants callback calls (it may not be the main queue)
- (instancetype)initWithBackendControllers:(NSArray*)backendControllers
                                  listener:(id<ArsdkCoreListener>)listener
                      controllerDescriptor:(NSString* _Nonnull)controllerDescriptor
                         controllerVersion:(NSString* _Nonnull)controllerVersion {
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"init ArsdkCore"];
    }
    self = [super init];
    int res = 0;
    struct pomp_loop *internalLoop = NULL;
    if (self) {
        _controllerDescriptor = controllerDescriptor;
        _controllerVersion = controllerVersion;
        _callerThread = [NSThread currentThread];
        _backendControllers = backendControllers;
        _listener = listener;
        _commandListeners = [[NSMutableDictionary alloc] init];

        /* create the loop */
        self.pompLoopUtil = [[PompLoopUtil alloc] initWithName:@"arsdkcore.pomloop"];
        if (self.pompLoopUtil == nil) {
            goto error;
        }

        internalLoop = self.pompLoopUtil.internalPompLoop;

        /* create manager */
        res = arsdk_ctrl_new(internalLoop , &_ctrl);
        if (res < 0) {
            [ULog e:TAG msg:@"ArsdkCore.init: arsdk_ctrl_new %s", strerror(-res)];
            goto error;
        }

        struct arsdk_ctrl_device_cbs ctrl_device_cbs;
        ctrl_device_cbs.added = &device_added;
        ctrl_device_cbs.removed = &device_removed;
        ctrl_device_cbs.userdata = (__bridge void *)self;
        res = arsdk_ctrl_set_device_cbs(_ctrl, &ctrl_device_cbs);
        if (res < 0) {
            [ULog e:TAG msg:@"ArsdkCore.init arsdk_ctrl_set_device_cbs %s", strerror(-res)];
            goto error;
        }
    }
    return self;

error:
    if (_ctrl != NULL) {
        res = arsdk_ctrl_destroy(_ctrl);
        if (res < 0) {
            [ULog w:TAG msg:@"ArsdkCore.init arsdk_ctrl_destroy %s", strerror(-res)];
        }
    }
    return nil;
}

/**
 Retrieves the pomp loop utility.
 
 @return pomp loop utility
 */
- (PompLoopUtil * _Nonnull)pompLoopUtil {
    return _pompLoopUtil;
}

/**
 Start the backend controllers and run the loop
 */
- (void)start {
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"starting ArsdkCore"];
    }
    for (ArsdkBackendController *backendController in _backendControllers) {
        [backendController start:self];
    }
    [self.pompLoopUtil runLoop];
}

/**
 Stop the loop and the backend controllers
 */
- (void)stop {
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"stopping ArsdkCore"];
    }
    [self.pompLoopUtil stopRun];
}

/**
 Queue a block to be executed in the loop thread

 @param block: the block to execute
 */
- (void)dispatch:(void (^)(void))block {
    [self.pompLoopUtil dispatch:block];
}

- (void)dispatch_sync:(void (^)(void))block {
    [self.pompLoopUtil dispatch_sync:block];
}

/**
 Checks that current thread is the same than the one that called init
 */
- (void)assertCallerThread {
    NSAssert1(_callerThread == [NSThread currentThread],
              @"Must be called on the same thread than ArsdkFacade constructor: %@", _callerThread);
}

#pragma mark - device callbacks impl

static void device_added(struct arsdk_device *nativeDevice, void *userdata)
{
    int res;
    ArsdkCore *self = (__bridge ArsdkCore *)(userdata);
    uint16_t handle = arsdk_device_get_handle(nativeDevice);

    const struct arsdk_device_info *info = NULL;
    res = arsdk_device_get_info(nativeDevice, &info);
    if (res < 0) {
        [ULog e:TAG msg:@"arsdk_device_get_info %s", strerror(-res)];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.listener onDeviceAdded:[NSString stringWithUTF8String:info->id]
                                type:info->type
                         backendType:(ArsdkBackendType)info->backend_type
                                name:[NSString stringWithUTF8String:info->name]
                              handle:handle];
    });
}

static void device_removed(struct arsdk_device *nativeDevice, void *userdata)
{
    int res;

    ArsdkCore *self = (__bridge ArsdkCore *)(userdata);
    uint16_t handle = arsdk_device_get_handle(nativeDevice);
    const struct arsdk_device_info *info = NULL;
    res = arsdk_device_get_info(nativeDevice, &info);
    if (res < 0) {
        [ULog e:TAG msg:@"arsdk_device_get_info %s", strerror(-res)];
        return;
    }

    NSString* deviceId = [NSString stringWithUTF8String:info->id];
    int deviceType = info->type;
    ArsdkBackendType backendType = (ArsdkBackendType)info->backend_type;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.listener onDeviceRemoved:deviceId
                                  type:deviceType
                           backendType:backendType
                                handle:handle];
    });
}


- (void)deviceConnected:(int16_t)handle
{
    [self deviceDisconnected:handle];
    NSNumber *key = @(handle);
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    [self.commandListeners setObject:arr forKey:key];
}

- (void)deviceDisconnected:(int16_t)handle
{
    NSNumber *key = @(handle);
    [self.commandListeners removeObjectForKey:key];
}

- (bool)addDeviceCommandListener:(id<ArsdkCoreDeviceCommandListener> _Nonnull)listener toDevice:(int16_t)handle
{
    NSNumber *key = @(handle);
    NSMutableArray *arr = [self.commandListeners objectForKey:key];
    if (arr == nil)
        return NO;

    [arr addObject:listener];
    return YES;
}

- (void)passCommandToListeners:(const struct arsdk_cmd * _Nonnull)command forDevice:(int16_t)handle
{
    NSNumber *key = @(handle);
    NSMutableArray *arr = [self.commandListeners objectForKey:key];
    if (arr == nil)
        return;

    for (id<ArsdkCoreDeviceCommandListener> l in arr) {
        [l onCommandReceived:command];
    }
}

@end
