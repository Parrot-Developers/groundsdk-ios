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

import UIKit
import GroundSdk

class SkyCtrl3MappingListViewController: UIViewController, DeviceViewController {

    private let addEntrySegue = "addEntry"
    private let editEntrySegue = "editEntry"

    private let groundSdk = GroundSdk()
    private var rcUid: String?
    private var skyCtrl3Gamepad: Ref<SkyCtrl3Gamepad>?

    private var currentDroneModel: Drone.Model?
    private var currentMappings: [SkyCtrl3MappingEntry]?

    @IBOutlet private weak var tabBar: UITabBar!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var addBt: UIBarButtonItem!
    @IBOutlet private weak var resetBt: UIBarButtonItem!

    private var entryToEdit: SkyCtrl3MappingEntry?

    func setDeviceUid(_ uid: String) {
        rcUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // force tableview autolayout
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80

        if let remoteControl = groundSdk.getRemoteControl(uid: rcUid!) {
            skyCtrl3Gamepad =
                remoteControl.getPeripheral(Peripherals.skyCtrl3Gamepad) { [weak self] skyCtrl3Gamepad in
                    if let skyCtrl3Gamepad = skyCtrl3Gamepad {
                        self?.updateTabBar(skyCtrl3Gamepad: skyCtrl3Gamepad)

                        self?.reloadDataIfNeeded(skyCtrl3Gamepad: skyCtrl3Gamepad)
                    } else {
                        self?.performSegue(withIdentifier: "exit", sender: self)
                    }
            }
        }
    }

    private func updateTabBar(skyCtrl3Gamepad: SkyCtrl3Gamepad) {
        var tabBarItems = [UITabBarItem]()
        for supportedDrone in skyCtrl3Gamepad.supportedDroneModels {
            let image: UIImage?
            switch supportedDrone {
            case .anafi4k:
                image = #imageLiteral(resourceName: "anafi.png")
            case .anafiThermal:
                image = #imageLiteral(resourceName: "anafi.png")
            default:
                image = nil
            }
            let tabBarItem = UITabBarItem(title: supportedDrone.description, image: image, tag: supportedDrone.rawValue)
            tabBarItem.badgeValue = (skyCtrl3Gamepad.activeDroneModel == supportedDrone) ? "*" : nil

            tabBarItems.append(tabBarItem)
        }
        tabBarItems.sort(by: { return $0.tag <= $1.tag })
        if tabBar.items == nil || tabBarItems != tabBar.items! {
            tabBar.setItems(tabBarItems, animated: false)
        }

        if currentDroneModel == nil {
            if skyCtrl3Gamepad.activeDroneModel != nil {
                currentDroneModel = skyCtrl3Gamepad.activeDroneModel
            } else if tabBarItems.count > 0 {
                currentDroneModel = Drone.Model(rawValue: tabBarItems[0].tag)
            }
        }

        if currentDroneModel != nil {
            var tabItem: UITabBarItem?
            tabBarItems.forEach {
                if Drone.Model(rawValue: $0.tag) == currentDroneModel {
                    tabItem = $0
                    return
                }
            }
            tabBar.selectedItem = tabItem
        }
        addBt.isEnabled = currentDroneModel != nil
        resetBt.isEnabled = currentDroneModel != nil
    }

    private func reloadDataIfNeeded(skyCtrl3Gamepad: SkyCtrl3Gamepad?) {
        if let skyCtrl3Gamepad = skyCtrl3Gamepad, let currentDroneModel = self.currentDroneModel {
            let mappingsSet = skyCtrl3Gamepad.mapping(forModel: currentDroneModel)!
            if self.currentMappings == nil || Set(self.currentMappings!) != mappingsSet {
                self.currentMappings = Array(mappingsSet).sorted { entry1, entry2 in
                    if let btEntry1 = entry1 as? SkyCtrl3ButtonsMappingEntry,
                        let btEntry2 = entry2 as? SkyCtrl3ButtonsMappingEntry {
                        return btEntry1.action.rawValue < btEntry2.action.rawValue
                    } else if let btEntry1 = entry1 as? SkyCtrl3ButtonsMappingEntry,
                        let btEntry2 = entry2 as? SkyCtrl3ButtonsMappingEntry {
                        return btEntry1.action.rawValue < btEntry2.action.rawValue
                    } else {
                        return entry1.type.rawValue < entry2.type.rawValue
                    }
                }
                self.tableView.reloadData()
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mappingEditVC = segue.destination as? SkyCtrl3MappingEditViewController,
            (segue.identifier == addEntrySegue ||  segue.identifier == editEntrySegue) {
            mappingEditVC.droneModel = currentDroneModel!
            mappingEditVC.setDeviceUid(rcUid!)
            if segue.identifier == editEntrySegue {
                mappingEditVC.entry = entryToEdit!
                entryToEdit = nil
            }
        }
    }

    @IBAction func onResetMapping(_ sender: AnyObject) {
        if let currentDroneModel = currentDroneModel {
            skyCtrl3Gamepad?.value?.resetMapping(forModel: currentDroneModel)
        }
    }
}

extension SkyCtrl3MappingListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentMappings?.count ?? 0
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell

        let editEntry: (_ entry: SkyCtrl3MappingEntry) -> Void = {
            self.entryToEdit = $0
            self.performSegue(withIdentifier: self.editEntrySegue, sender: self)
        }

        // since there are items, we can assume that currentMappings is not nil
        let mappingEntry = currentMappings![indexPath.row]
        switch mappingEntry.type {
        case .buttons:
            cell = tableView.dequeueReusableCell(withIdentifier: "buttonsMapping", for: indexPath)
            if let buttonsEntry = mappingEntry as? SkyCtrl3ButtonsMappingEntry,
                let cell = cell as? SkyCtrl3ButtonsMappingEntryCell {
                cell.updateWith(buttonEntry: buttonsEntry, editEntry: editEntry)
            }
        case .axis:
            cell = tableView.dequeueReusableCell(withIdentifier: "axisMapping", for: indexPath)
            if let axisEntry = mappingEntry as? SkyCtrl3AxisMappingEntry,
                let cell = cell as? SkyCtrl3AxisMappingEntryCell {
                cell.updateWith(axisEntry: axisEntry, editEntry: editEntry)
            }
        }
        return cell
    }
}

extension SkyCtrl3MappingListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { _, indexPath in
            self.tableView.beginUpdates()
            let mappingToDelete = self.currentMappings!.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.tableView.endUpdates()
            self.skyCtrl3Gamepad?.value?.unregister(mappingEntry: mappingToDelete)
        }

        return [delete]
    }
}

extension SkyCtrl3MappingListViewController: UITabBarDelegate {
    public func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        currentDroneModel = Drone.Model(rawValue: item.tag)
        reloadDataIfNeeded(skyCtrl3Gamepad: skyCtrl3Gamepad?.value)
    }
}

class SkyCtrl3MappingEntryCell: UITableViewCell {
    private var entry: SkyCtrl3MappingEntry?
    private var editEntry: ((_ entry: SkyCtrl3MappingEntry) -> Void)?

    @IBAction func onEditPushed(_ sender: AnyObject) {
        if let editEntry = editEntry, let entry = entry {
            editEntry(entry)
        }
    }

    func updateWith(entry: SkyCtrl3MappingEntry, editEntry: ((_ entry: SkyCtrl3MappingEntry) -> Void)?) {
        self.entry = entry
        self.editEntry = editEntry
    }
}

class SkyCtrl3ButtonsMappingEntryCell: SkyCtrl3MappingEntryCell {
    @IBOutlet weak var action: UILabel!
    @IBOutlet weak var buttons: UILabel!

    func updateWith(buttonEntry: SkyCtrl3ButtonsMappingEntry, editEntry: ((_ entry: SkyCtrl3MappingEntry) -> Void)?) {
        super.updateWith(entry: buttonEntry, editEntry: editEntry)
        action.text = buttonEntry.action.description
        buttons.text = buttonEntry.buttonEvents.map({ $0.description }).description
    }
}

class SkyCtrl3AxisMappingEntryCell: SkyCtrl3MappingEntryCell {
    @IBOutlet weak var action: UILabel!
    @IBOutlet weak var buttons: UILabel!
    @IBOutlet weak var axis: UILabel!

    func updateWith(axisEntry: SkyCtrl3AxisMappingEntry, editEntry: ((_ entry: SkyCtrl3MappingEntry) -> Void)?) {
        super.updateWith(entry: axisEntry, editEntry: editEntry)
        action.text = axisEntry.action.description
        axis.text = axisEntry.axisEvent.description
        buttons.text = axisEntry.buttonEvents.map({ $0.description }).description
    }
}
