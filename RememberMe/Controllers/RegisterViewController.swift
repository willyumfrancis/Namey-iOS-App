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
        guard let email = EmailTextField.text, !email.isEmpty, let password = PasswordTextField.text, !password.isEmpty else {
               print("Debug: Email or password field is empty.")
               showErrorAlert(message: "Please enter both email and password.")
               return
           }
           
           if password.count < 6 {
               print("Debug: Password too short.")
               showErrorAlert(message: "Password must be at least 6 characters long.")
               return
           }
           
           Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
               guard let strongSelf = self else {
                   print("Debug: self is nil.")
                   return
               }
               if let e = error as NSError? {
                   print("Debug: Error in createUser - \(e.localizedDescription)")
                   if e.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                       strongSelf.showErrorAlert(message: "This email is already registered. Please use a different email.")
                   } else {
                       strongSelf.showErrorAlert(message: e.localizedDescription)
                   }
               } else {
                   let db = Firestore.firestore()
                   let emailKey = email
                   db.collection("users").document(emailKey).setData([
                       "email": email
                   ]) { error in
                       if let error = error {
                           print("Debug: Error writing document - \(error.localizedDescription)")
                           strongSelf.showErrorAlert(message: "Failed to register user: \(error.localizedDescription)")
                       } else {
                           print("Debug: Document successfully written!")
                           strongSelf.locationManager.requestWhenInUseAuthorization()
                           strongSelf.performSegue(withIdentifier: "RegisterSegue", sender: strongSelf)
                       }
                   }
               }
           }
       }
       
       override func viewDidLoad() {
           super.viewDidLoad()
           Register.layer.cornerRadius = 12
           locationManager.delegate = self
       }
       
       override func viewWillAppear(_ animated: Bool) {
           super.viewWillAppear(animated)
           navigationController?.setNavigationBarHidden(false, animated: false)
       }
       
       func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
           print("Debug: Location authorization status changed to \(status.rawValue)")
           if status == .authorizedWhenInUse {
               locationManager.requestLocation()
           }
       }
       
       func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
           if let location = locations.first {
               print("Debug: User's location - \(location)")
           }
       }
       
       func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
           print("Debug: Failed to get user's location - \(error.localizedDescription)")
       }
       
       private func showErrorAlert(message: String) {
           let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
           alert.addAction(UIAlertAction(title: "OK", style: .default))
           DispatchQueue.main.async {
               self.present(alert, animated: true)
           }
           print("Debug: Showing error alert with message: \(message)")
       }
   }
