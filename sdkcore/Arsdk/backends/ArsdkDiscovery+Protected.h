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

#import "ArsdkDiscovery.h"

/**
 Internal extension to the discovery
 */
@interface ArsdkDiscovery (Protected)

/**
 Called when the discovery is started.
 Implementation must start seaching for device
 */
- (void)doStart __attribute__((objc_requires_super));

/**
 Called when the discovery is stopped.
 Implementaiton must stop searching for devices
 */
- (void)doStop __attribute__((objc_requires_super));

/**
 Notify that a device has been discovered.

 Can be called on any thread, notification is forwarded on pomp loop thread

 @param name: device name
 @param type: device type
 @param addr: device address
 @param port: device port
 @param uid: device uid
 */
- (void)addDevice:(NSString*)name type:(NSInteger)type addr:(NSString*)addr port:(NSInteger)port uid:(NSString*)uid;

/**
 Notify that a previously discovered device has be removed

 Can be called on any thread, notification is forwarded on pomp loop thread

 @param name: device name
 @param type: device type
 */
- (void)removeDevice:(NSString*)name type:(NSInteger)type;


/**
 Notify that a previously discovered device has be removed

 Can be called on any thread, notification is forwarded on pomp loop thread

 @param uid: device id
 @param type: device type
 */
- (void)removeDeviceWithUid:(NSString*)uid type:(NSInteger)type;
@end

