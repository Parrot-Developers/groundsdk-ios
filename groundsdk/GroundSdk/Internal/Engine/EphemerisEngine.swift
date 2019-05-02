//// Copyright (C) 2019 Parrot Drones SAS
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

/// Ephemeris Type Enum, allowing to download them by different means
public enum EphemerisType: CustomStringConvertible {

    /// Ephemeris for ublox base gps
    case ublox

    /// Debug description.
    public var description: String {
        switch self {
        case .ublox: return "ublox"
        }
    }
}

/// Ephemeris engine
class EphemerisEngine: EngineBaseCore {

    /// Key used in UserDefaults dictionary
    private let storeDataKey = "ephemerisEngine"

    /// Root folder for Ephemeris
    ///
    /// Visibility is internal for testing purposes
    let rootFolder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        .appendingPathComponent("ephemeris")

    /// Ephemeris utility
    private var ephemerisUtility: EphemerisUtilityCoreImpl!

    /// Monitor of the connectivity changes
    private var connectivityMonitor: MonitorCore?

    /// Latest date on which we downloaded Ephemeris
    private var latestDownloadRequestDate: Date?

    /// Minimum download interval for Ephemeris of 48 hours
    private var minDownloadInterval: TimeInterval = 48 * 60 * 60

    /// Persisting Keys
    private enum PersistingDataKeys: String {
        case downloadRequestDate
    }

    /// Ublox downloader
    private var ubloxDownloader: UBloxEphemerisDownloader!

    /// groundsdk user default
    private var gsdkUserDefault: GroundSdkUserDefaults!

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        super.init(enginesController: enginesController)

        let httpSession = createHttpSession()
        gsdkUserDefault = createGsdkUserDefaults()

        ubloxDownloader = UBloxEphemerisDownloader(httpSession: httpSession)

        ephemerisUtility = EphemerisUtilityCoreImpl(ephemerisEngine: self)
        loadData()
        if GroundSdkConfig.sharedInstance.enableEphemeris {
            publishUtility(ephemerisUtility)
        }
    }

    override func startEngine() {
        ULog.d(.activationEngineTag, "Starting EphemerisEngine.")
        if GroundSdkConfig.sharedInstance.enableEphemeris {
            connectivityMonitor = utilities.getUtility(
             Utilities.internetConnectivity)?.startMonitoring { [unowned self] internetAvailable in
                if internetAvailable {
                    self.downloadEphemeris()
                }
            }
        }
    }

    override func stopEngine() {
        connectivityMonitor?.stop()
        connectivityMonitor = nil
    }

    // Create http session
    func createHttpSession() -> HttpSessionCore {
        return HttpSessionCore(sessionConfiguration: URLSessionConfiguration.default)
    }

    /// Create groundsdk user defaults
    func createGsdkUserDefaults() -> GroundSdkUserDefaults {
        return GroundSdkUserDefaults(storeDataKey)
    }

    /// Download Ephemeris every 48 hours
    private func downloadEphemeris() {
        if latestDownloadRequestDate == nil ||
            abs(latestDownloadRequestDate!.timeIntervalSince(Date())) > minDownloadInterval {

            ubloxDownloader.download(urlDestination: rootFolder) { [weak self] url in
                if let `self` = self, url != nil {
                    self.latestDownloadRequestDate = Date()
                    self.gsdkUserDefault.storeData(
                        [PersistingDataKeys.downloadRequestDate.rawValue: self.latestDownloadRequestDate])
                }
            }
        }
    }

    /// Load persisting data
    private func loadData() {
        let loadedDictionary = gsdkUserDefault.loadData() as? [String: Any]
        latestDownloadRequestDate = loadedDictionary?[PersistingDataKeys.downloadRequestDate.rawValue] as? Date
    }

    /// Get latest ephemeris local url
    ///
    /// - Parameter type: ephemeris type
    /// - Returns: the ephemeris file url if file exists, `nil` otherwise
    public func getLatestEphemeris (forType type: EphemerisType) -> URL? {
        switch type {
        case .ublox:
             let fileURL = rootFolder.appendingPathComponent(ubloxDownloader.ephemerisName)
             return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
        }
    }
}
