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

protocol MediaListViewController {
    func set(droneUid: String, medias: [MediaItem])
}

class MediaStoreViewController: UITableViewController, DeviceViewController {

    @IBOutlet weak var deleteButton: UIBarButtonItem!
    @IBOutlet weak var playButton: UIBarButtonItem!
    @IBOutlet weak var downloadButton: UIBarButtonItem!

    private let groundSdk = GroundSdk()
    private var mediaStoreRef: Ref<MediaStore>?
    private var droneUid: String?
    private var mediaListRef: Ref<[MediaItem]>?
    private var mediaList: [MediaItem]?

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // allows 3D-touch if available
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: view)
        }

        if let drone = groundSdk.getDrone(uid: droneUid!) {
            // load a ref on the media store
            mediaStoreRef = drone.getPeripheral(Peripherals.mediaStore) { [weak self] mediaStore in
                if mediaStore == nil {
                    self?.dismiss()
                }
            }

            // load media store content
            mediaListRef = mediaStoreRef?.value?.newList { [weak self] mediaList in
                self?.mediaList = mediaList
                self?.mediaList?.forEach { $0.userData = $0.userData ?? false }
                self?.tableView.reloadData()
                self?.updateButtonBarStatus()
            }
        }
        updateButtonBarStatus()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "media", for: indexPath)
        if let cell = cell as? MediaListCell, let media = mediaList?[indexPath.row] {
            cell.updateWith(mediaStore: mediaStoreRef!.value!, media: media)
            updateButtonBarStatus()
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let media = mediaList?[indexPath.row] {
            media.userData = !(media.userData as! Bool)
            tableView.reloadRows(at: [indexPath], with: .fade)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mediaList?.count ?? 0
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? MediaListViewController {
            destination.set(droneUid: droneUid!, medias: getSelectedMedias())
        } else if let destination = segue.destination as? MediaReplayViewController,
            let media = getFirstSelectedMedia() {
            destination.set(droneUid: droneUid!, media: media)
        } else if let destination = segue.destination as? DeviceViewController {
            destination.setDeviceUid(droneUid!)
        }
    }

    private func getSelectedMedias() -> [MediaItem] {
        if let mediaList = mediaList {
            return mediaList.filter({ return $0.userData! as! Bool })
        }
        return [MediaItem]()
    }

    private func getFirstSelectedMedia() -> MediaItem? {
        if let mediaList = mediaList {
            return mediaList.first(where: { return $0.userData! as! Bool })
        }
        return nil
    }

    private func updateButtonBarStatus() {
        let firstSelectedMedia = getFirstSelectedMedia()
        let enabled = firstSelectedMedia != nil
        deleteButton.isEnabled = enabled
        downloadButton.isEnabled = enabled

        var streamable = false
        if let firstSelectedMedia = firstSelectedMedia {
            streamable = firstSelectedMedia.resources.first(where: { return $0.streamable}) != nil
        }
        playButton.isEnabled = streamable
    }

    private func dismiss() {
        performSegue(withIdentifier: "exit", sender: self)
    }
}

/// 3D-Touch handling
extension MediaStoreViewController: UIViewControllerPreviewingDelegate {

    /// Create a previewing view controller to be shown at "Peek".
    func previewingContext(
        _ previewingContext: UIViewControllerPreviewing,

        viewControllerForLocation location: CGPoint) -> UIViewController? {

        // Obtain the index path and the cell that was pressed.
        guard let indexPath = tableView.indexPathForRow(at: location),
            let cell = tableView.cellForRow(at: indexPath) else {
                return nil
        }

        // Create a detail view controller and set its properties.
        guard let detailViewController = storyboard?.instantiateViewController(
            withIdentifier: "ResourceThumbnailList") as? MediaStoreResourceThumbnailList else {
                return nil
        }

        detailViewController.set(droneUid: droneUid!, mediaStore: mediaStoreRef!.value!,
                                 media: mediaList![indexPath.row])

        // Set the source rect to the cell frame, so surrounding elements are blurred.
        previewingContext.sourceRect = cell.frame

        return detailViewController
    }

    /// Present the view controller for the "Pop" action.
    func previewingContext(
        _ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        // Reuse the "Peek" view controller for presentation.
        viewControllerToCommit.modalPresentationStyle = .overCurrentContext
        present(viewControllerToCommit, animated: false, completion: nil)
    }
}

class MediaListCell: UITableViewCell {
    @IBOutlet weak var thumbnailView: UIImageView!
    @IBOutlet weak var textView: UILabel!
    @IBOutlet weak var detail1View: UILabel!
    @IBOutlet weak var detail2View: UILabel!

    var thumbnail: Ref<UIImage>?

    private static var dateFormater: DateFormatter = {
        let dateFormater = DateFormatter()
        dateFormater.dateStyle = .long
        dateFormater.timeStyle = .long
        return dateFormater
    }()

    func updateWith(mediaStore: MediaStore, media: MediaItem) {
        textView.text = MediaListCell.dateFormater.string(from: media.creationDate)
        detail1View.text = media.runUid
        let resources = media.resources.reduce("") {str, res in
            let streamableTxt = res.streamable == true ? " streamable" : ""
            return "\(str) [\(res.format) \(res.size)\(streamableTxt)]"
        }
        let photoModeTxt = media.photoMode != nil ? " \(media.photoMode!.description)" : ""
        let thermalText = media.metadataTypes.contains(.thermal) ? " Thermal" : ""
        detail2View.text = "\(media.type.description)\(photoModeTxt)\(resources)\(thermalText)"
        if media.userData as! Bool {
            accessoryType = .checkmark
        } else {
            accessoryType = .none
        }
        thumbnail = mediaStore.newThumbnailDownloader(media: media) { [weak self] image in
            if let image = image {
                self?.thumbnailView.image = image
            }
        }
    }

    override func prepareForReuse() {
        thumbnail = nil
        thumbnailView.image = #imageLiteral(resourceName: "thumbnail")
    }
}
