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
import FirebaseStorage




class AppState {
    static let shared = AppState()
    
    var rotationSpeed: Double = 0.5
    var wasPlaying: Bool = false
    
    private init() {}
}



class SettingsViewController: UIViewController, MFMailComposeViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

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
    
    private var onboardingView: UIView?
    private var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "HasSeenSettingsOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "HasSeenSettingsOnboarding") }
    }
    @objc private func dismissOnboarding() {
        UIView.animate(withDuration: 0.3, animations: {
            self.onboardingView?.alpha = 0
        }) { _ in
            self.onboardingView?.removeFromSuperview()
            self.onboardingView = nil
            self.hasSeenOnboarding = true
        }
    }
    
    private func setupOnboardingView() {
        guard !hasSeenOnboarding else { return }
        
        onboardingView = UIView(frame: view.bounds)
        onboardingView?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        
        let contentView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.layer.cornerRadius = 20
        contentView.clipsToBounds = true
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "square.and.arrow.up")
        imageView.tintColor = .white
        
        let label = UILabel()
        label.text = "Share with a friend to unlock custom avatars!"
        label.textAlignment = .center
        label.font = UIFont(name: "Avenir-Medium", size: 20)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let gotItButton = UIButton(type: .system)
        gotItButton.setTitle("Got it!", for: .normal)
        gotItButton.setTitleColor(.white, for: .normal)
        gotItButton.titleLabel?.font = UIFont(name: "Avenir-Heavy", size: 22)
        gotItButton.addTarget(self, action: #selector(dismissOnboarding), for: .touchUpInside)
        gotItButton.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.contentView.addSubview(imageView)
        contentView.contentView.addSubview(label)
        contentView.contentView.addSubview(gotItButton)
        onboardingView?.addSubview(contentView)
        
        view.addSubview(onboardingView!)
        
        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: onboardingView!.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: onboardingView!.centerYAnchor),
            contentView.widthAnchor.constraint(equalTo: onboardingView!.widthAnchor, multiplier: 0.8),
            contentView.heightAnchor.constraint(equalTo: onboardingView!.heightAnchor, multiplier: 0.4),
            
            imageView.topAnchor.constraint(equalTo: contentView.contentView.topAnchor, constant: 30),
            imageView.centerXAnchor.constraint(equalTo: contentView.contentView.centerXAnchor),
            imageView.widthAnchor.constraint(equalTo: contentView.contentView.widthAnchor, multiplier: 0.3),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: contentView.contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.contentView.trailingAnchor, constant: -20),
            
            gotItButton.centerXAnchor.constraint(equalTo: contentView.contentView.centerXAnchor),
            gotItButton.bottomAnchor.constraint(equalTo: contentView.contentView.bottomAnchor, constant: -20),
            gotItButton.topAnchor.constraint(greaterThanOrEqualTo: label.bottomAnchor, constant: 20)
        ])
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
        
        setupAudioSession()
        let audioSession = AVAudioSession.sharedInstance()
        print("Audio session category: \(audioSession.category)")
        print("Audio session mode: \(audioSession.mode)")
        print("Audio session options: \(audioSession.categoryOptions)")
        setupOnboardingView()

        
        catImage.image = UIImage()
        if let userEmailString = Auth.auth().currentUser?.email {
            userEmail.text = userEmailString
            loadUserAvatar(for: userEmailString)
        } else {
            userEmail.text = "Not logged in"
        }
        
        setupShareButton()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(labelTapped))
            betaTap.addGestureRecognizer(tapGesture)
            betaTap.isUserInteractionEnabled = true

            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(labelLongPressed))
            longPressGesture.minimumPressDuration = 0.5 // Adjust this value to change how long the user needs to press
            betaTap.addGestureRecognizer(longPressGesture)
        
        if let path = Bundle.main.path(forResource: "eastersong", ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                print("Audio player initialized.")
            } catch {
                print("Could not initialize audio player: \(error.localizedDescription)")
            }
        } else {
            print("Could not find audio file.")
        }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        catImage.isUserInteractionEnabled = true
        catImage.addGestureRecognizer(tapGestureRecognizer)
        
        let labelTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(labelTapped))
        betaTap.isUserInteractionEnabled = true
        betaTap.addGestureRecognizer(labelTapGestureRecognizer)
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(labelLongPressed))
        longPressGestureRecognizer.minimumPressDuration = 1.0
        betaTap.addGestureRecognizer(longPressGestureRecognizer)
        
        setupFeedbackButton()
        setupAnimalButton()
        checkInvitedFriends()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.catImage.image == UIImage() {
                self?.catImage.image = UIImage(named: "jellydev")
                self?.animateCatImageAppearance()
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
        
        if let audioPlayer = audioPlayer {
            audioPlayer.volume = 1.0
            audioPlayer.play()
            print("Audio player started playing. Duration: \(audioPlayer.duration), Is playing: \(audioPlayer.isPlaying)")
        } else {
            print("Audio player is not initialized.")
        }
    }

    
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            print("Audio session category set successfully.")
        } catch {
            print("Failed to set audio session category. Error: \(error)")
        }
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
    
    func animateCatImageAppearance() {
        catImage.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
            self.catImage.transform = CGAffineTransform.identity
        }, completion: nil)
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
            feedbackButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
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
    
    

    func loadUserAvatar(for email: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(email)
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                print("Error fetching document: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                if let avatarURL = document.data()?["avatarURL"] as? String {
                    if avatarURL == "default_cat_image" { // Use the same identifier for the default image
                        self?.catImage.image = UIImage(named: "jellydev") // Use the correct default cat image name
                        self?.animateCatImageAppearance()
                    } else if let url = URL(string: avatarURL) {
                        self?.loadImage(from: url)
                    }
                } else {
                    // No avatar URL found, use default cat image
                    self?.catImage.image = UIImage(named: "jellydev") // Use the correct default cat image name
                    self?.animateCatImageAppearance()
                }
            } else {
                // Document does not exist, use default cat image
                self?.catImage.image = UIImage(named: "jellydev") // Use the correct default cat image name
                self?.animateCatImageAppearance()
            }
        }
    }

    func loadImage(from url: URL) {
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.catImage.image = image
                    self.animateCatImageAppearance() // Animate the appearance of the loaded image
                }
            } else {
                print("Error loading image from URL.")
            }
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
    
    // MARK: - Animal Button Setup
    
    var animalButton: UIButton!

    
    func setupAnimalButton() {
        animalButton = UIButton(type: .system)
        if let animalImage = UIImage(systemName: "pawprint") {
            animalButton.setImage(animalImage, for: .normal)
        }
        animalButton.tintColor = .white
        animalButton.addTarget(self, action: #selector(animalButtonTapped), for: .touchUpInside)
        animalButton.isHidden = true  // Hidden by default

        view.addSubview(animalButton)
        animalButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animalButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animalButton.topAnchor.constraint(equalTo: view.centerYAnchor, constant: view.bounds.height / 4 + 50), // Positioning below the share button
            animalButton.widthAnchor.constraint(equalToConstant: 80),
            animalButton.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func inviteFriend(_ friendEmail: String) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("No current user email found.")
            return
        }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserEmail)
        
        userRef.updateData([
            "invited": FieldValue.arrayUnion([friendEmail])
        ]) { [weak self] error in
            if let error = error {
                print("Error updating document: \(error)")
            } else {
                print("Successfully invited friend: \(friendEmail)")
                self?.openEmailClient(to: friendEmail, from: currentUserEmail)
                self?.checkInvitedFriends()  // Check if the user has invited any friends
            }
        }
    }
    
    func checkInvitedFriends() {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("No current user email found.")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserEmail)
        
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                print("Error fetching document: \(error)")
                return
            }
            
            if let document = document, document.exists {
                if let invited = document.data()?["invited"] as? [String], !invited.isEmpty {
                    print("User has invited friends: \(invited)")
                    self?.animalButton.isHidden = false
                } else {
                    print("User has not invited any friends.")
                    self?.animalButton.isHidden = true
                }
            } else {
                print("Document for user \(currentUserEmail) does not exist")
            }
        }
    }



        
    @objc func animalButtonTapped() {
        let alert = UIAlertController(title: "Change Image", message: "Choose an option", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Use Miss Jelly", style: .default, handler: { [weak self] _ in
            self?.setDefaultCatImage()
        }))
        
        alert.addAction(UIAlertAction(title: "Upload Image", style: .default, handler: { [weak self] _ in
            self?.presentImagePicker()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alert, animated: true, completion: nil)
    }

    func setDefaultCatImage() {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("No current user email found.")
            return
        }
        
        let defaultCatImageURL = "default_cat_image" // Use an identifier for the default image
        
        // Update Firestore with the default cat image identifier
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserEmail)
        userRef.updateData(["avatarURL": defaultCatImageURL]) { [weak self] error in
            if let error = error {
                print("Error updating Firestore: \(error.localizedDescription)")
            } else {
                print("Firestore updated with default cat image identifier.")
                self?.catImage.image = UIImage(named: "jellydev") // Use the correct default cat image name
                self?.animateCatImageAppearance()
            }
        }
    }



    
    func presentImagePicker() {
           let imagePickerController = UIImagePickerController()
           imagePickerController.delegate = self
           imagePickerController.sourceType = .photoLibrary
           present(imagePickerController, animated: true, completion: nil)
       }
       
       func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
           picker.dismiss(animated: true, completion: nil)
           
           if let selectedImage = info[.originalImage] as? UIImage {
               catImage.image = selectedImage
               uploadImageToFirebase(selectedImage)
           }
       }
       
       func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
           picker.dismiss(animated: true, completion: nil)
       }
       
    func uploadImageToFirebase(_ image: UIImage) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("No current user email found.")
            return
        }
        
        let storageRef = Storage.storage().reference().child("useravatars/\(currentUserEmail).jpg")
        
        if let uploadData = image.jpegData(compressionQuality: 0.8) {
            storageRef.putData(uploadData, metadata: nil) { (metadata, error) in
                if let error = error {
                    print("Error uploading image: \(error.localizedDescription)")
                    return
                }
                
                storageRef.downloadURL { (url, error) in
                    if let error = error {
                        print("Error getting download URL: \(error.localizedDescription)")
                        return
                    }
                    
                    if let url = url {
                        print("Image uploaded successfully. URL: \(url)")
                        // Update Firestore with new avatar URL
                        let db = Firestore.firestore()
                        let userRef = db.collection("users").document(currentUserEmail)
                        userRef.updateData(["avatarURL": url.absoluteString]) { error in
                            if let error = error {
                                print("Error updating Firestore: \(error.localizedDescription)")
                            } else {
                                print("Firestore updated with new avatar URL.")
                                self.loadImage(from: url) // Set and animate the new image
                            }
                        }
                    }
                }
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
    
    // MARK: - Share Button Setup
        
        func setupShareButton() {
            let shareButton = UIButton(type: .system)
            if let shareImage = UIImage(systemName: "square.and.arrow.up") {
                shareButton.setImage(shareImage, for: .normal)
            }
            shareButton.tintColor = .white
            shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
            
            view.addSubview(shareButton)
            shareButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                shareButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                shareButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: view.bounds.height / 4), // Positioning towards the bottom half
                shareButton.widthAnchor.constraint(equalToConstant: 50),
                shareButton.heightAnchor.constraint(equalToConstant: 50)
            ])
        }
        
    @objc func shareButtonTapped() {
           let alert = UIAlertController(title: "Invite a Friend", message: "Enter a friend's email to invite them.", preferredStyle: .alert)
           alert.addTextField { textField in
               textField.placeholder = "Friend's email"
               textField.keyboardType = .emailAddress
           }
           let sendAction = UIAlertAction(title: "Send", style: .default) { [weak self, weak alert] _ in
               guard let textField = alert?.textFields?.first, let friendEmail = textField.text, !friendEmail.isEmpty else {
                   return
               }
               self?.inviteFriend(friendEmail)
           }
           let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
           alert.addAction(sendAction)
           alert.addAction(cancelAction)
           present(alert, animated: true, completion: nil)
       }
    
    private func openEmailClient(to friendEmail: String, from currentUserEmail: String) {
            let subject = "Join me on Namey!"
            let body = "Hi there!\n\nI've been using Namey and thought you might like it too."  + "It's a great way to stay connected and remember important moments. https://apps.apple.com/us/app/namie/id6449910626"
            
            let urlString = "mailto:\(friendEmail)?subject=\(subject)&body=\(body)"
            
            if let emailUrl = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
                if UIApplication.shared.canOpenURL(emailUrl) {
                    UIApplication.shared.open(emailUrl, options: [:], completionHandler: nil)
                } else {
                    showAlert(withTitle: "Cannot Open Mail", message: "Your device couldn't open the mail client. Please send the invite manually to \(friendEmail).")
                }
            }
        }
        
    
    
    
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

    private var lastTapTime: TimeInterval = 0
    private var tapCount: Int = 0

    @objc private func labelTapped() {
        let currentTime = CACurrentMediaTime()
        let timeSinceLastTap = currentTime - lastTapTime
        
        // Reset tap count if it's been more than 0.5 seconds since last tap
        if timeSinceLastTap > 0.5 {
            tapCount = 0
        }
        
        tapCount += 1
        lastTapTime = currentTime
        
        // Cancel any ongoing animations
        self.betaTap.layer.removeAllAnimations()
        self.catImage.layer.removeAllAnimations()
        
        // Calculate jump height and duration based on tap count
        let jumpHeight = min(-3.0 * CGFloat(tapCount), -20.0) // Cap at -20 points
        let duration = max(0.05, 0.1 - 0.005 * Double(tapCount)) // Minimum duration of 0.05 seconds
        
        // Animate label jump
        UIView.animate(withDuration: duration, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            self.betaTap.transform = CGAffineTransform(translationX: 0, y: jumpHeight)
        }) { _ in
            UIView.animate(withDuration: duration, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                self.betaTap.transform = .identity
            })
        }
        
        // Animate cat image shrink
        if catImage.transform.d != 0 {
            let shrinkFactor = max(0.8, 0.95 - 0.01 * CGFloat(tapCount)) // Minimum shrink to 80%
            UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                self.catImage.transform = self.catImage.transform.scaledBy(x: shrinkFactor, y: shrinkFactor)
            })
        }
    }

    @objc private func labelLongPressed(gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            // Shrink the label
            UIView.animate(withDuration: 0.3, animations: {
                self.betaTap.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            })
            
            // Enlarge the cat image
            UIView.animate(withDuration: 3, animations: {
                self.catImage.transform = self.catImage.transform.scaledBy(x: 2, y: 2) // increase the size by 100%
            })
        case .ended, .cancelled:
            // Rebound the label
            UIView.animate(withDuration: 0.2, animations: {
                self.betaTap.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    self.betaTap.transform = .identity
                }
            }
            
          
        default:
            break
        }
    }
    
    
    
}
