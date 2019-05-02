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

/** Firmware version type */
typedef NS_ENUM(NSInteger, ArsdkFirmwareVersionType) {
    // Numerical values must be kept in sync with C code (puf_version_type)
    /* development version */
    ArsdkFirmwareVersionDev = 0,
    /* alpha or unknown version */
    ArsdkFirmwareVersionAlpha = 1,
    /* beta version */
    ArsdkFirmwareVersionBeta = 2,
    /* release candidate version */
    ArsdkFirmwareVersionRc = 3,
    /* release version */
    ArsdkFirmwareVersionRelease = 4
};

/** Firmware version */
@interface ArsdkFirmwareVersion: NSObject

/** Type of the firmware version */
@property (nonatomic, assign, readonly) ArsdkFirmwareVersionType type;
/** Major version */
@property (nonatomic, assign, readonly) NSInteger major;
/** Minor version */
@property (nonatomic, assign, readonly) NSInteger minor;
/** Patch version */
@property (nonatomic, assign, readonly) NSInteger patch;
/** Build version */
@property (nonatomic, assign, readonly) NSInteger build;

/**
 Constructor

 @param name: firmware version as string.
              Should be formatted like that: `major.minor.patch-typebuild` for non production version, with
              Alpha = `alpha`, Beta = `beta`, Rc = `rc`.
              Or `major.minor.patch` for production version.
 */
- (instancetype _Nullable)initFromName:(NSString* _Nullable)name;

/**
 Returns an NSComparisonResult value that indicates the ordering of the receiver and another given firmware version.
 */
- (NSComparisonResult)compare:(ArsdkFirmwareVersion* _Nonnull)otherVersion;

@end

/** Information about a firmware file */
@interface ArsdkFirmwareInfo: NSObject

/** File path */
@property (nonatomic, strong, readonly) NSString * _Nonnull filepath;
/** Firmware version */
@property (nonatomic, strong, readonly) ArsdkFirmwareVersion * _Nonnull version;
/** Firmware name (version as string) */
@property (nonatomic, strong, readonly) NSString * _Nonnull name;
/** Device for which this firmware is dedicated to */
@property (nonatomic, assign, readonly) NSInteger device;
/** Size of the firmware */
@property (nonatomic, assign, readonly) size_t size;
/** MD5 sum of the file */
@property (nonatomic, strong, readonly) NSString * _Nonnull md5;

/** Get the firmware info from a given file */
- (instancetype _Nullable)initFromFile:(NSString* _Nonnull)filepath;

@end
