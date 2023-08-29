//
//  RegisterViewController.swift
//  RememberMe
//
//  Created by William Misiaszek on 3/13/23.
//

import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

class RegisterViewController: UIViewController, CLLocationManagerDelegate {
    @IBOutlet weak var EmailTextField: UITextField!
    @IBOutlet weak var PasswordTextField: UITextField!
    
    @IBOutlet weak var Register: UIButton!
    let locationManager = CLLocationManager()
    
    @IBAction func RegisterButton(_ sender: Any) {
        
        if let email = EmailTextField.text, let password = PasswordTextField.text {
               Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                   if let e = error {
                       print(e)
                       // Show error as an alert
                       let errorMessage = e.localizedDescription
                       let alertController = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
                       alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                       self.present(alertController, animated: true, completion: nil)
                   } else {
                       //Navigate to Chat View Controller
                       self.locationManager.requestWhenInUseAuthorization()
                       self.performSegue(withIdentifier: "RegisterSegue", sender: self)
                   }
               }
           }
       }
       
       override func viewDidLoad() {
           super.viewDidLoad()
           
           // Code for rounding the corners of the login button
                  Register.layer.cornerRadius = 12 // Adjust corner radiu
           
           // Request location authorization
           locationManager.delegate = self
       }
       
       override func viewWillAppear(_ animated: Bool) {
           super.viewWillAppear(animated)
           navigationController?.setNavigationBarHidden(false, animated: false)
       }
       
       // CLLocationManagerDelegate method
       func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
           if status == .authorizedWhenInUse {
               locationManager.requestLocation()
           }
       }
       
       // CLLocationManagerDelegate method
       func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
           if let location = locations.first {
               print("User's location: \(location)")
           }
       }
       
       // CLLocationManagerDelegate method
       func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
           print("Failed to get user's location: \(error.localizedDescription)")
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
