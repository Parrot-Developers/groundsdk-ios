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

func `is`(_ connectionState: DeviceState.ConnectionState) -> Matcher<DeviceState> {
    return Matcher("ConnectionState = \(connectionState)") { $0.connectionState == connectionState }
}

func `is`(_ connectionStateCause: DeviceState.ConnectionStateCause) -> Matcher<DeviceState> {
    return Matcher("ConnectionStateCause = \(connectionStateCause)") {
        $0.connectionStateCause == connectionStateCause
    }
}

func canBeForgotten(_ state: Bool) -> Matcher<DeviceState> {
    return Matcher("canBeForgotten = \(state)") { $0.canBeForgotten == state }
}

func canBeConnected(_ state: Bool) -> Matcher<DeviceState> {
    return Matcher("canBeConnected = \(state)") { $0.canBeConnected == state }
}

func canBeDisconnected(_ state: Bool) -> Matcher<DeviceState> {
    return Matcher("canBeDisconnected = \(state)") { $0.canBeDisconnected == state }
}

func has(connector: DeviceConnector) -> Matcher<DeviceState> {
    return Matcher("hasConnector = \(connector)") { $0.connectors.contains(where: {$0 == connector}) }
}

func dontHaveConnectors() -> Matcher<DeviceState> {
    return Matcher("dontHaveConnectors") { $0.connectors.isEmpty }
}

func hasActiveConnector(_ connector: DeviceConnector)  -> Matcher<DeviceState> {
    return Matcher("hasActiveConnector \(connector)") {
        $0.activeConnector != nil ? $0.activeConnector! == connector : false
    }
}

func dontHaveActiveConnector()  -> Matcher<DeviceState> {
    return Matcher("dontHaveActiveConnectors") { $0.activeConnector == nil }
}
