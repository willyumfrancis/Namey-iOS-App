//
//  NamesViewController.swift
//  RememberMe
//
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import CoreData
import CoreLocation
import MapKit

public protocol NamesViewControllerDelegate: AnyObject {
    func pinSelected(with locationName: String)
}

class NamesViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    var mapView: MKMapView!
    var locationManager = CLLocationManager()
    var visibilityState: Bool = false
    var locationUpdateTimer: Timer?
    var initialLocationSet: Bool = false  // Used to track if initial location centering is done
    
    weak var delegate: NamesViewControllerDelegate?
    
    let locationButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "location"), for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 3
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.tintColor = .black
        button.addTarget(self, action: #selector(locationButtonTapped), for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        setupMapView()
        mapView.showsUserLocation = visibilityState
        setupLocationButton()
        observeUsersLocations()
    }

    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
    }

    func setupMapView() {
        mapView = MKMapView()
        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func setupLocationButton() {
        view.addSubview(locationButton)
        NSLayoutConstraint.activate([
            locationButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            locationButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            locationButton.widthAnchor.constraint(equalToConstant: 40),
            locationButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    @objc func locationButtonTapped() {
        toggleVisibilityAndUpdateLocation()
        if visibilityState, let location = locationManager.location {
            centerMapOnLocation(location)
        }
        locationButton.tintColor = visibilityState ? .systemBlue : .black
    }

    func toggleVisibilityAndUpdateLocation() {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User is not logged in")
            return
        }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userEmail)
        visibilityState.toggle()
        
        mapView.showsUserLocation = visibilityState
        
        if visibilityState {
            startLocationUpdates()
            if let location = locationManager.location {
                updateFirestoreWithLocation(location, for: userEmail)
            }
            showVisibilityNotification(visible: true)
        } else {
            stopLocationUpdates()
            userRef.updateData([
                "visibility": false,
                "location": FieldValue.delete()
            ])
            showVisibilityNotification(visible: false)
        }
    }

    func startLocationUpdates() {
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self, let location = self.locationManager.location else { return }
            self.updateFirestoreWithLocation(location, for: Auth.auth().currentUser?.email ?? "")
        }
    }

    func stopLocationUpdates() {
        locationUpdateTimer?.invalidate()
    }

    func updateFirestoreWithLocation(_ location: CLLocation?, for userEmail: String) {
        guard let location = location else { return }
        let locationData = ["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude]
        let db = Firestore.firestore()
        db.collection("users").document(userEmail).updateData([
            "location": locationData,
            "visibility": true
        ])
    }

    func observeUsersLocations() {
        let db = Firestore.firestore()
        db.collection("users").whereField("visibility", isEqualTo: true).addSnapshotListener { [weak self] (querySnapshot, error) in
            guard let self = self, let snapshot = querySnapshot else {
                print("Error fetching user locations: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            for change in snapshot.documentChanges {
                if let locationData = change.document.data()["location"] as? [String: Double],
                   let latitude = locationData["latitude"], let longitude = locationData["longitude"],
                   change.document.documentID != Auth.auth().currentUser?.email { // Exclude current user
                    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    
                    switch change.type {
                    case .added, .modified:
                        self.addOrUpdateAnnotationForUser(at: coordinate, email: change.document.documentID)
                    case .removed:
                        self.removeAnnotationForUser(email: change.document.documentID)
                    }
                } else if change.type == .removed || change.document.data()["visibility"] as? Bool == false {
                    self.removeAnnotationForUser(email: change.document.documentID)
                }
            }
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? MKPointAnnotation, annotation.title != Auth.auth().currentUser?.email else {
            return nil
        }

        let identifier = "FriendLocation"
        var view: MKAnnotationView
        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
            dequeuedView.annotation = annotation
            view = dequeuedView
        } else {
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.canShowCallout = true
            view.calloutOffset = CGPoint(x: -5, y: 5)
            view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }

        // Resizing the "jellydev" image to fit the annotation view
        if let jellyDevImage = UIImage(named: "jellydev") {
            let size = CGSize(width: 50, height: 70)  // Set your desired size
            UIGraphicsBeginImageContext(size)
            jellyDevImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            view.image = resizedImage
        }
        
        return view
    }

    func addOrUpdateAnnotationForUser(at coordinate: CLLocationCoordinate2D, email: String) {
        let existingAnnotation = mapView.annotations.first {
            ($0 as? MKPointAnnotation)?.title == email
        } as? MKPointAnnotation

        if let annotation = existingAnnotation {
            DispatchQueue.main.async {
                annotation.coordinate = coordinate
            }
        } else {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = email
            DispatchQueue.main.async {
                self.mapView.addAnnotation(annotation)
            }
        }
    }

    func removeAnnotationForUser(email: String) {
        if let annotation = (mapView.annotations.first {
            ($0 as? MKPointAnnotation)?.title == email
        } as? MKPointAnnotation) {
            DispatchQueue.main.async {
                self.mapView.removeAnnotation(annotation)
            }
        }
    }

    func showVisibilityNotification(visible: Bool) {
        let message = visible ? "You are now visible to others." : "You are now hidden from others."
        let alert = UIAlertController(title: "Visibility Changed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func centerMapOnLocation(_ location: CLLocation) {
        if !initialLocationSet {
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: true)
            initialLocationSet = true  // Ensure we only center the map initially
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last, visibilityState {
            if !initialLocationSet {
                centerMapOnLocation(location)
            }
        }
    }
}
