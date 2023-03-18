//
//  MenuController.swift
//  RememberMe
//
//  Created by William Misiaszek on 3/18/23.
//

import UIKit

class MenuController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()


        
        // Customize the tabBar appearance
               tabBar.backgroundColor = UIColor(red: 1, green: 0.91, blue: 0.83, alpha: 1)
               tabBar.layer.borderWidth = 1
               tabBar.layer.borderColor = UIColor.black.cgColor
               tabBar.clipsToBounds = true
               tabBar.layer.cornerRadius = 5
               tabBar.tintColor = UIColor.black

           }

    }

    // You can add other delegate methods and custom functions as needed

// Create a rounded rectangle view
//        let roundedRectangleView = UIView(frame: CGRect(x: 0, y: 0, width: 428, height: 87))
//        roundedRectangleView.backgroundColor = UIColor(red: 1, green: 0.91, blue: 0.83, alpha: 1)
//        roundedRectangleView.layer.cornerRadius = 5
//        roundedRectangleView.layer.borderWidth = 1
//        roundedRectangleView.layer.borderColor = UIColor.black.cgColor

// Position the view where you want it to appear
//        roundedRectangleView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)

// Add the view to the menu controller's view
//        view.addSubview(roundedRectangleView)


