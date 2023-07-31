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
        
        // Image view configuration
        locationImageView.contentMode = .scaleAspectFill
        locationImageView.layer.borderWidth = 3.0
        locationImageView.layer.borderColor = UIColor.black.cgColor
        locationImageView.layer.cornerRadius = 10
        locationImageView.clipsToBounds = true

        // Cell configuration
        self.layer.borderWidth = 1.5  // Add a border width
        self.layer.borderColor = UIColor.black.cgColor  // Set border color
        self.layer.cornerRadius = 0  // Add rounded corners
        self.clipsToBounds = true  // This is important to ensure corners are visible
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        // Clear the image to ensure no old data is shown in the recycled cell
        locationImageView.image = nil
    }
    
    func configure(with locationData: LocationData) {
        locationNameLabel.text = locationData.name

        // Set image with the given URL
        locationImageView.sd_setImage(with: locationData.imageURL, placeholderImage: UIImage(named: "placeholder"))
    }



}
