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


func safeFileName(for locationName: String) -> String {
    let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    let components = locationName.components(separatedBy: allowedCharacters.inverted)
    return components.joined(separator: "_")
}


class PlacesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate {
    
    
    struct LocationData {
        let name: String
        let location: CLLocation
        let imageURL: URL?
    }
    
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
                        
                        let minSamples = 1
                        self.locations = self.clusterLocations(locations: fetchedLocations, eps: 30.0, minSamples: minSamples)
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
        
        cell.locationNameLabel.text = locationData.name
        if let imageURL = locationData.imageURL {
            cell.locationImageView.sd_setImage(with: imageURL, placeholderImage: UIImage(named: "placeholder"))
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
    
    weak var delegate: PlacesViewControllerDelegate?
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < notes.count else {
            print("Invalid indexPath.row")
            return
        }
        let note = notes[indexPath.row]
        delegate?.didSelectLocation(note: note)
        
        // Switch to HomeViewController tab
        if let tabBar = self.tabBarController {
            tabBar.selectedIndex = 0 // Assuming the HomeViewController is at index 0
        }
    }






}

//MARK: - Extensions + Protocols
protocol PlacesViewControllerDelegate: AnyObject {
    func didSelectLocation(note: Note)
}




    
    


