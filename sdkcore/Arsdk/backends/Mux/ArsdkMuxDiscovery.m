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

#import "ArsdkMuxDiscovery.h"
#import <arsdkctrl/arsdkctrl.h>
#import "Logger.h"

extern ULogTag* TAG;

@interface ArsdkMuxDiscovery ()
@property (nonatomic, readonly, weak) ArsdkCore* arsdkCore;
@property (nonatomic, assign) struct arsdk_discovery_mux *discovery;
@end

@implementation ArsdkMuxDiscovery

/**
 Constructor
 */
- (instancetype) initWithArsdkCore:(ArsdkCore*)arsdkCore mux:(ArsdkMux*)mux backend:(ArsdkMuxBackend*)backend
                       deviceTypes:(NSSet<NSNumber*>*)deviceTypes {
    enum arsdk_device_type* discovery_types = malloc(sizeof(enum arsdk_device_type) * deviceTypes.count);
    if (discovery_types) {
        self = [super init];
        if (self) {
            _arsdkCore = arsdkCore;

            int idx = 0;
            for (NSNumber* deviceType in deviceTypes) {
                discovery_types[idx] = (enum arsdk_device_type)deviceType.integerValue;
                idx++;
            }
            const struct arsdk_discovery_cfg discovery_cfg = {
                .types = discovery_types,
                .count = (uint32_t)deviceTypes.count
            };
            int res = arsdk_discovery_mux_new(_arsdkCore.ctrl,  backend.muxBackend, &discovery_cfg, mux.mux, &_discovery);
            if (res < 0) {
                [ULog e:TAG msg:@"ArsdkMuxDiscovery.init arsdk_discovery_mux_new: %s", strerror(-res)];
            }
        }
        free(discovery_types);
    }
    return self;
}

/**
 Destructor
 */
-(void)dealloc {
    int res = arsdk_discovery_mux_destroy(_discovery);
    if (res < 0) {
        [ULog e:TAG msg:@"ArsdkMuxDiscovery.dealloc arsdk_discovery_destroy: %s", strerror(-res)];
    }
}

/**
 Start the discovery
 */
- (void)start {
    int res = arsdk_discovery_mux_start(_discovery);
    if (res < 0) {
        [ULog e:TAG msg:@"ArsdkMuxDiscovery.start arsdk_discovery_mux_start: %s", strerror(-res)];
    }
}

/**
 Stop the discovery
 */
- (void)stop {
    int res = arsdk_discovery_mux_stop(_discovery);
    if (res < 0) {
        [ULog e:TAG msg:@"ArsdkMuxDiscovery.stop arsdk_discovery_mux_stop: %s", strerror(-res)];
    }
}

@end
