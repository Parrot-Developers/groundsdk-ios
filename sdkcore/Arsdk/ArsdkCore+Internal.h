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
#import "PompLoopUtil.h"

/*
 Arsdk control internal API
 */
@interface ArsdkCore ()

/** Controller descriptor, sent during connection */
@property (nonatomic, strong) NSString * _Nonnull controllerDescriptor;
/** Controller version, sent during connection */
@property (nonatomic, strong) NSString * _Nonnull controllerVersion;
/** ArsdkCoreDeviceCommandListener storage */
@property (nonatomic, strong) NSMutableDictionary * _Nonnull commandListeners;

/**
 Checks that current thread is the same than the one that called init
 */
- (void)assertCallerThread;

/**
 Queue a block to be executed in the loop thread

 @param block: the block to execute
 */
- (void)dispatch:(void (^ _Nonnull)(void))block;

/**
 Allow adding commandListeners to the given device handle
 */
- (void)deviceConnected:(int16_t)handle;

/**
 Disallow (& release) commandListeners to the given device handle
 */
- (void)deviceDisconnected:(int16_t)handle;

/**
 Add a command listener to the given device.
 The listener is retained for the duration of the connection.
 If the handle is not associated with a connected drone, this method returns NO.
 */
- (bool)addDeviceCommandListener:(id<ArsdkCoreDeviceCommandListener> _Nonnull)listener toDevice:(int16_t)handle;

/**
 Pass the given command to all registered listeners for the given device
 */
- (void)passCommandToListeners:(const struct arsdk_cmd * _Nonnull)command forDevice:(int16_t)handle;

/**
 Retrieves the pomp loop utility.
 
 @return pomp loop utility
 */
- (PompLoopUtil * _Nonnull)pompLoopUtil;

@end

