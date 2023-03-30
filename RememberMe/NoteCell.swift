//
//  NoteCell.swift
//  RememberMe
//
//  Created by William Misiaszek on 3/27/23.
//

import UIKit

protocol NoteCellDelegate: AnyObject {
func noteCell(_ cell: NoteCell, didUpdateNote note: Note)
}

class NoteCell: UITableViewCell {
    
    @IBOutlet weak var noteTextField: UITextField!
    
    weak var delegate: NoteCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        noteTextField.delegate = self
    }
//    override func setSelected(_ selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)
//
//        // Configure the view for the selected state
//    }
//
//}

}

extension NoteCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let noteText = textField.text {
            let noteId = String(tag)
            let updatedNote = Note(id: noteId, text: noteText)
            delegate?.noteCell(self, didUpdateNote: updatedNote)
        }
    }
}


