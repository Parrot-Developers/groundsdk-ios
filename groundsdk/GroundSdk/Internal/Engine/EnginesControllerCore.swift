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

/// Internal class that loads, starts and stops engines.
public class EnginesControllerCore: NSObject {

    /// External engines to load
    private let externalEngineClasses = ["ArsdkEngine"]

    /// GroundSdk utility registry
    let utilityRegistry: UtilityCoreRegistry

    /// Store used to publish facilities.
    let facilityStore: ComponentStoreCore

    /// List of all engines
    var engines: [EngineBaseCore] = []

    /// An optionnal GroundSdkUserDefaults object to use (useful for testing. An engine can test this value and use a
    /// specific GroungSdkUserDefaults to store its data)
    var groundSdkUserDefaults: GroundSdkUserDefaults?

    /// Create a EnginesControllerCore with the specified drone store
    ///
    /// - Parameters:
    ///   - utilityRegistry: groundsdk utility registry
    ///   - facilityStore: store used to publish facilities
    internal init(utilityRegistry: UtilityCoreRegistry, facilityStore: ComponentStoreCore,
                  groundSdkUserDefaults: GroundSdkUserDefaults? = nil) {
        self.groundSdkUserDefaults = groundSdkUserDefaults
        self.utilityRegistry = utilityRegistry
        self.facilityStore = facilityStore
        super.init()
        engines = initEngines()
    }

    /// Init all engines and store them into a list of engines
    ///
    /// - Returns: the list of all engines
    func initEngines() -> [EngineBaseCore] {
        var allEngineList = [EngineBaseCore]()

        // publish the cloud server utility
        utilityRegistry.publish(utility: CloudServerCore(utilityRegistry: utilityRegistry))

        // create internal engines
        allEngineList.append(SystemEngine(enginesController: self))
        allEngineList.append(ReverseGeocoderEngine(enginesController: self))
        allEngineList.append(AutoConnectionEngine(enginesController: self))
        allEngineList.append(ActivationEngine(enginesController: self))
        allEngineList.append(UserAccountEngine(enginesController: self))
        if GroundSdkConfig.sharedInstance.enableCrashReport && GroundSdkConfig.sharedInstance.applicationKey != nil {
            allEngineList.append(CrashReportEngine(enginesController: self))
        }
        if GroundSdkConfig.sharedInstance.enableFirmwareSynchronization {
            allEngineList.append(FirmwareEngine(enginesController: self))
        }
        if GroundSdkConfig.sharedInstance.enableBlackBox && GroundSdkConfig.sharedInstance.applicationKey != nil {
            allEngineList.append(BlackBoxEngine(enginesController: self))
        }
        if GroundSdkConfig.sharedInstance.enableFlightData && GroundSdkConfig.sharedInstance.applicationKey != nil {
            allEngineList.append(FlightDataEngine(enginesController: self))
        }
        if GroundSdkConfig.sharedInstance.enableFlightData && GroundSdkConfig.sharedInstance.applicationKey != nil {
            allEngineList.append(FlightLogEngine(enginesController: self))
        }

        if GroundSdkConfig.sharedInstance.enableEphemeris {
            allEngineList.append(EphemerisEngine(enginesController: self))
        }

        // load all external engines
        allEngineList.append(contentsOf: loadExternalEngines(controller: self))

        return allEngineList
    }

    /// Start all engines
    public func start() {
        ULog.i(.coreTag, "Starting engines")
        for engine in engines {
            engine.start()
        }
        for engine in engines {
            engine.allEnginesDidStart()
        }
    }

    /// Stop all engines
    public func stop() {
        ULog.i(.coreTag, "Stopping engines")
        for engine in engines {
            engine.stop()
        }
    }
}

/// Extension of EnginesControllerCore that loads external engines
extension EnginesControllerCore {
    /// Load all external engines.
    ///
    /// - Parameter controller: engines controller
    /// - Returns: a set of external engines
    private func loadExternalEngines(controller: EnginesControllerCore) -> Set<EngineBaseCore> {
        var externalEngines: Set<EngineBaseCore> = []

        for engineClassName in externalEngineClasses {
            if let classEngine = NSClassFromString(engineClassName) as? EngineBaseCore.Type {
                let engine = classEngine.init(enginesController: controller)
                ULog.i(.coreTag, "Loading engine \(classEngine)")
                externalEngines.insert(engine)
            }
        }
        return externalEngines
    }
}
