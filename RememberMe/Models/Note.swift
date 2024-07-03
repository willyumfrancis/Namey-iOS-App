
//  RememberMe
//
//  Created by William Misiaszek on 3/27/23.

import Foundation
import CoreLocation

struct Note {
    let id: String
    var text: String
    let location: CLLocationCoordinate2D
    var locationName: String
    var imageURL: URL? 
    var notificationsEnabled: Bool
}
