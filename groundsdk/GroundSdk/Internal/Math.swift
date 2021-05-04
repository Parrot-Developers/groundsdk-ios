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

/// Operator ≈≈ is infix and has the same precedence as the comparison operator
infix operator ≈≈: ComparisonPrecedence

/// Utilities to manage math computations

/// Extension to Double that brings angle unity conversion
extension Double {
    /// Converts the value taken as a radian value to degrees.
    ///
    /// - Returns: the converted angle value, in degrees
    public func toDegrees() -> Double {
        return self * 180.0 / .pi
    }

    /// Converts the value taken as a radian value to degrees in the range 0..<360.
    ///
    /// - Returns: the converted angle value in the range [0, 360[, in degrees
    public func toBoundedDegrees() -> Double {
        let angleDegrees = self.toDegrees().truncatingRemainder(dividingBy: 360)
        return angleDegrees < 0 ? 360 + angleDegrees: angleDegrees
    }

    /// Converts the value taken as a degree value to radians.
    ///
    /// - Returns: the converted angle value, in radians
    public func toRadians() -> Double {
        return self * .pi / 180.0
    }

    /// Almost equal operator
    ///
    /// - Parameters:
    ///   - left: left value
    ///   - right: right value
    /// - Returns: `true` if left is close to right with a maximum delta of 0.01.
    static func ≈≈ (left: Double, right: Double) -> Bool {
        return left.isCloseTo(right, withDelta: 0.01)
    }

    /// Gets whether this value is close to another one
    ///
    /// - Parameters:
    ///   - other: the other value
    ///   - delta: the maximal acceptance delta
    /// - Returns: `true` if this value is equal to the other one with the given acceptation delta
    public func isCloseTo(_ other: Double, withDelta delta: Double) -> Bool {
        return abs(self - other) <= delta
    }

    /// Round the value to N number of decimal places
    ///
    /// - Parameter decimal: number of decimal places to use
    /// - Returns: rounded value to decimal
    public func roundedToDecimal(_ decimal: Int) -> Double {
        let divisor = pow(10.0, Double(decimal))
        return (self * divisor).rounded() / divisor
    }
}

/// Extension to Int
extension Int {

    /// Compute greatest common divider of two numbers.
    ///
    /// - Parameters:
    ///   - a: first number
    ///   - b: second number
    /// - Returns: greatest common divider
    static func gcd(_ a: Int, _ b: Int) -> Int {
        let r = a % b
        if r != 0 {
            return gcd(b, r)
        } else {
            return b
        }
    }
}
