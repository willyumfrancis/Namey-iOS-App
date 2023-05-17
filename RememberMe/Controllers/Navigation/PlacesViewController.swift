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


class PlacesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate {
    
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
        
        loadLocationData()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        
        print("Locations loaded")
        
        loadNotes()
        if let tabBarController = self.tabBarController, let viewControllers = tabBarController.viewControllers {
               for viewController in viewControllers {
                   if let homeViewController = viewController as? HomeViewController {
                       self.delegate = homeViewController
                   }
               }
           }
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
    
    func loadNotes() {
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







    
    


