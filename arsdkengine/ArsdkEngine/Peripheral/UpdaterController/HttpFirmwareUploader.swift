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
import GroundSdk

/// Firmware uploader that works with http
class HttpFirmwareUploader: UpdaterFirmwareUploader {
    /// Update REST Api.
    /// Not nil when uploader has been configured. Nil after a reset.
    private var updateApi: UpdateRestApi?

    func configure(updater: UpdaterController) {
        if let droneServer = updater.deviceController.droneServer {
            updateApi = UpdateRestApi(server: droneServer)
        }
    }

    func reset(updater: UpdaterController) {
        updateApi = nil
    }

    func update(toVersion firmwareVersion: FirmwareVersion, deviceController: DeviceController,
                store: FirmwareStoreCore,
                uploadProgress: @escaping (_ progress: Int) -> Void,
                updateEndStatus: @escaping (_ status: UpdaterUpdateState) -> Void) -> CancelableCore? {
        if let localUrl = store.getFirmwareFile(firmwareIdentifier: FirmwareIdentifier(
            deviceModel: deviceController.deviceModel, version: firmwareVersion)) {

            return updateApi?.update(
                withFirmware: localUrl,
                progress: { percent in
                    uploadProgress(percent)
            },
                completion: { result in
                    switch result {
                    case .success:
                        updateEndStatus(.success)
                    case .error:
                        updateEndStatus(.failed)
                    case .canceled:
                        updateEndStatus(.canceled)
                    }
            })
        }
        return nil
    }
}
