import SwiftUI
import MapKit
import CoreLocation

struct MapView: UIViewRepresentable {
    var attractions: [Attraction]
    var trackedLocations: [TrackedLocation]
    @Binding var region: MKCoordinateRegion
    var replayMarker: CLLocationCoordinate2D? = nil
    var showFeet: Bool = false
    var feetTrail: [TrackedLocation] = []
    var animateFeet: Bool = false

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.register(AttractionMarkerView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: true)
        uiView.removeOverlays(uiView.overlays)
        uiView.removeAnnotations(uiView.annotations.filter { !($0 is MKUserLocation) })

        // Attraction pins
        let attractionAnnotations = attractions.map { AttractionAnnotation(attraction: $0) }
        uiView.addAnnotations(attractionAnnotations)

        // User path
        let coords = trackedLocations.map { $0.coordinate }
        if coords.count > 1 {
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            uiView.addOverlay(polyline)
        }

        // Attraction stops
        for loc in trackedLocations where loc.attractionName != nil {
            let annotation = MKPointAnnotation()
            annotation.coordinate = loc.coordinate
            annotation.title = loc.attractionName
            annotation.subtitle = DateFormatter.localizedString(from: loc.timestamp, dateStyle: .none, timeStyle: .short)
            uiView.addAnnotation(annotation)
        }

        // Replay marker (feet)
        if showFeet, let markerCoord = replayMarker {
            let marker = MKPointAnnotation()
            marker.coordinate = markerCoord
            marker.title = "You"
            uiView.addAnnotation(marker)
        }

        // Feet trail (draw little feet at each location)
        if showFeet {
            for (i, loc) in feetTrail.enumerated() {
                let feetAnnotation = MKPointAnnotation()
                feetAnnotation.coordinate = loc.coordinate
                feetAnnotation.title = "feet-\(i)"
                uiView.addAnnotation(feetAnnotation)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        init(_ parent: MapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let attractionAnnotation = annotation as? AttractionAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier, for: attractionAnnotation) as? AttractionMarkerView
                view?.annotation = attractionAnnotation
                view?.update(for: attractionAnnotation.attraction)
                return view
            } else if annotation is MKUserLocation {
                return nil
            } else if let point = annotation as? MKPointAnnotation, point.title == "You" {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "ReplayMarker")
                view.markerTintColor = .systemRed
                view.glyphText = parent.animateFeet ? "👟" : "🦶"
                view.canShowCallout = false
                return view
            } else if let point = annotation as? MKPointAnnotation, point.title?.starts(with: "feet-") == true {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "FeetTrail")
                view.markerTintColor = .systemBlue
                view.glyphText = "🦶"
                view.canShowCallout = false
                return view
            } else if let point = annotation as? MKPointAnnotation, point.title != nil {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "UserStop")
                view.markerTintColor = .systemGreen
                view.glyphText = "🎢"
                view.canShowCallout = true
                return view
            }
            return nil
        }
    }
}

class AttractionAnnotation: NSObject, MKAnnotation {
    let attraction: Attraction
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    
    init(attraction: Attraction) {
        self.attraction = attraction
        self.title = attraction.name
        self.coordinate = CLLocationCoordinate2D(latitude: attraction.latitude ?? 0, longitude: attraction.longitude ?? 0)
    }
}

class AttractionMarkerView: MKMarkerAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "attraction"
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func update(for attraction: Attraction) {
        markerTintColor = WaitTimeViewModel.statusColor(status: attraction.status, waitTime: attraction.wait_time, isOpen: attraction.is_open).toUIColor()
        glyphText = attraction.wait_time != nil ? "\(attraction.wait_time!)" : " "
        canShowCallout = true
    }
}

extension Color {
    func toUIColor() -> UIColor {
        return UIColor(self)
    }
}
