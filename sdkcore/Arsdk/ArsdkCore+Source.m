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
#import "ArsdkCore+Source.h"
#import "Logger.h"
#import <arsdkctrl/arsdkctrl.h>
#import <arsdkctrl/internal/arsdkctrl_internal.h>
#import <pdraw/pdraw.h>

/** common loging tag */
extern ULogTag *TAG;

@interface ArsdkSource()

/** Dispatch queue running the pomp loop */
@property (nonatomic, weak) ArsdkCore * arsdkCore;
/** Connected device handle */
@property (nonatomic, assign) short deviceHandle;
/** Stream url */
@property (nonatomic) NSString * _Nonnull url;
/** Tcp proxy for rtsp over mux */
@property (nonatomic, assign) struct arsdk_device_tcp_proxy * _Nullable rtspProxy;

@end

@implementation ArsdkSource

- (instancetype _Nullable)initWithArsdkCore:(ArsdkCore * _Nonnull)arsdkCore
                               deviceHandle:(short)deviceHandle
                                        url:(NSString * _Nonnull)url {
    self = [super init];
    if (self) {
        self.arsdkCore = arsdkCore;
        self.deviceHandle = deviceHandle;
        self.url = url;
        self.rtspProxy = NULL;
    }
    return self;
}

- (int)open:(/*struct pdraw * */void*)ppdraw {
    struct pdraw *pdraw = ppdraw;

    struct arsdk_device *device = arsdk_ctrl_get_device(_arsdkCore.ctrl, _deviceHandle);
    if (device == NULL) {
        [ULog e:TAG msg:@"ArsdkSource creation: nativeDevice not found"];
        return -ENODEV;
    }
    
    const struct arsdk_device_info *info = NULL;
    int res = arsdk_device_get_info(device, &info);
    if (info == NULL) {
        [ULog e:TAG msg:@"ArsdkSource arsdk_device_get_info failed: %s", strerror(-res)];
        return res;
    }
    
    struct arsdkctrl_backend *backend = arsdk_device_get_backend(device);
    if (backend == NULL) {
        [ULog e:TAG msg:@"ArsdkSource arsdk_device_get_backend failed"];
        return -ENODEV;
    }
    
    char *rtsp_url = NULL;
    switch (info->backend_type) {
        case ARSDK_BACKEND_TYPE_NET:
            switch (info->type) {
                case ARSDK_DEVICE_TYPE_ANAFI4K:
                case ARSDK_DEVICE_TYPE_ANAFI_THERMAL:
                case ARSDK_DEVICE_TYPE_ANAFI_UA:
                case ARSDK_DEVICE_TYPE_ANAFI_USA:
                    res = asprintf(&rtsp_url, "rtsp://%s/%s", info->addr, [_url UTF8String]);
                    if (res <= 0) {
                        res = -ENOMEM;
                        break;
                    }
                    res = pdraw_open_url(pdraw, rtsp_url);
                    free(rtsp_url);
                    break;
                default:
                    res = -ENODEV;
                    [ULog e:TAG msg:@"ArsdkSource device type(%d) unsupported", info->type];
                    break;
            }
            break;
        case ARSDK_BACKEND_TYPE_MUX: {
            struct arsdkctrl_backend_mux *backend_mux = arsdkctrl_backend_get_child(backend);
            if (backend_mux == NULL) {
                res = -EINVAL;
                [ULog e:TAG msg:@"ArsdkSource failed to get backend mux"];
                break;
            }
            
            struct mux_ctx *mux = arsdkctrl_backend_mux_get_mux_ctx(backend_mux);
            
            switch(info->type) {
                case ARSDK_DEVICE_TYPE_SKYCTRL_3:
                case ARSDK_DEVICE_TYPE_SKYCTRL_UA:
                    res = arsdk_device_create_tcp_proxy(device, info->type, 554, &_rtspProxy);
                    if (res < 0)
                        break;
                    res = asprintf(&rtsp_url, "rtsp://127.0.0.1:%d/%s",
                                   arsdk_device_tcp_proxy_get_port(_rtspProxy), [_url UTF8String]);
                    if (res <= 0) {
                        res = -ENOMEM;
                        break;
                    }
                    res = pdraw_open_url_mux(pdraw, rtsp_url, mux);
                    free(rtsp_url);
                    break;
                default:
                    res = -ENODEV;
                    [ULog e:TAG msg:@"ArsdkSource device type(%d) unsupported", info->type];
                    break;
            }
            break;
        }
        default:
            res = -ENODEV;
            [ULog e:TAG msg:@"ArsdkSource backend type(%d) unsupported", info->backend_type];
            break;
    }
    return res;
}

-(void)close {
    if (_rtspProxy != NULL) {
        arsdk_device_destroy_tcp_proxy(_rtspProxy);
        _rtspProxy = NULL;
    }
}

@end
