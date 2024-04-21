//
//  NamesViewController.swift
//  RememberMe
//
//  Created by William Misiaszek on 3/13/23.
//
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import CoreData
import CoreLocation
import MapKit

class NamesViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    var mapView: MKMapView!
    var locationManager = CLLocationManager()  // CLLocationManager instance
    var shouldCenterMapOnUserLocation = true


    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        setupMapView()
        mapView.showsUserLocation = true  // Show the user's location on the map
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = false
        self.navigationController?.navigationBar.isTranslucent = false
        displayFriendsOnMap()  // Optionally, load and display friends locations when the view appears
    }
    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()  // Request user's permission for location
        locationManager.startUpdatingLocation()  // Start updating the location
    }
    
    func setupMapView() {
        mapView = MKMapView()
        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false  // Use Auto Layout
        self.view.addSubview(mapView)
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            mapView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            mapView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            mapView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last, shouldCenterMapOnUserLocation {
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: true)
            shouldCenterMapOnUserLocation = false  // Set to false after first location update
        }
    }

    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()  // Start location updates when authorized
        }
    }
    
    func displayFriendsOnMap() {
        guard let currentUserEmail = Auth.auth().currentUser?.email else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserEmail)
        
        userRef.getDocument { [weak self] (document, error) in
            if let document = document, document.exists, let friends = document.data()?["friends"] as? [String] {
                for friendEmail in friends {
                    let friendRef = db.collection("users").whereField("email", isEqualTo: friendEmail)
                    friendRef.getDocuments { (querySnapshot, error) in
                        if let documents = querySnapshot?.documents, let locationData = documents.first?.data()["location"] as? [String: Double],
                           let latitude = locationData["latitude"], let longitude = locationData["longitude"] {
                            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                            self?.addAnnotation(for: coordinate, title: friendEmail)
                        }
                    }
                }
            } else {
                print("Error fetching friends: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    
    
    
    @objc func toggleUserLocation() {
        mapView.showsUserLocation.toggle()  // Toggle the visibility of the user location
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        let gestureRecognizers = mapView.gestureRecognizers ?? []
        for gesture in gestureRecognizers {
            if gesture.state == .began || gesture.state == .ended {
                shouldCenterMapOnUserLocation = false
                break
            }
        }
    }
    
    @IBAction func LocationOnOff(_ sender: UIBarButtonItem) {
            shouldCenterMapOnUserLocation = !shouldCenterMapOnUserLocation  // Toggle the centering behavior
            if mapView.showsUserLocation {
                sender.title = "Hide Location"
            } else {
                sender.title = "Show Location"
            }
            mapView.showsUserLocation = !mapView.showsUserLocation
            if shouldCenterMapOnUserLocation, let location = locationManager.location {
                let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
                mapView.setRegion(region, animated: true)
            }
        }

    
    
    func addAnnotation(for coordinate: CLLocationCoordinate2D, title: String) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = title
        mapView.addAnnotation(annotation)
    }
    
    
}
