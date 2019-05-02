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

#import "NoAckCommandLoop.h"
#import "ArsdkCore+Devices.h"
#import <arsdkctrl/arsdkctrl.h>
#import "Logger.h"
#import "NoAckStorage.h"

/** common loging tag */
extern ULogTag *TAG;

@interface NoAckCommandLoop()

/** Array of NoAck command encoders */
@property (atomic, strong) NSArray<NoAckStorage *> *encoders;

/** device handle fot this pcmd loop */
@property (nonatomic) int16_t device_handle;
/** arsdk ctrl instance */
@property (nonatomic) struct arsdk_ctrl *ctrl;
/** loop timer */
@property (nonatomic) struct pomp_timer *timer;

/** period of the loop */
@property (nonatomic) int periodMs;

/** generate and send NoAck command */
- (void)sendCommands;
@end


@implementation NoAckCommandLoop

/**
 pomp timer callback
 */
static void pcmd_timer_cb(struct pomp_timer *timer, void *userdata) {
    NoAckCommandLoop* self = (__bridge NoAckCommandLoop *)(userdata);
    if (self) {
        [self sendCommands];
    }
}

/**
 Constructor NoAckCommandLoop
 @param ctrl arsdk ctrl instance
 @param deviceHandle arsdk handle for the Device backend
 @param period lopp period in ms
 @return instance
 */
- (instancetype _Nonnull )initWithArsdkctrl:(struct arsdk_ctrl *_Nonnull)ctrl
                               deviceHandle:(short)deviceHandle
                                   periodMs:(int)period
{
    self = [super init];
    if (self) {
        _periodMs = period;
        _timer = NULL;
        _ctrl = ctrl;
        _device_handle = deviceHandle;
        _encoders = nil;
    }
    return self;
}

/**
 Set a  array of blocks to be executed continuously in the loop, each returning an ArsdkCommandEncoder
 These blocks `ArsdkCommandEncoder (^)(void)` are stored in NoAckStorage objects

 Note : A non empty array will start the loop. A empty array will stop the loop.
 Note : this method is thread safe (this method can be called from a different thread than the loop's thread

 @param encoders the array of blocks
 */
- (void)setEncoderList:(NSArray<NoAckStorage *> *_Nullable)encoders
{
    self.encoders = encoders;

    if (self.encoders.count && self.timer == nil) {
        // start the loop
        [self start];
    } else if (self.encoders.count == 0 && self.timer){
        [self stop];
    }
}

/**
 Starts timer
 */
- (int)start {
    _timer = pomp_timer_new(arsdk_ctrl_get_loop(_ctrl), &pcmd_timer_cb, (__bridge void *)self);
    if (_timer == NULL)
        return -EINVAL;
    int res = pomp_timer_set_periodic(_timer, self.periodMs, self.periodMs);
    return res;
}

/**
 Stops timer
 */
- (void)stop {
    if (_timer) {
        pomp_timer_clear(_timer);
        pomp_timer_destroy(_timer);
        _timer = NULL;
    }
}

- (void)reset {
    [self setEncoderList:nil];
}

/**
 Generate and send NoAck commands
 */
- (void)sendCommands {

    // get the list of encoders
    // keep a strong reference
    NSArray<NoAckStorage *> *encodersArray = self.encoders;

    struct arsdk_device *device = arsdk_ctrl_get_device(_ctrl, _device_handle);
    if (device ==  NULL) {
        [ULog e:TAG msg:@"NoAckCommandLoop.sendCommand arsdk_ctrl_get_device: device not found"];
        return;
    }

    struct arsdk_cmd_itf *cmd_itf = arsdk_device_get_cmd_itf(device);
    if (cmd_itf ==  NULL) {
        [ULog e:TAG msg:@"NoAckCommandLoop.sendCommand arsdk_device_get_cmd_itf: device not found"];
        return;
    }
    for (NoAckStorage *storage in encodersArray) {
        ArsdkCommandEncoder (^encoderBlock)(void) = storage.encoderBlock;
        struct arsdk_cmd command;
        ArsdkCommandEncoder encoder = encoderBlock();
        if (encoder) {
            int res = encoder(&command);
            if (res == 0) {
                arsdk_cmd_itf_send(cmd_itf, &command, NULL, NULL);
                arsdk_cmd_clear(&command);
            }
        }
    }
}

@end

