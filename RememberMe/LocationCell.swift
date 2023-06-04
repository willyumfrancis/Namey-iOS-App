//
//  LocationCell.swift
//  RememberMe
//
//  Created by William Misiaszek on 4/20/23.
//

import UIKit

class LocationCell: UITableViewCell {

    @IBOutlet weak var locationImageView: UIImageView!
    @IBOutlet weak var locationNameLabel: UILabel!
    
    
    
     override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        locationImageView.contentMode = .scaleAspectFit
         
         // Initialization code
                locationImageView.contentMode = .scaleAspectFit
                self.layer.borderWidth = 2.0  // Add a border width
                self.layer.borderColor = UIColor.black.cgColor  // Set border color
                self.layer.cornerRadius = 0  // Add rounded corners
                self.clipsToBounds = true  // This is important to ensure corners are visible
            
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}

