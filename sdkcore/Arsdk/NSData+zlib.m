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

#import "NSData+zlib.h"
#include <zlib.h>

static int gzip(unsigned char *dest, size_t *dest_len,
                const unsigned char *source1, unsigned long source1_len,
                const unsigned char *source2, unsigned long source2_len) {
    z_stream stream;
    int err;
    size_t total_dest_len = *dest_len;

    // request gzip header
    stream.zalloc = (alloc_func)Z_NULL;
    stream.zfree = (free_func)Z_NULL;
    stream.opaque = (voidpf)Z_NULL;
    err = deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15+16, 8, Z_DEFAULT_STRATEGY);
    if (err != Z_OK)
        return err;

    // compress source 1
    stream.next_in = (Bytef *)source1;
    stream.avail_in = (uInt)source1_len;
    stream.next_out = (Bytef *)dest;
    stream.avail_out = (uInt)total_dest_len;

    int flushFlag = (source2 != NULL) ? Z_NO_FLUSH : Z_FINISH;
    err = deflate(&stream, flushFlag);
    if ((flushFlag == Z_FINISH && err != Z_STREAM_END) ||
        (flushFlag == Z_NO_FLUSH && err != Z_OK)) {
        deflateEnd(&stream);
        return err == Z_OK ? Z_BUF_ERROR : err;
    }
    *dest_len = (size_t)stream.total_out;

    if (source2 != NULL) {
        // compress source 2
        stream.next_in = (Bytef *)source2;
        stream.avail_in = (uInt)source2_len;
        stream.next_out = (Bytef *)(dest + *dest_len);
        stream.avail_out = (uInt)(total_dest_len - *dest_len);

        err = deflate(&stream, Z_FINISH);
        if (err != Z_STREAM_END) {
            deflateEnd(&stream);
            return err == Z_OK ? Z_BUF_ERROR : err;
        }
        *dest_len += (size_t)stream.total_out;
    }

    err = deflateEnd(&stream);
    return err;
}

@implementation NSData (Zlib)

- (NSData *)compress {
    int ret;
    void *compressedData = NULL;

    /* calculate upper bound on the compressed size
     * Add 32 bytes for gzip header */
    size_t comp_size = compressBound(self.length) + 32;

    /* allocate compressed buffer */
    compressedData = malloc(comp_size);
    if (compressedData == NULL) {
        return nil;
    }

    /* compress attachment file */
    ret = gzip(compressedData, &comp_size, self.bytes, self.length, NULL, 0);
    if (ret != 0) {
        free(compressedData);
        return nil;
    } else {
        return [NSData dataWithBytesNoCopy:compressedData length:comp_size];
    }
}

- (NSData*)compressWithAddedData:(NSData *)addedData {
    int ret;
    void *compressedData = NULL;

    /* calculate upper bound on the compressed size
     * Add 32 bytes for gzip header */
    size_t comp_size = compressBound(self.length + addedData.length) + 32;

    /* allocate compressed buffer */
    compressedData = malloc(comp_size);
    if (compressedData == NULL) {
        return nil;
    }

    /* compress attachment file */
    ret = gzip(compressedData, &comp_size, self.bytes, self.length, addedData.bytes, addedData.length);
    if (ret != 0) {
        free(compressedData);
        return nil;
    } else {
        return [NSData dataWithBytesNoCopy:compressedData length:comp_size];
    }
}
@end
