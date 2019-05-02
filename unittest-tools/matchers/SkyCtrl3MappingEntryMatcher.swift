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

func isButtonsMappingEntry(forDrone droneModel: Drone.Model, action: ButtonsMappableAction,
                           buttons: Set<SkyCtrl3ButtonEvent>) -> Matcher<SkyCtrl3MappingEntry> {
    return allOf(
        has(type: .buttons), has(droneModel: droneModel), has(action: action), has(buttons: buttons))
}

func isAxisMappingEntry(forDrone droneModel: Drone.Model, action: AxisMappableAction, axis: SkyCtrl3AxisEvent,
                        buttons: Set<SkyCtrl3ButtonEvent>) -> Matcher<SkyCtrl3MappingEntry> {
    return allOf(has(type: .axis), has(droneModel: droneModel), has(action: action), has(axis: axis),
                 has(buttons: buttons))
}

func has(droneModel: Drone.Model) -> Matcher<SkyCtrl3MappingEntry> {
    return Matcher("droneModel = \(droneModel)") { $0.droneModel == droneModel }
}

func has(type: SkyCtrl3MappingEntryType) -> Matcher<SkyCtrl3MappingEntry> {
    return Matcher("type = \(type)") { $0.type == type }
}

func has(action: ButtonsMappableAction) -> Matcher<SkyCtrl3MappingEntry> {
    return allOf(has(type: .buttons),
                 Matcher("action = \(action)") { ($0 as? SkyCtrl3ButtonsMappingEntry)?.action == action })
}

func has(action: AxisMappableAction) -> Matcher<SkyCtrl3MappingEntry> {
    return allOf(has(type: .axis),
                 Matcher("action = \(action)") { ($0 as? SkyCtrl3AxisMappingEntry)?.action == action })
}

func has(axis: SkyCtrl3AxisEvent) -> Matcher<SkyCtrl3MappingEntry> {
    return allOf(has(type: .axis),
                 Matcher("axis = \(axis)") { ($0 as? SkyCtrl3AxisMappingEntry)?.axisEvent == axis })
}

func has(buttons: Set<SkyCtrl3ButtonEvent>) -> Matcher<SkyCtrl3MappingEntry> {
    return anyOf(allOf(has(type: .axis),
                       Matcher("buttons = \(buttons)") { ($0 as? SkyCtrl3AxisMappingEntry)?.buttonEvents == buttons }),
                 allOf(has(type: .buttons),
                       Matcher("buttons = \(buttons)") { ($0 as? SkyCtrl3ButtonsMappingEntry)?.buttonEvents == buttons }
        )
    )
}
