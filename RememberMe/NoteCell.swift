//
//  NoteCell.swift
//  RememberMe
//
//  Created by William Misiaszek on 3/27/23.
//

import UIKit
import CoreLocation

protocol NoteCellDelegate: AnyObject {
    func noteCellTextFieldShouldReturn(_ textField: UITextField)
    func noteCell(_ cell: NoteCell, didUpdateNote note: Note)
    func noteCellDidEndEditing(_ cell: NoteCell) // Add this line
}

weak var delegate: NoteCellDelegate?


class NoteCell: UITableViewCell {
    
    var saveButtonPressed = false

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        delegate?.noteCellTextFieldShouldReturn(textField)
        return true
    }

    
    @IBOutlet weak var noteTextField: UITextField!
    weak var delegate: NoteCellDelegate?
       var noteLocation: CLLocationCoordinate2D? // Add this property to store the note's location

       override func awakeFromNib() {
           super.awakeFromNib()
           noteTextField.delegate = self
           noteTextField.tintColor = .black
           
       }
       
       override func setSelected(_ selected: Bool, animated: Bool) {
           super.setSelected(selected, animated: animated)

           // Configure the view for the selected state
       }
    
   }

extension NoteCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let homeVC = delegate as? HomeViewController {
            homeVC.activeNoteCell = self
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let noteText = textField.text, let location = noteLocation {
            let noteId = String(tag)
            let updatedNote = Note(id: noteId, text: noteText, location: location, locationName: "")
            delegate?.noteCell(self, didUpdateNote: updatedNote) // Add this line

        }
        delegate?.noteCellDidEndEditing(self)
    }
}

