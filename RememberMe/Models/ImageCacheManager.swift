//
//  ImageCacheManager.swift
//  Namey
//
//  Created by William Misiaszek on 8/31/23.
//

import Foundation
import SDWebImage
import UIKit
import FirebaseStorage

class ImageCacheManager {
    static let shared = ImageCacheManager()
    let imageCache = NSCache<NSString, UIImage>()
    
    private init() {}
    
    func prefetchImage(for locationData: LocationData, completion: @escaping (UIImage?) -> Void) {
        print("Attempting to prefetch image for \(locationData.name)")  // Debugging line

        let cacheKey = NSString(string: safeFileName(for: locationData.name))
        
        // Check if image is already in cache
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }
        
        // Download the image if it's not in cache
        let storageRef = Storage.storage().reference().child("location_images/\(safeFileName(for: locationData.name)).jpg")
        
        storageRef.downloadURL { [weak self] (url, error) in
            if let url = url {
                SDWebImageDownloader.shared.downloadImage(with: url, completed: { (image, error, cacheType, imageURL) in
                    if let downloadedImage = image {
                        // Cache the downloaded image
                        self?.imageCache.setObject(downloadedImage, forKey: cacheKey)
                        completion(downloadedImage)
                    } else {
                        completion(nil)
                    }
                })
            } else {
                completion(nil)
            }
        }
    }
}

