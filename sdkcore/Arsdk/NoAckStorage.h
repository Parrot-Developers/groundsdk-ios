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
#import "ArsdkCore+Devices.h"

/** No Ack command type */
typedef NS_ENUM(NSInteger, ArsdkNoAckCmdType) {
    /** Piloting command */
    ArsdkNoAckCmdTypePiloting,
    /** Gimbal control */
    ArsdkNoAckCmdTypeGimbalControl,
    /** Camera zoom */
    ArsdkNoAckCmdTypeCameraZoom,
};

/**
Storage of an ArsdkCommandEncoder block registered in the NoAck Command Loop

This container class is used to store "NoAckCde Encoders blocks" in an array.

The type of a "Command Block" is : `ArsdkCommandEncoder (^encoderBlock)(void)`
These blocks are stored at the ArsdkEngine level (DeviceController.swift) in an Array.

To give this array of closures (from Swift) to an array of blocks (Objective-C), it is necessary to encapsulate
each block in this class.

It seems that Swift closures and Objective-C blocks are not exactly identical (although they are closely related).
If the Swift closure / Objective-C block interoperability seems to work well for a function parameter or a property,
this is obviously not the case for a closure array.
 */
@interface NoAckStorage : NSObject

/** ArsdkCommandEncoder block */
@property (readonly)  ArsdkCommandEncoder (^encoderBlock)(void);
@property (readonly, assign) ArsdkNoAckCmdType type;

- (instancetype)initWithCmdEncoder:(ArsdkCommandEncoder (^)(void))encoderBlock type:(ArsdkNoAckCmdType)type;

@end
