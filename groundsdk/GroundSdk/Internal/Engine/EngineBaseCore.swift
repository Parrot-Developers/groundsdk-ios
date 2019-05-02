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

/// Internal base class for an engine.
/// Specific engine must be subclasses.
///
/// - Note: All subclasses **must** set the delegate right after been initialized.
open class EngineBaseCore: NSObject {

    /// Engine controller
    private unowned let enginesController: EnginesControllerCore

    /// GroundSdk utility registry
    public var utilities: UtilityCoreRegistry {
        guard started else {
            preconditionFailure("Utilities are only available when the engine is started.")
        }
        return enginesController.utilityRegistry
    }

    /// Whether or not the engine is started.
    private(set) public var started = false

    /// Create a EngineBase.
    ///
    /// Engine base is an abstract class
    ///
    /// - Parameter enginesController: the engine controller
    public required init(enginesController: EnginesControllerCore) {
        self.enginesController = enginesController
    }

    /// Publishes a utility.
    ///
    /// - Parameter utility: the utility to publish
    public func publishUtility(_ utility: UtilityCore) {
        enginesController.utilityRegistry.publish(utility: utility)
    }

    /// Start the engine
    final func start() {
        started = true
        startEngine()
    }

    /// Stop the engine
    final func stop() {
        stopEngine()
        started = false
    }

    /// Start the engine.
    ///
    /// - Note: Should not be called directly. Callers should use `start()` instead. This function might be overriden
    ///   by subclasses.
    open func startEngine() { }

    /// Stop the engine.
    ///
    /// - Note: Should not be called directly. Callers should use `stop()` instead. This function might be overriden
    ///   by subclasses.
    open func stopEngine() { }

    /// Notifies that all engines have been started.
    open func allEnginesDidStart() { }
}
