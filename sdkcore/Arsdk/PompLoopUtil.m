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

#import "PompLoopUtil.h"
#import "Logger.h"
#include <libpomp.h>

extern ULogTag* TAG;


@interface PompLoopUtil ()

/** True when stop has been called */
@property (nonatomic) bool stopped;
/** True when runLoop has been called */
@property (nonatomic) bool running;
/** Dispatch queue running the pomp loop */
@property (nonatomic, strong) dispatch_queue_t queue;
/** Pomp loop processor block */
@property (nonatomic, strong) void (^loopProcess)(void);
/** Pomp Loop */
@property (nonatomic, assign) struct pomp_loop *loop;
/** Thread that called init, used to check methods are called in the same thread */
@property (nonatomic, strong) NSThread *callerThread;
/** Name for logs */
@property (nonatomic, strong) NSString *name;
@end

/** pomp loop queue identifier */
static const void *const kLooperQueueIdentifier = &kLooperQueueIdentifier;


@implementation PompLoopUtil

/**
 Retrieves the internal pomp loop

 @return the pomp loop
 */
- (struct pomp_loop * _Nonnull)internalPompLoop {
    return self.loop;
}

- (instancetype)init
{
    return [self initWithName: nil];
}

/**
 Constructor
 @param name String Id used in Logs
 @return instancetype or NIL if error
 */
- (instancetype _Nonnull)initWithName:(NSString * _Nullable)name{
    if (name.length == 0) {
        name = @"noname";
    }
    self.name = name;
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"init PompLoop %s", name.UTF8String];
    }

    self = [super init];
    if (self) {
        _callerThread = [NSThread currentThread];
        self.loop = pomp_loop_new();
        if (self.loop == NULL) {
            [ULog w:TAG msg:@"PompLoop %s.init", self.name.UTF8String];
        } else {
            NSString *queueName = [NSString stringWithFormat:@"com.parrot.pomploop.%@", name];
            self.queue = dispatch_queue_create(queueName.UTF8String, DISPATCH_QUEUE_SERIAL);
            dispatch_queue_set_specific(self.queue, kLooperQueueIdentifier, (void *)kLooperQueueIdentifier, NULL);
            PompLoopUtil* __weak weakSelf = self;
            _loopProcess = ^{
                if (weakSelf != nil) {
                    pomp_loop_wait_and_process(weakSelf.loop, -1);
                    if (weakSelf != nil && !weakSelf.stopped) {
                        dispatch_async(weakSelf.queue, weakSelf.loopProcess);
                    }
                }
            };
        }
    }
    return self;
}

/**
 Run the Loop.
 The caller must be in the same thread as the one used during the init
 */
- (void)runLoop {
    [self assertCallerThread];
    if (self.running){
        return;
    }
    self.stopped = false;
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"run Loop %s", self.name.UTF8String];
    }
    dispatch_async(self.queue, self.loopProcess);
}

/**
 The caller must be in the same thread as the one used during the init
 */
- (void)stopRun {
    [self assertCallerThread];
    self.running = false;
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"stop loop %s", self.name.UTF8String];
    }

    if (!self.stopped) {
        self.stopped = true;
        pomp_loop_wakeup(self.loop);
    }
}

/**
 Queue a block to be executed in the loop thread

 @param block The block to execute.
 */
- (void)dispatch:(void (^)(void))block {
    [self assertNotLooperQueue];
    dispatch_async(self.queue, block);
    pomp_loop_wakeup(self.loop);
}

/**
 Queue a block to be executed in the loop thread and wait until execution

 @param block The block to execute.
 */
- (void)dispatch_sync:(void (^)(void))block {
    if (!self.stopped) {
        [self assertNotLooperQueue];
        
        NSCondition *condition = [[NSCondition alloc] init];
        
        [condition lock];
        dispatch_async(_queue, ^{
            block();
            [condition lock];
            [condition signal];
            [condition unlock];
        });
        pomp_loop_wakeup(self.loop);
        [condition wait];
        [condition unlock];
    }
}

- (void)dealloc {
    if (self.loop) {
        if (self.running) {
            self.stopped = true;
            self.running = false;
            pomp_loop_wakeup(self.loop);
        }
        pomp_loop_idle_flush(_loop);
        pomp_loop_destroy(_loop);
        _loop = nil;
    }
}


/**
 Checks that current thread is the same than the one that called init
 */
- (void)assertCallerThread {
    NSAssert1(_callerThread == [NSThread currentThread],
              @"Must be called on the same thread than constructor: %@", _callerThread);
}

/**
 Checks that code is running inside the pomp loop dispatch queue
 */
- (void)assertLooperQueue {
    NSAssert(dispatch_get_specific(kLooperQueueIdentifier) != NULL, @"Not in loop queue");
}

/**
 Checks that code is not running inside the pomp loop dispatch queue
 */
- (void)assertNotLooperQueue {
    NSAssert(dispatch_get_specific(kLooperQueueIdentifier) == NULL, @"Already in loop queue");
}

@end
