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

/// Engine providing system information.
/// These pieces of information all come from the phone (or tablet).
/// The engine publishes utilities that can be monitored such as Internet connectivity, device location, geolocalizer...
class SystemEngine: EngineBaseCore {
    /// User Location GPS facility
    private var userLocation: UserLocationCore!
    private var userHeading: UserHeadingCore!
    /// User Location utility
    private var systemPositionCoreImpl: SystemPositionCoreImpl!
    private var userLocationMonitor: MonitorCore?
    private var userHeadingMonitor: MonitorCore?
    /// System Barometer Utility
    private var systemBarometerCoreImpl: SystemBarometerCoreImpl!

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        super.init(enginesController: enginesController)

        // init facilities : GPS
        userLocation = UserLocationCore(
            store: enginesController.facilityStore,
            didRegisterFirstListenerCallback: { [unowned self] in
                self.startMonitoringUserLocation()
            },
            didUnregisterLastListenerCallback: { [unowned self] in
                self.stopMonitoringUserLocation()
        })

        // init facilities : Heading
        userHeading = UserHeadingCore(
            store: enginesController.facilityStore,
            didRegisterFirstListenerCallback: { [unowned self] in
                self.startMonitoringUserHeading()
            },
            didUnregisterLastListenerCallback: { [unowned self] in
                self.stoptMonitoringUserHeading()
        })
        // init utilities
        systemPositionCoreImpl = SystemPositionCoreImpl()
        systemBarometerCoreImpl = SystemBarometerCoreImpl()
        ULog.d(.systemEngineTag, "Loading SystemEngine.")

        publishMonitorable()
    }

    /// Creates and publishes all available monitorable utilities.
    ///
    /// Only visible for tests purposes.
    func publishMonitorable() {
        publishUtility(InternetConnectivityCoreImpl())
        publishUtility(systemPositionCoreImpl)
        publishUtility(systemBarometerCoreImpl)
    }

    public override func startEngine() {
        ULog.d(.systemEngineTag, "Starting MonitorEngine.")
        // publish facilities
        userLocation.publish()
        userHeading.publish()
    }

    public override func stopEngine() {
        ULog.d(.systemEngineTag, "Stopping MonitorEngine.")
        // unpublish facilities
        userLocation.unpublish()
        userHeading.unpublish()
        stopMonitoringUserLocation()
        stoptMonitoringUserHeading()
    }
}

// MARK: - Location Monitoring
extension SystemEngine {

    private func startMonitoringUserLocation() {
        guard userLocationMonitor == nil else {
            return
        }
        // monitoring the userLocation
        userLocationMonitor = systemPositionCoreImpl.startLocationMonitoring(passive: false,
            userLocationDidChange: { [unowned self] newLocation in
                self.userLocation.update(userLocation: newLocation).notifyUpdated()
            },
            stoppedDidChange: { [unowned self] newStopped in
                self.userLocation.update(stopped: newStopped).notifyUpdated()
            },
            authorizedDidChange: { [unowned self] newAuthorized in
                self.userLocation.update(authorized: newAuthorized).notifyUpdated()
        })
    }

    private func stopMonitoringUserLocation() {
        // monitoring the userLocation
        userLocationMonitor?.stop()
        userLocationMonitor = nil
    }
}

// MARK: - Heading Monitoring
extension SystemEngine {
    private func startMonitoringUserHeading() {
        guard userHeadingMonitor == nil else {
            return
        }
        // monitoring the heading
        userHeadingMonitor = systemPositionCoreImpl.startHeadingMonitoring(
            headingDidChange: { [unowned self] newHeading in
                self.userHeading.update(heading: newHeading).notifyUpdated()
            }
        )
    }

    private func stoptMonitoringUserHeading() {
        // monitoring the heading
        userHeadingMonitor?.stop()
        userHeadingMonitor = nil
    }
}
