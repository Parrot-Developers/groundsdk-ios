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
#import "ArsdkCore+FtpRequest.h"
#import "Logger.h"
#import <arsdkctrl/arsdkctrl.h>

/** common loging tag */
extern ULogTag *TAG;

#pragma mark - arsdk_ftp_helpers

static struct arsdk_ftp_itf *get_ftp_itf(struct arsdk_ctrl *ctrl, short device_handle) {
    struct arsdk_device *device = arsdk_ctrl_get_device(ctrl, device_handle);
    if (device ==  NULL) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_ctrl_get_device: device not found"];
        return NULL;
    }
    struct arsdk_ftp_itf *ftp_itf = NULL;
    int res = arsdk_device_get_ftp_itf(device, &ftp_itf);
    if (res < 0) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_device_get_ftp_itf: %s", strerror(-res)];
        return NULL;
    }
    return ftp_itf;
}

#pragma mark - FirmwareUpdateRequest

@interface FtpUploadRequest : ArsdkRequest
@property (nonatomic, readonly) ArsdkFtpRequestProgress progressBlock;
@property (nonatomic, readonly) ArsdkFtpRequestCompletion completionBlock;
@property (nonatomic) struct arsdk_ftp_req_put* request;

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(NSInteger)deviceType
                       serverType:(ArsdkFtpServerType)serverType
                          srcPath:(NSString* _Nonnull)srcPath
                           dstPth:(NSString* _Nonnull)dstPath
                         progress:(ArsdkFtpRequestProgress _Nonnull)progressBlock
                       completion:(ArsdkFtpRequestCompletion _Nonnull)completionBlock;

@end

@implementation FtpUploadRequest

- (instancetype)initWithArsdkCore:(ArsdkCore *)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(NSInteger)deviceType
                       serverType:(ArsdkFtpServerType)serverType
                          srcPath:(NSString *)srcPath
                           dstPth:(NSString *)dstPath
                         progress:(ArsdkFtpRequestProgress)progressBlock
                       completion:(ArsdkFtpRequestCompletion)completionBlock {
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

            struct arsdk_ftp_itf *ftp_itf = get_ftp_itf(self.arsdkCore.ctrl, deviceHandle);
            if (ftp_itf == NULL) {
                goto failed;
            }

            struct arsdk_ftp_req_put_cbs cbs;
            memset(&cbs, 0, sizeof(cbs));
            cbs.userdata = (__bridge_retained void *)self;
            cbs.progress = &upload_progress;
            cbs.complete = &upload_completed;
            int res = arsdk_ftp_itf_create_req_put(ftp_itf, &cbs, (enum arsdk_device_type)deviceType,
                                                   (enum arsdk_ftp_srv_type)serverType, [dstPath UTF8String],
                                                   [srcPath UTF8String], 0, &self->_request);

            if (res < 0) {
                [ULog e:TAG msg:@"FtpUploadRequest arsdk_ftp_itf_create_req_put: %s", strerror(-res)];
                goto failed;
            }
            return;

        failed:
            // failure, complete with error
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_completionBlock(ArsdkFtpRequestStatusFailed);
            });
        }];
    }
    return self;
}

-(void)cancel {
    [super cancel];
    [self.arsdkCore dispatch:^{
        if (self->_request) {
            arsdk_ftp_req_put_cancel(self->_request);
        }
    }];
}

static void upload_progress(struct arsdk_ftp_itf *itf,
                            struct arsdk_ftp_req_put *req,
                            float percent,
                            void *userdata) {
    FtpUploadRequest* request = (__bridge FtpUploadRequest*)(userdata);
    dispatch_async(dispatch_get_main_queue(), ^{
        request.progressBlock(percent);
    });
}

static void upload_completed(struct arsdk_ftp_itf *itf,
                             struct arsdk_ftp_req_put *req,
                             enum arsdk_ftp_req_status status,
                             int error,
                             void *userdata) {
    FtpUploadRequest* request = (__bridge_transfer FtpUploadRequest*)(userdata);
    request->_request = NULL;
    dispatch_async(dispatch_get_main_queue(), ^{
        request.completionBlock((ArsdkFtpRequestStatus)status);
    });
}

@end

@implementation ArsdkCore (FtpRequest)

-(ArsdkRequest *)ftpUpload:(int16_t)handle
                deviceType:(NSInteger)deviceType
                serverType:(ArsdkFtpServerType)serverType
                   srcPath:(NSString *)srcPath
                    dstPth:(NSString *)dstPath
                  progress:(ArsdkFtpRequestProgress)progressBlock
                completion:(ArsdkFtpRequestCompletion)completionBlock {
    [self assertCallerThread];
    return [[FtpUploadRequest alloc] initWithArsdkCore:self deviceHandle:handle deviceType:deviceType
                                            serverType:serverType srcPath:srcPath dstPth:dstPath
                                              progress:progressBlock completion:completionBlock];
}

@end
