

import UIKit
import CoreLocation

protocol NoteCellDelegate: AnyObject {
    func noteCellTextFieldShouldReturn(_ textField: UITextField) -> Bool
    func noteCell(_ cell: NoteCell, didUpdateNote note: Note)
    func noteCellDidEndEditing(_ cell: NoteCell)
}


class NoteCell: UITableViewCell {

    weak var delegate: NoteCellDelegate?
    
    var saveButtonPressed = false
    var noteId: String = ""


    @IBOutlet weak var noteTextField: UITextField!
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
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        delegate?.noteCellTextFieldShouldReturn(textField)
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let homeVC = delegate as? HomeViewController {
            homeVC.activeNoteCell = self
        }
    }
    

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let noteText = textField.text, let location = noteLocation, !noteId.isEmpty {
            let updatedNote = Note(id: noteId, text: noteText, location: location, locationName: "")
            delegate?.noteCell(self, didUpdateNote: updatedNote)
        }
        delegate?.noteCellDidEndEditing(self)
    }


}
