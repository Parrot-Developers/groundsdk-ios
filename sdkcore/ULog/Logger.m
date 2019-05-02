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

#import "Logger.h"
#import <stdio.h>
#import <asl.h>
#import <pthread.h>
#import <ulog.h>
@import os.log;

@interface ULogTag ()

@property (nonatomic, assign) struct ulog_cookie nativeCookie;
@property (nonatomic, retain) os_log_t log;

@end

@implementation ULogTag

#define SUBSYTEM "com.parrot.gsdk"

+(void) initialize {
    if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion >= 10) {
        ulog_set_cookie_register_func(&cookie_register_func);
    }
}

- (instancetype)initWithName:(NSString *)name {
    const char *nativeName = NULL;
    self = [super init];
    if (self) {
        nativeName = [name UTF8String];
        _nativeCookie.name = strdup(nativeName);
        _nativeCookie.namesize = (int)strlen(_nativeCookie.name)+1;
        _nativeCookie.level = -1;
        _nativeCookie.next = NULL;
        ulog_init(&_nativeCookie);
    }
    return self;
}

- (void) dealloc {
    free((char *)_nativeCookie.name);
}

- (void)setMinLevel:(Level)level {
    ulog_set_level(&_nativeCookie, level);
}

- (Level)minLevel {
    return ulog_get_level(&_nativeCookie);
}

- (struct ulog_cookie *)nativeCookiePtr {
    return &_nativeCookie;
}

static void cookie_register_func(struct ulog_cookie *cookie) {
    os_log_t log = os_log_create(SUBSYTEM, cookie->name);
    cookie->userdata = (__bridge_retained void *)log;
}

@end

/** Common logger based on ulog, using asl as backend */
@implementation ULog

/** Default folder where save the logs. Relative to the root of Documents */
#define DEFAULT_FOLDER "log"
/** Log file extension. */
#define LOG_EXT ".log"
static FILE *file;

/** called when the library is loaded, init ulog and asl or unified logging client */
+(void) initialize {
    if ([ULog useUnifiedLogging]) {
        unified_logging_init();
    } else {
        asl_ulog_init();
    }
}

+(BOOL)useUnifiedLogging {
    return [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion >= 10;
}

+ (NSString *)getLogPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //Get the get the path to the Documents directory
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *logsPath = [documentsDirectory stringByAppendingPathComponent: @DEFAULT_FOLDER];

    if (![[NSFileManager defaultManager] fileExistsAtPath:logsPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:logsPath withIntermediateDirectories:YES attributes:nil
                                                        error:NULL];
    }

    return logsPath;
}

+ (NSString *)getLogFilePath:(NSString *) path {
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HHmmss"];

    NSString *fileName = [[dateFormatter stringFromDate:[NSDate date]] stringByAppendingString:@LOG_EXT];

    return [path stringByAppendingPathComponent:fileName];
}

+ (NSString *)startFileRecord {
    if (file == NULL) {
        NSString *logPath = [self getLogPath];
        NSString *filePath = [self getLogFilePath:logPath];
        file = fopen([filePath UTF8String], "w+");

        if ([ULog useUnifiedLogging]) {
            // create dipatch queue for logging
            fileLogQueue = dispatch_queue_create("com.parrot.ulog", nil);
        } else {
            int fd = fileno(file);
            asl_add_output_file(client, fd, FORMAT, ASL_TIME_FMT_LCL, ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG),
                                ASL_ENCODE_SAFE);
        }
        return filePath;
    } else {
        return nil;
    }
}

+ (void)stopFileRecord {
    if (file != NULL) {
        if (![ULog useUnifiedLogging]) {
            int fd = fileno(file);
            asl_remove_log_file(client, fd);
        }
        fflush(file);
        fclose(file);
        file = NULL;
        fileLogQueue = NULL;
    }
}

#pragma mark - unified logging

static NSDateFormatter *dateFormatter;

static const char * const priotab[8] = {
    " ", " ", "C", "E", "W", "N", "I", "D"
};

/** dispatch queue used to log in file */
static dispatch_queue_t fileLogQueue;

static void unified_logging_init() {
    // create dipatch queue for logging
    fileLogQueue = dispatch_queue_create("com.parrot.file_logger", nil);
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM-dd HH:mm:ss.SSS"];
    ulog_set_write_func(&unified_logging_write_func);
}

static void unified_logging_write_func(uint32_t prio, struct ulog_cookie *cookie, const char *buf, int len) {
    os_log_type_t type;
    switch (prio) {
        case ULOG_DEBUG:
            type = OS_LOG_TYPE_DEBUG;
            break;
        case ULOG_INFO:
        case ULOG_NOTICE:
            type = OS_LOG_TYPE_INFO;
            break;
        case ULOG_WARN:
        case ULOG_ERR:
            type = OS_LOG_TYPE_ERROR;
            break;
        case ULOG_CRIT:
            type = OS_LOG_TYPE_FAULT;
            break;
        default:
            type = OS_LOG_TYPE_DEFAULT;
            break;
    }
    os_log_t os_log = OS_LOG_DEFAULT;
    if (cookie->userdata != NULL) {
        os_log = (__bridge os_log_t)cookie->userdata;
    }

    os_log_with_type(os_log, type, "%{public}s", buf);
    if (file != NULL) {
        char *local_buf = calloc(len, sizeof(char));
        char *local_tag = calloc(cookie->namesize, sizeof(char));
        if ((local_buf != NULL) && (local_tag != NULL)) {
            // prepare the log parts before changing the thread
            snprintf(local_buf, len, "%s", buf);
            snprintf(local_tag, cookie->namesize, "%s", cookie->name);

            uint64_t tid;
            pthread_threadid_np(NULL, &tid);

            NSDate *date = [NSDate date];
            dispatch_async(fileLogQueue, ^(){
                fprintf(file, "%s\t%d\t%llu\t%s\t%s:\t%s\n", [[dateFormatter stringFromDate:date] UTF8String],
                        [[NSProcessInfo processInfo] processIdentifier],
                        tid, priotab[prio], local_tag, local_buf);
                fflush(file);
                free(local_buf);
                free(local_tag);
            });
        } else {
            if (local_buf != NULL) {
                free(local_buf);
            }
            if (local_tag != NULL) {
                free(local_tag);
            }
        }
    }
}

#pragma mark - asl logging

/** asl client */
static aslclient client;
/** dispatch queue used to log */
static dispatch_queue_t logQueue;
/** log format */
static const char* FORMAT = "$((Time)(local.3)) $((Level)(char)) $(TAG) ($(Sender)-$(PID)/$(TID)) : $Message";

static void asl_ulog_init() {
    // open client connection
    client = asl_open(nil, nil, ASL_OPT_NO_REMOTE);
    asl_set_filter(client, ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));
    // add stderr log for XCode
    asl_add_output_file(client, STDOUT_FILENO, FORMAT, ASL_TIME_FMT_LCL, ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG),
                        ASL_ENCODE_SAFE);
    // create dipatch queue for logging
    logQueue = dispatch_queue_create("com.parrot.ulog", nil);

    ulog_set_write_func(&asl_ulog_write_func);
}


static void asl_ulog_write_func(uint32_t prio, struct ulog_cookie *cookie, const char *buf, int len) {
    char local_buf[ULOG_BUF_SIZE];
    // add tag
    asl_object_t msg = asl_new(ASL_TYPE_MSG);
    asl_set(msg, "TAG", cookie->name);
    // add level
    snprintf(local_buf, ULOG_BUF_SIZE , "%d", prio);
    asl_set(msg, ASL_KEY_LEVEL, local_buf);
    // add tid
    uint64_t tid;
    pthread_threadid_np(NULL, &tid);
    snprintf(local_buf, ULOG_BUF_SIZE , "%llu", tid);
    asl_set(msg, "TID", local_buf);
    // add message
    asl_set(msg, ASL_KEY_MSG, buf);
    // dispach sending message
    dispatch_async(logQueue, ^(){
         asl_send(client, msg);
         asl_release(msg);
    });
}

/**
 Send a log.

 - param prio priority of the log.
 - param tag tag use to log.
 - param msg message to log.
 */
+ (void) log:(Level)prio tag:(ULogTag *)tag msg:(NSString *)msg {
    if (prio <= [tag minLevel ]) {
        ulog_log_str(prio, [tag nativeCookiePtr], [msg UTF8String]);
    }
}

/**
 Send a log.

 - param prio priority of the log.
 - param tag: tag use to log.
 - param msg: message to log.
 - param args: message format argument
 */
+ (void) vlog:(Level)prio tag:(ULogTag *)tag msg:(NSString *)msg args:(va_list)args {
    if (prio <= [tag minLevel ]) {
        ulog_vlog(prio, [tag nativeCookiePtr], [msg UTF8String], args);
    }
}

+ (void) c:(ULogTag *)tag msg:(NSString *)msg, ... {
    va_list args;
    va_start(args, msg);
    [ULog vlog:LOG_CRIT tag:tag msg:msg args:args];
    va_end(args);
}

+ (void) c:(ULogTag *)tag :(NSString *)msg {
    [ULog log:LOG_CRIT tag:tag msg:msg];
}

+ (void) e:(ULogTag *)tag msg:(NSString *)msg, ... {
    va_list args;
    va_start(args, msg);
    [ULog vlog:LOG_ERR tag:tag msg:msg args:args];
    va_end(args);
}

+ (void) e:(ULogTag *)tag :(NSString *)msg {
    [ULog log:LOG_ERR tag:tag msg:msg];
}

+ (void) w:(ULogTag *)tag msg:(NSString *)msg, ...  {
    va_list args;
    va_start(args, msg);
    [ULog vlog:LOG_WARN tag:tag msg:msg args:args];
    va_end(args);
}

+ (void) w:(ULogTag *)tag :(NSString *)msg {
    [ULog log:LOG_WARN tag:tag msg:msg];
}

+ (void) n:(ULogTag *)tag msg:(NSString *)msg, ...  {
    va_list args;
    va_start(args, msg);
    [ULog vlog:LOG_NOTICE tag:tag msg:msg args:args];
    va_end(args);
}

+ (void) n:(ULogTag *)tag :(NSString *)msg {
    [ULog log:LOG_NOTICE tag:tag msg:msg];
}

+ (void) i:(ULogTag *)tag msg:(NSString *)msg, ...  {
    va_list args;
    va_start(args, msg);
    [ULog vlog:LOG_INFO tag:tag msg:msg args:args];
    va_end(args);
}

+ (void) i:(ULogTag *)tag :(NSString *)msg {
    [ULog log:LOG_INFO tag:tag msg:msg];
}

+ (void) d:(ULogTag *)tag msg:(NSString *)msg, ...  {
    va_list args;
    va_start(args, msg);
    [ULog vlog:LOG_DEBUG tag:tag msg:msg args:args];
    va_end(args);
}

+ (void) d:(ULogTag *)tag :(NSString *)msg {
    [ULog log:LOG_DEBUG tag:tag msg:msg];
}

+ (int) setLogLevel:(Level) minLevel tagName:(NSString *)tagName {
    return ulog_set_tag_level([tagName UTF8String], minLevel);
}

+ (BOOL) c:(ULogTag *) tag {
    return [tag minLevel] >= LOG_CRIT;
}

+ (BOOL) e:(ULogTag *) tag {
    return [tag minLevel] >= LOG_ERR;
}

+ (BOOL) w:(ULogTag *) tag {
    return [tag minLevel] >= LOG_WARN;
}

+ (BOOL) i:(ULogTag *) tag {
    return [tag minLevel] >= LOG_INFO;
}

+ (BOOL) n:(ULogTag *) tag {
    return [tag minLevel] >= LOG_NOTICE;
}

+ (BOOL) d:(ULogTag *) tag {
    return [tag minLevel] >= LOG_DEBUG;
}

@end
