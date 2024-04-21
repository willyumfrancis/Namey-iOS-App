//
//  SettingsViewController.swift
//  RememberMe
//
//  Created by William Misiaszek on 3/13/23.
//

import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import AVFoundation

class AppState {
    static let shared = AppState()
    
    var rotationSpeed: Double = 0.5
    var wasPlaying: Bool = false
    
    private init() {}
}


class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var friendRequests: [String] = []
     
     // IBOutlet for the UITableView to display the friend requests
     @IBOutlet weak var friendRequestsTableView: UITableView!
  
      
      // Function to load friend requests from Firestore
      private func loadFriendRequests() {
          guard let currentUserEmail = Auth.auth().currentUser?.email else {
              // Add error handling if needed
              return
          }
          let db = Firestore.firestore()
          let userRef = db.collection("users").document(currentUserEmail)
          
          userRef.getDocument { [weak self] (document, error) in
              if let document = document, document.exists,
                 let requests = document.data()?["friendRequests"] as? [String] {
                  self?.friendRequests = requests
                  self?.friendRequestsTableView.reloadData()
              } else {
                  // Handle the error or the case where the document does not exist
              }
          }
      }
    
    
    static var savedRotationSpeed: Double = 0.5 // Static property to save rotation speed
    static var wasPlaying: Bool = false // Static property to save audio state
    
    var rotationSpeed: Double {
        get { return SettingsViewController.savedRotationSpeed }
        set { SettingsViewController.savedRotationSpeed = newValue }
    }
    
    
    
    var audioPlayer: AVAudioPlayer?
    
    @IBOutlet weak var betaTap: UILabel!
    
    @IBOutlet weak var catImage: UIImageView!
    
    @IBOutlet weak var audioControlButton: UIButton!
    
    @IBAction func LogOutButton(_ sender: UIBarButtonItem) {
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
            
            // Notify the scene delegate to show the initial view controller
            NotificationCenter.default.post(name: .didSignOut, object: nil)
            
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        
        
        // Create a background view
        let backgroundView = UIView(frame: view.bounds)
        backgroundView.backgroundColor = UIColor(patternImage: UIImage(named: "starry_night")!) // Replace "starry_night" with your image file name
        view.insertSubview(backgroundView, at: 0)
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Set the delegate and data source for your friendRequestsTableView
        friendRequestsTableView.delegate = self
        friendRequestsTableView.dataSource = self
        
        // Load the friend requests from Firestore
        loadFriendRequests()
        // Initialize audio player with the new path
        if let path = Bundle.main.path(forResource: "eastersong", ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                print("Audio player initialized.")
            } catch {
                print("Could not initialize audio player: \(error.localizedDescription)")
            }
        } else {
            print("Could not find audio file.")
        }
        
        
        // Add UITapGestureRecognizer to catImage
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        catImage.isUserInteractionEnabled = true
        catImage.addGestureRecognizer(tapGestureRecognizer)
        
        // Add UITapGestureRecognizer to betaTap label
        let labelTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(labelTapped))
        betaTap.isUserInteractionEnabled = true
        betaTap.addGestureRecognizer(labelTapGestureRecognizer)
        
        // Add UILongPressGestureRecognizer to betaTap label
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(labelLongPressed))
        longPressGestureRecognizer.minimumPressDuration = 1.0 // 1 second
        betaTap.addGestureRecognizer(longPressGestureRecognizer)
        
        
    }
    // Do any additional setup after loading the view.
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audioPlayer?.stop() // Stop the song when view will disappear
        print("Stopped the song.")
    }
    
    
       
       @IBAction func deleteAccountButtonTapped(_ sender: UIButton) {
           let alert = UIAlertController(title: "Delete Account", message: "Please type 'delete' to confirm.", preferredStyle: .alert)
           alert.addTextField { textField in
               textField.placeholder = "Type 'delete' here"
           }
           let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
               guard let textField = alert.textFields?.first, textField.text?.lowercased() == "delete" else {
                   print("Deletion cancelled or incorrect confirmation text.")
                   return
               }
               self?.deleteUserAccount()
           }
           let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
               print("User cancelled deletion.")
           }
           alert.addAction(deleteAction)
           alert.addAction(cancelAction)
           present(alert, animated: true)
       }
       
       func deleteUserAccount() {
           let user = Auth.auth().currentUser
           user?.delete { error in
               if let error = error {
                   print("Error deleting user account: \(error.localizedDescription)")
               } else {
                   print("Account deleted successfully.")
                   // Optionally, navigate user to a different screen or logout
                   NotificationCenter.default.post(name: .didSignOut, object: nil)
               }
           }
       }
    
    // Add IBOutlet for the email text field and the button in your storyboard
    @IBOutlet weak var friendEmailTextField: UITextField!

    @IBAction func addFriendButtonTapped(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Add Friend", message: "Enter your friend's email:", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "Friend's email"
        }
        
        let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak self, weak alertController] _ in
            guard let textField = alertController?.textFields?.first, let friendEmail = textField.text, !friendEmail.isEmpty else {
                return // Optionally add error handling
            }
            self?.addFriend(friendEmail: friendEmail)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
        
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return friendRequests.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCell", for: indexPath)
            cell.textLabel?.text = friendRequests[indexPath.row]
            return cell
        }


    
    func addFriend(friendEmail: String) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            return // Optionally add error handling
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserEmail)
        
        userRef.updateData([
            "friendRequests": FieldValue.arrayUnion([friendEmail])
        ]) { error in
            if let error = error {
                // Handle error
            } else {
                // Update the UI to reflect the friend request
                self.updateFriendRequestsListView()
            }
        }
    }

    
      
      private func updateFriendRequestsListView() {
          // The function to refresh the list of friend requests
          loadFriendRequests()
      }
    


    // This function handles sending a friend request
    func sendFriendRequest(to friendEmail: String) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            // Handle case where current user is not logged in
            return
        }
        
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        
        // Check if user with friendEmail exists
        usersRef.whereField("email", isEqualTo: friendEmail).getDocuments { (querySnapshot, error) in
            if let error = error {
                // Handle any errors
            } else if querySnapshot!.documents.isEmpty {
                // Handle case where no user with friendEmail exists
            } else {
                // User with friendEmail exists, proceed to send friend request
                // Add currentUserEmail to the friendRequests array of the user with friendEmail
                let friendRef = usersRef.document(friendEmail)
                friendRef.updateData([
                    "friendRequests": FieldValue.arrayUnion([currentUserEmail])
                ]) { error in
                    if let error = error {
                        // Handle any errors
                    } else {
                        // Friend request sent successfully
                    }
                }
            }
        }
    }


    
    
    @objc private func imageTapped() {
        
        rotationSpeed += 0.03
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.toValue = NSNumber(value: Double.pi * 2.0 * rotationSpeed)
        rotationAnimation.duration = 1.0
        rotationAnimation.isCumulative = true
        rotationAnimation.repeatCount = Float.greatestFiniteMagnitude
        catImage.layer.add(rotationAnimation, forKey: "rotationAnimation")
        // Play the song when cat is tapped
        if audioPlayer?.play() == true {
            //                   audioControlButton.isHidden = false // Show the audio control button
            //                   audioControlButton.setTitle("⏸", for: .normal) // Set to pause symbol when playing
            print("Started the song.")
        } else {
            print("Failed to start the song.")
        }
    }
    
    
    @objc private func labelTapped() {
        
        if catImage.transform.d != 0 { // checking if the image is visible
            UIView.animate(withDuration: 0.3, animations: {
                self.catImage.transform = self.catImage.transform.scaledBy(x: 0.9, y: 0.9) // reduce the size by 10%
            })
        }
    }
    
    @objc private func labelLongPressed(gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { // Only perform the action when the long press begins
            UIView.animate(withDuration: 3, animations: {
                self.catImage.transform = self.catImage.transform.scaledBy(x: 2, y: 2) // increase the size by 50%
            })
        }
    }
    
    
    
}
