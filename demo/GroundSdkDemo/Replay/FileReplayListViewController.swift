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

class FileReplayListViewController: UITableViewController {

    @IBOutlet weak var emptyLabel: UILabel!

    var videoFileList: [URL]?
    var selectedVideoFile: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        videoFileList = getVideoFileList()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "videoFile", for: indexPath)
        if let cell = cell as? VideoFileListCell, let videoFile = videoFileList?[indexPath.row] {
            cell.updateWith(file: videoFile)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedVideoFile = videoFileList?[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        performSegue(withIdentifier: "fileReplay", sender: self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = videoFileList?.count ?? 0
        emptyLabel.isHidden = count != 0
        return count
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? FileReplayViewController,
            let selectedVideoFile = selectedVideoFile {
            destination.set(fileUrl: selectedVideoFile)
        }
    }

    private func getVideoFileList() -> [URL] {
        let videoFileList: [URL]
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("medias")
        do {
            let fileUrls = try fileManager.contentsOfDirectory(at: documentsPath,
                                                               includingPropertiesForKeys: nil,
                                                               options: .skipsHiddenFiles)
            videoFileList = fileUrls.filter { $0.pathExtension.lowercased() == "mp4" }
        } catch {
            videoFileList = []
        }
        return videoFileList
    }
}

class VideoFileListCell: UITableViewCell {
    @IBOutlet weak var fileNameView: UILabel!

    func updateWith(file: URL) {
        fileNameView.text = file.lastPathComponent
    }
}
