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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friendRequests.count + acceptedFriends.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCell", for: indexPath)

        // Determine whether the cell is for a friend request or an accepted friend
        if indexPath.row < friendRequests.count {
            cell.textLabel?.text = friendRequests[indexPath.row]
            // Customize the cell to indicate it's a friend request
        } else {
            let acceptedFriendIndex = indexPath.row - friendRequests.count
            cell.textLabel?.text = acceptedFriends[acceptedFriendIndex]
            // Customize the cell to indicate it's an accepted friend
        }
        return cell
    }

    
    var allUserEmails: [String] = []

    var acceptedFriends: [String] = []

    
    var friendRequests: [String] = []
     
     // IBOutlet for the UITableView to display the friend requests
     @IBOutlet weak var friendRequestsTableView: UITableView!
  
      
    // Function to load friend requests from Firestore
    private func loadFriendRequests() {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("No current user email found.")
            return
        }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserEmail.lowercased())  // Ensure lowercase is used if emails are stored in lowercase
        
        print("Attempting to load friend requests for user: \(currentUserEmail)")
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                print("Error fetching document: \(error)")
                return
            }
            guard let document = document, document.exists else {
                print("Document for user \(currentUserEmail) does not exist")
                return
            }
            print("Document data: \(document.data() ?? [:])")  // Print out the document data
            if let requests = document.data()?["friendRequests"] as? [String] {
                print("Loaded friend requests: \(requests)")
                self?.friendRequests = requests
                DispatchQueue.main.async {
                    self?.friendRequestsTableView.reloadData()
                }
            } else {
                print("Failed to load friend requests or no requests exist.")
            }
        }
    }


    // Function to load accepted friends
          private func loadAcceptedFriends() {
              guard let currentUserEmail = Auth.auth().currentUser?.email else { return }
              let db = Firestore.firestore()
              let userRef = db.collection("users").document(currentUserEmail)
              userRef.getDocument { [weak self] (document, error) in
                  if let document = document, document.exists, let friends = document.data()?["friends"] as? [String] {
                      self?.acceptedFriends = friends
                      self?.friendRequestsTableView.reloadData()
                  } else {
                      print("Error loading accepted friends: \(error?.localizedDescription ?? "Unknown error")")
                  }
              }
          }


    
    
    static var savedRotationSpeed: Double = 0.5 // Static property to save rotation speed
    static var wasPlaying: Bool = false // Static property to save audio state
    
    var rotationSpeed: Double {
        get { return SettingsViewController.savedRotationSpeed }
        set { SettingsViewController.savedRotationSpeed = newValue }
    }
    
    
    @IBOutlet weak var userEmail: UILabel!
    
    var audioPlayer: AVAudioPlayer?
    
    @IBOutlet weak var betaTap: UILabel!
    
    @IBOutlet weak var catImage: UIImageView!
    
    
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
        
        // Load the friend requests and accepted friends from Firestore
        loadFriendRequests()
        loadAcceptedFriends()
    }
    

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        friendRequestsTableView.layer.cornerRadius = 10
        friendRequestsTableView.layer.masksToBounds = true
        
        if let userEmailString = Auth.auth().currentUser?.email {
            userEmail.text = userEmailString
        } else {
            userEmail.text = "Not logged in"
        }
        
        
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
    
    // Load all user emails from the Firestore users collection.
        private func loadAllUserEmailsFromUsersCollection() {
            let db = Firestore.firestore()
            db.collection("users").getDocuments { [weak self] (querySnapshot, error) in
                if let e = error {
                    print("Error getting documents: \(e)")
                } else {
                    self?.allUserEmails = querySnapshot?.documents.compactMap {
                        $0.get("email") as? String
                    } ?? []
                    print("Loaded all user emails: \(self?.allUserEmails ?? [])")
                }
            }
        }
  

    @IBAction func addFriendButtonTapped(_ sender: UIButton) {
        loadAllUserEmailsFromUsersCollection()

        // UIAlertController to send a friend request
          let alertController = UIAlertController(title: "Add Friend", message: "Enter your friend's email:", preferredStyle: .alert)
          
          alertController.addTextField { textField in
              textField.placeholder = "Friend's email"
          }
          
          let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak self, weak alertController] _ in
              guard let textField = alertController?.textFields?.first,
                    let friendEmail = textField.text, !friendEmail.isEmpty else {
                  print("The email field was empty.")
                  return
              }
              self?.sendFriendRequest(to: friendEmail)
          }
          
          let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
          
          alertController.addAction(confirmAction)
          alertController.addAction(cancelAction)
          
          present(alertController, animated: true)
      }
    
    
    // This function handles the logic for sending a friend request
    // This function handles the logic for sending a friend request
    private func sendFriendRequest(to recipientEmail: String) {
        guard let currentUserEmail = Auth.auth().currentUser?.email?.replacingOccurrences(of: ",", with: ".") else {
            print("User not logged in")
            return
        }

        let formattedRecipientEmail = recipientEmail.replacingOccurrences(of: ",", with: ".")
        

        // Ensure the recipient's email exists in allUserEmails before proceeding.
        guard allUserEmails.contains(recipientEmail) else {
            print("User with email \(recipientEmail) does not exist in all users' emails.")
            return
        }

        let db = Firestore.firestore()
        let usersRef = db.collection("users")

        usersRef.whereField("email", isEqualTo: recipientEmail).getDocuments { [weak self] (querySnapshot, error) in
            if let error = error {
                print("Error finding user: \(error)")
            } else if let documents = querySnapshot?.documents, !documents.isEmpty {
                let recipientRef = usersRef.document(documents.first!.documentID)
                recipientRef.updateData([
                    "friendRequests": FieldValue.arrayUnion([currentUserEmail])
                ]) { error in
                    if let error = error {
                        print("Error sending friend request: \(error)")
                    } else {
                        print("Friend request sent to \(recipientEmail)")
                        // Show success message
                        self?.showAlert(withTitle: "Success", message: "Friend Request Sent!")
                    }
                }
            } else {
                print("User with email \(recipientEmail) does not exist")
            }
        }
    }

    // Function to show an alert
    private func showAlert(withTitle title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true)
    }

    
    private func loadAllUserEmailsFromNotes() {
        let db = Firestore.firestore()
        db.collection("notes").getDocuments { [weak self] (querySnapshot, error) in
            if let e = error {
                print("Error getting documents: \(e)")
            } else {
                for document in querySnapshot!.documents {
                    let noteRef = db.collection("notes").document(document.documentID).collection("yourSubcollectionName")
                    noteRef.getDocuments { (subQuerySnapshot, subError) in
                        if let subError = subError {
                            print("Error getting subdocuments: \(subError)")
                        } else {
                            // Now you have access to each subcollection
                            // Use subQuerySnapshot to extract data
                        }
                    }
                }
            }
        }
    }


    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.row < friendRequests.count {
            let acceptAction = UIContextualAction(style: .normal, title: "Accept") { [weak self] (action, view, completionHandler) in
                self?.acceptFriendRequest(at: indexPath.row)
                completionHandler(true)
            }
            acceptAction.backgroundColor = .green
            return UISwipeActionsConfiguration(actions: [acceptAction])
        } else {
            // No action for accepted friends in leading swipe
            return nil
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Remove") { [weak self] (action, view, completionHandler) in
            if indexPath.row < self?.friendRequests.count ?? 0 {
                self?.rejectFriendRequest(at: indexPath.row)
            } else {
                self?.removeAcceptedFriend(at: indexPath.row - (self?.friendRequests.count ?? 0))
            }
            completionHandler(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    // New function to handle the removal of an accepted friend
    private func removeAcceptedFriend(at index: Int) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("Current user email not found.")
            return
        }
        
        let friendEmail = acceptedFriends[index]
        let db = Firestore.firestore()
        let currentUserRef = db.collection("users").document(currentUserEmail)

        // Update the current user's friends array to remove the friend
        currentUserRef.updateData([
            "friends": FieldValue.arrayRemove([friendEmail])
        ]) { [weak self] error in
            if let error = error {
                print("Error removing friend: \(error)")
            } else {
                print("Friend removed successfully.")
                self?.acceptedFriends.remove(at: index)
                self?.friendRequestsTableView.reloadData()
            }
        }
    }

    // Logic to accept a friend request.
    private func acceptFriendRequest(at index: Int) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("Current user email not found.")
            return
        }

        let friendEmail = friendRequests[index]
        let db = Firestore.firestore()
        let currentUserRef = db.collection("users").document(currentUserEmail)

        // Start a batch to perform multiple write operations as one transaction
        let batch = db.batch()

        // Add the current user's updates to the batch
        batch.updateData([
            "friendRequests": FieldValue.arrayRemove([friendEmail]),
            "friends": FieldValue.arrayUnion([friendEmail])
        ], forDocument: currentUserRef)

        // Find the friend's user document
        let friendRef = db.collection("users").whereField("email", isEqualTo: friendEmail)
        friendRef.getDocuments { [weak self] (querySnapshot, error) in
            if let error = error {
                print("Error finding user: \(error)")
            } else if let friendDocument = querySnapshot?.documents.first {
                // Add the friend's updates to the batch
                batch.updateData([
                    "friends": FieldValue.arrayUnion([currentUserEmail])
                ], forDocument: friendDocument.reference)

                // Commit the batch inside the completion block of getDocuments
                batch.commit { error in
                    if let error = error {
                        print("Error accepting friend request: \(error)")
                    } else {
                        print("Friend request accepted.")
                        // Move the updates for local arrays and table view here
                        self?.updateLocalFriendListsAndTableView(for: friendEmail, at: index)
                    }
                }
            } else {
                print("User with email \(friendEmail) does not exist")
            }
        }
    }

    private func updateLocalFriendListsAndTableView(for friendEmail: String, at index: Int) {
        self.acceptedFriends.append(friendEmail)
        self.friendRequests.remove(at: index)
        // Perform table view updates on the main thread
        DispatchQueue.main.async {
            self.friendRequestsTableView.performBatchUpdates({
                let indexPathForDeletion = IndexPath(row: index, section: 0)
                let indexPathForInsertion = IndexPath(row: self.acceptedFriends.count - 1, section: 0)

                self.friendRequestsTableView.deleteRows(at: [indexPathForDeletion], with: .automatic)
                self.friendRequestsTableView.insertRows(at: [indexPathForInsertion], with: .automatic)
            }, completion: nil)
        }
    }

      private func animateCellBounce(_ cell: UITableViewCell) {
          let animationDuration = 0.5
          let animationDelay = 0.0
          let animationSpringDamping: CGFloat = 0.6
          let animationInitialSpringVelocity: CGFloat = 0.1

          // Start with the cell frame 30 points above its final resting place
          cell.transform = CGAffineTransform(translationX: 0, y: -30)
          cell.alpha = 0

          // Animate with a bounce effect
          UIView.animate(
              withDuration: animationDuration,
              delay: animationDelay,
              usingSpringWithDamping: animationSpringDamping,
              initialSpringVelocity: animationInitialSpringVelocity,
              options: [],
              animations: {
                  // End at a transform identity to be in the final position
                  cell.transform = CGAffineTransform.identity
                  cell.alpha = 1
              },
              completion: nil
          )
      }
    
    // Logic to reject a friend request.
    private func rejectFriendRequest(at index: Int) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("Current user email not found.")
            return
        }
        
        let friendEmail = friendRequests[index]
        let db = Firestore.firestore()
        let currentUserRef = db.collection("users").document(currentUserEmail)
        
        // Remove the friend's email from the current user's friendRequests array
        currentUserRef.updateData([
            "friendRequests": FieldValue.arrayRemove([friendEmail])
        ]) { [weak self] error in
            if let error = error {
                print("Error rejecting friend request: \(error)")
            } else {
                print("Friend request rejected.")
                self?.friendRequests.remove(at: index)
                self?.friendRequestsTableView.reloadData()
            }
        }
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
