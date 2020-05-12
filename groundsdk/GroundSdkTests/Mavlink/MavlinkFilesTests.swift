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

/// Test MavlinkFiles tool
class MavlinkFilesTests: XCTestCase {

    private let filepath = NSHomeDirectory().appending("/mavlink.txt")

    override func tearDown() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filepath) {
            try? fileManager.removeItem(atPath: filepath)
        }
    }

    func testGenerate() {
        let commands = [
            NavigateToWaypointCommand(latitude: 48.8, longitude: 2.3, altitude: 3, yaw: 45),
            ReturnToLaunchCommand(),
            LandCommand(),
            TakeOffCommand(),
            DelayCommand(delay: 3.5),
            ChangeSpeedCommand(speedType: .groundSpeed, speed: 7.5),
            SetRoiCommand(latitude: 48.9, longitude: 2.4, altitude: 5.3),
            MountControlCommand(tiltAngle: 45),
            StartPhotoCaptureCommand(interval: 3.5, count: 5, format: .rectilinear),
            StopPhotoCaptureCommand(),
            StartVideoCaptureCommand(),
            StopVideoCaptureCommand(),
            CreatePanoramaCommand(horizontalAngle: 2, horizontalSpeed: 3, verticalAngle: 4, verticalSpeed: 6),
            SetViewModeCommand(mode: .roi, roiIndex: 7),
            SetStillCaptureModeCommand(mode: .gpslapse, interval: 4.5)
        ]

        MavlinkFiles.generate(filepath: filepath, commands: commands)

        let content = try? String(contentsOfFile: filepath, encoding: .utf8).components(separatedBy: .newlines)
        assertThat(content?[0], `is`("QGC WPL 120"))
        assertThat(content?[1],
                   `is`("0\t0\t3\t16\t0.000000\t5.000000\t0.000000\t45.000000\t48.800000\t2.300000\t3.000000\t1"))
        assertThat(content?[2],
                   `is`("1\t0\t3\t20\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[3],
                   `is`("2\t0\t3\t21\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[4],
                   `is`("3\t0\t3\t22\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[5],
                   `is`("4\t0\t3\t112\t3.500000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[6],
                   `is`("5\t0\t3\t178\t1.000000\t7.500000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[7],
                   `is`("6\t0\t3\t201\t3.000000\t0.000000\t0.000000\t0.000000\t48.900000\t2.400000\t5.300000\t1"))
        assertThat(content?[8],
                   `is`("7\t0\t3\t205\t45.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t2.000000\t1"))
        assertThat(content?[9],
                   `is`("8\t0\t3\t2000\t3.500000\t5.000000\t12.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[10],
                   `is`("9\t0\t3\t2001\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[11],
                   `is`("10\t0\t3\t2500\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[12],
                   `is`("11\t0\t3\t2501\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[13],
                   `is`("12\t0\t3\t2800\t2.000000\t4.000000\t3.000000\t6.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[14],
                   `is`("13\t0\t3\t50000\t2.000000\t7.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
        assertThat(content?[15],
                   `is`("14\t0\t3\t50001\t1.000000\t4.500000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1"))
    }

    func testParse() {
        let content = """
            QGC WPL 120
            0\t0\t3\t16\t0.000000\t5.000000\t0.000000\t45.000000\t48.800000\t2.300000\t3.000000\t1
            1\t0\t3\t20\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            2\t0\t3\t21\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            3\t0\t3\t22\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            4\t0\t3\t112\t3.500000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            5\t0\t3\t178\t1.000000\t7.500000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            6\t0\t3\t201\t3.000000\t0.000000\t0.000000\t0.000000\t48.900000\t2.400000\t5.300000\t1
            7\t0\t3\t205\t45.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t2.000000\t1
            8\t0\t3\t2000\t3.500000\t5.000000\t12.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            9\t0\t3\t2001\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            10\t0\t3\t2500\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            11\t0\t3\t2501\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            12\t0\t3\t2800\t2.000000\t4.000000\t3.000000\t6.000000\t0.000000\t0.000000\t0.000000\t1
            13\t0\t3\t50000\t2.000000\t7.000000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            14\t0\t3\t50001\t1.000000\t4.500000\t0.000000\t0.000000\t0.000000\t0.000000\t0.000000\t1
            """
        try? content.write(toFile: filepath, atomically: false, encoding: .utf8)

        let commands = MavlinkFiles.parse(filepath: filepath)

        assertThat(commands[0], instanceOfAnd(
            `is`(latitude: 48.8, longitude: 2.3, altitude: 3, yaw: 45, holdTime: 0, acceptanceRadius: 5)))
        assertThat(commands[1], instanceOf(ReturnToLaunchCommand.self))
        assertThat(commands[2], instanceOf(LandCommand.self))
        assertThat(commands[3], instanceOf(TakeOffCommand.self))
        assertThat(commands[4], instanceOfAnd(`is`(delay: 3.5)))
        assertThat(commands[5], instanceOfAnd(`is`(speedType: .groundSpeed, speed: 7.5)))
        assertThat(commands[6], instanceOfAnd(`is`(latitude: 48.9, longitude: 2.4, altitude: 5.3)))
        assertThat(commands[7], instanceOfAnd(`is`(tiltAngle: 45)))
        assertThat(commands[8], instanceOfAnd(`is`(interval: 3.5, count: 5, format: .rectilinear)))
        assertThat(commands[9], instanceOf(StopPhotoCaptureCommand.self))
        assertThat(commands[10], instanceOf(StartVideoCaptureCommand.self))
        assertThat(commands[11], instanceOf(StopVideoCaptureCommand.self))
        assertThat(commands[12], instanceOfAnd(
            `is`(horizontalAngle: 2, horizontalSpeed: 3, verticalAngle: 4, verticalSpeed: 6)))
        assertThat(commands[13], instanceOfAnd(`is`(mode: .roi, roiIndex: 7)))
        assertThat(commands[14], instanceOfAnd(`is`(mode: .gpslapse, interval: 4.5)))
    }
}
