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
#import "ArsdkCore+Crashml.h"
#import "Logger.h"
#import <arsdkctrl/arsdkctrl.h>

/** common loging tag */
extern ULogTag *TAG;

#pragma mark - arsdk_crashml_helpers

static struct arsdk_crashml_itf *get_crashml_itf(struct arsdk_ctrl *ctrl, short device_handle) {
    struct arsdk_device *device = arsdk_ctrl_get_device(ctrl, device_handle);
    if (device ==  NULL) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_ctrl_get_device: device not found"];
        return NULL;
    }
    struct arsdk_crashml_itf *crashml_itf = NULL;
    int res = arsdk_device_get_crashml_itf(device, &crashml_itf);
    if (res < 0) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_device_get_crashml_itf: %s", strerror(-res)];
        return NULL;
    }
    return crashml_itf;
}

#pragma mark - CrashmlDownloadRequest

@interface CrashmlDownloadRequest : ArsdkRequest
@property (nonatomic, readonly) ArsdkCrashmlDownloadProgress progressBlock;
@property (nonatomic, readonly) ArsdkCrashmlDownloadCompletion completionBlock;
@property (nonatomic) struct arsdk_crashml_req* request;

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                             path:(NSString* _Nonnull)path
                         progress:(ArsdkCrashmlDownloadProgress)progressBlock
                       completion:(ArsdkCrashmlDownloadCompletion)completionBlock;

@end

@implementation CrashmlDownloadRequest

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                             path:(NSString* _Nonnull)path
                         progress:(ArsdkCrashmlDownloadProgress)progressBlock
                       completion:(ArsdkCrashmlDownloadCompletion)completionBlock {
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

            struct arsdk_crashml_itf *crashml_itf = get_crashml_itf(self.arsdkCore.ctrl, deviceHandle);
            if (crashml_itf == NULL) {
                goto failed;
            }

            if (![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:nil]) {
                goto failed;
            }
            struct arsdk_crashml_req_cbs cbs;
            memset(&cbs, 0, sizeof(cbs));
            cbs.userdata = (__bridge_retained void *)self;
            cbs.progress = &crashml_progress;
            cbs.complete = &crashml_completed;
            int res = arsdk_crashml_itf_create_req(crashml_itf, [path UTF8String], (enum arsdk_device_type)deviceType,
                                                   &cbs, ARSDK_CRASHML_TYPE_TARGZ, &self->_request);
            if (res < 0) {
                [ULog e:TAG msg:@"CrashmlDownloadRequest arsdk_crashml_itf_create_req: %s", strerror(-res)];
                goto failed;
            }
            return;

        failed:
            // failure, complete with error
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_completionBlock(ArsdkCrashmlStatusFailed);
            });
        }];
    }
    return self;
}

-(void)cancel {
    [super cancel];
    [self.arsdkCore dispatch:^{
        if (self->_request) {
            arsdk_crashml_req_cancel(self->_request);
        }
    }];
}

static void crashml_progress(struct arsdk_crashml_itf *itf,
                             struct arsdk_crashml_req *req,
                             const char *path,
                             int count,
                             int total,
                             enum arsdk_crashml_req_status status,
                             void *userdata) {
    CrashmlDownloadRequest* request = (__bridge CrashmlDownloadRequest*)(userdata);
    NSString* nspath = [NSString stringWithUTF8String:path];
    dispatch_async(dispatch_get_main_queue(), ^{
        request.progressBlock(nspath, (ArsdkCrashmlStatus)status);
    });
}

static void crashml_completed(struct arsdk_crashml_itf *itf,
                              struct arsdk_crashml_req *req,
                              enum arsdk_crashml_req_status status,
                              int error,
                              void *userdata) {
    CrashmlDownloadRequest* request = (__bridge_transfer CrashmlDownloadRequest*)(userdata);
    request->_request = NULL;
    dispatch_async(dispatch_get_main_queue(), ^{
        request.completionBlock((ArsdkCrashmlStatus)status);
    });
}

@end


@implementation ArsdkCore (Crashml)

/** Crashml request */
- (ArsdkRequest * _Nonnull)downloadCrashml:(int16_t)handle
                               deviceType:(NSInteger)deviceType
                                     path:(NSString*)path
                                 progress:(ArsdkCrashmlDownloadProgress)progressBlock
                               completion:(ArsdkCrashmlDownloadCompletion)completionBlock
{
    [self assertCallerThread];
    return [[CrashmlDownloadRequest alloc] initWithArsdkCore:self
                                               deviceHandle:handle
                                                 deviceType:(int)deviceType
                                                       path:path
                                                   progress:progressBlock
                                                 completion:completionBlock];
}

@end
