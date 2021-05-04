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
#import "ArsdkCore+FlightLog.h"
#import "Logger.h"
#import <arsdkctrl/arsdkctrl.h>

/** common loging tag */
extern ULogTag *TAG;

#pragma mark - arsdk_flight_log_helpers

static struct arsdk_flight_log_itf *get_flight_log_itf(struct arsdk_ctrl *ctrl, short device_handle) {
    struct arsdk_device *device = arsdk_ctrl_get_device(ctrl, device_handle);
    if (device ==  NULL) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_ctrl_get_device: device not found"];
        return NULL;
    }
    struct arsdk_flight_log_itf *flight_log_itf = NULL;
    int res = arsdk_device_get_flight_log_itf(device, &flight_log_itf);
    if (res < 0) {
        [ULog w:TAG msg:@"ArsdkRequest arsdk_device_get_flight_log_itf: %s", strerror(-res)];
        return NULL;
    }
    return flight_log_itf;
}

#pragma mark - FlightLogDownloadRequest

@interface FlightLogDownloadRequest : ArsdkRequest
@property (nonatomic, readonly) ArsdkFlightLogDownloadProgress progressBlock;
@property (nonatomic, readonly) ArsdkFlightLogDownloadCompletion completionBlock;
@property (nonatomic) struct arsdk_flight_log_req* request;

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                             path:(NSString* _Nonnull)path
                         progress:(ArsdkFlightLogDownloadProgress)progressBlock
                       completion:(ArsdkFlightLogDownloadCompletion)completionBlock;

@end

@implementation FlightLogDownloadRequest

- (instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore
                     deviceHandle:(short)deviceHandle
                       deviceType:(int)deviceType
                             path:(NSString* _Nonnull)path
                         progress:(ArsdkFlightLogDownloadProgress)progressBlock
                       completion:(ArsdkFlightLogDownloadCompletion)completionBlock {
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

            struct arsdk_flight_log_itf *flight_log_itf = get_flight_log_itf(self.arsdkCore.ctrl, deviceHandle);
            if (flight_log_itf == NULL) {
                goto failed;
            }

            if (![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:nil]) {
                goto failed;
            }
            struct arsdk_flight_log_req_cbs cbs;
            memset(&cbs, 0, sizeof(cbs));
            cbs.userdata = (__bridge_retained void *)self;
            cbs.progress = &flight_log_progress;
            cbs.complete = &flight_log_completed;
            int res = arsdk_flight_log_itf_create_req(flight_log_itf, [path UTF8String],
                                                      (enum arsdk_device_type)deviceType, &cbs, &self->_request);
            if (res < 0) {
                [ULog e:TAG msg:@"FlightLogDownloadRequest arsdk_flight_log_itf_create_req: %s", strerror(-res)];
                goto failed;
            }
            return;

        failed:
            // failure, complete with error
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_completionBlock(ArsdkFlightLogStatusFailed);
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
            arsdk_flight_log_req_cancel(self->_request);
        }
    }];
}

static void flight_log_progress(struct arsdk_flight_log_itf *itf,
                             struct arsdk_flight_log_req *req,
                             const char *path,
                             int count,
                             int total,
                             enum arsdk_flight_log_req_status status,
                             void *userdata) {
    FlightLogDownloadRequest* request = (__bridge FlightLogDownloadRequest*)(userdata);
    NSString* nspath = [NSString stringWithUTF8String:path];
    dispatch_async(dispatch_get_main_queue(), ^{
        request.progressBlock(nspath, (ArsdkFlightLogStatus)status);
    });
}

static void flight_log_completed(struct arsdk_flight_log_itf *itf,
                              struct arsdk_flight_log_req *req,
                              enum arsdk_flight_log_req_status status,
                              int error,
                              void *userdata) {
    FlightLogDownloadRequest* request = (__bridge_transfer FlightLogDownloadRequest*)(userdata);
    request->_request = NULL;
    dispatch_async(dispatch_get_main_queue(), ^{
        request.completionBlock((ArsdkFlightLogStatus)status);
    });
}

@end


@implementation ArsdkCore (FlightLog)

/** FlightLog request */
- (ArsdkRequest * _Nonnull)downloadFlightLog:(int16_t)handle
                                deviceType:(NSInteger)deviceType
                                      path:(NSString*)path
                                  progress:(ArsdkFlightLogDownloadProgress)progressBlock
                                completion:(ArsdkFlightLogDownloadCompletion)completionBlock
{
    [self assertCallerThread];
    return [[FlightLogDownloadRequest alloc] initWithArsdkCore:self
                                                deviceHandle:handle
                                                  deviceType:(int)deviceType
                                                        path:path
                                                    progress:progressBlock
                                                  completion:completionBlock];
}

@end
