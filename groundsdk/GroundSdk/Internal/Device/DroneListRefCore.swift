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

/// A reference to a list of DroneListEntry.
public class DroneListRefCore: Ref<[DroneListEntry]> {
    /// A filter to apply to include a drone into the list
    let filter: (DroneListEntry) -> Bool

    /// A monitor on the drone store to be informed when a drone is added/removed
    var storeMonitor: MonitorCore!

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: drone store
    ///    - filter: closure applied to include or not a drone into the list
    ///    - observer: observer notified when the list changes
    init(store: DroneStoreUtilityCore, filter: @escaping (DroneListEntry) -> Bool, observer: @escaping Observer) {
        self.filter = filter
        super.init(observer: observer)
        // monitor the store to notify when the list changes
        self.storeMonitor = store.startMonitoring(
            didAddDevice: { [unowned self] in self.droneAdded($0) },
            deviceInfoDidChange: { [unowned self] in self.droneDidChange($0) },
            didRemoveDevice: { [unowned self] in self.droneRemoved($0) }
        )
        // build the initial list
        var list: [DroneListEntry] = []
        store.getDevices().forEach { drone in
            if filter(DroneListEntry(drone: drone)) {
                list.append(DroneListEntry(drone: drone))
            }
        }
        self.setup(value: list)
    }

    deinit {
        storeMonitor.stop()
    }

    private func droneAdded(_ drone: DroneCore) {
        let entry = DroneListEntry(drone: drone)
        if filter(entry) {
            var newList = value!
            newList.append(entry)
            update(newValue: newList)
        }
    }

    private func droneRemoved(_ drone: DroneCore) {
        if let idx = value!.index(where: { $0.uid == drone.uid }) {
            var newList = value!
            newList.remove(at: idx)
            update(newValue: newList)
        }
    }

    private func droneDidChange(_ drone: DroneCore) {
        var newList = value!
        // create new entry with updated data (some entry data are value type)
        let entry = DroneListEntry(drone: drone)
        // check if the drone is already in the list
        if let idx = value!.index(where: { $0.uid == drone.uid }) {
            // drone is in the list, check if it still pass the filter
            if filter(entry) {
                newList[idx] = entry
            } else {
                newList.remove(at: idx)
            }
            update(newValue: newList)
        } else {
            // drone is not in the list, check it it should be added
            if filter(entry) {
                newList.append(entry)
                update(newValue: newList)
            }
        }
    }
}
