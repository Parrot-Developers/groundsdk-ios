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

import XCTest
@testable import GroundSdk

/// Test DeviceModel class
class DeviceModelTests: XCTestCase {

    func testModelMappings() {
        Drone.Model.allCases.forEach {
            assertThat(DeviceModel.from(name: $0.description), presentAnd(`is`(.drone($0))))
        }
        RemoteControl.Model.allCases.forEach {
            assertThat(DeviceModel.from(name: $0.description), presentAnd(`is`(.rc($0))))
        }
        DeviceModel.allDevices.forEach {
            assertThat(DeviceModel.from(name: $0.description), presentAnd(`is`($0)))
        }
    }

    func testAllModels() {
        var allDevices: Set<DeviceModel> = []
        for drone in Drone.Model.allCases {
            allDevices.insert(.drone(drone))
        }
        for rc in RemoteControl.Model.allCases {
            allDevices.insert(.rc(rc))
        }
        assertThat(DeviceModel.allDevices, `is`(allDevices))
    }

    func testNoNameDuplicate() {
        // this test ensures the uniqueness of enum names across both Drone.Model and RemoteControl.Model,
        // which unfortunately cannot be ensured statically at compile-time
        var allNames: Set<String> = []
        DeviceModel.allDevices.forEach {
            let (inserted, _) = allNames.insert($0.description)
            assertThat(inserted, `is`(true))
        }
    }

}
