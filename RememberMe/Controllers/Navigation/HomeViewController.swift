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






    class HomeViewController: UIViewController, CLLocationManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        //MARK: - OUTLETS
        @IBOutlet weak var tableView: UITableView!
        //Current Place & Goal of People
        @IBOutlet weak var CurrentPlace: UIImageView!
        @IBOutlet weak var Progressbar: UIProgressView!
        @IBOutlet weak var SaveButtonLook: UIButton!
        @IBOutlet weak var NewNameLook: UIButton!
        @IBOutlet weak var LocationButtonOutlet: UIButton!
        
        
        //FireBase Cloud Storage
        let db = Firestore.firestore()
        
        //Core Location instance & variable
        private let locationManager = CLLocationManager()
        var currentLocation: CLLocationCoordinate2D?
        var selectedNote: Note?
        
        

        
        
        @IBAction func uploadImageButton(_ sender: UIButton) {
            print("Upload Image button pressed")

            presentImagePicker()
        }
        //Location Button
        @IBAction func LocationButton(_ sender: UIButton) {
            print("Location Button Pressed")
            updateCurrentLocationAndFetchNotes()

        }
        
        //Save Name Button
        @IBAction func SaveName(_ sender: UIButton) {
        
        if let selectedNote = selectedNote {
                   if let indexPath = notes.firstIndex(where: { $0.id == selectedNote.id }) {
                       if let cell = tableView.cellForRow(at: IndexPath(row: indexPath, section: 0)) as? NoteCell {
                           let updatedNote = Note(id: selectedNote.id, text: cell.noteTextField.text!, location: selectedNote.location, imageURL: selectedNote.imageURL)
                           notes[indexPath] = updatedNote
                           saveNoteToCloud(note: updatedNote)
                           print("Manually Saved to Cloud")
                           cell.noteTextField.resignFirstResponder()
                       }
                   }
               }
           }

        //Create New Name
        @IBAction func NewName(_ sender: UIButton) {
            if let currentLocation = self.currentLocation {
                let newNote = Note(id: UUID().uuidString, text: "", location: currentLocation, imageURL: "")
                    saveNote(note: newNote)
                    selectedNote = newNote // Add this line to update the selectedNote variable
                }
            }
        
        
        
        var notes: [Note] = []
        var authStateListenerHandle: AuthStateDidChangeListenerHandle?
        
        
        
        //MARK: - Appearance Code
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.setNavigationBarHidden(true, animated: false)

            updateCurrentLocationAndFetchNotes()

            authStateListenerHandle = Auth.auth().addStateDidChangeListener { auth, user in
                if user != nil {
                    print("User is signed in: \(user?.email ?? "Unknown email")")
                } else {
                    print("User is not signed in")
                    // Handle the case where the user is not signed in
                }
            }
        }

        
        // VIEWDIDLOAD BRO
        override func viewDidLoad() {
            super.viewDidLoad()

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
            
            locationManager.delegate = self
                   locationManager.desiredAccuracy = kCLLocationAccuracyBest
                   locationManager.requestWhenInUseAuthorization()
            
            NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        }

        @objc func applicationDidBecomeActive() {
            if let location = locationManager.location?.coordinate {
                loadNotes(at: location)
            }

        }
        
        //MARK: - FUNCTIONS
        
        //Is Location Nearby?
        func isLocationNearby(_ location1: CLLocationCoordinate2D, _ location2: CLLocationCoordinate2D, thresholdInMeters: Double = 100) -> Bool {
            let distanceInMeters = CLLocation(latitude: location1.latitude, longitude: location1.longitude)
                .distance(from: CLLocation(latitude: location2.latitude, longitude: location2.longitude))
            return distanceInMeters <= thresholdInMeters
        }

        
        //Fetch Note for Location
        func fetchNoteForLocation(_ location: CLLocationCoordinate2D) -> Note? {
            return notes.first { note in
                let noteLocation = CLLocation(latitude: note.location.latitude, longitude: note.location.longitude)
                let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                return noteLocation.distance(from: currentLocation) <= 50 // Replace 50 with the desired radius in meters
            }
        }

        
        //Fetch Image for Current Location
        func userDidEnterLocation(_ location: CLLocationCoordinate2D) {
            displayImageForLocation(location: location)
        }

        
        //Display Image
        func displayImageForLocation(location: CLLocationCoordinate2D) {
            let locationIdentifier = "\(location.latitude),\(location.longitude)"
            let storageRef = Storage.storage().reference().child("location_images/\(locationIdentifier).jpg")
            
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


        
        //Selects User Image and Stores in Model for Location.
        func userDidSelectImage(_ image: UIImage, forLocation location: CLLocationCoordinate2D) {
            uploadImage(image: image, location: location) { result in
                switch result {
                case .success(let url):
                    print("Image successfully uploaded to URL: \(url)")
                case .failure(let error):
                    print("Error uploading image: \(error)")
                }
            }
        }


        
        //Upload Image to Fire Storage (Google Cloud) -> 5GB Max for Free Tier
        func uploadImage(image: UIImage, location: CLLocationCoordinate2D, completion: @escaping (Result<URL, Error>) -> Void) {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                completion(.failure(NSError(domain: "ImageConversionError", code: -1, userInfo: nil)))
                return
            }
            
            let imageName = "\(location.latitude),\(location.longitude).jpg"
            let storageRef = Storage.storage().reference().child("location_images").child(imageName)
            
            let temporaryDirectory = NSTemporaryDirectory()
            let localFilePath = temporaryDirectory.appending(imageName)
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
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let pickedImage = info[.originalImage] as? UIImage {
                let resizedImage = resizeAndCrop(image: pickedImage, targetSize: CurrentPlace.frame.size)
                CurrentPlace.image = resizedImage

                if let currentLocation = currentLocation {
                    userDidSelectImage(resizedImage, forLocation: currentLocation)

                    print("Successfully created new note with image at current location")

                    let imageName = UUID().uuidString
                    let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)

                    if let imageData = resizedImage.jpegData(compressionQuality: 0.8) {
                        do {
                            try imageData.write(to: imagePath)
                            print("Successfully saved image locally with path: \(imagePath)")
                        } catch {
                            print("Error saving image locally: \(error)")
                        }
                    }

                    let newNote = Note(id: UUID().uuidString, text: "", location: currentLocation, imageURL: "")
                    saveNote(note: newNote)
                }
            }

            dismiss(animated: true, completion: nil)
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

        
        
        //Progress Bar Code
        func updateProgressBar() {
            let maxPeople = 3
            let currentPeople = notes.count
            let progress = Float(currentPeople) / Float(maxPeople)

            Progressbar.progress = progress

            if progress >= 1.0 {
                Progressbar.progressTintColor = #colorLiteral(red: 0, green: 0.9314488769, blue: 0, alpha: 1)
            } else {
                Progressbar.progressTintColor = UIColor.systemBlue
            }
        }

       
        
        
        //Update Notes Based on Location
        func updateDisplayedNotes() {
            // Check if the user's location is available
            if let userLocation = locationManager.location?.coordinate {
                // Filter the notes based on the user's proximity to the note's location
                let filteredNotes = notes.filter { note in
                    let noteLocation = CLLocation(latitude: note.location.latitude, longitude: note.location.longitude)
                    let userCurrentLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    let distance = noteLocation.distance(from: userCurrentLocation)
                    return distance <= 300 // Replace 'proximityThreshold' with the desired distance in meters
                }
                notes = filteredNotes
                
                // Reload the table view without animation
                UIView.performWithoutAnimation {
                    tableView.reloadData()
                }
                updateProgressBar()
                
            }
        }

        


        
        //Update Location via Button Function
        func updateCurrentLocationAndFetchNotes() {
            locationManager.requestLocation()
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
                let coordinate = location.coordinate
                loadNotes(at: coordinate)
                updateDisplayedNotes()
                tableView.reloadData()
                locationManager.stopUpdatingLocation() // Stop updating location after receiving the first update
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
        
        //MARK: - Notes Code
        
        
        //Load FireStore Notes
        func loadNotes(at location: CLLocationCoordinate2D) {
            guard let userEmail = Auth.auth().currentUser?.email else { return }
            let notesRef = db.collection("notes")
            
            notesRef.whereField("userEmail", isEqualTo: userEmail).getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error loading notes: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.notes = documents.compactMap { (document) -> Note? in
                    let data = document.data()
                    
                    guard
                        let id = document.documentID,
                        let text = data["text"] as? String,
                        let imageURL = data["imageURL"] as? String,
                        let latitude = data["latitude"] as? Double,
                        let longitude = data["longitude"] as? Double
                    else { return nil }
                    
                    let noteLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    
                    if isLocationNearby(location, noteLocation) {
                        return Note(id: id, text: text, location: noteLocation, imageURL: imageURL)
                    } else {
                        return nil
                    }
                }
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }


        
    //Save Note to Cloud
        private func saveNoteToCloud(note: Note) {
            if let userEmail = Auth.auth().currentUser?.email {
                if !note.text.isEmpty {
                    let noteDocument = db.collection("notes").document(note.id)
                    noteDocument.setData([
                        "user": userEmail,
                        "note": note.text,
                        "location": GeoPoint(latitude: note.location.latitude, longitude: note.location.longitude),
                        "timestamp": Timestamp()
                    ]) { error in
                        if let e = error {
                            print("Error saving note: \(e)")
                        } else {
                            print("Note saved successfully.")
                        }
                    }
                }
            }
        }
        // Save Note
        private func saveNote(note: Note) {
            notes.append(note) // Add the new note to the existing notes array
            let indexPath = IndexPath(row: notes.count - 1, section: 0)
            tableView.insertRows(at: [indexPath], with: .automatic)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            saveNoteToCloud(note: note) // Save the new note to the cloud
            updateProgressBar() // Update the progress bar after saving a note

        }
        
    }

    extension HomeViewController: UITableViewDataSource {
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return notes.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as! NoteCell
            let note = notes[indexPath.row]
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
                let note = notes[indexPath.row]
                notes.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
                let noteID = note.id
                db.collection("notes").document(noteID).delete { error in
                    if let e = error {
                        print("There was an issue deleting the note: \(e)")
                    } else {
                        print("Note deleted successfully.")
                    }
                }
                updateProgressBar() // Update the progress bar after deleting a note

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
                    let updatedNote = Note(id: note.id, text: cell.noteTextField.text!, location: note.location, imageURL: note.imageURL)
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

