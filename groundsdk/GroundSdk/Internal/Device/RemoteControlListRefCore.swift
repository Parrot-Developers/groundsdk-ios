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

/// A reference to a list of RemoteControlListEntry.
public class RemoteControlListRefCore: Ref<[RemoteControlListEntry]> {

    /// A filter to apply to include a remoteControl into the list
    let filter: (RemoteControlListEntry) -> Bool

    /// A monitor on the remoteControl store to be informed when a remoteControl is added/removed
    var storeMonitor: MonitorCore!

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: remoteControl store
    ///    - filter: closure applied to include or not a remoteControl into the list
    ///    - observer: observer notified when the list changes
    init(store: RemoteControlStoreUtilityCore, filter: @escaping (RemoteControlListEntry) -> Bool,
         observer: @escaping Observer) {
        self.filter = filter
        super.init(observer: observer)
        // monitor the store to notify when the list changes
        self.storeMonitor = store.startMonitoring(
            didAddDevice: { [unowned self] in self.remoteControlAdded($0) },
            deviceInfoDidChange: { [unowned self] in self.remoteControlDidChange($0) },
            didRemoveDevice: { [unowned self] in self.remoteControlRemoved($0) }
        )
        // build the initial list
        var list: [RemoteControlListEntry] = []
        store.getDevices().forEach { remoteControl in
            if filter(RemoteControlListEntry(remoteControl: remoteControl)) {
                list.append(RemoteControlListEntry(remoteControl: remoteControl))
            }
        }
        self.setup(value: list)
    }

    deinit {
        storeMonitor.stop()
    }

    private func remoteControlAdded(_ remoteControl: RemoteControlCore) {
        let entry = RemoteControlListEntry(remoteControl: remoteControl)
        if filter(entry) {
            var newList = value!
            newList.append(entry)
            update(newValue: newList)
        }
    }

    private func remoteControlRemoved(_ remoteControl: RemoteControlCore) {
        if let idx = value!.index(where: { $0.uid == remoteControl.uid }) {
            var newList = value!
            newList.remove(at: idx)
            update(newValue: newList)
        }
    }

    private func remoteControlDidChange(_ remoteControl: RemoteControlCore) {
        var newList = value!
        // create new entry with updated data (some entry data are value type)
        let entry = RemoteControlListEntry(remoteControl: remoteControl)
        // check if the remoteControl is already in the list
        if let idx = value!.index(where: { $0.uid == remoteControl.uid }) {
            // remoteControl is in the list, check if it still pass the filter
            if filter(entry) {
                newList[idx] = entry
            } else {
                newList.remove(at: idx)
            }
            update(newValue: newList)
        } else {
            // remoteControl is not in the list, check it it should be added
            if filter(entry) {
                newList.append(entry)
                update(newValue: newList)
            }
        }
    }
}
