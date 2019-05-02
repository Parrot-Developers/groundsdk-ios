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

typedef NS_ENUM(NSInteger, Level) {
    LOG_CRIT =     2, /* critical conditions */
    LOG_ERR =      3, /* error conditions */
    LOG_WARN =     4, /* warning conditions */
    LOG_NOTICE =   5, /* normal but significant condition */
    LOG_INFO =     6, /* informational message */
    LOG_DEBUG =    7, /* debug-level message */
};

/**
 Ulog tag used to associate log tag and log level.
 */
@interface ULogTag : NSObject

- (instancetype)initWithName:(NSString *)name;

/**
 Set the minimum level to log for the tag.

 @param level the minimum level.
 */
- (void)setMinLevel:(Level)level;

/**
 Get the minimum level to log for the tag.

 @param level the minimum level.
 */
- (Level)minLevel;

@end

/** Common logger based on ulog, using asl as backend */
@interface ULog : NSObject

/**
 Start to save logs in file.
 */
+ (NSString *)startFileRecord;

/**
 Get the log path.
 */
+ (NSString *)getLogPath ;

/**
 Stop to save logs in file.
 */
+ (void)stopFileRecord;

/**
 Send a critical log.

 @param tag tag use to log.
 @param msg message to log.
 */
+ (void) c:(ULogTag *)tag msg:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);
+ (void) c:(ULogTag *)tag :(NSString *)msg;

/**
 Send an error log.

 @param tag tag use to log.
 @param msg message to log.
 */
+ (void) e:(ULogTag *)tag msg:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);
+ (void) e:(ULogTag *)tag :(NSString *)msg;

/**
 Send a warning log.

 @param tag tag use to log.
 @param msg message to log.
 */
+ (void) w:(ULogTag *)tag msg:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);
+ (void) w:(ULogTag *)tag :(NSString *)msg;

/**
 Send a notice log.

 @param tag tag use to log.
 @param msg message to log.
 */
+ (void) n:(ULogTag *)tag msg:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);
+ (void) n:(ULogTag *)tag :(NSString *)msg;

/**
 Send an informational log.

 @param tag tag use to log.
 @param msg message to log.
 */
+ (void) i:(ULogTag *)tag msg:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);
+ (void) i:(ULogTag *)tag :(NSString *)msg;

/**
 Send a debug log.

 @param tag tag use to log.
 @param msg message to log.
 */
+ (void) d:(ULogTag *)tag msg:(NSString *)msg, ...;
+ (void) d:(ULogTag *)tag :(NSString *)msg;

/**
 Set the minimum level to log for a tag.

 @param minLevel the minimum level to log.
 @param tagName tag name.
 */
+ (int) setLogLevel:(Level) minLevel tagName:(NSString *)tagName ;

/**
 Check if the critical log will be logged for this tag.

 @param tag tag to check.
 @return true if critical log is enabled otherwise false.
 */
+ (BOOL) c:(ULogTag *)tag;

/**
 Check if the error log will be logged for this tag.

 @param tag tag to check.
 @return true if error log is enabled otherwise false.
 */
+ (BOOL) e:(ULogTag *)tag;

/**
 Check if the warning log will be logged for this tag.

 @param tag tag to check.
 @return true if warning log is enabled otherwise false.
 */
+ (BOOL) w:(ULogTag *)tag;

/**
 Check if the informational log will be logged for this tag.

 @param tag tag to check.
 @return true if informational log is enabled otherwise false.
 */
+ (BOOL) i:(ULogTag *)tag;

/**
 Check if the notice log will be logged for this tag.

 @param tag tag to check.
 @return true if notice log is enabled otherwise false.
 */
+ (BOOL) n:(ULogTag *)tag;

/**
 Check if the debug log will be logged for this tag.

 @param tag tag to check.
 @return true if debug log is enabled otherwise false.
 */
+ (BOOL) d:(ULogTag *)tag;
@end
