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
//    * Neither the name of Parrot nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

#import "ArsdkCore.h"
#import "ArsdkCore+Internal.h"
#import "ArsdkCore+RcBlackBox.h"
#import "Logger.h"
#import <arsdkctrl/arsdkctrl.h>

/** common loging tag */
extern ULogTag *TAG;

#pragma mark - arsdk_blackbox_helpers

static struct arsdk_blackbox_itf *get_blackbox_itf(struct arsdk_ctrl *ctrl, short device_handle) {
    struct arsdk_device *device = arsdk_ctrl_get_device(ctrl, device_handle);
    if (device ==  NULL) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_mngr_get_device: device not found"];
        return NULL;
    }
    struct arsdk_blackbox_itf *blackbox_itf = NULL;
    int res = arsdk_device_get_blackbox_itf(device, &blackbox_itf);
    if (res < 0) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_device_get_blackbox_itf: %s", strerror(-res)];
        return NULL;
    }
    return blackbox_itf;
}

#pragma mark - BlackBoxListener

@interface BlackBoxListener: ArsdkRequest

@property (nonatomic, readonly) ArsdkRcBlackBoxButtonActionCb buttonActionBlock;
@property (nonatomic, readonly) ArsdkRcBlackBoxPilotingInfoCb pilotingInfoBlock;
@property (nonatomic) struct arsdk_blackbox_listener *listener;

- (instancetype)initWithArsdkCore:(ArsdkCore *)arsdkCore
                     deviceHandle:(short)deviceHandle
                     buttonAction:(ArsdkRcBlackBoxButtonActionCb)buttonActionBlock
                     pilotingInfo:(ArsdkRcBlackBoxPilotingInfoCb)pilotingInfoBlock;

@end

@implementation BlackBoxListener

- (instancetype)initWithArsdkCore:(ArsdkCore *)arsdkCore
                     deviceHandle:(short)deviceHandle
                     buttonAction:(ArsdkRcBlackBoxButtonActionCb)buttonActionBlock
                     pilotingInfo:(ArsdkRcBlackBoxPilotingInfoCb)pilotingInfoBlock {
    self = [super initWithArsdkCore:arsdkCore];
    if (self) {
        _buttonActionBlock = buttonActionBlock;
        _pilotingInfoBlock = pilotingInfoBlock;
        // switch to arsdk thread (i.e pomp_loop thread)
        [arsdkCore dispatch:^{
            // ignore request if already canceled
            if (self.canceled) {
                return;
            }

            struct arsdk_blackbox_itf *blackbox_itf = get_blackbox_itf(self.arsdkCore.ctrl, deviceHandle);
            if (blackbox_itf == NULL) {
                //goto failed;
                return;
            }

            struct arsdk_blackbox_listener_cbs cbs;
            memset(&cbs, 0, sizeof(cbs));
            cbs.userdata = (__bridge_retained void *)self;
            cbs.rc_button_action = &rc_button_action;
            cbs.rc_piloting_info = &rc_piloting_info;
            cbs.unregister = &unregister;
            int res = arsdk_blackbox_itf_create_listener(blackbox_itf, &cbs, &self->_listener);
            if (res < 0) {
                [ULog e:TAG msg:@"BlackBoxListener arsdk_blackbox_itf_create_listener: %s", strerror(-res)];
                //goto failed;
            }
            return;
        }];
    }
    return self;
}

-(void)cancel {
    [self.arsdkCore dispatch:^{
        if (self->_listener) {
            arsdk_blackbox_listener_unregister(self->_listener);
        }
    }];
}

static void rc_button_action(struct arsdk_blackbox_itf *itf,
                             struct arsdk_blackbox_listener *listener,
                             int action,
                             void *userdata) {
    BlackBoxListener* bboxlistener = (__bridge BlackBoxListener*)(userdata);
    dispatch_async(dispatch_get_main_queue(), ^{
        bboxlistener.buttonActionBlock(action);
    });
}

static void rc_piloting_info(struct arsdk_blackbox_itf *itf,
                             struct arsdk_blackbox_listener *listener,
                             struct arsdk_blackbox_rc_piloting_info *info,
                             void *userdata) {
    BlackBoxListener* bboxlistener = (__bridge BlackBoxListener*)(userdata);
    dispatch_async(dispatch_get_main_queue(), ^{
        bboxlistener.pilotingInfoBlock(info->roll, info->pitch, info->yaw, info->gaz, info->source);
    });
}

static void unregister(struct arsdk_blackbox_itf *itf,
                       struct arsdk_blackbox_listener *listener,
                       void *userdata) {
    BlackBoxListener* bboxlistener = (__bridge_transfer BlackBoxListener*)(userdata);
    bboxlistener->_listener = NULL;
}

@end

@implementation ArsdkCore (RcBlackBox)

/** BlackBox request */
- (ArsdkRequest * _Nonnull)subscribeToRcBlackBox:(int16_t)handle
                                    buttonAction:(ArsdkRcBlackBoxButtonActionCb)buttonActionBlock
                                    pilotingInfo:(ArsdkRcBlackBoxPilotingInfoCb)pilotingInfoBlock {
    [self assertCallerThread];
    return [[BlackBoxListener alloc] initWithArsdkCore:self
                                          deviceHandle:handle
                                          buttonAction:buttonActionBlock
                                          pilotingInfo:pilotingInfoBlock];
}

@end
