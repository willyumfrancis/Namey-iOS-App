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



class HomeViewController: UIViewController, CLLocationManagerDelegate {
    
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
                       let updatedNote = Note(id: selectedNote.id, text: cell.noteTextField.text!, location: selectedNote.location)
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
                let newNote = Note(id: UUID().uuidString, text: "", location: currentLocation)
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
        
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { auth, user in
            if user != nil {
                print("User is signed in: \(user?.email ?? "Unknown email")")
                self.loadNotes()
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
        }
    }

    


    
    //Update Location via Button Function
    func updateCurrentLocationAndFetchNotes() {
        locationManager.startUpdatingLocation()
    }


    
    //Location Manager
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    //Location Manager Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
               currentLocation = location.coordinate
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
    private func loadNotes() {
        if let userEmail = Auth.auth().currentUser?.email {
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
                                   let locationData = data["location"] as? GeoPoint {
                                    let location = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
                                    let newNote = Note(id: doc.documentID, text: noteText, location: location)
                                    self.notes.append(newNote) // Add the new note to the array
                                }
                            }
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                            }
                        }
                    }
                }
        } else {
            print("User email not found")
        }
    }
    
    
    
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
    
    
    private func saveNote(note: Note) {
        notes.append(note) // Add the new note to the existing notes array
        let indexPath = IndexPath(row: notes.count - 1, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        saveNoteToCloud(note: note) // Save the new note to the cloud
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
                let updatedNote = Note(id: note.id, text: cell.noteTextField.text!, location: note.location)
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

