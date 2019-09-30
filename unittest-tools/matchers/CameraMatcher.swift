// Copyright (C) 2019 Parrot Drones SAS
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

import GroundSdk

// MARK: - mode
func supports(modes: Set<CameraMode>) -> Matcher<CameraModeSetting> {
    return Matcher("modes = \(modes)") {
        $0.supportedModes == modes
    }
}

func `is`(mode: CameraMode, updating: Bool) -> Matcher<CameraModeSetting> {
    return allOf(
        Matcher("mode \(mode)") {
            $0.mode == mode
        },
        Matcher("updating \(updating)") {
            $0.updating == updating
        }
    )
}

// MARK: - exposure
func supports(exposureModes: Set<CameraExposureMode>, shutterSpeeds: Set<CameraShutterSpeed>,
              isoSensitivities: Set<CameraIso>, maximumIsoSensitivities: Set<CameraIso>)
    -> Matcher<CameraExposureSettings> {
        return allOf(
            Matcher("supportedModes \(exposureModes)") {
                $0.supportedModes == exposureModes
            },
            Matcher("supportedManualShutterSpeeds \(shutterSpeeds)") {
                $0.supportedManualShutterSpeeds == shutterSpeeds
            },
            Matcher("supportedManualIsoSensitivity \(isoSensitivities)") {
                $0.supportedManualIsoSensitivity == isoSensitivities
            },
            Matcher("supportedMaximumIsoSensitivity \(maximumIsoSensitivities)") {
                $0.supportedMaximumIsoSensitivity == maximumIsoSensitivities
            }
        )
}

func `is`(mode: CameraExposureMode? = nil, shutterSpeed: CameraShutterSpeed? = nil, isoSensitivity: CameraIso? = nil,
          maximumIsoSensitivity: CameraIso? = nil, updating: Bool? = nil)
    -> Matcher<CameraExposureSettings> {
        var matchers = [Matcher<CameraExposureSettings>]()
        if let mode = mode {
            matchers.append(Matcher("mode = \(mode)") {
                $0.mode == mode
            })
        }
        if let shutterSpeed = shutterSpeed {
            matchers.append(Matcher("shutterSpeed = \(shutterSpeed)") {
                $0.manualShutterSpeed == shutterSpeed
            })
        }
        if let isoSensitivity = isoSensitivity {
            matchers.append(Matcher("isoSensitivity = \(isoSensitivity)") {
                $0.manualIsoSensitivity == isoSensitivity
            })
        }
        if let maximumIsoSensitivity = maximumIsoSensitivity {
            matchers.append(Matcher("maximumIsoSensitivity = \(maximumIsoSensitivity)") {
                $0.maximumIsoSensitivity == maximumIsoSensitivity
            })
        }
        if let updating = updating {
            matchers.append(Matcher("updating = \(updating)") {
                $0.updating == updating
            })
        }
        return allOf(matchers)
}

// MARK: - exposure lock
func `is`(mode: CameraExposureLockMode? = nil, updating: Bool? = nil) -> Matcher<CameraExposureLock> {
    var matchers = [Matcher<CameraExposureLock>]()
    if let mode = mode {
        matchers.append(Matcher("mode = \(mode)") {
            $0.mode == mode
        })
    }
    if let updating = updating {
        matchers.append(Matcher("updating = \(updating)") {
            $0.updating == updating
        })
    }
    return allOf(matchers)
}

// MARK: - exposure compensation
func supports(exposureCompensationValues: Set<CameraEvCompensation>)
    -> Matcher<CameraExposureCompensationSetting> {
        return Matcher("exposureCompensationValues = \(exposureCompensationValues)") {
            $0.supportedValues == exposureCompensationValues
        }
}

func `is`(value: CameraEvCompensation? = nil, updating: Bool? = nil) -> Matcher<CameraExposureCompensationSetting> {
    var matchers = [Matcher<CameraExposureCompensationSetting>]()
    if let value = value {
        matchers.append(Matcher("value = \(value)") {
            $0.value == value
        })
    }
    if let updating = updating {
        matchers.append(Matcher("updating = \(updating)") {
            $0.updating == updating
        })
    }
    return allOf(matchers)
}

// MARK: - whiteBalance
func supports(whiteBalanceModes: Set<CameraWhiteBalanceMode>, customTemperatures: Set<CameraWhiteBalanceTemperature>)
    -> Matcher<CameraWhiteBalanceSettings> {
        return allOf(
            Matcher("supportedModes = \(whiteBalanceModes)") {
                $0.supportedModes == whiteBalanceModes
            },
            Matcher("supporteCustomTemperature = \(customTemperatures)") {
                $0.supporteCustomTemperature == customTemperatures
            }
        )
}

// MARK: - white balance locked
func `is`(locked: Bool? = nil, updating: Bool? = nil) -> Matcher<CameraWhiteBalanceLock> {
    var matchers = [Matcher<CameraWhiteBalanceLock>]()
    if let locked = locked {
        matchers.append(Matcher("locked = \(locked)") {
            $0.locked == locked
        })
    }
    if let updating = updating {
        matchers.append(Matcher("updating = \(updating)") {
            $0.updating == updating
        })
    }
    return allOf(matchers)
}

func `is`(mode: CameraWhiteBalanceMode? = nil, customTemperature: CameraWhiteBalanceTemperature? = nil,
          updating: Bool? = nil) -> Matcher<CameraWhiteBalanceSettings> {
    var matchers = [Matcher<CameraWhiteBalanceSettings>]()
    if let mode = mode {
        matchers.append(Matcher("mode = \(mode)") {
            $0.mode == mode
        })
    }
    if let customTemperature = customTemperature {
        matchers.append(Matcher("customTemperature = \(customTemperature)") {
            $0.customTemperature == customTemperature
        })
    }
    if let updating = updating {
        matchers.append(Matcher("updating = \(updating)") {
            $0.updating == updating
        })
    }
    return allOf(matchers)
}


// MARK: - styles
func supports(styles: Set<CameraStyle>) -> Matcher<CameraStyleSettings> {
    return  Matcher("styles = \(styles)") {
        $0.supportedStyles == styles
    }
}

func `is`(activeStyle: CameraStyle? = nil, saturation: (min: Int, value: Int, max: Int)? = nil,
          contrast: (min: Int, value: Int, max: Int)? = nil, sharpness: (min: Int, value: Int, max: Int)? = nil,
          updating: Bool? = nil)  -> Matcher<CameraStyleSettings> {
    var matchers: [Matcher<CameraStyleSettings>] = []
    if let activeStyle = activeStyle {
        matchers.append(Matcher("activeStyle = \(activeStyle)") {
            $0.activeStyle == activeStyle
        })
    }
    if let saturation = saturation {
        matchers.append(Matcher("saturation = \((saturation.min, saturation.value, saturation.max))") {
            $0.saturation.min == saturation.min && $0.saturation.value == saturation.value &&
                $0.saturation.max == saturation.max
        })
    }
    if let contrast = contrast {
        matchers.append(Matcher("saturation = \((contrast.min, contrast.value, contrast.max))") {
            $0.contrast.min == contrast.min && $0.contrast.value == contrast.value &&
                $0.contrast.max == contrast.max
        })
    }
    if let sharpness = sharpness {
        matchers.append(Matcher("sharpness = \((sharpness.min, sharpness.value, sharpness.max))") {
            $0.sharpness.min == sharpness.min && $0.sharpness.value == sharpness.value &&
                $0.sharpness.max == sharpness.max
        })
    }
    if let updating = updating {
        matchers.append(Matcher("updating = \(updating)") {
            $0.updating == updating
        })
    }
    return allOf(matchers)
}

// MARK: - recording
func supports(recordingModes: Set<CameraRecordingMode>, hyperlapseValues: Set<CameraHyperlapseValue>)
    -> Matcher<CameraRecordingSettings> {
        return allOf(
            Matcher("supportedModes = \(recordingModes)") {
                $0.supportedModes == recordingModes
            },
            Matcher("supportedHyperlapseValues=\(hyperlapseValues)") {
                $0.supportedHyperlapseValues == hyperlapseValues
            }
        )
}

func supports(resolutions: Set<CameraRecordingResolution>, framerates: Set<CameraRecordingFramerate>)
    -> Matcher<CameraRecordingSettings>  {
        return allOf(
            Matcher("supportedResolutions = \(resolutions)") {
                $0.supportedResolutions == resolutions
            },
            Matcher("supportedFramerates=\(framerates)") {
                $0.supportedFramerates == framerates
            }
        )
}

func supports(forMode mode: CameraRecordingMode, resolutions: Set<CameraRecordingResolution>)
    -> Matcher<CameraRecordingSettings>  {
        return Matcher("supportedResolutions = \(resolutions)") {
            $0.supportedResolutions(forMode: mode) == resolutions
        }
}

func supports(forMode mode: CameraRecordingMode, resolution: CameraRecordingResolution,
              framerates: Set<CameraRecordingFramerate>) -> Matcher<CameraRecordingSettings>  {
    return Matcher("supportedFramerates=\(framerates)") {
        $0.supportedFramerates(forMode: mode, resolution: resolution) == framerates
    }
}

func `is`(hdrAvailable: Bool) -> Matcher<CameraRecordingSettings>  {
    return Matcher("hdrAvailable=\(hdrAvailable)") {
        $0.hdrAvailable == hdrAvailable
    }
}

func `is`(hdrAvailable: Bool, forMode mode: CameraRecordingMode, resolution: CameraRecordingResolution,
          framerate: CameraRecordingFramerate) -> Matcher<CameraRecordingSettings>  {
    return Matcher("hdrAvailable=\(hdrAvailable)") {
        $0.hdrAvailable(forMode: mode, resolution: resolution, framerate: framerate) == hdrAvailable
    }
}

func `is`(mode: CameraRecordingMode? = nil, resolution: CameraRecordingResolution? = nil,
          framerate: CameraRecordingFramerate? = nil, hyperlapse: CameraHyperlapseValue? = nil,
          bitrate: Int? = nil, updating: Bool? = nil)
    -> Matcher<CameraRecordingSettings> {
        var matchers = [Matcher<CameraRecordingSettings>]()
        if let mode = mode {
            matchers.append(Matcher("mode = \(mode)") {
                $0.mode == mode
            })
        }
        if let resolution = resolution {
            matchers.append(Matcher("resolution = \(resolution)") {
                $0.resolution == resolution
            })
        }
        if let framerate = framerate {
            matchers.append(Matcher("framerate = \(framerate)") {
                $0.framerate == framerate
            })
        }
        if let hyperlapse = hyperlapse {
            matchers.append(Matcher("hyperlapseValue = \(hyperlapse)") {
                $0.hyperlapseValue == hyperlapse
            })
        }
        if let bitrate = bitrate {
            matchers.append(Matcher("bitrate = \(bitrate)") {
                $0.bitrate == bitrate
            })
        }
        if let updating = updating {
            matchers.append(Matcher("updating = \(updating)") {
                $0.updating == updating
            })
        }
        return allOf(matchers)
}

// MARK: - photo
func supports(photoModes: Set<CameraPhotoMode>, burstValues: Set<CameraBurstValue>,
              bracketingValues: Set<CameraBracketingValue>) -> Matcher<CameraPhotoSettings> {
    return allOf(
        Matcher("supportedModes = \(photoModes)") {
            $0.supportedModes == photoModes
        },
        Matcher("supportedBurstValues=\(burstValues)") {
            $0.supportedBurstValues == burstValues
        },
        Matcher("supportedBracketingValues = \(bracketingValues)") {
            $0.supportedBracketingValues == bracketingValues
        }
    )
}

func supports(formats: Set<CameraPhotoFormat>)
    -> Matcher<CameraPhotoSettings>  {
        return Matcher("supportedFormats = \(formats)") {
            $0.supportedFormats == formats
        }
}

func supports(forMode mode: CameraPhotoMode, formats: Set<CameraPhotoFormat>) -> Matcher<CameraPhotoSettings>  {
    return Matcher("supportedFormats = \(formats)") {
        $0.supportedFormats(forMode: mode) == formats
    }
}

func supports(fileFormats: Set<CameraPhotoFileFormat>)
    -> Matcher<CameraPhotoSettings>  {
        return Matcher("supportedFileFormats = \(fileFormats)") {
            $0.supportedFileFormats == fileFormats
        }
}

func supports(forMode mode: CameraPhotoMode, format: CameraPhotoFormat, fileFormats: Set<CameraPhotoFileFormat>)
    -> Matcher<CameraPhotoSettings>  {
        return Matcher("fileFormat = \(fileFormats)") {
            $0.supportedFileFormats(forMode: mode, format: format) == fileFormats
        }
}

func `is`(mode: CameraPhotoMode? = nil, format: CameraPhotoFormat? = nil,
          fileFormat: CameraPhotoFileFormat? = nil, burst: CameraBurstValue? = nil,
          bracketing: CameraBracketingValue? = nil, updating: Bool? = nil)
    -> Matcher<CameraPhotoSettings> {
        var matchers = [Matcher<CameraPhotoSettings>]()
        if let mode = mode {
            matchers.append(Matcher("mode = \(mode)") {
                $0.mode == mode
            })
        }
        if let format = format {
            matchers.append(Matcher("format = \(format)") {
                $0.format == format
            })
        }
        if let fileFormat = fileFormat {
            matchers.append(Matcher("fileFormat = \(fileFormat)") {
                $0.fileFormat == fileFormat
            })
        }
        if let burst = burst {
            matchers.append(Matcher("burstValue = \(burst)") {
                $0.burstValue == burst
            })
        }
        if let bracketing = bracketing {
            matchers.append(Matcher("bracketingValue = \(bracketing)") {
                $0.bracketingValue == bracketing
            })
        }
        if let updating = updating {
            matchers.append(Matcher("updating = \(updating)") {
                $0.updating == updating
            })
        }
        return allOf(matchers)
}

func `is`(hdrAvailable: Bool) -> Matcher<CameraPhotoSettings>  {
    return Matcher("hdrAvailable=\(hdrAvailable)") {
        $0.hdrAvailable == hdrAvailable
    }
}

func `is`(hdrAvailable: Bool, forMode mode: CameraPhotoMode, format: CameraPhotoFormat,
          fileFormat: CameraPhotoFileFormat) -> Matcher<CameraPhotoSettings>  {
    return Matcher("hdrAvailable=\(hdrAvailable)") {
        $0.hdrAvailable(forMode: mode, format: format, fileFormat: fileFormat) == hdrAvailable
    }
}

// MARK: - recording state
func `is`(recordingFunctionState: CameraRecordingFunctionState, startTime: Date? = nil, mediaId: String? = nil)
    -> Matcher<CameraRecordingState> {
        var matchers = [Matcher<CameraRecordingState>]()
        matchers.append(Matcher("functionState = \(recordingFunctionState)") {
            $0.functionState == recordingFunctionState
        })
        if let startTime = startTime {
            matchers.append(Matcher("startTime = \(startTime)") {
                $0.startTime == startTime
            })
        }
        if let mediaId = mediaId {
            matchers.append(Matcher("mediaId = \(mediaId)") {
                $0.mediaId == mediaId
            })
        }
        return allOf(matchers)
}

// MARK: - photo state
func `is`(photoFunctionState: CameraPhotoFunctionState, photoCount: Int? = nil, mediaId: String? = nil)
    -> Matcher<CameraPhotoState> {
        var matchers = [Matcher<CameraPhotoState>]()
        matchers.append(Matcher("functionState = \(photoFunctionState)") {
            $0.functionState == photoFunctionState
        })
        if let photoCount = photoCount {
            matchers.append(Matcher("photoCount = \(photoCount)") {
                $0.photoCount == photoCount
            })
        }
        if let mediaId = mediaId {
            matchers.append(Matcher("mediaId = \(mediaId)") {
                $0.mediaId == mediaId
            })
        }
        return allOf(matchers)
}

// MARK: - Zoom
// settings are not included in this matcher.
func `is`(available: Bool? = nil, currentLevel: Double? = nil, maxLossLessLevel: Double? = nil,
          maxLossyLevel: Double? = nil) -> Matcher<CameraZoom> {
    var matchers = [Matcher<CameraZoom>]()
    if let available = available {
        matchers.append(Matcher("available = \(available)") {
            $0.isAvailable == available
        })
    }
    if let currentLevel = currentLevel {
        matchers.append(Matcher("current level = \(currentLevel)") {
            $0.currentLevel == currentLevel
        })
    }
    if let maxLossLessLevel = maxLossLessLevel {
        matchers.append(Matcher("max lossless level = \(maxLossLessLevel)") {
            $0.maxLossLessLevel == maxLossLessLevel
        })
    }
    if let maxLossyLevel = maxLossyLevel {
        matchers.append(Matcher("max lossy level = \(maxLossyLevel)") {
            $0.maxLossyLevel == maxLossyLevel
        })
    }
    return allOf(matchers)
}

// MARK: - alignment
func `is`(yawLowerBound: Double, yaw: Double, yawUpperBound: Double,
          pitchLowerBound: Double, pitch: Double, pitchUpperBound: Double,
          rollLowerBound: Double, roll: Double, rollUpperBound: Double, updating: Bool) -> Matcher<CameraAlignment> {
    return allOf(
        Matcher("yawLowerBound \(yawLowerBound)") {
            $0.supportedYawRange.lowerBound == yawLowerBound
        },
        Matcher("yaw \(yaw)") {
            $0.yaw == yaw
        },
        Matcher("yawUpperBound \(yawUpperBound)") {
            $0.supportedYawRange.upperBound == yawUpperBound
        },
        Matcher("pitchLowerBound \(pitchLowerBound)") {
            $0.supportedPitchRange.lowerBound == pitchLowerBound
        },
        Matcher("pitch \(pitch)") {
            $0.pitch == pitch
        },
        Matcher("pitchUpperBound \(pitchUpperBound)") {
            $0.supportedPitchRange.upperBound == pitchUpperBound
        },
        Matcher("rollLowerBound \(rollLowerBound)") {
            $0.supportedRollRange.lowerBound == rollLowerBound
        },
        Matcher("roll \(roll)") {
            $0.roll == roll
        },
        Matcher("rollUpperBound \(rollUpperBound)") {
            $0.supportedRollRange.upperBound == rollUpperBound
        },
        Matcher("updating \(updating)") {
            $0.updating == updating
        }
    )
}
