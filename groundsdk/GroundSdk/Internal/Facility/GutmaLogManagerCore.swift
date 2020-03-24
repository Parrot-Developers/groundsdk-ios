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

/// Gutma Log Manager backend
protocol GutmaLogManagerBackend: class {
    /// Deletes a gutma log.
    ///
    /// - Parameter file: URL of the file gutma log file to delete
    /// - Returns: `true` if the specified file exists and was successfully deleted, `false` otherwise
    func delete(file: URL) -> Bool
}

/// Core implementation of the Gutma Log Manager facility
class GutmaLogManagerCore: FacilityCore, GutmaLogManager {

    /// Implementation backend
    private unowned let backend: GutmaLogManagerBackend

    public private(set) var files = Set<URL>()

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: Component store owning this component
    ///   - backend: FirmwareManagerBackend backend
    public init(store: ComponentStoreCore, backend: GutmaLogManagerBackend) {
        self.backend = backend
        super.init(desc: Facilities.gutmaLogManager, store: store)
    }

    public func delete(file: URL) -> Bool {
        guard files.contains(file) else {
            return false
        }
        return backend.delete(file: file)
    }
}

/// Backend callback methods
extension GutmaLogManagerCore {
    /// Changes current set of converted files.
    ///
    /// - Parameter files: new set of files
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(files newValue: Set<URL>) -> GutmaLogManagerCore {
        if files != newValue {
            files = newValue
            markChanged()
        }
        return self
    }
}
