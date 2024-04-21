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

class NamesViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UITableViewDelegate, UITableViewDataSource {
    // UITableViewDataSource methods
       func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
           return friendRequests.count
       }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
           let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCell", for: indexPath)
           cell.textLabel?.text = friendRequests[indexPath.row]
           return cell
       }
    
    var mapView: MKMapView!
    
    // Add these properties
      var friendRequests: [String] = []
      
      // Make sure you connect this IBOutlet from your TableView in the storyboard
      @IBOutlet weak var friendRequestsTableView: UITableView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        
        
        // Set the delegate and data source for your TableView
        friendRequestsTableView.delegate = self
        friendRequestsTableView.dataSource = self
        
        // Rest of your viewDidLoad
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = false
        self.navigationController?.navigationBar.isTranslucent = false
    }


    func setupMapView() {
        mapView = MKMapView()
        mapView.delegate = self
        mapView.showsUserLocation = false
        mapView.translatesAutoresizingMaskIntoConstraints = false  // Use Auto Layout
        self.view.addSubview(mapView)
        
        if let navBar = self.navigationController?.navigationBar {
            mapView.topAnchor.constraint(equalTo: navBar.bottomAnchor).isActive = true
        } else {
            mapView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        }
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            mapView.leftAnchor.constraint(equalTo: self.func, constant: updateFriendRequestsListView() {
                guard let currentUserEmail = Auth.auth().currentUser?.email else {
                    return // Optionally add error handling
                }
                
                let db = Firestore.firestore()
                let userRef = db.collection("users").document(currentUserEmail)
                
                userRef.getDocument { (document, error) in
                    if let error = error {
                        // Handle error
                    } else if let document = document, document.exists {
                        // This will get the 'friendRequests' field, which is an array of strings
                        if let requests = document.data()?["friendRequests"] as? [String] {
                            self.friendRequests = requests
                            self.friendRequestsTableView.reloadData()
                        }
                    }
                }
            }

            // Implement UITableViewDataSource methods
            func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
                return friendRequests.count
            }

            func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCell", for: indexPath)
                cell.textLabel?.text = friendRequests[indexPath.row]
                return cell
            };view.leftAnchor;),
            mapView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            mapView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }
    



    @objc func toggleUserLocation() {
        mapView.showsUserLocation.toggle()  // Toggle the visibility of the user location
    }
    
    
    @IBAction func LocationOnOff(_ sender: UIBarButtonItem) {
        
        mapView.showsUserLocation.toggle()
           sender.title = mapView.showsUserLocation ? "Hide Location" : "Show Location"  // Update the button title accordingly
       }
    }
    

