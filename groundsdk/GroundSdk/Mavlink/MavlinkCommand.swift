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

import Foundation

/// A MAVLink command.
///
/// Clients of this API cannot instantiate this class directly, and must use one of the subclasses defining a specific
/// MAVLink command.
public class MavlinkCommand {

    /// MAVLink command type.
    enum CommandType: Int, CustomStringConvertible {
        /// Navigate to waypoint.
        case navigateToWaypoint = 16
        /// Return to home.
        case returnToLaunch = 20
        /// Land.
        case land = 21
        /// Take off.
        case takeOff = 22
        /// Delay the next command.
        case delay = 112
        /// Change speed.
        case changeSpeed = 178
        /// Set Region Of Interest.
        case setRoi = 201
        /// Control the camera tilt.
        case mountControl = 205
        /// Start photo capture.
        case startPhotoCapture = 2000
        /// Stop photo capture.
        case stopPhotoCapture = 2001
        /// Start video recording.
        case startVideoCapture = 2500
        /// Stop video recording.
        case stopVideoCapture = 2501
        /// Create a panorama.
        case createPanorama = 2800
        /// Set view mode.
        case setViewMode = 50000
        /// Set still capture mode.
        case setStillCaptureMode = 50001

        /// Debug description.
        var description: String {
            switch self {
            case .navigateToWaypoint:  return "navigateToWaypoint"
            case .returnToLaunch:      return "returnToLaunch"
            case .land:                return "land"
            case .takeOff:             return "takeOff"
            case .delay:               return "delay"
            case .changeSpeed:         return "changeSpeed"
            case .setRoi:              return "setRoi"
            case .mountControl:        return "mountControl"
            case .startPhotoCapture:   return "startPhotoCapture"
            case .stopPhotoCapture:    return "stopPhotoCapture"
            case .startVideoCapture:   return "startVideoCapture"
            case .stopVideoCapture:    return "stopVideoCapture"
            case .createPanorama:      return "createPanorama"
            case .setViewMode:         return "setViewMode"
            case .setStillCaptureMode: return "setStillCaptureMode"
            }
        }
    }

    /// Value always used for current waypoint; set to false.
    private static let currentWaypoint = 0

    /// Value always used for coordinate frame; set to global coordinate frame, relative altitude over ground.
    private static let frame = 3

    /// Value always used for auto-continue; set to true.
    private static let autoContinue = 1

    /// The MAVLink command type.
    private let type: CommandType

    /// Constructor.
    ///
    /// - Parameter type: the MAVLink command type
    init(type: CommandType) {
        self.type = type
    }

    /// Writes the MAVLink command to the specified file.
    ///
    /// This is the default implementation for commands with no parameter. Subclasses should override this method to add
    /// command specific parameters.
    ///
    /// - Parameters:
    ///   - fileHandle: handle on the file the command is written to
    ///   - index: the index of the command
    func write(fileHandle: FileHandle, index: Int) {
        doWrite(fileHandle: fileHandle, index: index)
    }

    /// Writes the MAVLink command to the specified file.
    ///
    /// - Parameters:
    ///   - fileHandle: handle on the file the command is written to
    ///   - index: the index of the command
    ///   - param1: first parameter of the command, type dependant
    ///   - param2: second parameter of the command, type dependant
    ///   - param3: third parameter of the command, type dependant
    ///   - param4: fourth parameter of the command, type dependant
    ///   - latitude: the latitude of the command
    ///   - longitude: the longitude of the command
    ///   - altitude: the altitude of the command
    func doWrite(fileHandle: FileHandle, index: Int, param1: Double = 0, param2: Double = 0, param3: Double = 0,
                 param4: Double = 0, latitude: Double = 0, longitude: Double = 0, altitude: Double = 0) {
        let line = String(format: "%d\t%d\t%d\t%d\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%d\n",
                          index, MavlinkCommand.currentWaypoint, MavlinkCommand.frame, type.rawValue, param1, param2,
                          param3, param4, latitude, longitude, altitude, MavlinkCommand.autoContinue)
        if let data = line.data(using: .utf8) {
            fileHandle.write(data)
        }
    }

    /// Parses a line of a MAVLink file.
    ///
    /// - Parameter line: line of MAVLink file
    /// - Returns: MAVLink command, or `nil` if the line could not be parsed
    static func parse(line: String) -> MavlinkCommand? {
        let tokens = line.split(separator: "\t")
        if tokens.count == 12, let rawType = Int(tokens[3]), let type = CommandType(rawValue: rawType) {
            let parameters = tokens[4...10].map { Double($0) }
            switch type {
            case .navigateToWaypoint:
                return NavigateToWaypointCommand(parameters: parameters)
            case .returnToLaunch:
                return ReturnToLaunchCommand()
            case .land:
                return LandCommand()
            case .takeOff:
                return TakeOffCommand()
            case .delay:
                return DelayCommand(parameters: parameters)
            case .changeSpeed:
                return ChangeSpeedCommand(parameters: parameters)
            case .setRoi:
                return SetRoiCommand(parameters: parameters)
            case .mountControl:
                return MountControlCommand(parameters: parameters)
            case .startPhotoCapture:
                return StartPhotoCaptureCommand(parameters: parameters)
            case .stopPhotoCapture:
                return StopPhotoCaptureCommand()
            case .startVideoCapture:
                return StartVideoCaptureCommand()
            case .stopVideoCapture:
                return StopVideoCaptureCommand()
            case .createPanorama:
                return CreatePanoramaCommand(parameters: parameters)
            case .setViewMode:
                return SetViewModeCommand(parameters: parameters)
            case .setStillCaptureMode:
                return SetStillCaptureModeCommand(parameters: parameters)
            }
        }
        return nil
    }
}
