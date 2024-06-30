import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import CoreData
import CoreLocation
import MapKit
import UserNotifications

public protocol NamesViewControllerDelegate: AnyObject {
    func pinSelected(with locationName: String)
}

class NamesViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UNUserNotificationCenterDelegate {
    var mapView: MKMapView!
    var locationManager = CLLocationManager()
    var visibilityState: Bool = false
    var locationUpdateTimer: Timer?
    var disableLocationTimer: Timer?
    var initialLocationSet: Bool = false
    var countdownLabel: UILabel!
    
    weak var delegate: NamesViewControllerDelegate?

    let locationButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "location"), for: .normal)
        button.backgroundColor = UIColor(red: 0.07450980392, green: 0.9803921569, blue: 0.9019607843, alpha: 1)
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.cornerRadius = 8
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 3
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.addTarget(self, action: #selector(locationButtonTapped), for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        requestNotificationPermission()
        setupLocationManager()
        setupMapView()
        fetchAndDisplayLocations()
        mapView.showsUserLocation = visibilityState
        setupLocationButton()
        setupCountdownLabel()
        fetchUserNotes()
        checkLocationSharingState() // Check the location sharing state on launch
        UNUserNotificationCenter.current().delegate = self
    }

    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
        print("Location manager setup complete.")
    }
    // New method to fetch and display locations
      func fetchAndDisplayLocations() {
          guard let userEmail = Auth.auth().currentUser?.email else { return }
          let db = Firestore.firestore()
          db.collection("locations").whereField("user", isEqualTo: userEmail).getDocuments { [weak self] (querySnapshot, error) in
              guard let self = self, let documents = querySnapshot?.documents else {
                  print("Error fetching locations: \(error?.localizedDescription ?? "unknown error")")
                  return
              }
              
              for document in documents {
                  if let locationData = document.data()["location"] as? GeoPoint,
                     let locationName = document.data()["locationName"] as? String {
                      let coordinate = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
                      self.addLocationAnnotation(at: coordinate, name: locationName)
                  }
              }
          }
      }

      // New method to add location annotation
      func addLocationAnnotation(at coordinate: CLLocationCoordinate2D, name: String) {
          let annotation = MKPointAnnotation()
          annotation.coordinate = coordinate
          annotation.title = name
          DispatchQueue.main.async {
              self.mapView.addAnnotation(annotation)
          }
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
        print("Map view setup complete.")
    }

    func setupCountdownLabel() {
        countdownLabel = UILabel()
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.backgroundColor = UIColor(red: 0.07450980392, green: 0.9803921569, blue: 0.9019607843, alpha: 1)
        countdownLabel.textColor = .black
        countdownLabel.textAlignment = .center
        countdownLabel.layer.borderWidth = 2
        countdownLabel.layer.borderColor = UIColor.black.cgColor
        countdownLabel.layer.cornerRadius = 8
        countdownLabel.layer.shadowOpacity = 0.3
        countdownLabel.layer.shadowRadius = 3
        countdownLabel.layer.shadowOffset = CGSize(width: 0, height: 3)
        countdownLabel.layer.masksToBounds = true
        view.addSubview(countdownLabel)
        NSLayoutConstraint.activate([
            countdownLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            countdownLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            countdownLabel.widthAnchor.constraint(equalToConstant: 120),
            countdownLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        countdownLabel.isHidden = true
        print("Countdown label setup complete.")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("Notification will present: \(notification.request.content.title)")
        completionHandler([.banner, .sound])
    }

    


    func setupLocationButton() {
        view.addSubview(locationButton)
        NSLayoutConstraint.activate([
            locationButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            locationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            locationButton.widthAnchor.constraint(equalToConstant: 40),
            locationButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        print("Location button setup complete.")
    }

    @objc func locationButtonTapped() {
        print("Location button tapped.")
        if visibilityState, let location = locationManager.location {
            centerMapOnLocation(location)
        }
        updateLocationButtonColor()
    }

    func startLocationUpdates() {
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self, let location = self.locationManager.location else { return }
            self.updateFirestoreWithLocation(location, for: Auth.auth().currentUser?.email ?? "")
        }
        print("Started location updates.")
    }

    func stopLocationUpdates() {
        locationUpdateTimer?.invalidate()
        disableLocationTimer?.invalidate()
        countdownLabel.isHidden = true
        print("Stopped location updates.")
    }

    func updateFirestoreWithLocation(_ location: CLLocation?, for userEmail: String) {
        guard let location = location else { return }
        let locationData = ["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude]
        let db = Firestore.firestore()
        db.collection("users").document(userEmail).updateData([
            "location": locationData,
            "visibility": true
        ]) { error in
            if let error = error {
                print("Error updating Firestore location: \(error)")
            } else {
                print("Firestore location updated for user \(userEmail)")
            }
        }
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied.")
            }
        }
    }

    private func updateLocationEnabledAt(for userEmail: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userEmail)
        userRef.updateData([
            "locationEnabledAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating locationEnabledAt: \(error)")
            } else {
                print("LocationEnabledAt timestamp updated successfully")
                self.scheduleLocationDisableTimer()
            }
        }
    }

    
    private func scheduleLocationDisableTimer() {
        disableLocationTimer = Timer.scheduledTimer(timeInterval: 4 * 60 * 60, target: self, selector: #selector(disableLocationSharing), userInfo: nil, repeats: false)
        updateCountdownLabel(with: 4 * 60 * 60) // 4 hours countdown
        print("Scheduled location disable timer.")
    }

    @objc private func disableLocationSharing() {
        guard visibilityState else { return }
        print("Disabling location sharing after 4 hours.")
    }

    private func updateCountdownLabel(with timeInterval: TimeInterval) {
        countdownLabel.isHidden = false
        var remainingTime = Int(timeInterval)
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if remainingTime > 0 {
                remainingTime -= 1
                let hours = remainingTime / 3600
                let minutes = (remainingTime % 3600) / 60
                let seconds = remainingTime % 60
                self.countdownLabel.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                self.countdownLabel.isHidden = true
                timer.invalidate()
            }
        }
    }

    private func checkLocationSharingState() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userEmail)
        userRef.getDocument { [weak self] document, error in
            guard let self = self, let document = document, document.exists else { return }
            if let visibility = document.data()?["visibility"] as? Bool {
                self.visibilityState = visibility
                self.mapView.showsUserLocation = visibility
                self.updateLocationButtonColor()
            }
        }
    }

    private func updateLocationButtonColor() {
        locationButton.tintColor = visibilityState ? .black : #colorLiteral(red: 0.2916863561, green: 0.2916863561, blue: 0.2916863561, alpha: 0.499249793)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else {
            return nil // Use default blue dot for user location
        }

        let identifier = "LocationPin"
        
        var view: MKAnnotationView
        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
            dequeuedView.annotation = annotation
            view = dequeuedView
        } else {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.canShowCallout = true
            view.calloutOffset = CGPoint(x: -5, y: 5)
            view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }

        if let title = annotation.title, title == Auth.auth().currentUser?.email {
            if let jellyDevImage = UIImage(named: "jellydev") {
                let size = CGSize(width: 50, height: 70)
                UIGraphicsBeginImageContext(size)
                jellyDevImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                view.image = resizedImage
            }
        } else if let markerView = view as? MKMarkerAnnotationView {
            markerView.markerTintColor = .purple // For location pins
        }

        return view
    }


    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let annotation = view.annotation else { return }

        let coordinate = annotation.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = annotation.title ?? "Location"

        let options = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]
        mapItem.openInMaps(launchOptions: options)

        if let title = annotation.title {
            delegate?.pinSelected(with: title!)
        }
    }


    func centerMapOnLocation(_ location: CLLocation) {
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: true)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last, visibilityState {
            if !initialLocationSet {
                centerMapOnLocation(location)
                initialLocationSet = true
            }
        }
    }

    // New function to fetch user notes and display them as annotations on the map
    func fetchUserNotes() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        let db = Firestore.firestore()
        db.collection("notes").whereField("user", isEqualTo: userEmail).getDocuments { [weak self] (querySnapshot, error) in
            guard let self = self, let documents = querySnapshot?.documents else {
                print("Error fetching user notes: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            var seenLocationNames: Set<String> = []
            for document in documents {
                if let locationData = document.data()["location"] as? GeoPoint,
                   let locationName = document.data()["locationName"] as? String {
                    if seenLocationNames.contains(locationName) {
                        continue // Skip duplicate location names
                    }
                    seenLocationNames.insert(locationName)
                    let coordinate = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
                    self.addOrUpdateAnnotationForNote(at: coordinate, locationName: locationName)
                }
            }
        }
    }

    func addOrUpdateAnnotationForNote(at coordinate: CLLocationCoordinate2D, locationName: String) {
        let existingAnnotation = mapView.annotations.first {
            ($0 as? MKPointAnnotation)?.title == locationName
        } as? MKPointAnnotation

        if let annotation = existingAnnotation {
            DispatchQueue.main.async {
                annotation.coordinate = coordinate
            }
        } else {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = locationName
            DispatchQueue.main.async {
                self.mapView.addAnnotation(annotation)
            }
        }
    }
}
