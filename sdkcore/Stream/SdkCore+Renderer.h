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
#import <CoreGraphics/CoreGraphics.h>
#import "ArsdkCore.h"

/** Rendering Fill Mode */
typedef NS_ENUM(NSInteger, SdkCoreStreamRenderingFillMode) {
    // Numerical values must be kept in sync with C code (pdraw_video_renderer_fill_mode)
    /** Fit Mode */
    SdkCoreStreamRenderingFillModeFit = 0,
    /** Crop mode */
    SdkCoreStreamRenderingFillModeCrop = 1,
    /** Rendering fill mode fit, padded with a blur of an image cropped. */
    SdkCoreStreamRenderingFillModeFitPadBlurCrop = 2,
    /** Rendering fill mode fit, padded with ao blur of an image extended. */
    SdkCoreStreamRenderingFillModeFitPadBlurExtend = 3,
};

/**
 Listener that will be called when events about the renderer are emitted by the native renderer object.
 */
@protocol SdkCoreRendererListener <NSObject>

/**
 Called when the native renderer is ready to render a frame.
 */
- (void)onFrameReady;

/**
 Called when the content zone is updated.
 
 @param zone: the new content zone.
 */
- (void)contentZoneDidUpdate:(CGRect)zone;

@end

/** Data relative to texture loading. */
@interface SdkCoreTextureLoaderFrame: NSObject

/** Handle on the frame. */
@property (readonly, nonatomic, assign) const void * _Nonnull frame;

/** Handle on the frame user data. */
@property (readonly, nonatomic, assign) const void * _Nullable userData;

/** Length of the frame user data. */
@property (readonly, nonatomic, assign) size_t userDataLen;

/** Handle on the session metadata. */
@property (readonly, nonatomic, assign) const void * _Nonnull sessionMetadata;

@end

/**
 Listener for texture loader.
 */
@protocol SdkCoreTextureLoaderListener <NSObject>

/**
 Called back to load custom GL texture.
 
 Called back on the render thread.
 
 @param width: texture width
 @param height: texture height
 @param frame: frame data, non-persistent data, should not be used after the return of the callback.
 */
- (bool)loadTexture:(int)width
             height:(int)height
              frame:(SdkCoreTextureLoaderFrame * _Nonnull)frame;

@end


/** Data relative to histograms. */
@interface SdkCoreHistogram: NSObject

/** Histogram channel red. */
@property (readonly, nonatomic) const float * _Nullable histogramRed;
/** Length of histogram channel red. */
@property (readonly, nonatomic) size_t histogramRedLen;

/** Histogram channel green. */
@property (readonly, nonatomic) const float * _Nullable histogramGreen;
/** Length of histogram channel green. */
@property (readonly, nonatomic) size_t histogramGreenLen;

/** Histogram channel blue. */
@property (readonly, nonatomic) const float * _Nullable histogramBlue;
/** Length of histogram channel blue. */
@property (readonly, nonatomic) size_t histogramBlueLen;

/** Histogram channel luma. */
@property (readonly, nonatomic) const float * _Nullable histogramLuma;
/** Length of histogram channel luma. */
@property (readonly, nonatomic) size_t histogramLumaLen;

@end

/**
 Listener that will be called when overlay data are available.
 */
@protocol SdkCoreRendererOverlayListener <NSObject>

/**
 Called back to render an overlay.
 
 Called back on the render thread.
 
 @param renderZone: rendering area.
 @param contentPos: stream rendering area.
 @param histogram: histogram data,
                   non-persistent data, should not be used after the return of the callback.
 */
- (void)overlay:(const void * _Nonnull)renderZone
     contentPos:(const void * _Nonnull)contentPos
      histogram:(SdkCoreHistogram * _Nullable)histogram;

@end

/** Video renderer object that have a native renderer object*/
@interface SdkCoreRenderer: NSObject

/** Content zone, relative to the renderer zone **/
@property (nonatomic, readonly) CGRect contentZone;

/**
 Init renderer.
 
 @param pdraw: Pdraw instance.
 @param renderZone: rendering area.
 @param fillMode: rendering fill mode.
 @param zebrasEnabled: 'true' to enable the zebras of overexposure zone.
 @param zebrasThreshold: threshold of overexposure used by zebras, used by zebras, in range [0.0, 1.0].
                         '0.0' for the maximum of zebras and '1.0' for the minimum.
 @param textureWidth: texture width in pixels, unused if 'textureLoaderlistener' is nil.
 @param textureDarWidth: texture aspect ratio width, unused if 'textureLoaderlistener' is nil.
 @param textureDarHeight: texture aspect ratio height, unused if 'textureLoaderlistener' is nil.
 @param textureLoaderlistener: texture loader listener.
 @param histogramsEnabled: 'true' to enable histograms computation.
 @param overlayListener: overlay rendering listener.
 @param listener: renderer listener.
 */
- (instancetype _Nullable)initWithPdraw:(/*struct pdraw **/void * _Nonnull)pdraw
                                   zone:(CGRect)renderZone
                               fillMode:(SdkCoreStreamRenderingFillMode)fillMode
                          zebrasEnabled:(BOOL)zebrasEnabled zebrasThreshold:(float)zebrasThreshold
                           textureWidth:(int)textureWidth textureDarWidth:(int)textureDarWidth textureDarHeight:(int)textureDarHeight
                  textureLoaderlistener:(id<SdkCoreTextureLoaderListener> _Nullable)textureLoaderlistener
                      histogramsEnabled:(BOOL)histogramsEnabled
                        overlayListener:(id<SdkCoreRendererOverlayListener> _Nonnull)overlayListener
                               listener:(id<SdkCoreRendererListener> _Nonnull)listener
NS_SWIFT_UNAVAILABLE("useless");
/** Stop renderer. */
- (void)stop;

/** Render a frame. */
- (void)renderFrame;

/** Set the rendering area.
 
 @param renderZone: new rendering area.
 */
- (void)setRenderZone:(CGRect)renderZone;

/** Sets the rendering fill mode
 
 @param mode: rendering fill mode
 */
- (void)setFillMode:(SdkCoreStreamRenderingFillMode)mode;

/** Enables zebras of overexposure image zones.
 Must be called in the GL thread.
 
 @param enable: 'true' to enable the zebras of overexposure zone, otherwise no zebras.
 
 see setZebrasThreshold(float)
 */
- (void)enableZebras:(BOOL)enabled
NS_SWIFT_NAME(enableZebras(_:));

/** Sets overexposure threshold for zebras.
 Must be called in the GL thread.
 
 @param threshold: threshold of overexposure used by zebras, in range [0.0, 1.0].
 '0.0' for the maximum of zebras and '1.0' for the minimum.
 
 see enableZebras(BOOL)
 */
- (void)setZebrasThreshold:(float)threshold
NS_SWIFT_NAME(setZebrasThreshold(_:));

/** Enables Histograms computing.
 Must be called in the GL thread.
 
 @param enable: 'true' to enable histograms computing.
 */
- (void)enableHistograms:(BOOL)enabled
NS_SWIFT_NAME(enableHistograms(_:));

@end
