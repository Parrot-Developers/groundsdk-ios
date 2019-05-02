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
#include <libpomp.h>

/**
 Objc Wrapper around a pomp_buffer
 */
@interface PompBuffer: NSObject
/** pomp_buffer instance */
@property (nonatomic) struct pomp_buffer* buf;
/** next buffer when buffer in a PompBufferQueue */
@property (nonatomic, strong) PompBuffer* next;

/**
 Constructor
 @param buf: native buffer to wrap
 */
- (instancetype)init:(struct pomp_buffer*) buf;

/**
 Gets buffer content as NSData.
 @return a NSData pointing to pomp_buffer data. Those data are valid as long as the PompBuffer is alive.
 */
- (NSData*)getAsData;

@end


/**
 A linked list of PompBuffer
 */
@interface PompBufferQueue : NSObject
/** First buffer in the queue, nil if queue is empty */
@property (nonatomic, strong) PompBuffer *first;
/** Last buffer in the queue, nil if queue is empty */
@property (nonatomic, strong) PompBuffer *last;
/** Offset in the first buffer.  */
@property (nonatomic) NSUInteger firstBufOffset;

/**
 Queue a buffer
 @param buf: buffer to queue
 */
- (void)queueBuffer:(PompBuffer *)buf;

/**
 Dequeue the first buffer
 */
- (void)dequeue;

@end
