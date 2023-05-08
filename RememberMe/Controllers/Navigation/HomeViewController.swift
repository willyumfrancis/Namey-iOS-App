//
//  ViewController.swift
//  RememberMe
//
//  Created by William Misiaszek on 3/13/23.
//

//MARK: - DO NOT EDIT

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

// loadNotes is the filtered notes function that works based on geolocation
//




class HomeViewController: UIViewController, CLLocationManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDragDelegate, UITableViewDropDelegate {
    
    
    //MARK: - OUTLETS
    @IBOutlet weak var tableView: UITableView!
    //Current Place & Goal of People
    @IBOutlet weak var CurrentPlace: UIImageView!
    @IBOutlet weak var Progressbar: UIProgressView!
    @IBOutlet weak var SaveButtonLook: UIButton!
    @IBOutlet weak var NewNameLook: UIButton!
    @IBOutlet weak var LocationButtonOutlet: UIButton!
    
    @IBOutlet weak var locationNameLabel: UILabel!
    @IBOutlet weak var notesCountLabel: UILabel!
    
    //FireBase Cloud Storage
    let db = Firestore.firestore()
    
    
    //MARK: - VARIABLES & CONSTANTS
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocationCoordinate2D?
    var selectedNote: Note?
    
    let progressBar = UIProgressView(progressViewStyle: .default)
    
    var maxPeople = 3
    var locationUpdateTimer: Timer?

    
    var notesLoaded = false
    
    
    var notes: [Note] = []
    var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    var sliderValueLabel: UILabel!
    var displayedNotes: [Note] = []
    var activeNoteCell: NoteCell?
    
    var currentLocationName: String?
    var fetchedLocationKeys: Set<String> = []
    var notesFetched = false
    
    
    
    @IBAction func uploadImageButton(_ sender: UIButton)
    {
        print("Upload Image button pressed")

        let alertController = UIAlertController(title: "Spot Name", message: "Please enter a name for this place:", preferredStyle: .alert)
        alertController.addTextField()

        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            guard let locationName = alertController.textFields?.first?.text, !locationName.isEmpty else {
                print("Location name is empty.")
                return
            }

            self.currentLocationName = locationName
            self.updateNotesCountLabel()

            self.presentImagePicker(locationName: locationName)
        }
        alertController.addAction(saveAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true)
    }

    //Goal (Star) Button
    @IBAction func goalButton(_ sender: UIButton) {
        goalButtonTapped()
        
    }
    
    //Location Button
    @IBAction func LocationButton(_ sender: UIButton) {
        print("Location Button Pressed")

        // Manually trigger location updates
        locationManager.startUpdatingLocation()

        // Update displayed notes based on the updated location
        loadNotes()
        animateTableViewCells()

        // You need to get the user's current location here and pass it to the function as a CLLocationCoordinate2D instance
        if let userLocation = locationManager.location {
            displayImageForLocation(location: userLocation.coordinate)
            // Call the updateLocationNameLabel function with the user's current location
            updateLocationNameLabel(location: userLocation.coordinate)
        } else {
            print("Unable to get user's current location")
        }
    }

    
    
    //Save Name Button
    @IBAction func SaveNote(_ sender: UIButton) {
        saveNote()
    }
    
    
    
    
    //Create New Name
    @IBAction func NewNote(_ sender: UIButton) {
        if let currentLocation = self.currentLocation {
            let emptyURL = URL(string: "")
            let newNote = Note(id: UUID().uuidString, text: "", location: currentLocation, locationName: "", imageURL: emptyURL)
            displayedNotes.append(newNote)
            selectedNote = newNote
            
            DispatchQueue.main.async {
                self.tableView.beginUpdates()
                self.tableView.insertRows(at: [IndexPath(row: self.displayedNotes.count - 1, section: 0)], with: .automatic)
                self.tableView.endUpdates()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    if let newRowIndexPath = self.tableView.indexPathForLastRow,
                       let newCell = self.tableView.cellForRow(at: newRowIndexPath) as? NoteCell {
                        newCell.noteTextField.becomeFirstResponder()
                    }
                }
            }
        }
    }
    
    
    
    //MARK: - APPEARANCE
    private func setupRoundedProgressBar() {
        // Apply corner radius
        Progressbar?.layer.cornerRadius = 12
        Progressbar?.clipsToBounds = true
        
        // Customize the progress tint and track color
        let progressTintColor = #colorLiteral(red: 1, green: 0.9098039216, blue: 0.831372549, alpha: 1)
        Progressbar?.progressTintColor = progressTintColor
        Progressbar?.trackTintColor = progressTintColor.withAlphaComponent(0.2)
        
        // Set the progress bar height
        let height: CGFloat = 22
        if let progressBarHeight = Progressbar?.frame.height {
            let transform = CGAffineTransform(scaleX: 1.0, y: height / progressBarHeight)
            Progressbar?.transform = transform
        }
        
        
        // Add drop shadow
        Progressbar?.layer.shadowColor = UIColor.black.cgColor
        Progressbar?.layer.shadowOffset = CGSize(width: 0, height: 2)
        Progressbar?.layer.shadowRadius = 4
        Progressbar?.layer.shadowOpacity = 0.3
        
        // Add a black border to the progress bar (border width reduced by 50%)
        Progressbar?.layer.borderColor = UIColor.black.cgColor
        Progressbar?.layer.borderWidth = 0.3
        
        // Add a black border to the progress bar's layer (border width reduced by 50%)
        let progressBarBorderLayer = CALayer()
        let progressBarWidth = (Progressbar?.bounds.width ?? 0) * 1.3 // Increase width by 30%
        progressBarBorderLayer.frame = CGRect(x: 0, y: 0, width: progressBarWidth, height: height)
        progressBarBorderLayer.borderColor = UIColor.black.cgColor
        progressBarBorderLayer.borderWidth = 0.3
        progressBarBorderLayer.cornerRadius = 7
        progressBarBorderLayer.masksToBounds = true
        
        Progressbar?.layer.addSublayer(progressBarBorderLayer)
        
        // Increase the width of the progress bar's frame by 30%
        if let progressBarSuperview = Progressbar?.superview {
            let progressBarFrame = Progressbar?.frame ?? .zero
            let increasedWidth = progressBarFrame.width * 2
            Progressbar?.frame = CGRect(x: progressBarFrame.origin.x, y: progressBarFrame.origin.y, width: increasedWidth, height: progressBarFrame.height)
        }
    }
    
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        
    }
    
    
    // VIEWDIDLOAD BRO
    override func viewDidLoad() {
        super.viewDidLoad()
        updateNotesWithImageURL()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateLocationWhenAppIsActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        
        locationManager.delegate = self
        
        tableView.dragDelegate = self
        tableView.dropDelegate = self
        tableView.dragInteractionEnabled = true
        
        
        //Apparance of App//
        
        NewNameLook.layer.cornerRadius = 12
        NewNameLook.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        NewNameLook.layer.borderWidth = 3
        NewNameLook.layer.borderColor = UIColor.black.cgColor
        
        SaveButtonLook.layer.cornerRadius = 12
        SaveButtonLook.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        SaveButtonLook.layer.borderWidth = 3
        SaveButtonLook.layer.borderColor = UIColor.black.cgColor
        
        print("viewDidLoad called") // Add print statement
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "NoteCell", bundle: nil), forCellReuseIdentifier: "NoteCell")
        
        setupLocationManager()
        setupRoundedImageView()
        setupRoundedProgressBar()
        
        
        let goalButton = UIBarButtonItem(title: "Set Goal", style: .plain, target: self, action: #selector(goalButtonTapped))
        navigationItem.rightBarButtonItem = goalButton
    }
    //ENDVIEWDIDLOAD
    
    
    
    func createAttributedString(from noteText: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: noteText)
        
        if let range = noteText.range(of: " - ") {
            let boldRange = NSRange(noteText.startIndex..<range.lowerBound, in: noteText)
            attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 19), range: boldRange)
        }
        
        return attributedString
    }
    
    
    func updateLocationNameLabel(location: CLLocationCoordinate2D) {
        let locationName = fetchLocationNameFor(location: location) ?? "Some Spot"
        locationNameLabel.text = "\(locationName)"
        print("Location name is \(locationName)")
        
    }
    
    
    
    //Update Name Goal
    func updateNotesCountLabel() {
        let currentPeople = displayedNotes.count
        if let userLocation = locationManager.location?.coordinate {
            let locationName = fetchLocationNameFor(location: userLocation) ?? "Some Spot"
            if currentPeople == 0 {
                notesCountLabel.text = "Go meet some people!"
            } else if currentPeople == 1 {
                let labelText = "You know 1 person at \(locationName)"
                notesCountLabel.text = labelText
            } else {
                let labelText = "You know \(currentPeople) people at \(locationName)."
                notesCountLabel.text = labelText
            }
        } else {
            print("User location not available yet")
        }
    }
    
    
    
    
    func updateProgressBar() {
        updateNotesCountLabel()
        let currentPeople = displayedNotes.count
        let progress = min(Float(currentPeople) / Float(maxPeople), 1.0)
        
        Progressbar.setProgress(progress, animated: true)
        
        if progress == 1.0 {
            Progressbar.progressTintColor = #colorLiteral(red: 1, green: 0.9098039216, blue: 0.831372549, alpha: 1)
            
        } else {
            Progressbar.progressTintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
        }
    }
    
    //MARK: - POP-UPS
    
    func animateTableViewCells() {
        let cells = tableView.visibleCells
        let tableViewHeight = tableView.bounds.size.height
        
        for cell in cells {
            cell.transform = CGAffineTransform(translationX: 0, y: tableViewHeight)
        }
        
        var delayCounter = 0
        for cell in cells {
            UIView.animate(withDuration: 0.5,
                           delay: 0.05 * Double(delayCounter),
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 0,
                           options: .curveEaseInOut,
                           animations: {
                cell.transform = CGAffineTransform.identity
            },
                           completion: nil)
            delayCounter += 1
        }
    }
    
    
    
    
    @objc func updateLocationWhenAppIsActive() {
        locationManager.startUpdatingLocation()
        
        if let userLocation = locationManager.location {
            let locationName = fetchLocationNameFor(location: userLocation.coordinate)
            if let locationName = locationName {
                // Use the location name
                print("Location name: \(locationName)")
            } else {
                // Use the placeholder text
                print("Some Spot")
            }
        } else {
            print("Unable to get user's current location")
        }
    }
    
    
    @objc func goalButtonTapped() {
        let alertController = UIAlertController(title: "Set Goal", message: "\n\n\n\n\n", preferredStyle: .alert)
        
        sliderValueLabel = UILabel(frame: CGRect(x: 10, y: 100, width: 250, height: 20)) // Increase y value to create space
        sliderValueLabel.textAlignment = .center
        sliderValueLabel.font = UIFont.systemFont(ofSize: 24) // Change font size here
        
        let slider = UISlider(frame: CGRect(x: 10, y: 60, width: 250, height: 20))
        slider.minimumValue = 1
        slider.maximumValue = 7
        slider.value = Float(maxPeople)
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        
        sliderValueLabel.text = "\(Int(slider.value))"
        
        alertController.view.addSubview(slider)
        alertController.view.addSubview(sliderValueLabel)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let doneAction = UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            self?.maxPeople = Int(slider.value)
            self?.updateProgressBar()
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(doneAction)
        
        // Change the size of the alert box
        let height: NSLayoutConstraint = NSLayoutConstraint(item: alertController.view!, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 200)
        alertController.view.addConstraint(height)
        
        present(alertController, animated: true)
    }
    
    
    
    
    @objc func sliderValueChanged(_ sender: UISlider) {
        let value = Int(sender.value)
        sliderValueLabel.text = "\(value)"
    }
    
    
    
    
    
    
    
    //MARK: - LOCATION
    
    func updateImageURLForNote(_ documentID: String) {
        // Get the noteRef for the given document ID
        let noteRef = db.collection("notes").document(documentID)
        
        // Fetch the note data
        noteRef.getDocument { (document, error) in
            if let document = document, document.exists {
                if let data = document.data(),
                   let locationName = data["locationName"] as? String {
                    // Use the logic for downloading the image to get the imageURL
                    let safeFileName = self.safeFileName(for: locationName)
                    let storageRef = Storage.storage().reference().child("location_images/\(safeFileName).jpg")
                    
                    storageRef.downloadURL { (url, error) in
                        if let error = error {
                            print("Error getting download URL: \(error)")
                            return
                        }
                        
                        guard let url = url else { return }
                        
                        // Update the imageURL for the note with the given document ID
                        noteRef.updateData([
                            "imageURL": url.absoluteString
                        ]) { err in
                            if let err = err {
                                print("Error updating imageURL for document ID \(documentID): \(err)")
                            } else {
                                print("ImageURL successfully updated for document ID \(documentID)")
                            }
                        }
                    }
                } else {
                    print("Error: Could not retrieve locationName or data is nil")
                }
            } else {
                print("Error: Document does not exist or there was an error retrieving it")
            }
        }
    }

    
    func updateNotesWithImageURL() {
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
                            
                            guard let locationData = data["location"] as? GeoPoint else {
                                print("Missing location data for document ID: \(doc.documentID)")
                                continue
                            }
                            
                            let noteLocation = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
                            
                            if let currentLocation = self.locationManager.location { // Get user's location
                                if self.isWithinUpdateRadius(location: noteLocation, userCurrentLocation: currentLocation) {
                                    self.updateImageURLForNote(doc.documentID)
                                }
                            }
                        }
                    } else {
                        print("No snapshot documents found")
                    }
                }
            }
    }

    func isWithinUpdateRadius(location: CLLocationCoordinate2D, userCurrentLocation: CLLocation) -> Bool {
        let updateRadius: CLLocationDistance = 100
        let noteLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let distance = noteLocation.distance(from: userCurrentLocation)
        return distance <= updateRadius
    }

  

    
    
    
    //SAFEFILENAME
    func safeFileName(for locationName: String) -> String {
        return locationName.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "'", with: "")
    }
    
    
    func updateImageURLForAllNotes(with imageURL: URL) {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }

        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .getDocuments { [weak self] querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            self?.updateImageURLForNote(doc.documentID, newImageURL: imageURL)
                        }
                    } else {
                        print("No snapshot documents found")
                    }
                }
            }
    }

    func updateImageURLForNote(_ documentID: String, newImageURL: URL) {
        // Update the imageURL for the note with the given document ID
        let noteRef = db.collection("notes").document(documentID)

        noteRef.updateData([
            "imageURL": newImageURL.absoluteString
        ]) { err in
            if let err = err {
                print("Error updating imageURL for document ID \(documentID): \(err)")
            } else {
                print("ImageURL successfully updated for document ID \(documentID)")
            }
        }
    }

    
    //SAVEIMAGE
    func saveImageToFirestore(image: UIImage, location: CLLocationCoordinate2D, locationName: String) {
        let safeFileName = self.safeFileName(for: locationName)
        let storageRef = Storage.storage().reference().child("location_images/\(safeFileName).jpg")
        
        // Delete the old image from Firebase Storage
        storageRef.delete { [weak self] error in
            if let error = error {
                print("Error deleting the old image: \(error)")
            } else {
                print("Old image deleted successfully")
            }
            
            // Upload the new image and get the download URL
            self?.uploadImage(image: image, location: location, locationName: locationName) { result in
                switch result {
                case .success(let imageURL):
                    print("Image uploaded and saved with URL: \(imageURL)")
                    
                    // Update the imageURL for all notes
                    self?.updateImageURLForAllNotes(with: imageURL)

                    // Save the new note using the saveNote function
                    guard let activeCell = self?.activeNoteCell else {
                        print("Failed to get active cell")
                        return
                    }
                    activeCell.noteTextField.text = ""
                    self?.selectedNote = nil
                    self?.saveNote()

                    // Update the locationName label on the main thread
                    DispatchQueue.main.async {
                        self?.locationNameLabel.text = locationName
                    }

                case .failure(let error):
                    print("Error uploading image: \(error)")
                }
            }
        }
    }

    
    
    //MARK: - IMPORTANT UPDATE L NAME FUNCTION
    //Updates the locationName of the notes that are within a certain distance.
    func updateNotesLocationName(location: CLLocationCoordinate2D, newLocationName: String, completion: @escaping ([Note]) -> Void) {
        let maxDistance: CLLocationDistance = 30 // Adjust this value according to your requirements
        _ = GeoPoint(latitude: location.latitude, longitude: location.longitude)
        
        if let userEmail = Auth.auth().currentUser?.email {
            db.collection("notes")
                .whereField("user", isEqualTo: userEmail)
                .getDocuments { querySnapshot, error in
                    if let e = error {
                        print("There was an issue retrieving data from Firestore: \(e)")
                        completion([])
                    } else {
                        if let snapshotDocuments = querySnapshot?.documents {
                            var updatedNotes: [Note] = []
                            for doc in snapshotDocuments {
                                let data = doc.data()
                                if let locationData = data["location"] as? GeoPoint {
                                    let noteLocation = CLLocation(latitude: locationData.latitude, longitude: locationData.longitude)
                                    let userCurrentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                                    let distance = noteLocation.distance(from: userCurrentLocation)
                                    
                                    if distance <= maxDistance {
                                        let noteId = doc.documentID
                                        let emptyURL = URL(string: "")
                                        let noteText = data["note"] as? String ?? ""
                                        let updatedNote = Note(id: noteId, text: noteText, location: CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude), locationName: newLocationName, imageURL: emptyURL)
                                        updatedNotes.append(updatedNote)
                                        
                                        // Update Firestore document with the new location name
                                        self.db.collection("notes").document(noteId).updateData([
                                            "locationName": newLocationName
                                        ]) { err in
                                            if let err = err {
                                                print("Error updating document: \(err)")
                                            } else {
                                                print("Document successfully updated")
                                            }
                                        }
                                    }
                                }
                            }
                            completion(updatedNotes)
                        }
                    }
                }
        } else {
            print("User email not found")
            completion([])
        }
    }
    
    
    // Display Image
    func displayImageForLocation(location: CLLocationCoordinate2D) {
        let maxDistance: CLLocationDistance = 30
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
                                if let locationData = data["location"] as? GeoPoint {
                                    let noteLocation = CLLocation(latitude: locationData.latitude, longitude: locationData.longitude)
                                    let distance = noteLocation.distance(from: userCurrentLocation)
                                    
                                    if distance <= maxDistance {
                                        if let locationName = data["locationName"] as? String, !locationName.isEmpty {
                                            self.locationNameLabel.text = "\(locationName)"
                                            self.downloadAndDisplayImage(locationName: locationName)

                                        } else {
                                            let locationKey = "\(locationData.latitude),\(locationData.longitude)"
                                            if !self.fetchedLocationKeys.contains(locationKey) {
                                                self.fetchedLocationKeys.insert(locationKey)
                                                self.downloadAndDisplayImage(locationName: locationKey)
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

    
    
    func downloadAndDisplayImage(locationName: String) {
        let safeFileName = safeFileName(for: locationName)
        let storageRef = Storage.storage().reference().child("location_images/\(safeFileName).jpg")
        
        storageRef.downloadURL { (url, error) in
            if let error = error {
                print("Error getting download URL: \(error)")
                return
            }
            
            guard let url = url else { return }
            
            self.CurrentPlace.sd_setImage(with: url, placeholderImage: UIImage(named: "placeholder")) { (image, error, cacheType, imageURL) in
                if let error = error {
                    print("Error loading image from URL: \(error)")
                } else {
                    print("Successfully loaded image from URL: \(String(describing: imageURL))")
                }
            }
        }
    }
    
    
    //Upload Image to Fire Storage (Google Cloud) -> 5GB Max for Free Tier
    func uploadImage(image: UIImage, location: CLLocationCoordinate2D, locationName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "ImageConversionError", code: -1, userInfo: nil)))
            return
        }
        print("Image data for upload: \(imageData)")
        
        
        let safeFileName = safeFileName(for: locationName)
        let storageRef = Storage.storage().reference().child("location_images").child("\(safeFileName).jpg")
        
        let temporaryDirectory = NSTemporaryDirectory()
        let localFilePath = temporaryDirectory.appending(safeFileName)
        let localFileURL = URL(fileURLWithPath: localFilePath)
        
        do {
            try imageData.write(to: localFileURL)
        } catch {
            completion(.failure(error))
            return
        }
        
        storageRef.putFile(from: localFileURL, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let url = url else {
                    completion(.failure(NSError(domain: "DownloadURLError", code: -1, userInfo: nil)))
                    return
                }
                
                completion(.success(url))
            }
        }
    }
    
    // Image Picker Delegate - Selection and Saving
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            print("Image captured from camera: \(image)")
            CurrentPlace.image = image
            picker.dismiss(animated: true)

            if let locationName = currentLocationName {
                guard let userLocation = self.locationManager.location?.coordinate else {
                    print("User location not available yet")
                    return
                }

                self.saveImageToFirestore(image: image, location: userLocation, locationName: locationName)
                DispatchQueue.main.async {
                              self.locationNameLabel.text = locationName
                          }

                          // Update notes with the new locationName
                          self.updateNotesLocationName(location: userLocation, newLocationName: locationName) { updatedNotes in
                              // Perform any required operations with the updated notes here
                          }

            } else {
                // Show an alert to get the location name from the user
                let alertController = UIAlertController(title: "Spot Name", message: "Please enter a name for this place:", preferredStyle: .alert)
                alertController.addTextField()

                let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
                    guard let locationName = alertController.textFields?.first?.text, !locationName.isEmpty else {
                        print("Location name is empty.")
                        return
                    }

                    self.currentLocationName = locationName
                    self.updateNotesCountLabel()

                    guard let userLocation = self.locationManager.location?.coordinate else {
                        print("User location not available yet")
                        return
                    }

                    if let image = self.CurrentPlace.image {
                        self.saveImageToFirestore(image: image, location: userLocation, locationName: locationName)
                    } else {
                        self.updateNotesLocationName(location: userLocation, newLocationName: locationName) { updatedNotes in
                            // Perform any required operations with the updated notes here
                        }
                    }
                }
                alertController.addAction(saveAction)

                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                alertController.addAction(cancelAction)

                picker.dismiss(animated: true) {
                    self.present(alertController, animated: true)
                }
            }
        } else {
            print("No image selected.")
        }
    }


    
    // Image Picker iOS
    func presentImagePicker(locationName: String) {
        // Store the location name for later use
        currentLocationName = locationName
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.mediaTypes = [kUTTypeImage as String]
        imagePickerController.allowsEditing = false

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let cameraAction = UIAlertAction(title: "Take Photo", style: .default) { _ in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                imagePickerController.sourceType = .camera
                self.present(imagePickerController, animated: true, completion: nil)
            }
        }
        let libraryAction = UIAlertAction(title: "Choose from Library", style: .default) { _ in
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                imagePickerController.sourceType = .photoLibrary
                self.present(imagePickerController, animated: true, completion: nil)
            }
        }
        
        // Add "Skip" action
        let skipAction = UIAlertAction(title: "Skip", style: .default) { _ in
            guard let userLocation = self.locationManager.location?.coordinate else {
                print("User location not available yet")
                return
            }

            self.updateNotesLocationName(location: userLocation, newLocationName: locationName) { updatedNotes in
                // Perform any required operations with the updated notes here
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alertController.addAction(cameraAction)
        alertController.addAction(libraryAction)
        alertController.addAction(skipAction) // Add the "Skip" action to the alertController
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    
    
    
    
    //Location Manager
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // Start the timer to update the location every 10 minutes (600 seconds)
            locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
                self.locationManager.startUpdatingLocation()
            }
    }
    // Location Manager Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }

        self.currentLocation = newLocation.coordinate
        print("User's location: \(newLocation)")

        // Call the updateLocationNameLabel function with the user's current location
        updateLocationNameLabel(location: newLocation.coordinate)

        loadNotes()
        self.displayImageForLocation(location: self.currentLocation!)

        // Stop updating location after receiving the location update
        locationManager.stopUpdatingLocation()
    }




    
    
    //END LOCATION STUFF
    
    private func setupRoundedImageView() {
        // Apply corner radius
        CurrentPlace?.layer.cornerRadius = 12
        CurrentPlace?.clipsToBounds = true
        
        // Apply border
        CurrentPlace?.layer.borderWidth = 2
        CurrentPlace?.layer.borderColor = UIColor.black.cgColor
        
        // Apply background color
        CurrentPlace?.backgroundColor = UIColor(red: 0.50, green: 0.23, blue: 0.27, alpha: 0.50)
    }
    
    //Resize and Crop Local Image
    func resizeAndCrop(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        let ratio = max(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let resized = resizedImage else { return image }
        
        let cropRect = CGRect(x: (resized.size.width - targetSize.width) / 2,
                              y: (resized.size.height - targetSize.height) / 2,
                              width: targetSize.width, height: targetSize.height)
        
        guard let cgImage = resized.cgImage?.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cgImage)
    }
    
    
    //Phone Doc Function for Image Picker
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    
    //MARK: - NOTES
    
    // textFieldShouldReturn method
    func noteCellTextFieldShouldReturn(_ textField: UITextField) {
        saveNote() // Perform the same action as the "Save Note" button
    }
    
    // New function to save the note
    func saveNote() {
        if let location = locationManager.location?.coordinate {
            guard let activeCell = activeNoteCell else {
                print("Failed to get active cell")
                return
            }
            let locationName = fetchLocationNameFor(location: location) ?? ""
            let emptyURL = URL(string: "")
            let newNote = Note(id: UUID().uuidString, text: activeCell.noteTextField.text ?? "", location: location, locationName: locationName, imageURL: emptyURL)
            
            // Save the new note using the saveNoteToFirestore function
            saveNoteToFirestore(noteText: newNote.text, location: newNote.location, locationName: newNote.locationName, imageURL: "") { success in
                if success {
                    print("Note saved successfully")
                    
                    if let selectedNote = self.selectedNote,
                       let selectedNoteIndex = self.displayedNotes.firstIndex(where: { $0.id == selectedNote.id }) {
                        self.displayedNotes[selectedNoteIndex] = newNote
                        self.selectedNote = newNote
                        
                        let indexPath = IndexPath(row: selectedNoteIndex, section: 0)
                        self.tableView.reloadRows(at: [indexPath], with: .automatic)
                        
                        self.updateProgressBar()
                        print("Loaded view after saving note")
                    } else {
                        print("Error updating note")
                    }
                } else {
                    print("Error saving note")
                }
            }
        } else {
            print("Failed to get user's current location")
        }
    }
    
    func updateNoteInFirestore(noteID: String, noteText: String, location: CLLocationCoordinate2D, locationName: String, imageURL: String, completion: @escaping (Bool) -> Void) {
        let noteRef = db.collection("notes").document(noteID)
        
        let noteData: [String: Any] = [
            "text": noteText,
            "location": GeoPoint(latitude: location.latitude, longitude: location.longitude),
            "locationName": locationName,
            "imageURL": imageURL,
            "timestamp": Timestamp(date: Date())
        ]
        
        noteRef.updateData(noteData) { error in
            if let error = error {
                print("There was an issue updating the note in Firestore: \(error)")
                completion(false)
            } else {
                print("Note successfully updated in Firestore")
                completion(true)
            }
        }
    }
    
    
    func saveNoteToFirestore(noteText: String, location: CLLocationCoordinate2D, locationName: String, imageURL: String, completion: @escaping (Bool) -> Void) {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            completion(false)
            return
        }
        
        let noteData: [String: Any] = [
            "user": userEmail,
            "note": noteText,
            "location": GeoPoint(latitude: location.latitude, longitude: location.longitude),
            "locationName": locationName,
            "imageURL": imageURL,
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("notes").addDocument(data: noteData) { error in
            if let error = error {
                print("Error saving note to Firestore: \(error)")
                completion(false)
            } else {
                print("Note successfully saved to Firestore")
                completion(true)
            }
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    //Filter Function
    func filterNotesByLocation(notes: [Note], currentLocation: CLLocationCoordinate2D, threshold: Double) -> [Note] {
        let userCurrentLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        
        return notes.filter { note in
            let noteLocation = CLLocation(latitude: note.location.latitude, longitude: note.location.longitude)
            let distance = noteLocation.distance(from: userCurrentLocation)
            return distance <= threshold
        }
    }
    
    
    
    
    //LOAD NOTES FIRESTORE
    func loadNotes() {
        print("loadNotes called")
        
        guard !notesLoaded else { return }
        if let userEmail = Auth.auth().currentUser?.email,
           let userLocation = locationManager.location?.coordinate { // Get user's location
            print("Loading notes for user: \(userEmail)")
            
            db.collection("notes")
                .whereField("user", isEqualTo: userEmail)
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { querySnapshot, error in
                    if let e = error {
                        print("There was an issue retrieving data from Firestore: \(e)")
                    } else {
                        self.notes = [] // Clear the existing notes array
                        if let snapshotDocuments = querySnapshot?.documents {
                            print("Found \(snapshotDocuments.count) notes")
                            for doc in snapshotDocuments {
                                let data = doc.data()
                                if let noteText = data["note"] as? String,
                                   let locationData = data["location"] as? GeoPoint,
                                   let locationName = data["locationName"] as? String {
                                    let location = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
                                    let emptyURL = URL(string: "")
                                    let newNote = Note(id: doc.documentID, text: noteText, location: location, locationName: locationName, imageURL: emptyURL)
                                    self.notes.append(newNote)
                                }
                            }
                            DispatchQueue.main.async {
                                // Perform the filtering and updating of displayed notes here
                                self.displayedNotes = self.filterNotesByLocation(notes: self.notes, currentLocation: userLocation, threshold: 30)
                                print("Showing \(self.displayedNotes.count) notes based on location")
                                self.tableView.reloadData()
                                
                                self.updateProgressBar()
                                self.updateLocationNameLabel(location: userLocation) // Update the location name label
                                self.updateNotesWithImageURL() // Call updateNotesWithImageURL after populating notes array

                            }
                        }
                    }
                }
            
            notesLoaded = true // Set notesLoaded to true after the notes have been loaded
            
        } else {
            print("User email not found or user location not available yet")
        }
    }
    
    
    
    
    
    func fetchLocationNameFor(location: CLLocationCoordinate2D) -> String? {
        let radius: CLLocationDistance = 30 // The radius in meters to consider notes as nearby
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        for note in self.notes {
            let noteLocation = CLLocation(latitude: note.location.latitude, longitude: note.location.longitude)
            if currentLocation.distance(from: noteLocation) <= radius {
                if !note.locationName.isEmpty {
                    return note.locationName
                }
            }
        }
        return nil
    }
    
    
}

//MARK: - EXTENSIONS

extension HomeViewController {
    
    // UITableViewDragDelegate
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let draggedNote = displayedNotes[indexPath.row]
        let itemProvider = NSItemProvider(object: draggedNote.text as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = draggedNote
        return [dragItem]
    }
    
    // UITableViewDropDelegate
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        let destinationIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath {
            destinationIndexPath = indexPath
        } else {
            let row = tableView.numberOfRows(inSection: 0)
            destinationIndexPath = IndexPath(row: row, section: 0)
        }
        
        coordinator.session.loadObjects(ofClass: NSString.self) { items in
            guard let noteText = items.first as? String else { return }
            if let sourceIndexPath = coordinator.items.first?.sourceIndexPath {
                tableView.performBatchUpdates({
                    let draggedNote = self.displayedNotes.remove(at: sourceIndexPath.row)
                    self.displayedNotes.insert(draggedNote, at: destinationIndexPath.row)
                    tableView.deleteRows(at: [sourceIndexPath], with: .automatic)
                    tableView.insertRows(at: [destinationIndexPath], with: .automatic)
                }, completion: nil)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        if tableView.hasActiveDrag {
            return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UITableViewDropProposal(operation: .forbidden)
    }
}

extension UITableView {
    var indexPathForLastRow: IndexPath? {
        let lastSectionIndex = max(numberOfSections - 1, 0)
        let lastRowIndex = max(numberOfRows(inSection: lastSectionIndex) - 1, 0)
        return IndexPath(row: lastRowIndex, section: lastSectionIndex)
    }
}

extension HomeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedNotes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as! NoteCell
        let note = displayedNotes[indexPath.row]
        
        cell.noteTextField.attributedText = createAttributedString(from: note.text)
        cell.noteTextField.delegate = cell
        cell.noteTextField.isEnabled = true
        cell.noteLocation = note.location
        cell.delegate = self
        
        cell.transform = CGAffineTransform(translationX: 0, y: tableView.bounds.size.height)
        UIView.animate(withDuration: 0.5,
                       delay: 0.05 * Double(indexPath.row),
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0,
                       options: .curveEaseInOut,
                       animations: {
            cell.transform = CGAffineTransform.identity
        },
                       completion: nil)
        
        return cell
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let cell = textField.superview?.superview as? NoteCell {
            activeNoteCell = cell
            saveNote()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let noteToDelete = displayedNotes[indexPath.row]
            if let indexInNotes = notes.firstIndex(where: { $0.id == noteToDelete.id }) {
                notes.remove(at: indexInNotes)
            }
            displayedNotes.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            let noteID = noteToDelete.id
            db.collection("notes").document(noteID).delete { error in
                if let e = error {
                    print("There was an issue deleting the note: \(e)")
                } else {
                    print("Note deleted successfully.")
                }
            }
        }
    }
}

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedNote = notes[indexPath.row]
    }
}

extension HomeViewController: NoteCellDelegate {
    func noteCellTextFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let cell = textField.superview?.superview as? NoteCell {
            activeNoteCell = cell
            SaveNote(UIButton())
        }
        return true
    }
    
    
    
    func noteCell(_ cell: NoteCell, didUpdateNote note: Note) {
        if let indexPath = tableView.indexPath(for: cell) {
            notes[indexPath.row] = note
            db.collection("notes").document(note.id).updateData([
                "note": note.text,
                "location": GeoPoint(latitude: note.location.latitude, longitude: note.location.longitude),
                "locationName": note.locationName
            ]) { error in
                if let e = error {
                    print("There was an issue updating the note in Firestore: \(e)")
                } else {
                    print("Note successfully updated in Firestore")
                }
            }
        }
    }
    
    func noteCellDidEndEditing(_ cell: NoteCell) {
        if let indexPath = tableView.indexPath(for: cell), indexPath.row < notes.count {
            let note = notes[indexPath.row]
            if cell.noteTextField.text != note.text {
                let emptyURL = URL(string: "")
                let updatedNote = Note(id: note.id, text: cell.noteTextField.text!, location: note.location, locationName: note.locationName, imageURL: emptyURL)
                notes[indexPath.row] = updatedNote
                if cell.saveButtonPressed {
                    print("Auto-Saved to Cloud")
                }
            }
        }
        cell.saveButtonPressed = false
    }
}
