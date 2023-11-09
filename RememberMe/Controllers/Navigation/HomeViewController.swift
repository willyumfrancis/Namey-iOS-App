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
import MobileCoreServices
import FirebaseStorage
import SDWebImage
import UserNotifications
import AVFoundation
import OpenAI

struct Geofence {
    let location: CLLocationCoordinate2D
    let radius: Double
    let identifier: String
}

class GeofenceManager: NSObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager!
    var notes: [Note] = []  // Your existing array of notes
    var geofences: [Geofence] = []  // New array for geofences
    var notifiedRegions: Set<String> = []
    var lastNotificationSentTime: [String: Date] = [:]
    
    override init() {
        super.init()
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        self.locationManager.requestAlwaysAuthorization()
        print("Location manager initialized")  // Debugging line
    }
}
    
    


class HomeViewController: UIViewController, CLLocationManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDragDelegate, UITableViewDropDelegate, UNUserNotificationCenterDelegate {
    
    // MARK: - NOTIFICATIONS
    
    //Location Manager
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
   
    var hasProcessedLocationUpdate = false

    // Location Manager Delegate
    var lastLocationUpdateTime: Date?

    // Location Manager Delegate
    var lastProcessedLocation: CLLocationCoordinate2D?

    // Define a property to keep track of whether the location has been fetched
    var hasFetchedLocation = false

    // Location Manager Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if hasFetchedLocation {
            return
        }

        guard let newLocation = locations.last else { return }

        self.userLocation = newLocation.coordinate
        self.currentLocation = newLocation.coordinate
        print("User's location: \(newLocation)")

        updateLocationNameLabel(location: newLocation.coordinate)
        self.displayImage(location: self.currentLocation!)

        if let coord = self.currentLocation {
            let locationObj = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            setupClosestFifteenGeofences(currentLocation: locationObj) {
                print("Called setupClosestFifteenGeofences completion block in didUpdateLocations")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.loadAndFilterNotes(for: self.userLocation!, goalRadius: 15.0) {
                        print("Notes are loaded and filtered.")
                    }
                }
            }
        }

        hasFetchedLocation = true
    }

         
    func setupClosestFifteenGeofences(currentLocation: CLLocation, completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            print("Setting up geofences for closest fifteen locations.")  // Debugging print statement

            let sortedNotes = self.notes.sorted {
                let location1 = CLLocation(latitude: $0.location.latitude, longitude: $0.location.longitude)
                let location2 = CLLocation(latitude: $1.location.latitude, longitude: $1.location.longitude)
                return currentLocation.distance(from: location1) < currentLocation.distance(from: location2)
            }

            let closestNotes = Array(sortedNotes.prefix(15))
            print("Closest notes count: \(closestNotes.count)")  // Debugging print statement

            self.geofenceManager.geofences.removeAll()

            for note in closestNotes {
                let coordinate = CLLocationCoordinate2D(latitude: note.location.latitude, longitude: note.location.longitude)
                let geofence = Geofence(location: coordinate, radius: 100, identifier: note.locationName)
                self.geofenceManager.geofences.append(geofence)
                self.setupGeoFence(location: geofence.location, identifier: geofence.identifier)
            }

            print("Geofences for closest fifteen locations set up.")  // Debugging print statement
            completion()
        }
    }

        
     // When exiting a region, remove it from the list of notified regions
     func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
         print("Exited region: \(region.identifier)")  // Debugging line
         
         // Remove from notified regions
         notifiedRegions.remove(region.identifier)

         if let circularRegion = region as? CLCircularRegion {
             print("Exited circular region with center: \(circularRegion.center) and radius: \(circularRegion.radius)")  // Debugging line
         }
     }

    var geofenceManager = GeofenceManager()  // Initialize GeofenceManager


         func setupGeoFence(location: CLLocationCoordinate2D, identifier: String) {
             let radius: CLLocationDistance = 100
             print("Setting up GeoFence at \(location) with radius \(radius)")  // Debugging line
             let region = CLCircularRegion(center: location, radius: radius, identifier: identifier)
             region.notifyOnEntry = true
             region.notifyOnExit = false
             
             if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
                 locationManager.startMonitoring(for: region)
                 print("GeoFence setup complete.") // Debugging line
             } else {
                 print("GeoFence monitoring is not available for this device.") // Debugging line
             }
         }

         func getLastThreeNotes(for locationName: String) -> [Note] {
             print("Fetching last three notes for location: \(locationName)") // Debugging line
             return Array(notes.filter { $0.locationName == locationName }.suffix(3))
         }
         
     func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
         DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
             print("Entered region: \(region.identifier)")  // Debugging line
             
             // Check if a notification has already been sent for this region
             if self.notifiedRegions.contains(region.identifier) {
                 print("Already notified for this region. Skipping.")  // Debugging line
                 return
             }
             
             
             if let circularRegion = region as? CLCircularRegion {
                 print("Entered circular region with center: \(circularRegion.center) and radius: \(circularRegion.radius)")  // Debugging line
             }
         }

             let lastThreeNotes = getLastThreeNotes(for: region.identifier)
             let lastThreeNotesText = lastThreeNotes.map { $0.text }

             // Debugging lines
             print("Last three notes for this region: \(lastThreeNotesText)")

             // Trigger the notification
             sendNotification(locationName: region.identifier, lastThreeNotes: lastThreeNotesText)

             // Add to notified regions
             notifiedRegions.insert(region.identifier)
         }
         

         
         func requestLocationAuthorization() {
             locationManager.requestWhenInUseAuthorization()
         }

         // Add a dictionary to keep track of last sent time for each location
         var lastNotificationSentTime: [String: Date] = [:]

    func sendNotification(locationName: String, lastThreeNotes: [String]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                print("Preparing to send notification for location: \(locationName)") // Debugging line
                
                // Check if locationName and lastThreeNotes are not empty
                if locationName.isEmpty || lastThreeNotes.isEmpty {
                    print("Either the location name or the last three notes are empty. Skipping notification.") // Debugging line
                    return
                }
                
                // Check for minimum time interval before sending next notification for the same location
                if let lastTime = self.geofenceManager.lastNotificationSentTime[locationName] {
                    let currentTime = Date()
                    let timeInterval = currentTime.timeIntervalSince(lastTime)
                    if timeInterval < 60 {  // 60 seconds as a rate limit
                        print("Skipping notification for \(locationName) due to rate limiting.") // Debugging line
                        return
                    }
                }
                
                // Update the last sent time for this location
                self.geofenceManager.lastNotificationSentTime[locationName] = Date()
                
                print("Sending notification for location: \(locationName)") // Debugging line
                let content = UNMutableNotificationContent()
                content.title = "Near \(locationName)"
                let notesText = lastThreeNotes.joined(separator: ", ")
                content.body = "Last notes: \(notesText)"
                content.categoryIdentifier = "notesCategory"
                content.sound = UNNotificationSound.default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Error adding notification: \(error)") // Debugging line
                    } else {
                        print("Notification added successfully") // Debugging line
                    }
                }
            }
        }

         func requestNotificationAuthorization() {
             print("Requesting notification authorization") // Debugging line
             let center = UNUserNotificationCenter.current()
             center.requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
                 if granted {
                     print("Notification access granted") // Debugging line
                 } else {
                     print("Notification access denied") // Debugging line
                     if let error = error {
                         print("Error requesting authorization: \(error)") // Debugging line
                     }
                 }
             }
         }

         func setupNotificationCategory() {
             print("Setting up notification category") // Debugging line
             let viewLastThreeNotesAction = UNNotificationAction(identifier: "viewLastThreeNotes", title: "View last three notes", options: [.foreground])
             let category = UNNotificationCategory(identifier: "notesCategory", actions: [viewLastThreeNotesAction], intentIdentifiers: [], options: [])
             UNUserNotificationCenter.current().setNotificationCategories([category])
             print("Notification category setup complete.") // Debugging line
         }
    
    
    
    
    
    
    
    
    //MARK: - OUTLETS
    @IBOutlet weak var tableView: UITableView!
    //Current Place & Goal of People
    @IBOutlet weak var CurrentPlace: UIImageView!
    @IBOutlet weak var Progressbar: UIProgressView!
    @IBOutlet weak var SaveButtonLook: UIButton!
    @IBOutlet weak var NewNameLook: UIButton!
    @IBOutlet weak var Header: UILabel!
    @IBOutlet weak var LocationButtonOutlet: UIButton!
    
    @IBOutlet weak var locationNameLabel: UILabel!
    
    @IBOutlet weak var notesCountLabel: UILabel!
    
    @IBOutlet weak var AdviceOutlet: UILabel!
    
    
    //FireBase Cloud Storage
    let db = Firestore.firestore()
    
    //MARK: - Swipe Right Expand Note
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: "Expand") { [weak self] (_, _, completionHandler) in
            self?.editNoteAtIndexPath(indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1) // Choose your color
        let configuration = UISwipeActionsConfiguration(actions: [editAction])
        return configuration
    }
    
    func editNoteAtIndexPath(_ indexPath: IndexPath) {
        let note = notes[indexPath.row]
        
        // Create the alert controller
        let alertController = UIAlertController(title: "Edit Note", message: "\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
        alertController.view.layer.cornerRadius = 15
        
        alertController.view.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1) // Set the background color
        alertController.view.tintColor = UIColor.black  // Replace UIColor.red with your desired color
        
        
        // Create the text field
        let textField = UITextView(frame: CGRect(x: 15, y: 55, width: 240, height: 240))
        textField.font = UIFont.systemFont(ofSize: 20)
        textField.text = note.text
        textField.backgroundColor = UIColor.clear // Set the background to clear
        
        alertController.view.addSubview(textField)
        
        // Create the actions
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            if let updatedText = textField.text {
                self.updateNoteAtIndexPath(indexPath, withText: updatedText)
            }
        }
        
        // Add the actions
        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)
        
        // Present the alert controller
        self.present(alertController, animated: true, completion: {
            textField.becomeFirstResponder()
        })
    }
    
    
    
    
    
    func updateNoteAtIndexPath(_ indexPath: IndexPath, withText updatedText: String) {
        let note = notes[indexPath.row]
        let locationToSave = note.location // Use the existing location
        
        getLocationName(from: locationToSave) { locationName in
            let locationNameToSave: String
            
            // Use the existing location name
            locationNameToSave = note.locationName
            
            let imageURLToSave = note.imageURL?.absoluteString ?? ""
            
            self.saveNoteToFirestore(noteId: note.id, noteText: updatedText, location: locationToSave, locationName: locationNameToSave, imageURL: imageURLToSave) { [weak self] success in
                if success {
                    print("Note saved successfully")
                    
                    // Update the local notes array
                    self?.notes[indexPath.row].text = updatedText
                    
                    // Reload the table view
                    DispatchQueue.main.async {
                        self?.tableView.reloadRows(at: [indexPath], with: .automatic)
                    }
                } else {
                    print("Error saving note")
                }
            }
        }
    }
    
    
    
    
    //MARK: - Whisper API
    
    var isRecording = false // Add this property to keep track of recording state
    
    
    @IBAction func toggleRecording(_ sender: UIButton) {
        if isRecording {
            print("Stopping recording...")
            stopRecordingAndTranscribeAudio()
            sender.setImage(UIImage(systemName: "mic"), for: .normal)
        } else {
            print("Starting recording...")
            startRecording()
            sender.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        }
        isRecording.toggle()
    }
    
    func stopRecordingAndTranscribeAudio() {
        print("Stopping recording.")
        audioRecorder.stop()
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.wav")
        print("Audio file URL: \(audioFilename)")
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: audioFilename.path) {
            print("File exists")
        } else {
            print("File does not exist")
        }
        
        print(audioFilename)
        
        APIManager.shared.transcribeAudio(fileURL: audioFilename) { result in
            print("Inside transcribeAudio completion handler") // Debugging line
            
            switch result {
            case .success(let transcription):
                print("Transcription successful: \(transcription)") // Debugging line
                
                DispatchQueue.main.async {
                    // Create a new note and add it to the notes array
                    let newNote = Note(id: UUID().uuidString, text: transcription, location: self.selectedLocation ?? CLLocationCoordinate2D(), locationName: "", imageURL: URL(string: ""))
                    self.notes.append(newNote)
                    
                    // Update the UI to insert the new note into the table view
                    self.tableView.beginUpdates()
                    self.tableView.insertRows(at: [IndexPath(row: self.notes.count - 1, section: 0)], with: .automatic)
                    self.tableView.endUpdates()
                    
                    // Find the newly added cell and set it as the active cell
                    if let newRowIndexPath = self.tableView.indexPathForLastRow,
                       let newCell = self.tableView.cellForRow(at: newRowIndexPath) as? NoteCell {
                        self.activeNoteCell = newCell
                        self.activeNoteCell?.note = newNote
                        self.activeNoteCell?.noteTextField.text = transcription
                        self.saveNote()  // Call the function to save the note
                    }
                }
            case .failure(let error):
                print("Error transcribing audio: \(error)") // Debugging line
                DispatchQueue.main.async {
      
                }
            }
        }
    }
    
    
    
    func showAlert(withTranscription text: String) {
        let alertController = UIAlertController(title: "Transcription", message: "Here is the transcription of your audio:\n\n\(text)", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    var audioRecorder: AVAudioRecorder!
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.wav") // Changed to .wav
        print("Starting recording. Audio filename: \(audioFilename)")
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder.record()
        } catch let error {
            print("Error starting recording: \(error)")
        }
    }
    
    
    
    
    func createNewNoteWithTranscription(_ transcription: String) {
        if let currentLocation = self.currentLocation {
            let emptyURL = URL(string: "")
            let newNote = Note(id: UUID().uuidString, text: transcription, location: currentLocation, locationName: "", imageURL: emptyURL)
            notes.append(newNote)
            selectedNote = newNote
            
            DispatchQueue.main.async {
                self.tableView.beginUpdates()
                self.tableView.insertRows(at: [IndexPath(row: self.notes.count - 1, section: 0)], with: .automatic)
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
    
    
    //MARK: - VARIABLES & CONSTANTS
    
    
    //Loading in Closest location variable true/false on entering placesviewcontroller.
    var hasEnteredPlacesViewController = false

    
    var expandedNotes: Set<String> = []
    var selectedLocationName: String?
    var selectedLocation: CLLocationCoordinate2D? //Necessary?
    var notesFromAverageLocation: [Note] = []
    var isLocationNameManuallySet = false  // Add this variable to keep track of user's manual input

    
    
    var averageSelectedLocation: CLLocationCoordinate2D? {
        didSet {
            if !isLocationNameManuallySet {  // Only update if the name was not manually set
                if let location = averageSelectedLocation {
                    currentLocationName = fetchLocationNameFor(location: location)
                } else {
                    if let location = locationManager.location?.coordinate {
                        currentLocationName = fetchLocationNameFor(location: location)
                    }
                }
            }
        }
    }
    
    var averageSelectedLocationName: String? {
        didSet {
            if !isLocationNameManuallySet {  // Only update if the name was not manually set
                if let locationName = averageSelectedLocationName {
                    currentLocationName = locationName
                }
            }
        }
    }
    
    
    
    
    var currentLocationName: String?
    var currentLocationImageURL: URL?
    
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocationCoordinate2D?
    var selectedNote: Note?
    
    let progressBar = UIProgressView(progressViewStyle: .default)
    
    var maxPeople = 3
    var locationUpdateTimer: Timer?
    
    
    // Assuming you have other variables and initializers defined elsewhere
    var notes: [Note] = []  // Replace Note with your Note class
    var notifiedRegions: Set<String> = []
    
    
    var notesLoaded = false
    
    var userLocation: CLLocationCoordinate2D?
    
    
    
    
    var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    var sliderValueLabel: UILabel!
    var activeNoteCell: NoteCell?
    
    var fetchedLocationKeys: Set<String> = []
    var notesFetched = false
    
    
    
    @IBAction func uploadImageButton(_ sender: UIButton) {
            print("Upload Image button pressed")
            print("Selected Location: \(String(describing: self.selectedLocation))")  // Debugging
            print("Selected Location Name: \(String(describing: self.selectedLocationName))")  // Debugging

            let alertController = UIAlertController(title: "Location Name", message: "Please enter a new name for this place:", preferredStyle: .alert)
            alertController.addTextField()

            let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
                guard let locationName = alertController.textFields?.first?.text, !locationName.isEmpty else {
                    print("Location name is empty.")  // Debugging
                    return
                }
                
                self.locationNameLabel.text = locationName  // Update current location name
                self.processLocationNameAndPresentImagePicker(locationName: locationName)
            }
            
            let skipAction = UIAlertAction(title: "Skip", style: .default) { _ in
                if let currentLocationName = self.locationNameLabel.text, !currentLocationName.isEmpty {
                    print("Skipping new name. Using current location name: \(currentLocationName)")  // Debugging
                    self.processLocationNameAndPresentImagePicker(locationName: currentLocationName)
                } else {
                    print("No current location name to skip to.")  // Debugging
                }
            }
            
            alertController.addAction(saveAction)
            alertController.addAction(skipAction)

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            alertController.addAction(cancelAction)
            
            self.present(alertController, animated: true)
        }


        func processLocationNameAndPresentImagePicker(locationName: String) {
            if let selectedLocation = self.selectedLocation {
                // User had selected a location from PlacesViewController
                print("Using selected location")  // Debugging
                self.updateLocationNameLabel(location: selectedLocation)
                self.presentImagePicker(locationName: locationName)
            } else if let currentLocation = self.locationManager.location?.coordinate {
                // No location was selected; use the current location
                print("Using current location")  // Debugging
                self.updateLocationNameLabel(location: currentLocation)
                self.presentImagePicker(locationName: locationName)
            } else if let currentLocationName = self.currentLocationName, !currentLocationName.isEmpty {
                // Use the current location name if available
                print("Using current location name: \(currentLocationName)")  // Debugging
                self.presentImagePicker(locationName: currentLocationName)
            }

            self.updateNotesCountLabel()
        }


    
    
    //AI Button
    @IBAction func aibutton(_ sender: UIButton) {
        print("AI button tapped") // Debugging print statement

               // Fetch advice directly when the AI button is tapped
               getAdvice { advice in
                   DispatchQueue.main.async {
                       self.AdviceOutlet.text = advice
                   }
               }
        
    }
    
    //Location Button
    @IBAction func LocationButton(_ sender: UIButton) {
        // Use the user's current location
           guard let userLocation = locationManager.location?.coordinate else {
                  print("User location not available yet")
                  return
               }

               // Set the user's current location as the selected location
               selectedLocation = userLocation

               // Update the current location information
               updateLocation(location: userLocation)
           }
       
    func updateLocation(location: CLLocationCoordinate2D) {
        loadAndFilterNotes(for: location, goalRadius: 15.0) {
            print("Notes are loaded and filtered in updateLocation.")
        }
        displayImage(location: location)
        updateNotesCountLabel()
        averageSelectedLocation = location
    }

    
    //MARK: - AI CODE
    func getAPIKey(named keyname: String, from plistName: String) -> String? {
        var nsDictionary: NSDictionary?
        if let path = Bundle.main.path(forResource: plistName, ofType: "plist") {
            nsDictionary = NSDictionary(contentsOfFile: path)
        }
        return nsDictionary?[keyname] as? String
    }
    
    func getAdvice(completion: @escaping (String) -> Void) {
           guard let apiKey = getAPIKey(named: "OpenAI_API_Key", from: "GoogleService-Info") else {
               print("API Key not found") // Debugging print statement
               return
           }
           
           let prompt = "Tell me a historical fact with a max of 70 charecters and no quotation marks."
           
           let messages = [["role": "system", "content": "You are a Fun Historian"],
                           ["role": "user", "content": prompt]]
           
           let json: [String: Any] = ["model": "gpt-3.5-turbo", "messages": messages]
           let jsonData = try? JSONSerialization.data(withJSONObject: json)
           
           var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
           request.httpMethod = "POST"
           request.httpBody = jsonData
           request.addValue("application/json", forHTTPHeaderField: "Content-Type")
           request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
           
           let task = URLSession.shared.dataTask(with: request) { data, response, error in
               print("Entered URLSession data task") // Debugging print statement
               
               if let error = error {
                   print("Error fetching advice: \(error)") // Debugging print statement
                   return
               }
               
               if let data = data {
                   do {
                       if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let choices = jsonResponse["choices"] as? [[String: Any]],
                          let message = choices.first?["message"] as? [String: Any],
                          let text = message["content"] as? String {
                           
                           let advice = text.trimmingCharacters(in: .whitespacesAndNewlines)
                           print("Advice: \(advice)") // Debugging print statement
                           completion(advice)
                       } else {
                           print("Unexpected response: \(String(data: data, encoding: .utf8) ?? "N/A")") // Debugging print statement
                       }
                   } catch {
                       print("JSON Serialization error: \(error)") // Debugging print statement
                   }
               } else {
                   print("Data is nil") // Debugging print statement
               }
           }
           task.resume()
       }
   
    
    
    

    //MARK: - SAVE AND NEW NOTE CREATION
    //Save Name Button
    @IBAction func SaveNote(_ sender: UIButton) {
        saveNote()
    }
    
    func lookupCoordinate(for locationName: String) -> CLLocationCoordinate2D? {
        for note in self.notes {
            if note.locationName == locationName {
                return note.location
            }
        }
        return nil
    }

    

    //Create New Name
    @IBAction func NewNote(_ sender: UIButton) {
            if let currentLocation = self.currentLocation {
                let emptyURL = URL(string: "")
                let userDefinedLocationName = currentLocationName ?? ""  // Fetch user-defined location name
                let newNote = Note(id: UUID().uuidString, text: "", location: currentLocation, locationName: userDefinedLocationName, imageURL: emptyURL)  // Use currentLocation and userDefinedLocationName
                notes.append(newNote)
                selectedNote = newNote

                DispatchQueue.main.async {
                    self.tableView.beginUpdates()
                    self.tableView.insertRows(at: [IndexPath(row: self.notes.count - 1, section: 0)], with: .automatic)
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

    
    
    
    //MARK: - Appearance
  
//    func updateProgressBar() {
//        updateNotesCountLabel()
//        let currentPeople = notes.count
//        let progress = min(Float(currentPeople) / Float(maxPeople), 1.0)
//
//        Progressbar.setProgress(progress, animated: true)
//
//        if progress == 1.0 {
//            Progressbar.progressTintColor = #colorLiteral(red: 0.07450980392, green: 0.9803921569, blue: 0.9019607843, alpha: 1)
//
//        } else {
//            Progressbar.progressTintColor = #colorLiteral(red: 0.07450980392, green: 0.9803921569, blue: 0.9019607843, alpha: 1)
//
//        }
//    }

    
    
    private func setupRoundedProgressBar() {
        // Set the progress bar height
        let height: CGFloat = 22

        // Apply corner radius
        Progressbar?.layer.cornerRadius = height / 7
        Progressbar?.clipsToBounds = true

        // Customize the progress tint and track color
        let trackTintColor = #colorLiteral(red: 0.521568656, green: 0.1098039225, blue: 0.05098039284, alpha: 1)  // red colors
        Progressbar?.trackTintColor = trackTintColor

        if let progressBarHeight = Progressbar?.frame.height {
            let transform = CGAffineTransform(scaleX: 1.0, y: height / progressBarHeight)
            Progressbar?.transform = transform
        }

        // Add drop shadow
        Progressbar?.layer.shadowColor = UIColor.black.cgColor
        Progressbar?.layer.shadowOffset = CGSize(width: 3, height: 20)
        Progressbar?.layer.shadowRadius = 8
        Progressbar?.layer.shadowOpacity = 0.8
        

        // Add a black border to the progress bar's layer
        let progressBarBorderLayer = CALayer()
        let progressBarWidth = (Progressbar?.bounds.width ?? 0) * 1.3 // Increase width by 30%
        progressBarBorderLayer.frame = CGRect(x: 0, y: 0, width: progressBarWidth, height: height)
        progressBarBorderLayer.cornerRadius = height / 2 // To make border circular
        progressBarBorderLayer.masksToBounds = true

        Progressbar?.layer.addSublayer(progressBarBorderLayer)

        // Increase the width of the progress bar's frame by 30%
        if let progressBarSuperview = Progressbar?.superview {
            let progressBarFrame = Progressbar?.frame ?? .zero
            let increasedWidth = progressBarFrame.width * 1.3
            Progressbar?.frame = CGRect(x: progressBarFrame.origin.x, y: progressBarFrame.origin.y, width: increasedWidth, height: progressBarFrame.height)
        }
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(true, animated: false)


        if let locationData = UserDefaults.standard.object(forKey: "averageSelectedLocation") as? Data {
            averageSelectedLocation = NSKeyedUnarchiver.unarchiveObject(with: locationData) as? CLLocationCoordinate2D
        } else {
            averageSelectedLocation = nil
        }

        averageSelectedLocationName = UserDefaults.standard.string(forKey: "averageSelectedLocationName")
    }

    @objc func handleAppDidBecomeActive() {
        print("App became active, updating location.")
        
        // Your code to update the location
        guard let userLocation = locationManager.location?.coordinate else {
            print("User location not available yet")
            return
        }

        // Set the user's current location as the selected location
        selectedLocation = userLocation

            }
    
    
    // VIEWDIDLOAD BRO
    override func viewDidLoad() {
        super.viewDidLoad()
        UNUserNotificationCenter.current().delegate = self
        requestNotificationAuthorization()
        checkNotificationSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: NSNotification.Name("appDidBecomeActive"), object: nil)
        
        // Retrieve the stored goal number from UserDefaults
          let storedValue = UserDefaults.standard.integer(forKey: "GoalNumber")
          if storedValue != 0 {
              maxPeople = storedValue
          }
        
        getAdvice { advice in
                    DispatchQueue.main.async {
                        self.AdviceOutlet.text = advice
                        print("Advice updated in viewDidLoad")  // Debugging print statement
                    }
                }
                
        
        
        // Load notifiedRegions from UserDefaults
               if let savedRegions = UserDefaults.standard.array(forKey: "notifiedRegions") as? [String] {
                   notifiedRegions = Set(savedRegions)
               }
        
        // Setting up location manager
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = kCLDistanceFilterNone
            locationManager.requestAlwaysAuthorization()

            // Setting up notification center
            UNUserNotificationCenter.current().delegate = self
            requestNotificationAuthorization()
            setupNotificationCategory()

//        // Update the progress bar according to the retrieved goal number
//           updateProgressBar()
        
        
                
        tableView.dragDelegate = self
        tableView.dropDelegate = self
        tableView.dragInteractionEnabled = false
        
        
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
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        CurrentPlace.isUserInteractionEnabled = true
        CurrentPlace.addGestureRecognizer(tapGestureRecognizer)

        
        
        let goalButton = UIBarButtonItem(title: "Set Goal", style: .plain, target: self, action: #selector(goalButtonTapped))
        navigationItem.rightBarButtonItem = goalButton
    }
    //ENDVIEWDIDLOAD
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    
    
    
    func createAttributedString(from noteText: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: noteText)
        
        if let dashRange = noteText.range(of: " - ") {
            let boldRange = NSRange(noteText.startIndex..<dashRange.lowerBound, in: noteText)
            attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 19), range: boldRange)
        } else if let colonRange = noteText.range(of: ": ") {
            let boldRange = NSRange(noteText.startIndex..<colonRange.lowerBound, in: noteText)
            attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 19), range: boldRange)
        }
        
        return attributedString
    }

    
    func updateLocationNameLabel(location: CLLocationCoordinate2D) {
        let locationName = fetchLocationNameFor(location: location) ?? "New Place"
        locationNameLabel.text = "\(locationName)"
        print("Location name is \(locationName)")
        
    }
    
    
    //Update Name Goal
    func updateNotesCountLabel() {
        let currentPeople = notes.count
        let displayedLocationName = locationNameLabel.text ?? "Unknown Location"

        if currentPeople == 0 {
            notesCountLabel.text = "Jot a name down!"
        } else if currentPeople == 1 {
            let labelText = "You have 1 note here."
            notesCountLabel.text = labelText
        } else {
            let labelText = "You have \(currentPeople) notes here."
            notesCountLabel.text = labelText
        }
    }




    
    //MARK: - POP-UPS
    
    func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            guard settings.authorizationStatus == .authorized else { return }
            if settings.alertSetting == .enabled {
                // Alerts are enabled
            } else {
                // Alerts are disabled
            }
        }
    }

    
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
    
    
    
    @objc func goalButtonTapped() {
        let alertController = UIAlertController(title: "Set Goal", message: "\n\n\n\n\n", preferredStyle: .alert)
        
        sliderValueLabel = UILabel(frame: CGRect(x: 10, y: 100, width: 250, height: 20)) // Increase y value to create space
        sliderValueLabel.textAlignment = .center
        sliderValueLabel.font = UIFont.systemFont(ofSize: 24) // Change font size here
        
        let slider = UISlider(frame: CGRect(x: 10, y: 60, width: 250, height: 20))
        slider.minimumValue = 1
        slider.maximumValue = 7
        
        // Retrieve value from UserDefaults
        let storedValue = UserDefaults.standard.integer(forKey: "GoalNumber")
        slider.value = storedValue != 0 ? Float(storedValue) : Float(maxPeople)
        
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        
        sliderValueLabel.text = "\(Int(slider.value))"
        
        alertController.view.addSubview(slider)
        alertController.view.addSubview(sliderValueLabel)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let doneAction = UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            self?.maxPeople = Int(slider.value)
            
            // Save value to UserDefaults when Done is pressed
            UserDefaults.standard.set(self?.maxPeople, forKey: "GoalNumber")
            
//            self?.updateProgressBar()
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
    
    
    
    
    
    
    

//MARK: - UPLOAD PHOTO CODE
    
    @objc func dismissFullscreenImage(_ sender: UITapGestureRecognizer) {
        self.navigationController?.isNavigationBarHidden = false
        self.tabBarController?.tabBar.isHidden = false
        sender.view?.removeFromSuperview()
    }

    @objc func imageTapped() {
        guard let image = CurrentPlace.image else { return }

        let scrollView = UIScrollView(frame: UIScreen.main.bounds)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 6.0
        scrollView.backgroundColor = .black

        let imageView = UIImageView(image: image)
        imageView.frame = UIScreen.main.bounds
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true

        scrollView.addSubview(imageView)

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissFullscreenImage))
        scrollView.addGestureRecognizer(tapGestureRecognizer)

        self.view.addSubview(scrollView)
        self.navigationController?.isNavigationBarHidden = true
        self.tabBarController?.tabBar.isHidden = true
    }



    
    func updateImageURLForNotesWithSameLocation(location: CLLocationCoordinate2D, locationName: String, newImageURL: URL) {
        print("Attempting to update imageURL for notes at location: \(location), locationName: \(locationName)")
        
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
                            
                            guard let noteLocationData = data["location"] as? GeoPoint else {
                                print("Missing location data for document ID: \(doc.documentID)")
                                continue
                            }
                            
                            guard let noteLocationName = data["locationName"] as? String else {
                                print("Missing locationName data for document ID: \(doc.documentID)")
                                continue
                            }
                            
                            let noteLocation = CLLocationCoordinate2D(latitude: noteLocationData.latitude, longitude: noteLocationData.longitude)
                            
                            if (noteLocation.latitude == location.latitude && noteLocation.longitude == location.longitude) || noteLocationName == locationName {
                                // Update the imageURL for the note with the given document ID
                                doc.reference.updateData([
                                    "imageURL": newImageURL.absoluteString
                                ]) { err in
                                    if let err = err {
                                        print("Error updating imageURL for document ID \(doc.documentID): \(err)")
                                    } else {
                                        print("Successfully updated imageURL for document ID \(doc.documentID)")
                                    }
                                }
                            }
                        }
                    } else {
                        print("No snapshot documents found")
                    }
                }
            }
    }


    
    
    func updateNotesImageURLGeoLocation(imageURL: URL?) {
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
                                        if let validImageURL = imageURL {
                                            self.updateImageURLForNote(doc.documentID, newImageURL: validImageURL) // Call updateImageURLForNote with imageURL
                                        }
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
    
    
    func updateImageURLForAllNotes(with imageURL: URL, location: CLLocationCoordinate2D) {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }
        print("Updating imageURL for location: \(location.latitude), \(location.longitude)")


        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .whereField("location.latitude", isEqualTo: location.latitude)
            .whereField("location.longitude", isEqualTo: location.longitude)
            .getDocuments { [weak self] querySnapshot, error in
                // Rest of the code as before
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
            }
        }
    }
    
    
    let distanceFilter: CLLocationDistance = 15
    
    func saveImageToFirestore(image: UIImage, location: CLLocationCoordinate2D, locationName: String) {
        _ = selectedLocation ?? location  // Use the selected location if it exists, otherwise use the given location.

        let safeFileName = self.safeFileName(for: locationName)
        let storageRef = Storage.storage().reference().child("location_images/\(safeFileName).jpg")

        // Delete the old image from Firebase Storage
        storageRef.delete { [weak self] error in
            if let error = error {
                print("Error deleting the old image: \(error)")
            } else {
                print("Old image deleted successfully")
            }

            self?.uploadImage(image: image, location: location, locationName: locationName) { result in
                    switch result {
                    case .success(let imageURL):
                        // Update all notes with the new imageURL and locationName
                        self?.updateAllNotesInFirestore(location: location, newLocationName: locationName, newImageURL: imageURL) { success in
                            if success {
                                print("All notes successfully updated.")
                            } else {
                                print("Failed to update all notes.")
                            }
                        }

                        // ... other code ...

                    case .failure(let error):
                        print("Error uploading image: \(error)")
                    }
                }
            }
    }
    
    
    func updateNotesWithImageURL(imageURL: URL?, selectedLocation: CLLocationCoordinate2D) {
        for i in 0..<notes.count {
            if notes[i].location.latitude == selectedLocation.latitude && notes[i].location.longitude == selectedLocation.longitude {
                // Update existing note
                notes[i].imageURL = imageURL
                if let imageURLString = imageURL?.absoluteString {
                    updateNoteInFirestore(noteID: notes[i].id, noteText: notes[i].text, location: notes[i].location, locationName: notes[i].locationName, imageURL: imageURLString) { success in
                        if success {
                            print("Note \(self.notes[i].id) updated successfully with imageURL")
                        } else {
                            print("Error updating note \(self.notes[i].id) with imageURL")
                        }
                    }
                }
                return  // Exit the loop once the note is found and updated
            }
        }
        // If code reaches here, no existing note was found to update
        // You can decide whether to create a new note or not
    }


    
    
    
    
    //MARK: - IMPORTANT UPDATE L NAME FUNCTION
    
    
    //Updates the locationName of the notes that are within a certain distance.
    func updateNotesLocationName(location: CLLocationCoordinate2D, newLocationName: String, completion: @escaping ([Note]) -> Void) {
        let maxDistance: CLLocationDistance = 15 // Adjust this value according to your requirements
        _ = GeoPoint(latitude: location.latitude, longitude: location.longitude)
        
        let actualLocation = selectedLocation ?? location  // Use the selected location if it exists, otherwise use the given location.

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
                            var locationExistsInNotes = false
                            
                            for doc in snapshotDocuments {
                                let data = doc.data()
                                if let locationData = data["location"] as? GeoPoint {
                                    let noteLocation = CLLocation(latitude: locationData.latitude, longitude: locationData.longitude)
                                    let userCurrentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                                    let distance = noteLocation.distance(from: userCurrentLocation)
                                    

                                    if distance <= maxDistance {
                                        locationExistsInNotes = true
                                        let noteId = doc.documentID
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

                            if !locationExistsInNotes {
                                // No note found within maxDistance, create new note with empty details
                                let newNoteRef = self.db.collection("notes").document()
                                newNoteRef.setData([
                                    "user": userEmail,
                                    "location": GeoPoint(latitude: location.latitude, longitude: location.longitude),
                                    "locationName": newLocationName,
                                    "note": "",
                                    "imageURL": "",
                                    "timestamp": Timestamp(date: Date())
                                ]) { error in
                                    if let error = error {
                                        print("Error creating new note: \(error)")
                                    } else {
                                        let newNote = Note(id: newNoteRef.documentID, text: "", location: location, locationName: newLocationName, imageURL: nil)
                                        updatedNotes.append(newNote)
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

    
    
    //MARK: - DISPLAY IMAGE FUNCTIONS
    
    
    func displayImage(location: CLLocationCoordinate2D? = nil, locationName: String? = nil) {
        // Clear the image view
        self.CurrentPlace.image = nil
        
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }
        
        var query: Query!
        
        if let location = location {
            query = db.collection("notes").whereField("user", isEqualTo: userEmail)
        } else if let locationName = locationName {
            query = db.collection("notes").whereField("user", isEqualTo: userEmail).whereField("locationName", isEqualTo: locationName)
        } else {
            print("No location or location name provided")
            return
        }
        
        query.getDocuments { querySnapshot, error in
            if let e = error {
                print("There was an issue retrieving data from Firestore: \(e)")
            } else if let snapshotDocuments = querySnapshot?.documents {
                for doc in snapshotDocuments {
                    let data = doc.data()
                    if let location = location, let locationData = data["location"] as? GeoPoint {
                        let userCurrentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                        let noteLocation = CLLocation(latitude: locationData.latitude, longitude: locationData.longitude)
                        let maxDistance: CLLocationDistance = 15
                        let distance = noteLocation.distance(from: userCurrentLocation)
                        if distance <= maxDistance {
                            self.handleNoteData(data: data)
                        }
                    } else if locationName != nil {
                        self.handleNoteData(data: data)
                    }
                }
            }
            
            // Add a delay before setting the default image
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.setDefaultImageIfNil()
            }
        }
    }

    
    func setDefaultImageIfNil() {
        if self.CurrentPlace.image == nil {
            DispatchQueue.main.async {
                self.CurrentPlace.image = UIImage(named: "default_image")
            }
        }
    }
    
    func updateUI(withLocationName locationName: String) {
        DispatchQueue.main.async {
            self.locationNameLabel.text = "\(locationName)"
            self.updateNotesCountLabel()
        }
    }



    func handleNoteData(data: [String: Any]) {
        if let locationName = data["locationName"] as? String, !locationName.isEmpty {
            self.updateUI(withLocationName: locationName)
            self.downloadAndDisplayImage(locationName: locationName)
            // If an image has been set, break the loop
            if self.CurrentPlace.image != nil {
                return
            }
        }
    }

    
    func downloadAndDisplayImage(locationName: String) {
        let safeFileName = safeFileName(for: locationName)
        let storageRef = Storage.storage().reference().child("location_images/\(safeFileName).jpg")
        
        storageRef.downloadURL { (url, error) in
            if let error = error {
                return
            }
            
            guard let url = url else { return }
            
            
            self.CurrentPlace.sd_setImage(with: url) { (image, error, cacheType, imageURL) in
                if let error = error {
                }
            }
        }
    }

    //Upload Image to Fire Storage
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
                
                // Success: tell the completion handler
                completion(.success(url))
                self.updateImageURLForNotesWithSameLocation(location: location, locationName: locationName, newImageURL: url)

                DispatchQueue.main.async {
                    // reloadData is being called on main thread as UI update should be done on main thread.
                    self.tableView.reloadData()
                }
            }
        }
       }
    
    // Image Picker Delegate - Selection and Saving
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            print("Image captured from camera: \(image)")
            CurrentPlace.image = image
            picker.dismiss(animated: true)
            
            // Determine which location to use: selectedLocation or userLocation
            var locationToUse: CLLocationCoordinate2D? = selectedLocation
            if locationToUse == nil {
                guard let userLocation = self.locationManager.location?.coordinate else {
                    print("User location not available yet")
                    return
                }
                locationToUse = userLocation
            }
            
            // Ensure locationToUse is not nil before proceeding
            guard let location = locationToUse else {
                print("Neither selected location nor user location is available.")
                return
            }
            
            if let locationName = currentLocationName {
                // Save the image and update the notes
                self.saveImageToFirestore(image: image, location: location, locationName: locationName)
                DispatchQueue.main.async {
                    self.currentLocationName = locationName
                    self.locationNameLabel.text = locationName
                }
                
                // Update notes with the new locationName
                self.updateNotesLocationName(location: location, newLocationName: locationName) { updatedNotes in
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
                    
                    // Save the image and update the notes
                    self.saveImageToFirestore(image: image, location: location, locationName: locationName)
                    
                    // Update notes with the new locationName
                    self.updateNotesLocationName(location: location, newLocationName: locationName) { updatedNotes in
                        // Perform any required operations with the updated notes here
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
                self.updateUI(withLocationName: locationName) // Update the UI

                
            }
        }
        let libraryAction = UIAlertAction(title: "Choose from Library", style: .default) { _ in
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                imagePickerController.sourceType = .photoLibrary
                self.present(imagePickerController, animated: true, completion: nil)
                self.updateUI(withLocationName: locationName) // Update the UI

            }
        }
        
        // Updated "Skip" action
         let skipAction = UIAlertAction(title: "Skip", style: .default) { _ in
             print("Skip action triggered.")
             if let selectedLocation = self.selectedLocation {
                 // Use the selected location if available
                 self.updateNotesLocationName(location: selectedLocation, newLocationName: locationName) { updatedNotes in
                     // Perform any required operations with the updated notes here
                     self.updateUI(withLocationName: locationName) // Update the UI
                     self.downloadAndDisplayImage(locationName: locationName) // Retain the associated image
                 }
             } else if let userLocation = self.locationManager.location?.coordinate {
                 // Fallback to the user's current location
                 self.updateNotesLocationName(location: userLocation, newLocationName: locationName) { updatedNotes in
                     // Perform any required operations with the updated notes here
                     self.updateUI(withLocationName: locationName) // Update the UI
                     self.downloadAndDisplayImage(locationName: locationName) // Retain the associated image
                 }
             } else {
                 print("Neither selected location nor user location is available.")
             }
        }

        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(cameraAction)
        alertController.addAction(libraryAction)
        alertController.addAction(skipAction) // Add the "Skip" action to the alertController
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    
    
    








    
    
    
    
    //END LOCATION STUFF
    private func setupRoundedImageView() {
        // Apply corner radius
        CurrentPlace?.layer.cornerRadius = 12
        CurrentPlace?.clipsToBounds = true
        
        // Apply border
        CurrentPlace?.layer.borderWidth = 3
        CurrentPlace?.layer.borderColor = UIColor.black.cgColor
        
        // Apply background color
        CurrentPlace?.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        
        // Set the content mode to ensure the image is scaled correctly in the UIImageView.
        CurrentPlace?.contentMode = .scaleAspectFill
    }

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
        
        // Set the image in the UIImageView.
        CurrentPlace?.image = UIImage(cgImage: cgImage)
        
        return UIImage(cgImage: cgImage)
    }

    
    
    //Phone Doc Function for Image Picker
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    
    //MARK: - NOTES
    
    // textFieldShouldReturn method
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let cell = textField.superview?.superview as? NoteCell {
            activeNoteCell = cell
            saveNote() // Calls the saveNote function to perform the save action
        }
        return true
    }

    
    // New function to save the note
    func saveNote() {
        var locationToSave: CLLocationCoordinate2D

        if let selectedLocation = selectedLocation {
            locationToSave = selectedLocation
        } else if let currentLocation = locationManager.location?.coordinate {
            locationToSave = currentLocation
        } else {
            print("Failed to get user's current location or selected location")
            return
        }

        guard let activeCell = activeNoteCell else {
            print("Failed to get active cell")
            return
        }

        if let noteText = activeCell.noteTextField.text, !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let noteId = activeCell.note?.id ?? UUID().uuidString

            getLocationName(from: locationToSave) { locationName in
                let locationNameToSave: String
                // Prioritize the name user chose
                if let userChosenName = self.currentLocationName, !userChosenName.isEmpty {
                    locationNameToSave = userChosenName
                } else {
                    // Fall back to the auto-generated name
                    locationNameToSave = locationName ?? "Unnamed Location"
                }
                let imageURLToSave = self.currentLocationImageURL?.absoluteString ?? ""

                activeCell.note?.location = locationToSave

                self.saveNoteToFirestore(noteId: noteId, noteText: noteText, location: locationToSave, locationName: locationNameToSave, imageURL: imageURLToSave) { [weak self] success in
                    if success {
                        print("Note saved successfully")
                        if let noteIndex = self?.notes.firstIndex(where: { $0.id == noteId }) {
                            self?.notes[noteIndex].text = noteText
                            DispatchQueue.main.async {
//                                self?.tableView.reloadData()
                                self?.tableView.scrollToRow(at: IndexPath(row: noteIndex, section: 0), at: .bottom, animated: true)
//                                self?.updateProgressBar()
                                self?.updateLocationNameLabel(location: locationToSave)
                                self!.updateUI(withLocationName: locationName!) // Update the UI

                            }
                        }
                    } else {
                        print("Error saving note")
                    }
                }
            }
        } else {
            print("Note text field is empty")
        }
    }


    func getLocationName(from location: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: location.latitude, longitude: location.longitude)

        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let error = error {
                print("There was an error reverse geocoding the location: \(error)")
                completion(nil)
            } else if let placemark = placemarks?.first {
                // Here you can choose how you want to format the location name
                // This is just one example
                var locationName = ""

                if let name = placemark.name {
                    locationName += name
                }

                if let locality = placemark.locality {
                    locationName += ", \(locality)"
                }


                if locationName.isEmpty {
                    locationName = "Unnamed Location"
                }

                completion(locationName)
            } else {
                print("No placemarks found for location")
                completion(nil)
            }
        }
    }

    func updateAllNotesInFirestore(location: CLLocationCoordinate2D, newLocationName: String, newImageURL: URL, completion: @escaping (Bool) -> Void) {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            completion(false)
            return
        }

        // Fetch all notes for this user and location
        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .whereField("location.latitude", isEqualTo: location.latitude)
            .whereField("location.longitude", isEqualTo: location.longitude)
            .getDocuments { querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                    completion(false)
                    return
                }

                for doc in querySnapshot!.documents {
                    let noteId = doc.documentID
                    let noteRef = self.db.collection("notes").document(noteId)

                    let noteData: [String: Any] = [
                        "locationName": newLocationName,
                        "imageURL": newImageURL.absoluteString
                    ]

                    // Update each note
                    noteRef.updateData(noteData) { err in
                        if let err = err {
                            print("There was an issue updating the note in Firestore: \(err)")
                            completion(false)
                        } else {
                            print("Note successfully updated in Firestore")
                        }
                    }
                }
                completion(true)
            }
    }


    
    func updateNoteInFirestore(noteID: String, noteText: String, location: CLLocationCoordinate2D, locationName: String, imageURL: String, completion: @escaping (Bool) -> Void) {
        let noteRef = db.collection("notes").document(noteID)
        
        let noteData: [String: Any] = [
            "note": noteText,
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
    
    
    func saveNoteToFirestore(noteId: String, noteText: String, location: CLLocationCoordinate2D, locationName: String, imageURL: String, completion: @escaping (Bool) -> Void) {
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

        db.collection("notes").document(noteId).setData(noteData) { error in
            if let error = error {
                print("Error saving note to Firestore: \(error)")
                completion(false)
            } else {
                print("Note successfully saved to Firestore")
                completion(true)
            }
        }
    }


    
    func fetchLocationNameFor(location: CLLocationCoordinate2D) -> String? {
        let radius: CLLocationDistance = 15 // The radius in meters to consider notes as nearby
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

    
    func loadAndFilterNotes(for location: CLLocationCoordinate2D, goalRadius: Double, completion: @escaping () -> Void) {

        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }
        
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        print("Loading and filtering notes for user: \(userEmail)")
        
        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .order(by: "timestamp", descending: false)
            .getDocuments { [weak self] querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                } else {
                    self?.notes = [] // Clear the existing notes array
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
                                                        
                                let noteLocation = CLLocation(latitude: newNote.location.latitude, longitude: newNote.location.longitude)
                                let distance = noteLocation.distance(from: currentLocation)
                                                        
                                if !self!.notesFromAverageLocation.contains(where: { $0.id == newNote.id }) {
                                    if distance <= goalRadius {
                                        self?.notes.append(newNote)
                                    }
                                }
                            }

                        }
                        DispatchQueue.main.async {
                            print("Showing \(self?.notes.count ?? 0) notes based on location")
                            self?.tableView.reloadData()
                            
//                            self?.updateProgressBar()
                            self?.updateLocationNameLabel(location: location) // Update the location name label
                        }
                    }
                }
            }
        completion()

    }
    


    
//MARK: - LOAD PLACES VIEW CONTROLLER DATA
    func LoadPlacesNotes(for locationName: String) {
        print("loadPlacesNotes called")
        
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            return
        }
        
        print("Loading notes for user: \(userEmail)")
        
        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .whereField("locationName", isEqualTo: locationName)
            .order(by: "timestamp", descending: false)
            .getDocuments { [weak self] querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                } else {
                    self?.notes = [] // Clear the existing notes array
                    
                    if let snapshotDocuments = querySnapshot?.documents {
                        print("Found \(snapshotDocuments.count) notes")
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let noteText = data["note"] as? String,
                               let locationData = data["location"] as? GeoPoint,
                               let locationName = data["locationName"] as? String,
                               !noteText.isEmpty {
                                let location = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
                                let imageURLString = data["imageURL"] as? String
                                let imageURL = URL(string: imageURLString ?? "")
                                let newNote = Note(id: doc.documentID, text: noteText, location: location, locationName: locationName, imageURL: imageURL)
                                
                                // Store this location as the selected location
                                self?.selectedLocation = location
                                
                                self?.notes.append(newNote)
                            }
                        }

                        DispatchQueue.main.async {
                            print("Showing \(self?.notes.count ?? 0) notes based on location")
                            self?.tableView.reloadData()
                            
//                            self?.updateProgressBar()
                            // Update the location name label
                            self?.locationNameLabel.text = "\(locationName)"
                            self?.currentLocationName = locationName
                            self?.fetchImageURLFor(locationName: locationName) { imageURL in
                                self?.currentLocationImageURL = imageURL
                                self?.updateNotesImageURLGeoLocation(imageURL: self?.currentLocationImageURL ?? nil)
                            }
                        }
                    }
                }
            }
    }





    func fetchImageURLFor(locationName: String, completion: @escaping (URL?) -> Void) {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User email not found")
            completion(nil)
            return
        }
        
        db.collection("notes")
            .whereField("user", isEqualTo: userEmail)
            .whereField("locationName", isEqualTo: locationName)
            .getDocuments { querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                    completion(nil)
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let imageURLString = data["imageURL"] as? String,
                               let imageURL = URL(string: imageURLString) {
                                completion(imageURL)
                                return
                            }
                        }
                    }
                    completion(nil)
                }
            }
    }



    func updateViewWithNote(_ note: Note) {
        // Set current location
        self.currentLocation = note.location

        // Call the functions to update the image view, location name label, and notes count label
        displayImage(location: note.location)
        updateLocationNameLabel(location: note.location)
        updateNotesCountLabel()

        // Update the table view
        self.tableView.reloadData()
    }





}
    

//MARK: - EXTENSIONS

extension HomeViewController {
    
    // UITableViewDragDelegate
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let draggedNote = notes[indexPath.row]
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
                    let draggedNote = self.notes.remove(at: sourceIndexPath.row)
                    self.notes.insert(draggedNote, at: destinationIndexPath.row)
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
        return notes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as! NoteCell
        let note = notes[indexPath.row]
        
        cell.noteTextField.attributedText = createAttributedString(from: note.text)
        cell.noteTextField.delegate = cell
        cell.noteTextField.isEnabled = true
        cell.noteLocation = note.location
        cell.note = note // Set the note property
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
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let noteToDelete = notes[indexPath.row]
            notes.remove(at: indexPath.row)
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

extension HomeViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView.subviews.first
    }
}


extension HomeViewController: PlacesViewControllerDelegate {
    
    func didEnterPlacesViewController() {
        hasEnteredPlacesViewController = true
    }
    
    func didSelectLocation(with locationName: String) {
        tabBarController?.selectedIndex = 0
        // Lookup the coordinate based on the location name from your data model
        if let locationCoordinate = lookupCoordinate(for: locationName) {
            self.selectedLocationName = locationName
        }
        
        LoadPlacesNotes(for: locationName)
        displayImage(locationName: locationName)
    }
    
    func didUpdateClosestLocation(_ closestLocation: LocationData?) {
        if !hasEnteredPlacesViewController {
            if let closestLocation = closestLocation {
                print("Closest location is: \(closestLocation.name)")  // Debugging line
                self.selectedLocationName = closestLocation.name
                LoadPlacesNotes(for: closestLocation.name)
                displayImage(locationName: closestLocation.name)
            }
        }
    }
    
}
