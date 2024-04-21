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
    var shouldCenterMapOnUserLocation = false
    var locationUpdateTimer: Timer?
    
    let locationButton: UIButton = {
           let button = UIButton(type: .system)
           button.translatesAutoresizingMaskIntoConstraints = false // Use Auto Layout
           button.setTitle("My Location", for: .normal)
           button.backgroundColor = .white
           button.layer.cornerRadius = 8
           button.layer.shadowOpacity = 0.3
           button.layer.shadowRadius = 3
           button.layer.shadowOffset = CGSize(width: 0, height: 3)
           button.addTarget(self, action: #selector(locationButtonTapped), for: .touchUpInside)
           return button
       }()
       
    
    func addLocationPins() {
        let db = Firestore.firestore()
        db.collection("notes").getDocuments { (querySnapshot, error) in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            for document in documents {
                let data = document.data()
                if let locationGeoPoint = data["location"] as? GeoPoint,
                   let locationName = data["locationName"] as? String {
                    
                    let location = CLLocationCoordinate2D(latitude: locationGeoPoint.latitude, longitude: locationGeoPoint.longitude)
                    
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = location
                    annotation.title = locationName
                    self.mapView.addAnnotation(annotation)
                }
            }
        }
    }



    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        setupMapView()
        mapView.showsUserLocation = false  // Show the user's location on the map
        addLocationPins()
        setupLocationButton()

    }
    
    func setupLocationButton() {
           view.addSubview(locationButton)
           
           // Set constraints for the button; e.g., position it at the top-right of the view
           NSLayoutConstraint.activate([
               locationButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
               locationButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
               locationButton.widthAnchor.constraint(equalToConstant: 100),
               locationButton.heightAnchor.constraint(equalToConstant: 50)
           ])
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
             locationManager.requestAlwaysAuthorization()  // Request "Always" authorization
             locationManager.allowsBackgroundLocationUpdates = true  // Allow updates in the background
             locationManager.pausesLocationUpdatesAutomatically = false  // Prevent the system from pausing updates
             locationManager.startUpdatingLocation()  // Start updating the location
             startLocationUpdateTimer()  // Start the timer to limit updates
         }
         
    

    func setupMapView() {
        mapView = MKMapView()
        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false  // Use Auto Layout
        view.addSubview(mapView)
        
        // Set up constraints to make the map view extend to the top of the screen
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }


    
    func startLocationUpdateTimer() {
            // Invalidate the old timer if it exists
            locationUpdateTimer?.invalidate()
            // Schedule a timer to trigger every 2 minutes
            locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
                self?.locationManager.startUpdatingLocation()
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let location = locations.last {
                // Update the user's location in Firestore
                updateUserLocationInFirestore(location)
                // Stop further updates until the timer fires again
                locationManager.stopUpdatingLocation()
            }
        }

    func updateUserLocationInFirestore(_ location: CLLocation) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("User is not logged in")
            return
        }

        // Define the location data
        let locationData = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude
        ]

        // Reference to the user's document in Firestore
        let db = Firestore.firestore()
        let userRef = db.collection("users").whereField("email", isEqualTo: currentUserEmail)

        // Update the user's location
        userRef.getDocuments { (querySnapshot, error) in
            if let document = querySnapshot?.documents.first {
                document.reference.updateData(["location": locationData]) { error in
                    if let error = error {
                        print("Error updating location: \(error.localizedDescription)")
                    } else {
                        print("User location updated to Firestore successfully.")
                    }
                }
            }
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
    
    @objc func locationButtonTapped() {
        mapView.showsUserLocation.toggle()  // Toggle the visibility of the user location
        
        // Show an alert with the current state
        let message = mapView.showsUserLocation ? "Your location is now visible on the map for your friends!" : "Your location is now hidden."
        let alertController = UIAlertController(title: "Location Visibility", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true)

        // Optionally center the map on the user's current location when shown
        if mapView.showsUserLocation, let location = locationManager.location {
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: true)
        }
       }
    
    
    @IBAction func LocationOnOff(_ sender: UIButton) {
        mapView.showsUserLocation.toggle()  // Toggle the visibility of the user location
          
          // Change the button title based on the current visibility
       
          
          // Show an alert with the current state
          let message = mapView.showsUserLocation ? "Your location is now visible on the map." : "Your location is now hidden."
          let alertController = UIAlertController(title: "Location Visibility", message: message, preferredStyle: .alert)
          alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
          present(alertController, animated: true)

          // Optionally center the map on the user's current location when shown
          if mapView.showsUserLocation, let location = locationManager.location {
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
    
    
    deinit {
        // Invalidate the timer when the view controller is deinitialized
        locationUpdateTimer?.invalidate()
    }
}
    
    

