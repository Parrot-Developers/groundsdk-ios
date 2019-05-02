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
#import "ArsdkCore.h"


@class NoAckStorage;

/**
 Piloting command loop, used to send NoAck commands periodicaly
 */
@interface NoAckCommandLoop : NSObject

/**
 Constructor NoAckCommandLoop
 @param ctrl arsdk ctrl instance
 @param deviceHandle arsdk handle for the Device backend
 @param period lopp period in ms
 @return instance
 */
- (instancetype _Nonnull )initWithArsdkctrl:(struct arsdk_ctrl *_Nonnull)ctrl
                               deviceHandle:(short)deviceHandle
                                   periodMs:(int)period;

/**
 Set a  array of blocks to be executed continuously in the loop, each returning an ArsdkCommandEncoder
 These blocks `ArsdkCommandEncoder (^)(void)` are stored in NoAckStorage objects

 Note : A non empty array will start the loop. A empty array will stop the loop.
 Note : this method is thread safe (this method can be called from a different thread than the loop's thread

 @param encoders the array of NoAckStorage*
 */
- (void)setEncoderList:(NSArray<NoAckStorage *> *_Nullable)encoders;

/** Ensure the loop is stopped and the ListOfEncoder is empty */
- (void)reset;

@end
