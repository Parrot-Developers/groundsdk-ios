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

#import "ArsdkDiscovery.h"
#import "ArsdkDiscovery+Protected.h"
#import "ArsdkCore.h"
#import "ArsdkCore+Internal.h"
#import "Logger.h"
#import <arsdkctrl/arsdkctrl.h>
#import <arsdkctrl/internal/arsdkctrl_internal.h>

extern ULogTag *TAG;

@interface ArsdkDiscovery ()

@property (nonatomic, assign) struct arsdk_discovery *discovery;

@end


@implementation ArsdkDiscovery

-(instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore backend:(struct arsdkctrl_backend*)backend andName:(NSString*)name
{
    self = [super init];
    if (self) {
        _arsdkCore = arsdkCore;
        int res = arsdk_discovery_new([name UTF8String], backend, _arsdkCore.ctrl, &_discovery);
        if (res < 0) {
            [ULog e:TAG msg:@"ArsdkDiscovery.ini arsdk_discovery_new: %s", strerror(-res)];
        }
    }
    return self;
}

-(void)dealloc {
    int res = arsdk_discovery_destroy(_discovery);
    if (res < 0) {
        [ULog e:TAG msg:@"ArsdkDiscovery.dealloc arsdk_discovery_destroy: %s", strerror(-res)];
    }
}

-(void)start {
    if (!_started) {
        _started = YES;
        [self doStart];
    }
}

-(void)stop {
    if (_started) {
        [self doStop];
        _started = NO;
    }
}

/**
 Called when the discovery is started.
 Implementation must start seaching for device
 */
- (void)doStart {
    arsdk_discovery_start(_discovery);
}

/**
 Called when the discovery is stopped.
 Implementaiton must stop searching for devices
 */
- (void)doStop {
    arsdk_discovery_stop(_discovery);
}

- (void)addDevice:(NSString*)name type:(NSInteger)type addr:(NSString*)addr port:(NSInteger)port
              uid:(NSString*)uid {
    [_arsdkCore dispatch:^{
        int res;
        struct arsdk_discovery_device_info info;
        memset(&info, 0, sizeof(info));

        info.name = [name UTF8String];
        info.addr = [addr UTF8String];
        info.id = [uid UTF8String];
        info.type = (enum arsdk_device_type)type;
        info.port = port;

        res = arsdk_discovery_add_device(self->_discovery, &info);
        if (res < 0) {
            [ULog e:TAG msg:@"ArsdkDiscovery.addDevice arsdk_discovery_add_device: %s", strerror(-res)];
        }
    }];
}


- (void)removeDevice:(NSString*)name type:(NSInteger)type {
    [_arsdkCore dispatch:^{
        int res;
        struct arsdk_discovery_device_info info;
        memset(&info, 0, sizeof(info));

        info.name = [name UTF8String];
        info.type = (enum arsdk_device_type)type;

        res = arsdk_discovery_remove_device(self->_discovery, &info);
        if (res < 0) {
            [ULog e:TAG msg:@"ArsdkDiscovery.removeDevice arsdk_discovery_remove_device: %s", strerror(-res)];
        }
    }];
}

- (void)removeDeviceWithUid:(NSString*)uid type:(NSInteger)type {
    [_arsdkCore dispatch:^{
        int res;
        struct arsdk_discovery_device_info info;
        memset(&info, 0, sizeof(info));

        info.id = [uid UTF8String];
        info.type = (enum arsdk_device_type)type;

        res = arsdk_discovery_remove_device(self->_discovery, &info);
        if (res < 0) {
            [ULog e:TAG msg:@"ArsdkDiscovery.removeDevice arsdk_discovery_remove_device: %s", strerror(-res)];
        }
    }];
}

@end
