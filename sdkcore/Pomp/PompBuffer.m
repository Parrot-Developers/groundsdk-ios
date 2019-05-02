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

#import "PompBuffer.h"
#import "Logger.h"
extern ULogTag* TAG;

@implementation PompBuffer

/**
 Constructor
 @param buf: native buffer to wrap
 */
-(instancetype)init:(struct pomp_buffer*) buf {
    self = [super init];
    if (self) {
        pomp_buffer_ref(buf);
        _buf = buf;
        _next = NULL;
    }
    return self;
}

/**
 Destructor
 */
-(void)dealloc {
    pomp_buffer_unref(_buf);
}

/**
 Gets buffer content as NSData.
 @return a NSData pointing to pomp_buffer data. Those data are valid as long as the PompBuffer is alive.
 */
- (NSData*)getAsData {
    const void *data = NULL;
    size_t len = 0;

    // gets data to send
    int res = pomp_buffer_get_cdata(_buf, &data, &len, NULL);
    if (res != 0) {
        [ULog e:TAG msg:@"PompBuffer pomp_buffer_get_cdata %s", strerror(-res)];
        return NULL;
    }

    // wrap data in a NSData
    return [NSData dataWithBytesNoCopy:(uint8_t*)data length:len freeWhenDone:NO];
}

@end

@implementation PompBufferQueue

/**
 Queue a buffer
 @param buf: buffer to queue
 */
- (void)queueBuffer:(PompBuffer *)buf {
    if (_last != NULL) {
        _last.next = buf;
        _last = buf;
    } else {
        _last = buf;
        _first = buf;
    }
}

/**
 Dequeue the first buffer
 */
- (void)dequeue {
    PompBuffer* buf = _first;
    _first = _first.next;
    _firstBufOffset = 0;
    buf.next = NULL;
    if (_first == NULL) {
        _last = NULL;
    }
}
@end
