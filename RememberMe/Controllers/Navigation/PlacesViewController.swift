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

class PlacesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    struct LocationData {
        let name: String
        let imageURL: String
    }

    
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

            print("Locations loaded")
        }
        
        // MARK: - LOCATION IMAGE LOAD
    func loadLocationData() {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }
        
        print("User email found: \(userEmail)")

        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .getDocuments { querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        print("Snapshot documents count: \(snapshotDocuments.count)")
                        
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let locationName = data["locationName"] as? String,
                               let locationImageURL = data["locationImageURL"] as? String {
                                
                                print("Location Name: \(locationName), Image URL: \(locationImageURL)")
                                
                                let locationData = LocationData(name: locationName, imageURL: locationImageURL)
                                self.locations.append(locationData)
                            } else {
                                print("Failed to parse locationName or locationImageURL for document ID: \(doc.documentID)")
                            }
                        }
                        
                        print("Locations count: \(self.locations.count)")
                        
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    } else {
                        print("No snapshot documents found")
                    }
                }
            }
    }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return locations.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath) as! LocationCell

            let locationData = locations[indexPath.row]
            cell.locationNameLabel.text = locationData.name
            
            // Load the image from the imageURL
            if let url = URL(string: locationData.imageURL) {
                cell.locationImageView.sd_setImage(with: url)
            }
            
            return cell
        }
        
        // MARK: - UITableViewDelegate
        // Implement any delegate methods if needed
    }
