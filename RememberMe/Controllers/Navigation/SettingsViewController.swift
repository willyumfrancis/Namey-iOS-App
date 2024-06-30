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
import MessageUI



class AppState {
    static let shared = AppState()
    
    var rotationSpeed: Double = 0.5
    var wasPlaying: Bool = false
    
    private init() {}
}

class SettingsViewController: UIViewController, MFMailComposeViewControllerDelegate {
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
        
    }
    

    
    
    override func viewDidLoad() {
           super.viewDidLoad()
           
           if let userEmailString = Auth.auth().currentUser?.email {
               userEmail.text = userEmailString
           } else {
               userEmail.text = "Not logged in"
           }
           
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
        setupFeedbackButton()
       }
       
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
    
    func setupFeedbackButton() {
        let feedbackButton = UIButton(type: .system)
        feedbackButton.setTitle("Send Feedback!", for: .normal)
        feedbackButton.setTitleColor(.white, for: .normal)
        feedbackButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        feedbackButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        feedbackButton.addTarget(self, action: #selector(feedbackButtonTapped), for: .touchUpInside)
        
        view.addSubview(feedbackButton)
        feedbackButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            feedbackButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            feedbackButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            feedbackButton.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8) // Button width is at most 80% of the view width
        ])
    }
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    let feedbackEmail = "wmisiasz@gmail.com"
    @objc func feedbackButtonTapped() {
        if MFMailComposeViewController.canSendMail() {
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            
            mailComposer.setToRecipients([feedbackEmail])
            mailComposer.setSubject("Namie Feedback 🌝")
            
            present(mailComposer, animated: true, completion: nil)
        } else {
            openDefaultMailClient()
        }
    }

    func openDefaultMailClient() {
        let subject = "Namie Feedback 🌝"
        let body = "Enter your feedback here"
        
        let urlString = "mailto:\(feedbackEmail)?subject=\(subject)&body=\(body)"
        
        if let emailUrl = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            if UIApplication.shared.canOpenURL(emailUrl) {
                UIApplication.shared.open(emailUrl, options: [:], completionHandler: nil)
            } else {
                showAlert(withTitle: "Cannot Open Mail", message: "Your device couldn't open the mail client. You can send feedback to \(feedbackEmail)")
            }
        }
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
  
    
//MARK: - END IBACTIONS
    
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
