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

#include <arsdkctrl/arsdkctrl.h>
#import "ArsdkNetBackend.h"

@implementation ArsdkNetBackend

-(instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore {
    self = [super init];
    if (self) {
        int res;

        struct arsdkctrl_backend_net_cfg cfg = {
            .stream_supported = 1,
            .qos_mode_supported = 0,
            .proto_v_max = 1,
        };
        res = arsdkctrl_backend_net_new(arsdkCore.ctrl, &cfg, &_netBackend);
        if (res < 0) {
            [NSException raise:@"ArsdkNetBackend" format:@"arsdkctrl_backend_net_new returned an error: %i", res];
        }
    }
    return self;
}

-(void)dealloc {
    int res = arsdkctrl_backend_net_destroy(_netBackend);
    if (res < 0) {
        [NSException raise:@"ArsdkNetBackend" format:@"arsdkctrl_backend_net_destroy returned an error: %i", res];
    }
}

@end
