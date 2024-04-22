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

public protocol NamesViewControllerDelegate: AnyObject {
    func pinSelected(with locationName: String)
}



class NamesViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    var mapView: MKMapView!
    var locationManager = CLLocationManager()  // CLLocationManager instance
    var shouldCenterMapOnUserLocation = false
    var locationUpdateTimer: Timer?
    
    weak var delegate: NamesViewControllerDelegate?


    
    let locationButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false // Use Auto Layout
        button.setImage(UIImage(systemName: "location"), for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 3
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.tintColor = .black // Set the color of the location icon
        button.addTarget(self, action: #selector(locationButtonTapped), for: .touchUpInside)
        
        // Set the size of the button
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        return button
    }()
    
//    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
//        if let locationName = view.annotation?.title {
//            print("Pin selected with location name: \(locationName)")
//            delegate?.pinSelected(with: locationName!)
//            mapView.deselectAnnotation(view.annotation, animated: true)
//            performSegue(withIdentifier: "PinSegue", sender: locationName)
//        }
//    }



       
    
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
                        
                        let annotation = MKPointAnnotation(__coordinate: location, title: locationName, subtitle: nil)
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let userLocation = locationManager.location {
            let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: true)
        }
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
                        if let documents = querySnapshot?.documents {
                            for document in documents {
                                if let locationData = document.data()["location"] as? [String: Double],
                                   let latitude = locationData["latitude"], let longitude = locationData["longitude"],
                                   let imageURL = document.data()["imageURL"] as? String {
                                    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                                    self?.addAnnotation(for: coordinate, title: friendEmail, imageURL: imageURL)
                                
                                }
                            }
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
    
    class LocationAnnotation: MKPointAnnotation {
        var imageURL: String?
        var image: UIImage?
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? LocationAnnotation {
            let identifier = "LocationAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKAnnotationView
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            if let imageURL = annotation.imageURL, let url = URL(string: imageURL) {
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        print("Error loading image: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        let size = CGSize(width: 50, height: 50)
                        UIGraphicsBeginImageContext(size)
                        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                        if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                            UIGraphicsEndImageContext()

                            // Create the annotation view on the main thread
                            DispatchQueue.main.async {
                                annotation.image = resizedImage
                                // Update the existing annotation view if it's visible, otherwise, it will be used when the view is created
                                if let annotationView = mapView.view(for: annotation) as? MKAnnotationView {
                                    annotationView.image = resizedImage
                                }
                            }
                        } else {
                            UIGraphicsEndImageContext()
                            print("Error resizing image")
                        }
                    }
                }.resume()
            } else {
                print("Invalid URL or no image URL provided")
                // Handle the case where the URL is not valid or no imageURL is provided
            }

            
            return annotationView
        }
        
        return nil
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
    
    // In NamesViewController
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PinSegue", let homeVC = segue.destination as? HomeViewController {
            if let locationName = sender as? String {
                homeVC.selectedLocationName = locationName
                print("Location name set for HomeViewController: \(locationName)")
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
    
    
    var locationImages: [String: UIImage] = [:]

    
    
    
    func addAnnotation(for coordinate: CLLocationCoordinate2D, title: String, imageURL: String?) {
        // Create the annotation with the provided details
        let annotation = LocationAnnotation(__coordinate: coordinate, title: title, subtitle: nil)
        annotation.imageURL = imageURL

        // Add the annotation to the map
        self.mapView.addAnnotation(annotation)
        
        // Load the image asynchronously if it is not already in the cache
        if let imageURL = imageURL, locationImages[title] == nil {
            URLSession.shared.dataTask(with: URL(string: imageURL)!) { [weak self] data, response, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error loading image: \(error.localizedDescription)")
                } else if let data = data, let image = UIImage(data: data) {
                    let size = CGSize(width: 50, height: 50)
                    UIGraphicsBeginImageContext(size)
                    image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    // Cache the image
                    self.locationImages[title] = resizedImage
                    
                    // Create the annotation view on the main thread
                    DispatchQueue.main.async {
                        // Find the annotation by title and update its image if it's visible
                        if let annotations = self.mapView.annotations as? [LocationAnnotation] {
                            for ann in annotations where ann.title == title {
                                if let annotationView = self.mapView.view(for: ann) as? MKAnnotationView {
                                    annotationView.image = resizedImage
                                }
                            }
                        }
                    }
                }
            }.resume()
        } else if let cachedImage = locationImages[title] {
            // If the image is already in the cache, find the annotation and update its image
            if let annotations = self.mapView.annotations as? [LocationAnnotation] {
                for ann in annotations where ann.title == title {
                    if let annotationView = self.mapView.view(for: ann) as? MKAnnotationView {
                        annotationView.image = cachedImage
                    }
                }
            }
        }
    }

    


    
    deinit {
        // Invalidate the timer when the view controller is deinitialized
        locationUpdateTimer?.invalidate()
    }
}






    
    

