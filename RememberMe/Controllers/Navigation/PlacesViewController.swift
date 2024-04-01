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

// Utility function for sanitizing strings (newly added)
func sanitizeString(_ string: String) -> String {
    return string.lowercased().replacingOccurrences(of: " ", with: "_")
}

// Existing safeFileName function (unchanged)
func safeFileName(for locationName: String) -> String {
    // Define the set of allowed characters
    let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_ ")
    
    // Separate the original string into components based on the allowed characters
    let components = locationName.components(separatedBy: allowedCharacters.inverted)
    
    // Join the components back together, replacing any disallowed characters with an empty string
    let cleanedName = components.joined(separator: "")
    
    // Replace spaces with underscores
    let finalName = cleanedName.replacingOccurrences(of: " ", with: "_")
    
    return finalName
}






class PlacesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    var isFilteringByLetter = false
    
    
    
    weak var delegate: PlacesViewControllerDelegate?
    
    var filteredLocations: [LocationData] = []
    
    var locations: [LocationData] = []
    var fetchedLocationKeys: Set<String> = []
    let locationManager = CLLocationManager()
    var userLocation: CLLocation?
    var currentPage: Int = 0
    let pageSize: Int = 5
    var notes: [Note] = []
    
    let imageCache = NSCache<NSString, UIImage>()
    
    
    @IBOutlet weak var tableView: UITableView!
    
    
    @IBAction func ResetButton(_ sender: Any) {
        // Start keyframe animation
        UIView.animateKeyframes(withDuration: 0.5, delay: 0, options: [], animations: {
            // Add keyframes
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.25) {
                self.ResetBOutlet.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2) // 90 degrees
            }
            UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                self.ResetBOutlet.transform = CGAffineTransform(rotationAngle: CGFloat.pi) // 180 degrees
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.25) {
                self.ResetBOutlet.transform = CGAffineTransform(rotationAngle: 3 * CGFloat.pi / 2) // 270 degrees
            }
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                self.ResetBOutlet.transform = CGAffineTransform(rotationAngle: 2 * CGFloat.pi) // 360 degrees, back to original
            }
        }) { finished in
            if finished {
                // Reset transform to avoid accumulation of rotation effect
                self.ResetBOutlet.transform = CGAffineTransform.identity
            }
        }
        
        // Perform
        resetFilter()
        loadLocationData()
        
    }
    @IBOutlet weak var AlphaScrollView: UIScrollView!
    @IBOutlet weak var AlphaPlaces: UIStackView!
    
    @IBOutlet weak var ResetBOutlet: UIButton!
    
    let db = Firestore.firestore()
    let auth = Auth.auth()
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        tableView.reloadData()
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let locationCellNib = UINib(nibName: "LocationCell", bundle: nil)
        tableView.register(locationCellNib, forCellReuseIdentifier: "LocationCell")
        tableView.dataSource = self
        tableView.delegate = self
        UNUserNotificationCenter.current().delegate = self
        loadLocationData()
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: NSNotification.Name("AppDidBecomeActive"), object: nil)
        
        
        setupAlphabetScrollView()
        
        // Set border for the scrollView
        AlphaScrollView.layer.borderColor = UIColor.black.cgColor
        AlphaScrollView.layer.borderWidth = 2
        AlphaScrollView.layer.cornerRadius = 10.0 // Add this line
        AlphaScrollView.clipsToBounds = true
        
        
        // Remove vertical and horizontal scroll indicators
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        
        
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func appDidBecomeActive() {
        print("App became active - reloading location data.")
        locationManager.startUpdatingLocation() // This will trigger location update and eventually reload data
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        delegate?.didEnterPlacesViewController()
    }
    
    func setupAlphabetScrollView() {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for letter in alphabet {
            let button = UIButton()
            button.setTitle(String(letter), for: .normal)
            button.setTitleColor(.black, for: .normal)
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            button.addTarget(self, action: #selector(alphabetButtonTapped), for: .touchUpInside)
            AlphaPlaces.addArrangedSubview(button)
        }
    }
    
    @objc func alphabetButtonTapped(_ sender: UIButton) {
        guard let letter = sender.titleLabel?.text else { return }
        isFilteringByLetter = true
        filterLocations(startingWith: letter)
    }
    
    func filterLocations(startingWith letter: String) {
        filteredLocations = locations.filter { $0.name.uppercased().starts(with: letter) }
        tableView.reloadData()
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
    
    // MARK: - Notification Handling
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            }
        }
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
            .addSnapshotListener { (querySnapshot, error) in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        print("Number of snapshot documents: \(snapshotDocuments.count)") // Debugging line
                        var fetchedLocationsDict: [String: LocationData] = [:] // Use a dictionary to store unique locations
                        
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let locationName = data["locationName"] as? String,
                               let locationData = data["location"] as? GeoPoint {
                                
                                let location = CLLocation(latitude: locationData.latitude, longitude: locationData.longitude)
                                var imageURL: URL? = nil
                                
                                if let imageURLString = data["imageURL"] as? String {
                                    imageURL = URL(string: imageURLString)
                                }
                                
                                let locationDataInstance = LocationData(name: locationName, location: location, imageURL: imageURL)
                                
                                fetchedLocationsDict[locationName] = locationDataInstance // Use the name as a key to eliminate duplicates
                            } else {
                                print("Failed to parse location data for document ID: \(doc.documentID)")
                            }
                        }
                        
                        self.locations = Array(fetchedLocationsDict.values)
                        // Check if we are currently filtering by letter; if not, sort by distance
                        if !self.isFilteringByLetter {
                            if let userLocation = self.userLocation {
                                self.locations.sort { $0.location.distance(from: userLocation) < $1.location.distance(from: userLocation) }
                            }
                        } else {
                            // Keep the alphabetical order if isFilteringByLetter is true
                            self.locations.sort { $0.name < $1.name }
                        }
                        
                        // Update filteredLocations either way to keep the table view and data source consistent
                        self.filteredLocations = self.locations
                        
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    } else {
                        print("No snapshot documents found")
                    }
                }
            }
    }
    
    
    func sortLocationsByDistance() {
        guard let userLocation = userLocation else {
            print("User location is not available")
            return
        }
        locations.sort { locationData1, locationData2 in
            let distance1 = locationData1.location.distance(from: userLocation)
            let distance2 = locationData2.location.distance(from: userLocation)
            return distance1 < distance2
        }
        delegate?.didUpdateClosestLocation(locations.first)
    }
    
    func resetFilter() {
        isFilteringByLetter = false
        filteredLocations = locations // Assuming 'locations' is already sorted by proximity
        tableView.reloadData()
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
        return filteredLocations.count
    }
    
    let placeholderImage = UIImage(named: "default_image")
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath) as! LocationCell
        let locationData = filteredLocations[indexPath.row]
        cell.locationNameLabel.text = locationData.name
        
        // Cancel any ongoing image download tasks when reusing the cell
        cell.locationImageView.sd_cancelCurrentImageLoad()
        
        // Use cached image if available
        let cacheKey = NSString(string: safeFileName(for: locationData.name))
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            cell.locationImageView.image = cachedImage
            return cell
        }
        
        // Set the placeholder image initially
        cell.locationImageView.image = placeholderImage
        cell.locationImageView.alpha = 0 // Start with a transparent image view for the fade-in effect
        
        // Download the image if it's not in cache
        let storageRef = Storage.storage().reference().child("location_images/\(safeFileName(for: locationData.name)).jpg")
        storageRef.downloadURL { [weak self] (url, error) in
            guard let strongSelf = self else { return }
            
            if let url = url {
                cell.locationImageView.sd_setImage(with: url, placeholderImage: strongSelf.placeholderImage, options: [], completed: { (image, error, cacheType, imageURL) in
                    if let downloadedImage = image {
                        // Cache the downloaded image
                        strongSelf.imageCache.setObject(downloadedImage, forKey: cacheKey)
                        
                        UIView.transition(with: cell.locationImageView,
                                          duration: 0.3,
                                          options: .transitionCrossDissolve,
                                          animations: {
                            cell.locationImageView.image = downloadedImage
                            cell.locationImageView.alpha = 1 // Fade in the imageView to full opacity
                        }, completion: nil)
                    }
                })
            } else {
                print("Error: Unable to download image. A placeholder will be used.")
                UIView.animate(withDuration: 0.3) {
                    cell.locationImageView.alpha = 1 // Even for placeholder, we perform a fade-in
                }
            }
        }
        
        return cell
    }
    
    
    //SWIPE TO DELETE FUNCTIONS
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let locationToDelete = locations[indexPath.row]
            deleteLocationAndNotes(locationData: locationToDelete, indexPath: indexPath)
        }
    }
    func deleteLocationAndNotes(locationData: LocationData, indexPath: IndexPath) {
        // Presenting a confirmation alert before deleting
        let alert = UIAlertController(title: "Delete Location", message: "Are you sure you want to delete this location and all its notes?", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Yes", style: .destructive) { [weak self] action in
            guard let self = self else { return }
            
            // Check if there are notes associated with the location
            self.db.collection("notes")
                .whereField("locationName", isEqualTo: locationData.name)
                .getDocuments { (querySnapshot, error) in
                    if let error = error {
                        print("Error getting documents: \(error)")
                    } else {
                        let group = DispatchGroup()
                        for document in querySnapshot!.documents {
                            group.enter()
                            document.reference.delete { error in
                                if let error = error {
                                    print("Error removing document: \(error)")
                                }
                                group.leave()
                            }
                        }
                        
                        group.notify(queue: .main) {
                            // After all notes are deleted, delete the location
                            self.db.collection("locations").document(locationData.name).delete { error in
                                if let error = error {
                                    print("Error removing location: \(error)")
                                } else {
                                    print("Location successfully removed!")
                                    
                                    // Remove the location from the local array
                                    self.locations.removeAll { $0.name == locationData.name }
                                    // Reload the tableView instead of deleting single row to avoid inconsistency
                                    self.tableView.reloadData()
                                }
                            }
                        }
                    }
                }
        }
        
        let noAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
        alert.addAction(yesAction)
        alert.addAction(noAction)
        present(alert, animated: true)
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
        
        // Decide which array to use based on whether we're currently filtering.
        let selectedLocation = isFilteringByLetter ? filteredLocations[indexPath.row] : locations[indexPath.row]
        
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
    func didEnterPlacesViewController()
    func didUpdateClosestLocation(_ closestLocation: LocationData?)
    func didSelectLocation(with locationName: String)
}




