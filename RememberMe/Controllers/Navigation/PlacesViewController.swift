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
        let location: CLLocationCoordinate2D
    }
    
    var fetchedLocationKeys: Set<String> = []
    let locationManager = CLLocationManager()
    var userLocation: CLLocation?
    var currentPage: Int = 0
    let pageSize: Int = 5
    
    
    @IBOutlet weak var tableView: UITableView!
    
    let db = Firestore.firestore()
    let auth = Auth.auth()
    
    var locations: [LocationData] = [] // Change the type of locations array
    
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
                        
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let locationName = data["locationName"] as? String,
                               let locationData = data["location"] as? GeoPoint {
                                
                                let location = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
                                let locationDataInstance = LocationData(name: locationName, location: location)
                                self.locations.append(locationDataInstance)
                            } else {
                                print("Failed to parse locationName for document ID: \(doc.documentID)")
                            }
                        }
                        self.sortLocationsByDistance()
                        self.loadNextPage()
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
           guard let userLocation = userLocation else { return }
           locations.sort { locationData1, locationData2 in
               let location1 = CLLocation(latitude: locationData1.location.latitude, longitude: locationData1.location.longitude)
               let location2 = CLLocation(latitude: locationData2.location.latitude, longitude: locationData2.location.longitude)
               return location1.distance(from: userLocation) < location2.distance(from: userLocation)
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

    
    
    // Display Image
    func displayImageForLocation(locationData: LocationData, cell: LocationCell) {
        let maxDistance: CLLocationDistance = 100
        let location = locationData.location
        let userCurrentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        if let userEmail = Auth.auth().currentUser?.email {
            db.collection("notes")
                .whereField("user", isEqualTo: userEmail)
                .getDocuments { querySnapshot, error in
                    if let e = error {
                        print("There was an issue retrieving data from Firestore: \(e)")
                    } else {
                        if let snapshotDocuments = querySnapshot?.documents {
                            for doc in snapshotDocuments {
                                let data = doc.data()
                                if let locationDataFromFirestore = data["location"] as? GeoPoint {
                                    let noteLocation = CLLocation(latitude: locationDataFromFirestore.latitude, longitude: locationDataFromFirestore.longitude)
                                    let distance = noteLocation.distance(from: userCurrentLocation)
                                    
                                    if distance <= maxDistance {
                                        let locationKey: String
                                        if let locationName = data["locationName"] as? String, !locationName.isEmpty {
                                            locationKey = locationName
                                        } else {
                                            locationKey = "\(locationDataFromFirestore.latitude),\(locationDataFromFirestore.longitude)"
                                        }
                                        
                                        if !self.fetchedLocationKeys.contains(locationKey) {
                                            self.fetchedLocationKeys.insert(locationKey)
                                            let newLocationData = LocationData(name: locationKey, location: CLLocationCoordinate2D(latitude: locationDataFromFirestore.latitude, longitude: locationDataFromFirestore.longitude))
                                            self.downloadAndDisplayImage(locationData: newLocationData) { url in
                                                DispatchQueue.main.async {
                                                    cell.locationImageView.sd_setImage(with: url, placeholderImage: UIImage(named: "placeholder"))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
        } else {
            print("User email not found")
        }
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
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return min(locations.count, currentPage * pageSize)
        }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath) as! LocationCell
        
        let locationData = locations[indexPath.row]
        
        cell.locationNameLabel.text = locationData.name
        displayImageForLocation(locationData: locationData, cell: cell)
        
        return cell
    }
    
    
    
    
    
}

