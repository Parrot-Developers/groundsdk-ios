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
import MapKit

/// The MapAnnotationDelegate will be triggered when a new move destination is chosen
public protocol AnnotationMapDelegate: class {
    func destinationDidChange(moveLocation: CLLocationCoordinate2D?)
}

class MapAnnotation: NSObject, MKAnnotation {
    enum MapAnnotationType: String {
        /// an annotation type for the drone
        case dronePin
        /// an annotation type for the activePoi
        case activePoiPin
        /// an annotation type for the Location destination
        case destinationPin
    }

    var coordinate: CLLocationCoordinate2D {
        willSet {
            self.willChangeValue(forKey: "coordinate")
        }
        didSet {
            self.didChangeValue(forKey: "coordinate")
        }
    }
    let annotationType: MapAnnotationType

    var annotationId: String { return annotationType.rawValue }

    var iconName: String {
        switch annotationType {
        case .dronePin: return "icn_quadri"
        case .activePoiPin: return "icn_poi"
        default: return ""
        }
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - coordinate: location for the annotation
    ///   - annotationType: type of the pin
    init(coordinate: CLLocationCoordinate2D, annotationType: MapAnnotationType) {
        self.coordinate = coordinate
        self.annotationType = annotationType
        super.init()
    }
}

class AnnotationMapViewController: UIViewController, DeviceViewController {

    @IBOutlet var mapView: MKMapView!

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var gps: Ref<Gps>?
    private var poiItf: Ref<PointOfInterestPilotingItf>?

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    weak var delegate: AnnotationMapDelegate?
    /// MKAnnotations for the mapView
    var activePoiPin: MapAnnotation?
    var dronePin: MapAnnotation?
    var movePin: MapAnnotation?
    var autoCenterOnDroneDone = false

    /// store the chosen destination
    /// updating this value updates the pin on the map
    var moveDestination: CLLocationCoordinate2D? {
        didSet {
            updateMoveCoordinate()
            delegate?.destinationDidChange(moveLocation: moveDestination)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapOnMap(sender:)))
        mapView.addGestureRecognizer(tapRecognizer)
    }

    override func viewDidAppear(_ animated: Bool) {
        super .viewDidAppear(animated)
        if let drone = groundSdk.getDrone(uid: droneUid!) {
            gps = drone.getInstrument(Instruments.gps) { [unowned self] gps in
                self.updateGpsElements(gps)
            }
            poiItf = drone.getPilotingItf(PilotingItfs.pointOfInterest) { [unowned self] pilotingItf in
                self.updatePoiElements(pilotingItf)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        gps = nil
    }

    private func updateGpsElements(_ gps: Gps?) {
        if let location = gps?.lastKnownLocation {
            updateDroneOnMap(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }

    private func updatePoiElements(_ poiItf: PointOfInterestPilotingItf?) {
        if let currentPointOfInterest = poiItf?.currentPointOfInterest {
            updatePoiOnMap(latitude: currentPointOfInterest.latitude, longitude: currentPointOfInterest.longitude)
        } else {
            removeAnyPoiOnMap()
        }
    }

    // TAP on map -> defines the moveDestination
    @objc
    private func tapOnMap(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            let touchPoint = sender.location(in: mapView)
            moveDestination = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        }
    }

    /// Center the map on the latitude, longitude parameters
    private func centerOnLocation(latitude: Double, longitude: Double) {
        let coords2D = CLLocationCoordinate2DMake(latitude, longitude)
        guard CLLocationCoordinate2DIsValid(coords2D) else {
            return
        }
        mapView.setCenter(coords2D, animated: true)
    }

    /// Center the map on the latitude, longitude parameters with distance meters
    private func centerOnLocation(latitude: Double, longitude: Double, distanceMeters: Double) {
        let coords2D = CLLocationCoordinate2DMake(latitude, longitude)
        guard CLLocationCoordinate2DIsValid(coords2D) else {
            return
        }
        let region = MKCoordinateRegion(
            center: coords2D, latitudinalMeters: distanceMeters, longitudinalMeters: distanceMeters)
        mapView.setRegion(region, animated: false)
    }

    // remove the drone annotation from the map
    private func removeAnyDroneOnMap() {
        if dronePin != nil {
            mapView.removeAnnotation(dronePin!)
            dronePin = nil
        }
    }

    // remove the Poi annotation from the map
    private func removeAnyPoiOnMap() {
        if activePoiPin != nil {
            mapView.removeAnnotation(activePoiPin!)
            activePoiPin = nil
        }
    }

    /// update or create an annotation for the drone
    private func updateDroneOnMap(latitude: Double, longitude: Double) {
        let dronePosition: CLLocationCoordinate2D = CLLocationCoordinate2DMake(latitude, longitude)
        guard CLLocationCoordinate2DIsValid(dronePosition) else {
            removeAnyDroneOnMap()
            return
        }

        // center the map on the drone
        if !autoCenterOnDroneDone {
            autoCenterOnDroneDone = true
            self.centerOnLocation(
                latitude: dronePosition.latitude, longitude: dronePosition.longitude, distanceMeters: 100)
        }

        if dronePin == nil {
            dronePin = MapAnnotation(coordinate: dronePosition, annotationType: .dronePin)
            mapView.addAnnotation(dronePin!)
        } else {
            dronePin!.coordinate = dronePosition
        }
    }

    /// update or update an annotation for the Poi
    private func updatePoiOnMap(latitude: Double, longitude: Double) {
        let poiPosition: CLLocationCoordinate2D = CLLocationCoordinate2DMake(latitude, longitude)
        guard CLLocationCoordinate2DIsValid(poiPosition) else {
            removeAnyPoiOnMap()
            return
        }

        if activePoiPin == nil {
            activePoiPin = MapAnnotation(coordinate: poiPosition, annotationType: .activePoiPin)
            mapView.addAnnotation(activePoiPin!)
        } else {
            activePoiPin!.coordinate = poiPosition
        }
    }

    /// update or create an annotation for the move destination (uses self.moveDestination)
    private func updateMoveCoordinate() {
        guard moveDestination != nil else {
            if let movePin = movePin {
                mapView.removeAnnotation(movePin)
                self.dronePin = nil
            }
            return
        }
        if movePin != nil {
            mapView.removeAnnotation(movePin!)
            movePin = nil
        }
        movePin = MapAnnotation(coordinate: moveDestination!, annotationType: .destinationPin)
        mapView.addAnnotation(movePin!)
    }
}

// MARK: - UITableViewDataSource
extension AnnotationMapViewController: MKMapViewDelegate {

    // MKAnnotationView
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MapAnnotation else {
            return nil
        }
        let mapAannotation = annotation as! MapAnnotation
        switch mapAannotation.annotationType {
        case .activePoiPin, .dronePin:
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: mapAannotation.annotationId)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: mapAannotation.annotationId)
            } else {
                annotationView!.annotation = annotation
            }
            annotationView!.image = UIImage.init(named: mapAannotation.iconName)
            return annotationView

        case .destinationPin:
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: mapAannotation.annotationId)
            if annotationView == nil {
                let pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: mapAannotation.annotationId)
                pinView.pinTintColor = MKPinAnnotationView.purplePinColor()
                pinView.animatesDrop = true
                annotationView = pinView
            } else {
                annotationView!.annotation = annotation
            }
            return annotationView
        }
    }
}
