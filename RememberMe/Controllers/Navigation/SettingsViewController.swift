//
//  SettingsViewController.swift
//  RememberMe
//
//  Created by William Misiaszek on 3/13/23.
//

import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

class SettingsViewController: UIViewController {
    

    @IBAction func LogOutButton(_ sender: UIBarButtonItem) {
        let firebaseAuth = Auth.auth()
           do {
               try firebaseAuth.signOut()

               // Notify the scene delegate to show the initial view controller
               NotificationCenter.default.post(name: .didSignOut, object: nil)

           } catch let signOutError as NSError {
               print("Error signing out: %@", signOutError)
           }
       }
    
    override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.setNavigationBarHidden(true, animated: false)
        }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
