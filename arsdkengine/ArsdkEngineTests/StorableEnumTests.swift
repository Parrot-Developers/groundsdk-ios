// Copyright (C) 2020 Parrot Drones SAS
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

import Foundation
import XCTest

@testable import ArsdkEngine
@testable import GroundSdk
import SdkCore
import SdkCoreTesting

class StorableEnumTests: XCTestCase {

    // Check that all storable enum are mapped
    func testMappers() {
        // CameraMode
        assertThat(CameraMode.recording, present())
        assertThat(CameraMode.photo, present())

        // CameraMode
        for val in CameraMode.allCases {
            assertThat(CameraMode.storableMapper.map(from: val), present())
        }

        // CameraExposureMode
        for val in CameraExposureMode.allCases {
            assertThat(CameraExposureMode.storableMapper.map(from: val), present())
        }

        // CameraAutoExposureMeteringMode
        for val in CameraAutoExposureMeteringMode.allCases {
            assertThat(CameraAutoExposureMeteringMode.storableMapper.map(from: val), present())
        }

        // CameraStyle
        for val in CameraStyle.allCases {
            assertThat(CameraStyle.storableMapper.map(from: val), present())
        }

        // CameraShutterSpeed
        for val in CameraShutterSpeed.allCases {
            assertThat(CameraShutterSpeed.storableMapper.map(from: val), present())
        }

        // CameraIso
        for val in CameraIso.allCases {
            assertThat(CameraIso.storableMapper.map(from: val), present())
        }

        // CameraWhiteBalanceMode
        for val in CameraWhiteBalanceMode.allCases {
            assertThat(CameraWhiteBalanceMode.storableMapper.map(from: val), present())
        }

        // CameraWhiteBalanceTemperature
        for val in CameraWhiteBalanceTemperature.allCases {
            assertThat(CameraWhiteBalanceTemperature.storableMapper.map(from: val), present())
        }

        // CameraRecordingMode
        for val in CameraRecordingMode.allCases {
            assertThat(CameraRecordingMode.storableMapper.map(from: val), present())
        }

        // CameraRecordingResolution
        for val in CameraRecordingResolution.allCases {
            assertThat(CameraRecordingResolution.storableMapper.map(from: val), present())
        }

        // CameraRecordingFramerate
        for val in CameraRecordingFramerate.allCases {
            assertThat(CameraRecordingFramerate.storableMapper.map(from: val), present())
        }

        // CameraHyperlapseValue
        for val in CameraHyperlapseValue.allCases {
            assertThat(CameraHyperlapseValue.storableMapper.map(from: val), present())
        }

        // CameraPhotoMode
        for val in CameraPhotoMode.allCases {
            assertThat(CameraPhotoMode.storableMapper.map(from: val), present())
        }

        // CameraPhotoFormat
        for val in CameraPhotoFormat.allCases {
            assertThat(CameraPhotoFormat.storableMapper.map(from: val), present())
        }

        // CameraPhotoFileFormat
        for val in CameraPhotoFileFormat.allCases {
            assertThat(CameraPhotoFileFormat.storableMapper.map(from: val), present())
        }

        // CameraBurstValue
        for val in CameraBurstValue.allCases {
            assertThat(CameraBurstValue.storableMapper.map(from: val), present())
        }

        // CameraBracketingValue
        for val in CameraBracketingValue.allCases {
            assertThat(CameraBracketingValue.storableMapper.map(from: val), present())
        }

        // CameraEvCompensation
        for val in CameraEvCompensation.allCases {
            assertThat(CameraEvCompensation.storableMapper.map(from: val), present())
        }

        // DriIdType
        for val in DriIdType.allCases {
            assertThat(DriIdType.storableMapper.map(from: val), present())
        }

        // GeofenceMode
        for val in GeofenceMode.allCases {
            assertThat(GeofenceMode.storableMapper.map(from: val), present())
        }

        // AntiflickerMode
        for val in AntiflickerMode.allCases {
            assertThat(AntiflickerMode.storableMapper.map(from: val), present())
        }

        // GimbalAxis
        for val in GimbalAxis.allCases {
            assertThat(GimbalAxis.storableMapper.map(from: val), present())
        }

        // PreciseHomeMode
        for val in PreciseHomeMode.allCases {
            assertThat(PreciseHomeMode.storableMapper.map(from: val), present())
        }

        // CopilotSource
        for val in CopilotSource.allCases {
            assertThat(CopilotSource.storableMapper.map(from: val), present())
        }

        // ThermalControlMode
        for val in ThermalControlMode.allCases {
            assertThat(ThermalControlMode.storableMapper.map(from: val), present())
        }

        // ThermalSensitivityRange
        for val in ThermalSensitivityRange.allCases {
            assertThat(ThermalSensitivityRange.storableMapper.map(from: val), present())
        }

        // ThermalCalibrationMode
        for val in ThermalCalibrationMode.allCases {
            assertThat(ThermalCalibrationMode.storableMapper.map(from: val), present())
        }

        // ReturnHomeTarget
        for val in ReturnHomeTarget.allCases {
            assertThat(ReturnHomeTarget.storableMapper.map(from: val), present())
        }

        // ReturnHomeEndingBehavior
        for val in ReturnHomeEndingBehavior.allCases {
            assertThat(ReturnHomeEndingBehavior.storableMapper.map(from: val), present())
        }
    }
}
