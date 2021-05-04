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

func has(name: String) -> Matcher<DebugSetting> {
    return Matcher("name = \(name)") { $0.name == name }
}

func `is`(readOnly: Bool) -> Matcher<DebugSetting> {
    return Matcher("readOnly = \(readOnly)") { $0.readOnly == readOnly }
}

func `is`(updating: Bool) -> Matcher<DebugSetting> {
    return Matcher("updating = \(updating)") { $0.updating == updating }
}

func has(value: Bool) -> Matcher<DebugSetting> {
    return allOf(
        Matcher("type boolean") {
            $0.type == .boolean
        },
        Matcher("value \(value)") { (debugSetting) -> MatchResult in
            if let debugSetting = debugSetting as? BoolDebugSetting {
                if debugSetting.value == value {
                    return .match
                } else {
                    return .mismatch("value [\(debugSetting.value)]")
                }
            } else {
                return .mismatch(nil)
            }
        }
    )
}

func has(value: String) -> Matcher<DebugSetting> {
    return allOf(
        Matcher("type text") {
            $0.type == .text
        },
        Matcher("value \(value)") { (debugSetting) -> MatchResult in
            if let debugSetting = debugSetting as? TextDebugSetting {
                if debugSetting.value == value {
                    return .match
                } else {
                    return .mismatch("value [\(debugSetting.value)]")
                }
            } else {
                return .mismatch(nil)
            }
        }
    )
}

func has(value: Double) -> Matcher<DebugSetting> {
    return allOf(
        Matcher("type numeric") {
            $0.type == .numeric
        },
        Matcher("value \(value)") { (debugSetting) -> MatchResult in
            if let debugSetting = debugSetting as? NumericDebugSetting {
                if debugSetting.value == value {
                    return .match
                } else {
                    return .mismatch("value [\(debugSetting.value)]")
                }
            } else {
                return .mismatch(nil)
            }
        }
    )
}

func has(range: ClosedRange<Double>?) -> Matcher<DebugSetting> {
    return allOf(
        Matcher("type numeric") {
            $0.type == .numeric
        },
        Matcher("range \(String(describing: range))") { (debugSetting) -> MatchResult in
            if let debugSetting = debugSetting as? NumericDebugSetting {
                if debugSetting.range == range {
                    return .match
                } else {
                    return .mismatch("range [\(String(describing: debugSetting.range))]")
                }
            } else {
                return .mismatch(nil)
            }
        }
    )
}
/*
func has(step: Double) -> Matcher<DebugSetting> {
    return allOf(
        Matcher("type numeric") {
            $0.type == .numeric
        },
        Matcher("step \(step)") { (debugSetting) -> MatchResult in
            if let debugSetting = debugSetting as? NumericDebugSetting,
            let debugSettingStep = debugSetting.step {
                if debugSettingStep == step {
                    return .match
                } else {
                    return .mismatch("step [\(debugSettingStep)]")
                }
            } else {
                return .mismatch(nil)
            }
        }
    )
}
*/
func has(step: Double?) -> Matcher<DebugSetting> {
    return allOf(
        Matcher("type numeric") {
            $0.type == .numeric
        },
        Matcher("step \(String(describing: step))") { (debugSetting) -> MatchResult in
            if let debugSetting = debugSetting as? NumericDebugSetting {
                if debugSetting.step == step {
                    return .match
                } else {
                    return .mismatch("step [\(String(describing: debugSetting.step))]")
                }
            } else {
                return .mismatch(nil)
            }
        }
    )
}
