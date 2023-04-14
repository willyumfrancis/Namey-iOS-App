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

// UpdateDisplayedNotes is the filtered notes function that works based on geolocation
//




    class HomeViewController: UIViewController, CLLocationManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
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
        
        
        
        var notes: [Note] = []
        var authStateListenerHandle: AuthStateDidChangeListenerHandle?
        var sliderValueLabel: UILabel!
        var displayedNotes: [Note] = []
        var activeNoteCell: NoteCell?
        
        var currentLocationName: String?
        var fetchedLocationKeys: Set<String> = []
        var notesFetched = false
        private var notesLoaded = false




        
        


    

    
    


    @IBAction func uploadImageButton(_ sender: UIButton) {
        print("Upload Image button pressed")

                   presentImagePicker()
    }
    //Goal (Star) Button
    @IBAction func goalButton(_ sender: UIButton) {
        goalButtonTapped()

    }
    
    //Location Button
    @IBAction func LocationButton(_ sender: UIButton) {
        print("Location Button Pressed")
           updateCurrentLocationAndFetchNotes()

    }
    
    //Save Name Button
    @IBAction func SaveName(_ sender: UIButton) {
            // Save a new note
            if let location = locationManager.location?.coordinate {
                guard let activeCell = activeNoteCell else {
                    print("Failed to get active cell")
                    return
                }
                let locationName = fetchLocationNameFor(location: location) ?? ""
                let newNote = Note(id: UUID().uuidString, text: activeCell.noteTextField.text ?? "", location: location, locationName: locationName)
                saveNote(note: newNote)
                print("Saved note to local array")
            } else {
                print("Failed to get user's current location")
            }
        }


        
    //Create New Name
    @IBAction func NewName(_ sender: UIButton) {
        if let currentLocation = self.currentLocation {
               let newNote = Note(id: UUID().uuidString, text: "", location: currentLocation, locationName: "")
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
    
    
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.setNavigationBarHidden(true, animated: false)
    
        }

    
    // VIEWDIDLOAD BRO
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)


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
        
        if !notesFetched {
              notesFetched = true
              loadNotes()
          }
        
 
        let goalButton = UIBarButtonItem(title: "Set Goal", style: .plain, target: self, action: #selector(goalButtonTapped))
        navigationItem.rightBarButtonItem = goalButton
    }
        
        func updateLocationNameLabel(location: CLLocationCoordinate2D) {
            let locationName = fetchLocationNameFor(location: location) ?? "Some Spot"
            locationNameLabel.text = "\(locationName)"
            print("Location name is \(locationName)")

        }

        //Update Notes Count Label
        func updateNotesCountLabel() {
            let currentPeople = notes.count
            if let userLocation = locationManager.location?.coordinate {
                let locationName = fetchLocationNameFor(location: userLocation) ?? "Some Spot"
                let labelText = "You know \(currentPeople) people at \(locationName)"
                notesCountLabel.text = labelText
            } else {
                print("User location not available yet")
            }
        }



    func updateProgressBar() {
        updateNotesCountLabel()
        let currentPeople = notes.count
        let progress = min(Float(currentPeople) / Float(maxPeople), 1.0)
        
        Progressbar.setProgress(progress, animated: true)
        
        if progress == 1.0 {
            Progressbar.progressTintColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)

        } else {
            Progressbar.progressTintColor = #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 1)

        }
    }

    //MARK: - POP-UPS
    
    @objc func goalButtonTapped() {
        let alertController = UIAlertController(title: "Set Goal", message: "\n\n\n\n\n", preferredStyle: .alert)
        
        sliderValueLabel = UILabel(frame: CGRect(x: 10, y: 80, width: 250, height: 20))
        sliderValueLabel.textAlignment = .center
        
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
        present(alertController, animated: true)
    }



    @objc func sliderValueChanged(_ sender: UISlider) {
        let value = Int(sender.value)
        sliderValueLabel.text = "\(value)"
    }




    


//MARK: - LOCATION
        
        @objc func appWillEnterForeground() {
                    updateCurrentLocationAndFetchNotes()
        }

        
        //SAFEFILENAME
        func safeFileName(for locationName: String) -> String {
            return locationName.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "'", with: "")
        }

        
        //SAVEIMAGE
        func saveImageToFirestore(image: UIImage, location: CLLocationCoordinate2D, locationName: String) {
            uploadImage(image: image, location: location, locationName: locationName) { result in
                switch result {
                case .success(let imageURL):
                    print("Image successfully uploaded, URL: \(imageURL)")

                    // Update location name for notes
                    self.updateNotesLocationName(location: location, newLocationName: locationName) { updatedNotes in
                        self.notes.removeAll() // Clear the notes array
                        self.notes = updatedNotes
                        self.locationNameLabel.text = locationName
                        self.tableView.reloadData() // Reload the tableView to reflect the changes
                    }

                case .failure(let error):
                    print("Error uploading image: \(error)")
                }
            }
        }


        
        //Updates the locationName of the notes that are within a certain distance.
        func updateNotesLocationName(location: CLLocationCoordinate2D, newLocationName: String, completion: @escaping ([Note]) -> Void) {
            let maxDistance: CLLocationDistance = 500 // Adjust this value according to your requirements
            let locationGeoPoint = GeoPoint(latitude: location.latitude, longitude: location.longitude)
            
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
                                            let noteText = data["note"] as? String ?? ""
                                            let updatedNote = Note(id: noteId, text: noteText, location: CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude), locationName: newLocationName)
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

    //Fetch Image for Current Location
          func userDidEnterLocation(_ location: CLLocationCoordinate2D) {
              displayImageForLocation(location: location)
          }
    

        // Display Image
        func displayImageForLocation(location: CLLocationCoordinate2D) {
            let maxDistance: CLLocationDistance = 300
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
                                            let locationKey: String
                                            if let locationName = data["locationName"] as? String, !locationName.isEmpty {
                                                locationKey = locationName
                                            } else {
                                                locationKey = "\(locationData.latitude),\(locationData.longitude)"
                                            }

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
                        print("Successfully loaded image from URL: \(imageURL)")
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

           //Image Picker Delegate - Selection and Saving
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
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

                    // Save the image and location data to Firestore with the locationName
                    self.saveImageToFirestore(image: image, location: userLocation, locationName: locationName)

                }
                alertController.addAction(saveAction)

                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                alertController.addAction(cancelAction)

                picker.dismiss(animated: true) {
                    self.present(alertController, animated: true)
                }
            }
        }


           //Image Picker iOS
           func presentImagePicker() {
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
               let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

               alertController.addAction(cameraAction)
               alertController.addAction(libraryAction)
               alertController.addAction(cancelAction)

               present(alertController, animated: true, completion: nil)
           }

    
    //Update Location via Button Function
        func updateCurrentLocationAndFetchNotes() {
            locationManager.startUpdatingLocation()
            if let userLocation = locationManager.location?.coordinate {
                // Load notes based on the updated location
                loadNotes()

                // Update displayed notes based on the updated location
                updateDisplayedNotes()

                // Update the image based on the updated location
                displayImageForLocation(location: userLocation)
            } else {
                print("User location not available yet")
            }
        }
    
    
    //Location Manager
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
        // Location Manager Delegate
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let location = locations.last {
                currentLocation = location.coordinate
                print("User's location: \(location)")
                locationManager.stopUpdatingLocation()
                loadNotes()
                displayImageForLocation(location: currentLocation!)
                updateLocationNameLabel(location: currentLocation!)
            }
        }



    
    private func setupRoundedImageView() {
        // Apply corner radius
        CurrentPlace?.layer.cornerRadius = 12
        CurrentPlace?.clipsToBounds = true
        
        // Apply border
        CurrentPlace?.layer.borderWidth = 1
        CurrentPlace?.layer.borderColor = UIColor.black.cgColor
        
        // Apply background color
        CurrentPlace?.backgroundColor = UIColor(red: 0.50, green: 0.23, blue: 0.27, alpha: 0.50)
    }
    
    private func setupRoundedProgressBar() {
        // Apply corner radius
        Progressbar?.layer.cornerRadius = 8
        Progressbar?.clipsToBounds = true
        
        // Customize the progress tint and track color
        let progressTintColor = UIColor(red: 0.50, green: 0.23, blue: 0.27, alpha: 0.50)
        Progressbar?.progressTintColor = progressTintColor
        Progressbar?.trackTintColor = progressTintColor.withAlphaComponent(0.2)
        
        // Set the progress bar height
        let height: CGFloat = 16
        if let progressBarHeight = Progressbar?.frame.height {
            let transform = CGAffineTransform(scaleX: 1.0, y: height / progressBarHeight)
            Progressbar?.transform = transform
        }
        
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
        
        //Filter Function
        func filterNotesByLocation(notes: [Note], currentLocation: CLLocationCoordinate2D, threshold: Double) -> [Note] {
            let userCurrentLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            
            return notes.filter { note in
                let noteLocation = CLLocation(latitude: note.location.latitude, longitude: note.location.longitude)
                let distance = noteLocation.distance(from: userCurrentLocation)
                return distance <= threshold
            }
        }

    
        // Update Notes Based on Location
        func updateDisplayedNotes() {
            guard let userLocation = locationManager.location?.coordinate else {
                print("User location not available yet")
                return
            }

            displayedNotes = filterNotesByLocation(notes: notes, currentLocation: userLocation, threshold: 300)
            print("Showing \(displayedNotes.count) notes based on location")

            UIView.performWithoutAnimation {
                tableView.reloadData()
            }
            updateProgressBar()

            if let closestNote = displayedNotes.min(by: { (note1, note2) -> Bool in
                let note1Location = CLLocation(latitude: note1.location.latitude, longitude: note1.location.longitude)
                let note2Location = CLLocation(latitude: note2.location.latitude, longitude: note2.location.longitude)
                let userCurrentLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                let distance1 = note1Location.distance(from: userCurrentLocation)
                let distance2 = note2Location.distance(from: userCurrentLocation)
                return distance1 < distance2
            }) {
                displayImageForLocation(location: closestNote.location)
            }
        }



    
    //LOAD NOTES FIRESTORE
        private func loadNotes() {
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
                                        let newNote = Note(id: doc.documentID, text: noteText, location: location, locationName: locationName)
                                        self.notes.append(newNote)
                                    }
                                }
                                DispatchQueue.main.async {
                                    self.updateDisplayedNotes() // Call updateDisplayedNotes here
                                    self.updateProgressBar()
                                    self.updateLocationNameLabel(location: userLocation) // Update the location name label
                                    self.updateNotesCountLabel() // Update the notes count label

                                }
                            }
                        }
                    }
                
                // Add this line to update the image based on user's location
                displayImageForLocation(location: userLocation)
                notesLoaded = true

            } else {
                print("User email not found or user location not available yet")
            }
        }

    
        func saveNoteToCloud(note: Note) {
            if let userEmail = Auth.auth().currentUser?.email {
                let noteDictionary: [String: Any] = [
                    "note": note.text,
                    "location": GeoPoint(latitude: note.location.latitude, longitude: note.location.longitude),
                    "locationName": note.locationName,
                    "user": userEmail,
                    "timestamp": FieldValue.serverTimestamp()
                ]
                
                db.collection("notes").addDocument(data: noteDictionary) { error in
                    if let e = error {
                        print("There was an issue saving data to Firestore: \(e)")
                    } else {
                        print("Note successfully saved to Firestore")
                        DispatchQueue.main.async {
                            print("Loaded view after saving note")
                        }
                    }
                }
            } else {
                print("User email not found")
            }
        }
        
        func fetchLocationNameFor(location: CLLocationCoordinate2D) -> String? {
            let radius: CLLocationDistance = 500 // The radius in meters to consider notes as nearby
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



    
    
        private func saveNote(note: Note) {
            displayedNotes.append(note) // Add the new note to the displayedNotes array
            let indexPath = IndexPath(row: notes.count - 1, section: 0)
            tableView.insertRows(at: [indexPath], with: .automatic)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            updateProgressBar()
            saveNoteToCloud(note: note) // Save the new note to the cloud
            print("Called saveNoteToCloud")
        }

    
    
    
}



//MARK: - EXTENSIONS

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
        cell.noteTextField.text = note.text
        cell.noteLocation = note.location // Update the cell's noteLocation property
        cell.delegate = self
        
        // Apply the drop-down animation
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
    func noteCell(_ cell: NoteCell, didUpdateNote note: Note) {
        if let indexPath = tableView.indexPath(for: cell) {
            notes[indexPath.row] = note
            saveNoteToCloud(note: note)
            print("Auto-Saved to Cloud")
        }
    }

    func noteCellDidEndEditing(_ cell: NoteCell) {
        if let indexPath = tableView.indexPath(for: cell), indexPath.row < notes.count {
            let note = notes[indexPath.row]
            if cell.noteTextField.text != note.text {
                let updatedNote = Note(id: note.id, text: cell.noteTextField.text!, location: note.location, locationName: note.locationName) // Include the imageURL parameter
                notes[indexPath.row] = updatedNote
                if cell.saveButtonPressed { // Add this condition
                    saveNoteToCloud(note: updatedNote)
                    print("Auto-Saved to Cloud")
                }
            }

        }
        cell.saveButtonPressed = false // Reset the flag
    }
}


