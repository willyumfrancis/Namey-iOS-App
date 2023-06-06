//
//  PlacesViewController.swift
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
import Photos
import MobileCoreServices
import FirebaseStorage
import SDWebImage
import UserNotifications

struct LocationData {
    let name: String
    let location: CLLocation
    let imageURL: URL?
}


func safeFileName(for locationName: String) -> String {
    let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    let components = locationName.components(separatedBy: allowedCharacters.inverted)
    return components.joined(separator: "_")
}


class PlacesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {

    weak var delegate: PlacesViewControllerDelegate?

    var locations: [LocationData] = []
    var fetchedLocationKeys: Set<String> = []
    let locationManager = CLLocationManager()
    var userLocation: CLLocation?
    var currentPage: Int = 0
    let pageSize: Int = 5
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])  // Replace with your preferred options
    }

    
    var notes: [Note] = []
    
    @IBOutlet weak var tableView: UITableView!
    
    let db = Firestore.firestore()
    let auth = Auth.auth()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let locationCellNib = UINib(nibName: "LocationCell", bundle: nil)
        tableView.register(locationCellNib, forCellReuseIdentifier: "LocationCell")
        
        tableView.dataSource = self
        tableView.delegate = self
        UNUserNotificationCenter.current().delegate = self

        
        
        loadLocationData()
        
        // Request for the notification authorization
        requestNotificationAuthorization()
        // Set up notification category
        setupNotificationCategory()

        // Call this after the locations are loaded
        for locationData in locations {
            addGeofenceForLocation(locationData)
        }
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        
        print("Locations loaded")
        
        loadNotes() { _ in
            // do nothing here
        }
        if let tabBarController = self.tabBarController, let viewControllers = tabBarController.viewControllers {
               for viewController in viewControllers {
                   if let homeViewController = viewController as? HomeViewController {
                       self.delegate = homeViewController
                   }
               }
           }
    }
    
    //MARK: - GeoFencing
    
    // Add geofence for a given location
        func addGeofenceForLocation(_ locationData: LocationData) {
            let geofenceRegionCenter = CLLocationCoordinate2D(
                latitude: locationData.location.coordinate.latitude,
                longitude: locationData.location.coordinate.longitude
            )

            // Create a 500-meter radius geofence
            let geofenceRegion = CLCircularRegion(
                center: geofenceRegionCenter,
                radius: 50,
                identifier: safeFileName(for: locationData.name)
            )
            
            geofenceRegion.notifyOnEntry = true
            geofenceRegion.notifyOnExit = true

            locationManager.startMonitoring(for: geofenceRegion)
        }
        
        // Remove all existing geofences and set up new ones
        func updateGeofences() {
            for region in locationManager.monitoredRegions {
                locationManager.stopMonitoring(for: region)
            }
            
            for locationData in locations {
                addGeofenceForLocation(locationData)
            }
        }
        
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            let locationName = region.identifier.replacingOccurrences(of: "_", with: " ") // Replace "_" with space in location name

            getLastNote(for: locationName) { [weak self] lastNote in
                let lastNoteText = lastNote?.text ?? "" // Get the last note for this location
                self?.getLastFiveNotes(for: locationName) { lastFiveNotes in
                    let lastFiveNotesTexts = lastFiveNotes.map { $0.text } // Get the last 5 notes for this location

                    // Trigger the notification
                    self?.sendNotification(locationName: locationName, lastNote: lastNoteText, lastFiveNotes: lastFiveNotesTexts)
                }
            }
        }
    }


      
      func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
          if region is CLCircularRegion {
              // Handle exiting region
              print("Exited region: \(region.identifier)")
          }
      }
        
    //MARK: - LOCATION


        
        func setupGeoFence(location: CLLocationCoordinate2D, radius: CLLocationDistance, identifier: String) {
            print("Setting up GeoFence at \(location) with radius \(radius)") // Debugging line
            let region = CLCircularRegion(center: location, radius: radius, identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            locationManager.startMonitoring(for: region)
        }

            
    func getLastNote(for locationName: String, completion: @escaping (Note?) -> Void) {
        print("getLastNote called")

        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }

        print("Loading notes for user: \(userEmail)")

        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .whereField("locationName", isEqualTo: locationName)
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                } else {
                    self?.notes = [] // Clear the existing notes array

                    if let snapshotDocuments = querySnapshot?.documents {
                        print("Found \(snapshotDocuments.count) notes")
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let noteText = data["note"] as? String,
                               let locationData = data["location"] as? GeoPoint,
                               let locationName = data["locationName"] as? String,
                               let imageURLString = data["imageURL"] as? String,
                               !noteText.isEmpty {
                                let location = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
                                let imageURL = URL(string: imageURLString)
                                let newNote = Note(id: doc.documentID, text: noteText, location: location, locationName: locationName, imageURL: imageURL)

                                self?.notes.append(newNote)
                            }
                        }

                        let lastNote = self?.notes.last
                        completion(lastNote)
                    }
                }
            }
    }

    func getLastFiveNotes(for locationName: String, completion: @escaping ([Note]) -> Void) {
        print("getLastFiveNotes called")

        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }

        print("Loading notes for user: \(userEmail)")

        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .whereField("locationName", isEqualTo: locationName)
            .order(by: "timestamp", descending: true)
            .limit(to: 5)
            .getDocuments { [weak self] querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                } else {
                    self?.notes = [] // Clear the existing notes array

                    if let snapshotDocuments = querySnapshot?.documents {
                        print("Found \(snapshotDocuments.count) notes")
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let noteText = data["note"] as? String,
                               let locationData = data["location"] as? GeoPoint,
                               let locationName = data["locationName"] as? String,
                               let imageURLString = data["imageURL"] as? String,
                               !noteText.isEmpty {
                                let location = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
                                let imageURL = URL(string: imageURLString)
                                let newNote = Note(id: doc.documentID, text: noteText, location: location, locationName: locationName, imageURL: imageURL)

                                self?.notes.append(newNote)
                            }
                        }

                        let lastFiveNotes = Array(self?.notes.suffix(5) ?? [])
                        completion(lastFiveNotes)
                    }
                }
            }
    }




    func sendNotification(locationName: String, lastNote: String, lastFiveNotes: [String]) {
        print("Preparing to send notification for location: \(locationName)") // Debugging line
        let content = UNMutableNotificationContent()
        content.title = "\(locationName)"
        content.body = "\(lastNote)"
        content.userInfo = ["LastFiveNotes": lastFiveNotes] // lastFiveNotes is now an array
        content.categoryIdentifier = "notesCategory"

        // Add a sound to the notification
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error adding notification: \(error)")
            } else {
                print("Notification added successfully for location: \(locationName)")
            }
        }
    }



        func requestNotificationAuthorization() {
            print("Requesting notification authorization") // Debugging line
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
                if granted {
                    print("Notification access granted")
                } else {
                    print("Notification access denied")
                    if let error = error {
                        print("Error requesting authorization: \(error)")
                    }
                }
            }
        }

        func setupNotificationCategory() {
            print("Setting up notification category") // Debugging line
            let viewLastFiveNotesAction = UNNotificationAction(identifier: "viewLastFiveNotes", title: "View more n", options: [.foreground])
            let category = UNNotificationCategory(identifier: "notesCategory", actions: [viewLastFiveNotesAction], intentIdentifiers: [], options: [])
            UNUserNotificationCenter.current().setNotificationCategories([category])
        }
        
        
    
    func clusterLocations(locations: [LocationData], eps: Double, minSamples: Int) -> [LocationData] {
        var visited = [Bool](repeating: false, count: locations.count)
        var noise = [Bool](repeating: false, count: locations.count)
        var clusters = [Int: [LocationData]]()
        var clusterIndex = 0
        
        for (index, _) in locations.enumerated() {
            if visited[index] {
                continue
            }
            visited[index] = true
            var neighbors = regionQuery(locations: locations, pointIndex: index, eps: eps)
            if neighbors.count < minSamples {
                noise[index] = true
            } else {
                let cluster = expandCluster(locations: locations, pointIndex: index, neighbors: &neighbors, clusterIndex: clusterIndex, eps: eps, minSamples: minSamples, visited: &visited, clusters: &clusters)
                if !cluster.isEmpty {
                    clusters[clusterIndex] = cluster
                    clusterIndex += 1
                }
            }
        }
        
        // Choose a representative for each cluster
        return clusters.values.map { locations in
            // You can return any point from the cluster, here we choose the first one
            return locations.first!
        }
    }

    func expandCluster(locations: [LocationData], pointIndex: Int, neighbors: inout [Int], clusterIndex: Int, eps: Double, minSamples: Int, visited: inout [Bool], clusters: inout [Int: [LocationData]]) -> [LocationData] {
        var cluster = [locations[pointIndex]]
        var i = 0
        while i < neighbors.count {
            let neighborIndex = neighbors[i]
            if !visited[neighborIndex] {
                visited[neighborIndex] = true
                let neighborNeighbors = regionQuery(locations: locations, pointIndex: neighborIndex, eps: eps)
                if neighborNeighbors.count >= minSamples {
                    neighbors.append(contentsOf: neighborNeighbors)
                }
            }
            if clusters[clusterIndex]?.contains(where: {$0.name == locations[neighborIndex].name && $0.location.coordinate.latitude == locations[neighborIndex].location.coordinate.latitude && $0.location.coordinate.longitude == locations[neighborIndex].location.coordinate.longitude}) == nil {
                cluster.append(locations[neighborIndex])
            }
            i += 1
        }
        
        return cluster
    }


    
    func regionQuery(locations: [LocationData], pointIndex: Int, eps: Double) -> [Int] {
        var neighbors = [Int]()
        for (index, location) in locations.enumerated() {
            let distance = location.location.distance(from: locations[pointIndex].location)
            if distance <= eps {
                neighbors.append(index)
            }
        }
        return neighbors
    }

    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let currentLocation = locations.last {
            userLocation = currentLocation
            locationManager.stopUpdatingLocation()
            
            loadLocationData()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get user location: \(error.localizedDescription)")
    }
    
    
    // MARK: - LOCATION IMAGE LOAD
    func loadLocationData() {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }
        
        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .getDocuments { querySnapshot, error in
                
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        var fetchedLocations: [LocationData] = []
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let locationName = data["locationName"] as? String,
                                let locationData = data["location"] as? GeoPoint,
                                let imageURLString = data["imageURL"] as? String,
                                let imageURL = URL(string: imageURLString) {
                                    
                                let location = CLLocation(latitude: locationData.latitude, longitude: locationData.longitude)
                                let locationDataInstance = LocationData(name: locationName, location: location, imageURL: imageURL)
                                fetchedLocations.append(locationDataInstance)
                            } else {
                                print("Failed to parse location data for document ID: \(doc.documentID)")
                            }
                        }
                        
                        self.locations = fetchedLocations.filter { locationData in
                            return locationData.name != "" && locationData.imageURL != nil
                        }
                        
                        let minSamples = 1
                        self.locations = self.clusterLocations(locations: self.locations, eps: 30.0, minSamples: minSamples)
                        self.sortLocationsByDistance()
                        self.loadNextPage()
                        // Update geofences
                                self.updateGeofences()
                        
                        DispatchQueue.main.async {
                            print(self.locations)  // Debugging line
                            self.tableView.reloadData()
                        }
                    }
 else {
                        print("No snapshot documents found")
                    }
                }
            }
    }
    
    func sortLocationsByDistance() {
           guard let userLocation = userLocation else { return }
           locations.sort { locationData1, locationData2 in
               return
               locationData1.location.distance(from: userLocation) < locationData2.location.distance(from: userLocation)
           }
       }
    
    func loadNotes(completion: @escaping ([Note]) -> Void) {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }

        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .getDocuments { querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        var fetchedNotes: [Note] = []
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            print("Fetched data: \(data)")  // Debugging line
                            
                            // Extract the values from the data dictionary
                            if let id = data["id"] as? String,
                               let text = data["text"] as? String,
                               let lat = data["latitude"] as? Double,
                               let lon = data["longitude"] as? Double,
                               let locationName = data["locationName"] as? String,
                               let imageURLString = data["imageURL"] as? String,
                               let imageURL = URL(string: imageURLString) {
                                
                                // Create a CLLocationCoordinate2D instance for the location
                                let location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                                
                                // Create a Note instance
                                let note = Note(id: id, text: text, location: location, locationName: locationName, imageURL: imageURL)
                                
                                print("Created note: \(note)")  // Debugging line
                                fetchedNotes.append(note)
                            } else {
                                print("Failed to create a note from data: \(data)")  // Debugging line
                            }
                        }
                        self.notes = fetchedNotes
                        print("Loaded notes: \(self.notes)")  // Debugging line
                        completion(fetchedNotes)
                    }
                }
            }
    }





    
    
    func loadNextPage() {
        let startIndex = currentPage * pageSize
        let endIndex = min((currentPage + 1) * pageSize, locations.count)
        
        if startIndex < endIndex {
            currentPage += 1
            tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(locations.count, currentPage * pageSize)
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath) as! LocationCell
        
        let locationData = locations[indexPath.row]
        
        // Check if the data is complete
        if let imageURL = locationData.imageURL {
            cell.locationImageView.sd_setImage(with: imageURL, placeholderImage: UIImage(named: "placeholder"))
            cell.locationNameLabel.text = locationData.name
        } else {
            cell.isHidden = true // If data is not complete, hide the cell
        }
        
        return cell
    }

    
    
    
    
    func downloadAndDisplayImage(locationData: LocationData, completion: @escaping (URL) -> Void) {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }
        
        let safeFileName = safeFileName(for: locationData.name)
        let storage = Storage.storage()
        
        let storageRef = storage.reference().child("location_images/\(safeFileName).jpg")
        storageRef.downloadURL { (url, error) in
            if let e = error {
                print("Error getting the download URL for the image: \(e)")
            } else {
                if let url = url {
                    completion(url)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedLocation = locations[indexPath.row]

        // Calculate the average of the selected location's notes' coordinates
        var totalLatitude = 0.0
        var totalLongitude = 0.0
        var notesCount = 0

        for note in notes {
            if note.locationName == selectedLocation.name {
                totalLatitude += note.location.latitude
                totalLongitude += note.location.longitude
                notesCount += 1
            }
        }

        if notesCount > 0 {
            let averageLatitude = totalLatitude / Double(notesCount)
            let averageLongitude = totalLongitude / Double(notesCount)
            let averageLocation = CLLocationCoordinate2D(latitude: averageLatitude, longitude: averageLongitude)

            let locationData = NSKeyedArchiver.archivedData(withRootObject: averageLocation)
            UserDefaults.standard.set(locationData, forKey: "averageSelectedLocation")
            UserDefaults.standard.set(selectedLocation.name, forKey: "averageSelectedLocationName")
        } else {
            UserDefaults.standard.removeObject(forKey: "averageSelectedLocation")
            UserDefaults.standard.removeObject(forKey: "averageSelectedLocationName")
        }

        UserDefaults.standard.synchronize()
        delegate?.didSelectLocation(with: selectedLocation.name)
    }







    

}

//MARK: - Extensions + Protocols
protocol PlacesViewControllerDelegate: AnyObject {
    func didSelectLocation(with locationName: String)
}







    
    


