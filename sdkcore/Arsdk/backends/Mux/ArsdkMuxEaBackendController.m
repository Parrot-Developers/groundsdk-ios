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

#import <UIKit/UIKit.h>
#import <arpa/inet.h>
#import <arsdkctrl/arsdkctrl.h>
#import "ArsdkMuxEaBackendController.h"
#import "ArsdkMux.h"
#import "ArsdkMuxBackend.h"
#import "ArsdkMuxDiscovery.h"
#import <ExternalAccessory/ExternalAccessory.h>
#import "Logger.h"

extern ULogTag* TAG;

typedef enum
{
    START_ACCESSORY_SUCCESS,
    START_ACCESSORY_FAILED,
    START_ACCESSORY_NOT_INTERESTED
}eSTART_ACCESSORY;


@interface ArsdkMuxEaBackendController() <ArsdkMuxDelegate>

/** Device types */
@property (nonatomic, strong) NSSet<NSNumber *> *deviceTypes;
/** External accessory session */
@property (nonatomic, strong) EASession* accessorySession;
/** External accessory connected */
@property (nonatomic, strong) EAAccessory *accessoryConnected;
/** The last session before entering background
 Keeps a weak ref to the EASession. When we reconnect the accessory, if an error occurs, we can check this ref :
 - a 'non null' ref means that the previous session was not closed (because there is still a strongRef on it).
 - we can try to close the input and output streams on this previous session */
@property (nonatomic, weak) EASession* latestSeenBeforeBackgroundAccessorySession;
/** Mux */
@property (nonatomic, strong) ArsdkMux *mux;
/** Backend */
@property (nonatomic, strong) ArsdkMuxBackend *backend;
/** Discovery */
@property (nonatomic, strong) ArsdkMuxDiscovery *discovery;
/** Timer to restart startaccessory */
@property (nonatomic, strong) NSTimer *timerStartAccessory;


@end

/** Accessory protocol */
static NSString* ACCESSORY_PROTOCOL = @"com.parrot.dronesdk";

@implementation ArsdkMuxEaBackendController

- (instancetype)initWithSupportedDeviceTypes:(NSSet<NSNumber*>*)deviceTypes {
    self = [super init];
    if (self) {
        _deviceTypes = deviceTypes;
    }
    return self;
}

- (void)start:(ArsdkCore*)arsdkCore {
    [super start:arsdkCore];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidConnect:)
                                                 name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidDisconnect:)
                                                 name:EAAccessoryDidDisconnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enteredBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification object: nil];
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
    [self startConnectedAccessory];
}

- (void)stop {
    [super stop];
    [[EAAccessoryManager sharedAccessoryManager] unregisterForLocalNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/** Check all connected accessory and start the first one with the right protocol available */
- (void)startConnectedAccessory {
    [_timerStartAccessory invalidate];
    _timerStartAccessory = nil;
    if (self.latestSeenBeforeBackgroundAccessorySession) {
        // waiting the end of the ArsdkMux's streamThread
        // (the auto check in ArsdkMux is 'MAIN_LOOP_TIMEOUT' -> see ArsdkMux.m
        _timerStartAccessory = [NSTimer scheduledTimerWithTimeInterval:(ARSDKMUX_LOOP_TIMEOUT + 1)
                                                                target:self
                                                              selector:@selector(startConnectedAccessory)
                                                              userInfo:nil repeats:NO];
        return;
    }

    NSArray *connectedAccessories = [EAAccessoryManager sharedAccessoryManager].connectedAccessories;
    for (EAAccessory *connectedAccessory in connectedAccessories) {
        eSTART_ACCESSORY stateAccessory = [self startAccessory:connectedAccessory];
        if (stateAccessory == START_ACCESSORY_SUCCESS) {
            _accessoryConnected = connectedAccessory;
            self.latestSeenBeforeBackgroundAccessorySession = nil;
            break;
        } else if (stateAccessory == START_ACCESSORY_FAILED) {
            _timerStartAccessory = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                                                selector:@selector(startConnectedAccessory) userInfo:nil repeats:NO];
            break;
        }
    }
}

/**
 Try to start the specified accessory.

 @param accessory: the accessory to start
 @return START_ACCESSORY_SUCCESS on success,
         START_ACCESSORY_NOT_INTERESTED if the accessory does not conform to the `ACCESSORY_PROTOCOL`,
         START_ACCESSORY_FAILED otherwise
 */
- (eSTART_ACCESSORY)startAccessory:(EAAccessory * _Nonnull)accessory {
    [ULog i:TAG msg:@"accessory connected %s %s", accessory.name.UTF8String, accessory.serialNumber.UTF8String];
    for (NSString* protocol in [accessory protocolStrings]) {
        if ([protocol isEqualToString:ACCESSORY_PROTOCOL]) {
            _accessorySession = [[EASession alloc] initWithAccessory:accessory forProtocol:protocol];
            if (_accessorySession) {
                _mux = [[ArsdkMux alloc] initWithDelegate:self
                                                arsdkCore:self.arsdkCore
                                              inputStream:_accessorySession.inputStream
                                             outputStream:_accessorySession.outputStream
                                                pomp_loop:arsdk_ctrl_get_loop(self.arsdkCore.ctrl)];
                return START_ACCESSORY_SUCCESS;
            } else {
                [ULog e:TAG msg:@"Unable to create accessory session for protocol %s", protocol.UTF8String];
                return START_ACCESSORY_FAILED;
            }
        }
    }
    [ULog i:TAG msg:@"accessory %s without protocol %s", accessory.name.UTF8String, ACCESSORY_PROTOCOL.UTF8String];
    // no protocol conforms to ACCESSORY_PROTOCOL
    return START_ACCESSORY_NOT_INTERESTED;
}

#pragma mark foreground / background notifications
/**
 Called on UIApplicationDidEnterBackgroundNotification.
 Stop the ArsdkMux.
 A new ArsdkMux will be instantiated on foreground event (if an acessory is present).
 */
- (void)enteredBackground:(NSNotification*)notification {
    [_timerStartAccessory invalidate];
    _timerStartAccessory = nil;

    self.latestSeenBeforeBackgroundAccessorySession = self.accessorySession;

    // close session for device
    [self.arsdkCore dispatch_sync:^{
        [self.discovery stop];
        [self.mux close];
        self.discovery = nil;
        self.backend = nil;
        self.mux = nil;
        self.accessorySession = nil;
        if (self.accessoryConnected != nil) {
            [self.accessoryConnected setDelegate:nil];
            self.accessoryConnected = nil;
        }
    }];
}

/**
 Called on UIApplicationWillEnterForegroundNotification.
 A ArsdkMux will be instantiated on this event (if an acessory is present).
 */
- (void)enterForeground:(NSNotification*)notification {
    [self.arsdkCore dispatch_sync:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startConnectedAccessory];
        });
    }];
}

#pragma mark accessory notifications
- (void)accessoryDidConnect:(NSNotification*)notification {
    EAAccessory* accessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    if (accessory) {
        [self startAccessory:accessory];
    }
}

- (void)accessoryDidDisconnect:(NSNotification*)notification {
    [ULog i:TAG msg:@"accessory disconnected"];
    _accessorySession = nil;
    self.latestSeenBeforeBackgroundAccessorySession = nil;
    [_timerStartAccessory invalidate];
    _timerStartAccessory = nil;
}

#pragma mark ArsdkMuxDelegate
- (void)muxDidStart {
    if (_mux != nil) {
        _backend = [[ArsdkMuxBackend alloc] initWithArsdkCore:self.arsdkCore mux:_mux];
        _discovery = [[ArsdkMuxDiscovery alloc] initWithArsdkCore:self.arsdkCore mux:_mux backend:_backend
                                                  deviceTypes: _deviceTypes];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.arsdkCore dispatch_sync:^{
                [self.discovery start];
            }];
        });
    }
    else {
        [self startConnectedAccessory];
    }
}

- (void)muxDidFail {
    [self.arsdkCore dispatch_sync:^{
        self.discovery = nil;
        self.backend = nil;
        self.mux = nil;
    }];
}

@end
