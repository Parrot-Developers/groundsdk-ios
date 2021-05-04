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
#import "ArsdkCore+Update.h"
#import "Logger.h"
#import <arsdkctrl/arsdkctrl.h>

/** common loging tag */
extern ULogTag *TAG;

#pragma mark - arsdk_update_helpers

static struct arsdk_updater_itf *get_updater_itf(struct arsdk_ctrl *ctrl, short device_handle) {
    struct arsdk_device *device = arsdk_ctrl_get_device(ctrl, device_handle);
    if (device ==  NULL) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_ctrl_get_device: device not found"];
        return NULL;
    }
    struct arsdk_updater_itf *updater_itf = NULL;
    int res = arsdk_device_get_updater_itf(device, &updater_itf);
    if (res < 0) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_device_get_updater_itf: %s", strerror(-res)];
        return NULL;
    }
    return updater_itf;
}

#pragma mark - FirmwareUpdateRequest

@interface FirmwareUpdateRequest : ArsdkRequest
@property (nonatomic, readonly) ArsdkUpdateProgress progressBlock;
@property (nonatomic, readonly) ArsdkUpdateCompletion completionBlock;
@property (nonatomic) struct arsdk_updater_req_upload* request;

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(NSInteger)deviceType
                             file:(NSString* _Nonnull)filepath
                         progress:(ArsdkUpdateProgress)progressBlock
                       completion:(ArsdkUpdateCompletion)completionBlock;

@end

@implementation FirmwareUpdateRequest

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(NSInteger)deviceType
                             file:(NSString* _Nonnull)filepath
                         progress:(ArsdkUpdateProgress)progressBlock
                       completion:(ArsdkUpdateCompletion)completionBlock {
    self = [super initWithArsdkCore:arsdkCore];
    if (self) {
        _progressBlock = progressBlock;
        _completionBlock = completionBlock;
        // switch to arsdk thread (i.e pomp_loop thread)
        [arsdkCore dispatch:^{
            // ignore request if already canceled
            if (self.canceled) {
                return;
            }

            struct arsdk_updater_itf *updater_itf = get_updater_itf(self.arsdkCore.ctrl, deviceHandle);
            if (updater_itf == NULL) {
                goto failed;
            }

            struct arsdk_updater_req_upload_cbs cbs;
            memset(&cbs, 0, sizeof(cbs));
            cbs.userdata = (__bridge_retained void *)self;
            cbs.progress = &update_progress;
            cbs.complete = &update_completed;
            int res = arsdk_updater_itf_create_req_upload(updater_itf, [filepath UTF8String],
                                                          (enum arsdk_device_type)deviceType, &cbs, &self->_request);
            if (res < 0) {
                [ULog e:TAG msg:@"FirmwareUpdateRequest arsdk_updater_itf_create_req_upload: %s", strerror(-res)];
                goto failed;
            }
            return;

        failed:
            // failure, complete with error
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_completionBlock(ArsdkUpdateStatusFailed);
            });
        }];
    }
    return self;
}

- (void)cancel {
    [super cancel];
    // ignore request if already canceled
    if (self.canceled) {
        return;
    }

    [self.arsdkCore dispatch:^{
        if (self->_request) {
            arsdk_updater_req_upload_cancel(self->_request);
        }
    }];
}

static void update_progress(struct arsdk_updater_itf *itf,
                            struct arsdk_updater_req_upload *req,
                            float percent,
                            void *userdata) {
    FirmwareUpdateRequest* request = (__bridge FirmwareUpdateRequest*)(userdata);
    dispatch_async(dispatch_get_main_queue(), ^{
        request.progressBlock(percent);
    });
}

static void update_completed(struct arsdk_updater_itf *itf,
                             struct arsdk_updater_req_upload *req,
                             enum arsdk_updater_req_status status,
                             int error,
                             void *userdata) {
    FirmwareUpdateRequest* request = (__bridge_transfer FirmwareUpdateRequest*)(userdata);
    request->_request = NULL;
    dispatch_async(dispatch_get_main_queue(), ^{
        request.completionBlock((ArsdkUpdateStatus)status);
    });
}

@end


@implementation ArsdkCore (Update)

/** Update request */
- (ArsdkRequest * _Nonnull)updateFirwmare:(int16_t)handle
                               deviceType:(NSInteger)deviceType
                                     file:(NSString*)filepath
                                 progress:(ArsdkUpdateProgress)progressBlock
                               completion:(ArsdkUpdateCompletion)completionBlock
{
    [self assertCallerThread];
    return [[FirmwareUpdateRequest alloc] initWithArsdkCore:self
                                               deviceHandle:handle
                                                 deviceType:deviceType
                                                       file:filepath
                                                   progress:progressBlock
                                                 completion:completionBlock];
}

@end
