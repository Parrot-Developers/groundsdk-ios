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

private extension UIDevice {

    static let modelIdentifier: String = {
        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModelIdentifier
        }
        var sysinfo = utsname()
        uname(&sysinfo)
        return String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)),
                      encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
    }()
}

@available(iOS 9.0, *)
public extension UIScreen {
    /// The number of pixels per inch for this device
    static let pixelsPerInch: CGFloat? = {
        switch UIDevice.modelIdentifier {
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":  // iPad 2
            return 132

        case "iPad2,5", "iPad2,6", "iPad2,7":             // iPad Mini
            return 163

        case "iPad3,1", "iPad3,2", "iPad3,3",         // iPad 3rd generation
         "iPad3,4", "iPad3,5", "iPad3,6",             // iPad 4th generation
         "iPad4,1", "iPad4,2", "iPad4,3",             // iPad Air
         "iPad5,3", "iPad5,4",                        // iPad Air 2
         "iPad6,7", "iPad6,8",                        // iPad Pro (12.9 inch)
         "iPad6,3", "iPad6,4",                        // iPad Pro (9.7 inch)
         "iPad6,11", "iPad6,12",                      // iPad 5th generation
         "iPad7,1", "iPad7,2",                        // iPad Pro (12.9 inch, 2nd generation)
         "iPad7,3", "iPad7,4",                        // iPad Pro (10.5 inch)
         "iPad7,5", "iPad7,6",                        // iPad 6th generation
         "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4",  // iPad Pro (11 inch)
         "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8",  // iPad Pro (12.9 inch, 3rd generation)
         "iPad11,3", "iPad11,4":                      // iPad Air (3rd generation)
            return 264

        case "iPhone4,1",                             // iPhone 4S
         "iPhone5,1", "iPhone5,2",                    // iPhone 5
         "iPhone5,3", "iPhone5,4",                    // iPhone 5C
         "iPhone6,1", "iPhone6,2",                    // iPhone 5S
         "iPhone8,4",                                 // iPhone SE
         "iPhone7,2",                                 // iPhone 6
         "iPhone8,1",                                 // iPhone 6S
         "iPhone9,1", "iPhone9,3",                    // iPhone 7
         "iPhone10,1", "iPhone10,4",                  // iPhone 8
         "iPhone11,8",                                // iPhone XR
         "iPhone12,1",                                // iPhone 11
         "iPod5,1",                                   // iPod Touch 5th generation
         "iPod7,1",                                   // iPod Touch 6th generation
         "iPad4,4", "iPad4,5", "iPad4,6",             // iPad Mini 2
         "iPad4,7", "iPad4,8", "iPad4,9",             // iPad Mini 3
         "iPad5,1", "iPad5,2",                        // iPad Mini 4
         "iPad11,1", "iPad11,2":                      // iPad Mini 5
            return 326

        case "iPhone7,1",                             // iPhone 6 Plus
         "iPhone8,2",                                 // iPhone 6S Plus
         "iPhone9,2", "iPhone9,4",                    // iPhone 7 Plus
         "iPhone10,2", "iPhone10,5":                  // iPhone 8 Plus
            return 401

        case "iPhone10,3", "iPhone10,6",              // iPhone X
        "iPhone11,2",                                 // iPhone XS
        "iPhone11,4", "iPhone11,6",                   // iPhone XS Max
        "iPhone12,3",                                 // iPhone 11 Pro
        "iPhone12,5":                                 // iPhone 11 Pro Max
            return 458

        default:                                      // unknown model identifier
            return .none
        }
    }()

    /// The number of pixels per centimeter for this device
    static let pixelsPerCentimeter: CGFloat? = {
        if let pixelsPerInch = pixelsPerInch {
            return pixelsPerInch / 2.54
        } else {
            return nil
        }
    }()
}
