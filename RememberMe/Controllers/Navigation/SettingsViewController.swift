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
    
    var rotationSpeed = 0.5

    @IBOutlet weak var betaTap: UILabel!
    
    @IBOutlet weak var catImage: UIImageView!
    
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

        // Add UITapGestureRecognizer to catImage
               let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
               catImage.isUserInteractionEnabled = true
               catImage.addGestureRecognizer(tapGestureRecognizer)
        
        // Add UITapGestureRecognizer to betaTap label
              let labelTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(labelTapped))
              betaTap.isUserInteractionEnabled = true
              betaTap.addGestureRecognizer(labelTapGestureRecognizer)
        
        // Add UILongPressGestureRecognizer to betaTap label
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(labelLongPressed))
        longPressGestureRecognizer.minimumPressDuration = 1.0 // 1 second
        betaTap.addGestureRecognizer(longPressGestureRecognizer)

          
           }
        // Do any additional setup after loading the view.
    
    
    
    @objc private func imageTapped() {
           rotationSpeed += 0.03
           let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
           rotationAnimation.toValue = NSNumber(value: Double.pi * 2.0 * rotationSpeed)
           rotationAnimation.duration = 1.0
           rotationAnimation.isCumulative = true
           rotationAnimation.repeatCount = Float.greatestFiniteMagnitude
           catImage.layer.add(rotationAnimation, forKey: "rotationAnimation")
       }
    
    @objc private func labelTapped() {
           if catImage.transform.d != 0 { // checking if the image is visible
               UIView.animate(withDuration: 0.3, animations: {
                   self.catImage.transform = self.catImage.transform.scaledBy(x: 0.9, y: 0.9) // reduce the size by 10%
               })
           }
       }
    
    @objc private func labelLongPressed(gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { // Only perform the action when the long press begins
            UIView.animate(withDuration: 3, animations: {
                self.catImage.transform = self.catImage.transform.scaledBy(x: 2, y: 2) // increase the size by 50%
            })
        }
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
