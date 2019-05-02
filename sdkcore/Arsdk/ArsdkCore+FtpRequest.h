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

#import <Foundation/Foundation.h>
#import "ArsdkCore.h"
#import "ArsdkRequest.h"

/** Ftp request status code */
typedef NS_ENUM(NSInteger, ArsdkFtpRequestStatus) {
    // Numerical values must be kept in sync with C code (arsdk_ftp_req_status)
    /** request succeeded */
    ArsdkFtpRequestStatusOk = 0,
    /** request canceled by the user */
    ArsdkFtpRequestStatusCanceled = 1,
    /** request failed */
    ArsdkFtpRequestStatusFailed = 2,
    /** request aborted by disconnection, no more requests can be sent */
    ArsdkFtpRequestStatusAborted = 3
};

/** Ftp server type */
typedef NS_ENUM(NSInteger, ArsdkFtpServerType) {
    // Numerical values must be kept in sync with C code (arsdk_ftp_srv_type)
    /** Flight Plan ftp server */
    ArsdkFtpServerTypeFlightPlan = 2,
};

/// Progress callback
typedef void(^ArsdkFtpRequestProgress)(float progress);

/// Completion callback
typedef void(^ArsdkFtpRequestCompletion)(ArsdkFtpRequestStatus status);


@interface ArsdkCore (FtpRequest)
/**
 Upload an file on the drone using an ftp request

 @param handle handle of the drone
 @param deviceType type of device
 @param serverType type of server
 @param srcPath local path of the file to upload
 @param dstPath destination path of the file to upload
 @param progressBlock progress block
 @param completionBlock completion block
 @return the request
 */
- (ArsdkRequest* _Nonnull)ftpUpload:(int16_t)handle
                         deviceType:(NSInteger)deviceType
                         serverType:(ArsdkFtpServerType)serverType
                            srcPath:(NSString* _Nonnull)srcPath
                             dstPth:(NSString* _Nonnull)dstPath
                           progress:(ArsdkFtpRequestProgress _Nonnull)progressBlock
                         completion:(ArsdkFtpRequestCompletion _Nonnull)completionBlock;
@end
