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

/** Crashml status code */
typedef NS_ENUM(NSInteger, ArsdkCrashmlStatus) {
    // Numerical values must be kept in sync with C code (arsdk_crashml_req_status)
    /** request succeeded */
    ArsdkCrashmlStatusOk = 0,
    /** request canceled by the user */
    ArsdkCrashmlStatusCanceled = 1,
    /** request failed */
    ArsdkCrashmlStatusFailed = 2,
    /** request aborted by disconnection, no more requests can be sent */
    ArsdkCrashmlStatusAborted = 3
};

/// Progress callback
typedef void(^ArsdkCrashmlDownloadProgress)(NSString* _Nonnull path, ArsdkCrashmlStatus status);

/// Completion callback
typedef void(^ArsdkCrashmlDownloadCompletion)(ArsdkCrashmlStatus status);


/**
 Arsdk Controller, Crashml related functions
 */
@interface ArsdkCore (Crashml)

/** Crashml request */
- (ArsdkRequest * _Nonnull)downloadCrashml:(int16_t)handle
                               deviceType:(NSInteger)deviceType
                                     path:(NSString* _Nonnull)path
                                 progress:(ArsdkCrashmlDownloadProgress _Nonnull)progressBlock
                               completion:(ArsdkCrashmlDownloadCompletion _Nonnull)completionBlock;
@end
