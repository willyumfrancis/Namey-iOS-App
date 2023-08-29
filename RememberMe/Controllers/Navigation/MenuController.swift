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
        tabBar.backgroundColor = #colorLiteral(red: 0.07450980392, green: 0.9803921569, blue: 0.9019607843, alpha: 1)
        tabBar.layer.borderWidth = 2
        tabBar.layer.borderColor = UIColor.black.cgColor
        tabBar.clipsToBounds = true
        tabBar.layer.cornerRadius = 5
        tabBar.tintColor = UIColor.black
        tabBar.unselectedItemTintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.499249793)


    }
    
}
