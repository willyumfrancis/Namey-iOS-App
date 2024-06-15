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
    var notifiedUsers: Set<String> = [] // Track notified users
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
        mapView.showsUserLocation = visibilityState
        setupLocationButton()
        setupCountdownLabel()
        observeUsersLocations()
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

    func observeUsersLocations() {
        let db = Firestore.firestore()
        db.collection("users").whereField("visibility", isEqualTo: true).addSnapshotListener { [weak self] (querySnapshot, error) in
            guard let self = self, let querySnapshot = querySnapshot else {
                print("Error fetching user locations: \(error?.localizedDescription ?? "unknown error")")
                return
            }

            var updatedUsers: Set<String> = []
            for change in querySnapshot.documentChanges {
                let userEmail = change.document.documentID
                if userEmail == Auth.auth().currentUser?.email {
                    continue  // Skip the current user's updates
                }

                let userName = userEmail  // Ideally, you would fetch the user's name from the document or cache

                if change.type == .added || (change.type == .modified && change.document.data()["visibility"] as? Bool == true) {
                    if let locationData = change.document.data()["location"] as? [String: Double],
                       let latitude = locationData["latitude"], let longitude = locationData["longitude"] {
                        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        self.addOrUpdateAnnotationForUser(at: coordinate, email: change.document.documentID)
                        updatedUsers.insert(userEmail)
                    }
                } else if change.type == .removed || change.document.data()["visibility"] as? Bool == false {
                    self.removeAnnotationForUser(email: change.document.documentID)
                    self.notifiedUsers.remove(userEmail)  // Remove user from notified set when they go offline
                }
            }

            // Send notifications for newly visible users
            for userEmail in updatedUsers {
                if !self.notifiedUsers.contains(userEmail) {
                    self.sendNotificationForUserGoingLive(userEmail)
                    self.notifiedUsers.insert(userEmail)
                }
            }
        }
    }

    private func sendNotificationForUserGoingLive(_ userName: String) {
        print("Sending notification for user \(userName) going live")
        let content = UNMutableNotificationContent()
        content.title = "\(userName) is live on Namie"
        content.body = "\(userName) has enabled their location sharing."
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: userName, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled successfully for user \(userName)")
            }
        }
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
        toggleVisibilityAndUpdateLocation()
        if visibilityState, let location = locationManager.location {
            centerMapOnLocation(location)
        }
        updateLocationButtonColor()
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
            updateLocationEnabledAt(for: userEmail)
        } else {
            stopLocationUpdates()
            userRef.updateData([
                "visibility": false,
                "location": FieldValue.delete()
            ]) { error in
                if let error = error {
                    print("Error updating Firestore visibility: \(error.localizedDescription)")
                } else {
                    print("Firestore visibility updated to false")
                }
            }
            showVisibilityNotification(visible: false)
        }
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
        toggleVisibilityAndUpdateLocation()
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

    // Handle the directions button tap
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let annotation = view.annotation as? MKPointAnnotation else { return }

        let coordinate = annotation.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = annotation.title ?? "Destination"

        let options = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]
        mapItem.openInMaps(launchOptions: options)
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
}
