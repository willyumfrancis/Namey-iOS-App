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

struct LocationData: Hashable {
    let name: String
    let location: CLLocation
    let imageURL: URL?  // The URL might be nil if no image URL was fetched
}





class PlacesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    
    
    func safeFileName(for locationName: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let components = locationName.components(separatedBy: allowedCharacters.inverted)
        return components.joined(separator: "_")
    }

    weak var delegate: PlacesViewControllerDelegate?

    var locations: [LocationData] = []
    var fetchedLocationKeys: Set<String> = []
    let locationManager = CLLocationManager()
    var userLocation: CLLocation?
    var currentPage: Int = 0
    let pageSize: Int = 5


    
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
        
    //MARK: - LOCATION

        
        func setupGeoFence(location: CLLocationCoordinate2D, radius: CLLocationDistance, identifier: String) {
            print("Setting up GeoFence at \(location) with radius \(radius)") // Debugging line
            let region = CLCircularRegion(center: location, radius: radius, identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            locationManager.startMonitoring(for: region)
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
        // Clear SDWebImage Cache
        SDImageCache.shared.clearMemory()
        
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
                        var fetchedLocations: [LocationData] = []
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let locationName = data["locationName"] as? String,
                               let locationData = data["location"] as? GeoPoint,
                               let imageUrlString = data["imageURL"] as? String,  // Fetch the image URL from the database
                               let imageUrl = URL(string: imageUrlString) {  // Convert the URL string to a URL instance

                                let location = CLLocation(latitude: locationData.latitude, longitude: locationData.longitude)
                                let locationDataInstance = LocationData(name: locationName, location: location, imageURL: imageUrl)
                    
                                
                                // Create a unique key for this location
                                let locationKey = self.safeFileName(for: locationName)
                                
                                // Ensure this location is unique
                                if !self.fetchedLocationKeys.contains(locationKey) {
                                    print("Fetched LocationData: \(locationDataInstance)")
                                    fetchedLocations.append(locationDataInstance)
                                    self.fetchedLocationKeys.insert(locationKey)
                                }
                            } else {
                                print("Failed to parse location data for document ID: \(doc.documentID)")
                            }
                        }
                        
                        // Append new locations to the existing ones
                        self.locations += fetchedLocations.filter { locationData in
                            return locationData.name != ""
                        }
                        
                        self.sortLocationsByDistance()
                        self.loadNextPage()
                        
                        DispatchQueue.main.async {
                            print(self.locations)  // Debugging line
                            self.tableView.reloadData()
                        }
                    } else {
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
                        var locationImageURLs: [String: URL] = [:]  // Dictionary to store image URL for each location name
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
                                
                                // Store the image URL for the location name
                                locationImageURLs[locationName] = imageURL

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
                        
                        // Update locations with the correct image URLs
                        for index in 0..<self.locations.count {
                            if let imageURL = locationImageURLs[self.locations[index].name] {
                                self.locations[index] = LocationData(name: self.locations[index].name, location: self.locations[index].location, imageURL: imageURL)
                            }
                        }
                        
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
            print("New Page of Locations: \(Array(locations[startIndex..<endIndex]))")
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(locations.count, currentPage * pageSize)
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath) as! LocationCell

        // Cancel the current image load
        cell.imageView!.sd_cancelCurrentImageLoad()

        // Clear the existing image
        cell.imageView!.image = nil

        let locationData = locations[indexPath.row]

        // Configure the cell with the location data
        cell.configure(with: locationData)
        
        return cell
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
    
    
//MARK: - SWIPE TO DELETE
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let locationToDelete = locations[indexPath.row]
            deleteLocationAndNotes(locationData: locationToDelete, indexPath: indexPath)
        }
    }
    func deleteLocationAndNotes(locationData: LocationData, indexPath: IndexPath) {
        // Deleting notes associated with the location.
        db.collection("notes")
            .whereField("locationName", isEqualTo: locationData.name)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error getting documents: \(error)")
                } else {
                    for document in querySnapshot!.documents {
                        document.reference.delete()
                    }
                }
            }
        // Deleting location from Firestore.
        db.collection("locations").document(locationData.name).delete { error in
            if let error = error {
                print("Error removing document: \(error)")
            } else {
                print("Document successfully removed!")
                
                // Find the index of the location in the locations array
                if let index = self.locations.firstIndex(where: { $0.name == locationData.name }) {
                    // If the location is found, remove it from the array
                    self.locations.remove(at: index)
                    
                    // Update the table view if the deleted location was found in the locations array
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                } else {
                    // If the location was not found in the array, log an error
                    print("Error: could not find location in locations array")
                }
            }
        }
    }
    
}


//MARK: - Extensions + Protocols
protocol PlacesViewControllerDelegate: AnyObject {
    func didSelectLocation(with locationName: String)
}


