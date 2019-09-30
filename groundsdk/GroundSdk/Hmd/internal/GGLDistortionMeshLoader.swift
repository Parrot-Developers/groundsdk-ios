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
import UIKit

/// Extension for resource files
let distortionMeshExt = ".txt"

/// Name of resource files (describing distortion parameters) by type
enum DistortionMeshData: String {
    case colors = "colors"
    case indices = "indices"
    case positions = "positions"
    case texBlue = "tex_coords_blue"
    case texRed = "tex_coords_red"
    case texGreen = "tex_coords_green"

    /// Get the file name
    ///
    /// - Parameter cockpit: CockpitGlasses model
    /// - Returns: the file name
    func fileName(_ cockpit: Cockpit) -> String {
        return cockpit.filePrefix() + self.rawValue + distortionMeshExt
    }
}

/// Class of utilities to load the resource files corresponding to the CockpitGlasses model
class GGLDistortionMeshLoader {

    static func dataArray(_ data: DistortionMeshData, _ cockpit: Cockpit) -> [GLfloat] {
        if let dataString = getFileData(data, cockpit) {
            return dataString.components(separatedBy: "\n").compactMap { GLfloat($0) }
        } else {
            return [GLfloat]()
        }
    }

    static func dataArray(_ data: DistortionMeshData, _ cockpit: Cockpit) -> [GLuint] {
        if let dataString = getFileData(data, cockpit) {
            return dataString.components(separatedBy: "\n").compactMap { GLuint($0) }
        } else {
            return [GLuint]()
        }
    }

    static func getFileData(_ data: DistortionMeshData, _ cockpit: Cockpit) -> String? {
        let name = data.fileName(cockpit)
        if let url = Bundle(for: self).url(forResource: name, withExtension: ""),
            let data = try? Data(contentsOf: url) {
            return String(decoding: data, as: UTF8.self)
        } else {
            ULog.e(.hmdTag, "No Data in file \(name)")
            return nil
        }
    }
}
