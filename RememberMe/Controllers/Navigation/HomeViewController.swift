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


class HomeViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    //Current Place & Goal of People
    @IBOutlet weak var CurrentPlace: UIImageView!
    @IBOutlet weak var Progressbar: UIProgressView!
    
    //FireBase Cloud Storage
    let db = Firestore.firestore()
    
    //Create New Note
    @IBAction func New(_ sender: UIButton) {
        let newNote = Note(id: UUID().uuidString, text: "")
            saveNote(note: newNote)
            notes.append(newNote)
            
            tableView.reloadData()
            let indexPath = IndexPath(row: notes.count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            if let cell = tableView.cellForRow(at: indexPath) as? NoteCell {
                cell.noteTextField.becomeFirstResponder()
            }
        }
    var notes: [Note] = []
    
    
    //MARK: - Appearance Code
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "NoteCell", bundle: nil), forCellReuseIdentifier: "NoteCell")
        
        loadNotes()
        
        setupRoundedImageView()
        setupRoundedProgressBar()
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
            db.collection("notes")
                .whereField("user", isEqualTo: userEmail)
                .getDocuments { querySnapshot, error in
                    self.notes = []
                    
                    if let e = error {
                        print("There was an issue retrieving data from Firestore: \(e)")
                    } else {
                        if let snapshotDocuments = querySnapshot?.documents {
                            for doc in snapshotDocuments {
                                let data = doc.data()
                                if let noteText = data["note"] as? String {
                                    let newNote = Note(id: doc.documentID, text: noteText)
                                    self.notes.append(newNote)
                                }
                            }
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                            }
                        }
                    }
                }
        }
    }


    private func saveNote(note: Note) {
        if let userEmail = Auth.auth().currentUser?.email {
            let noteDocument = db.collection("notes").document(note.id)
            noteDocument.setData([
                "user": userEmail,
                "note": note.text
            ]) { error in
                if let e = error {
                    print("There was an issue saving data to Firestore: \(e)")
                } else {
                    print("Successfully saved data.")
                }
            }
        }
    }
    
}

extension HomeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as! NoteCell
        cell.noteTextField.text = notes[indexPath.row].text
        cell.delegate = self
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
func tableView(_ tableView:
               UITableView, didSelectRowAt indexPath: IndexPath) {
               tableView.deselectRow(at: indexPath, animated: true)
               }
               }

extension HomeViewController: NoteCellDelegate {
    func noteCell(_ cell: NoteCell, didUpdateNote note: Note) {
        if let indexPath = tableView.indexPath(for: cell) {
            let updatedNote = Note(id: note.id, text: note.text)
            notes[indexPath.row] = updatedNote
            saveNote(note: updatedNote)
        }
    }
    
    
    
}
