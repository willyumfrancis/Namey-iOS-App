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
import AVFoundation

class AppState {
    static let shared = AppState()
    
    var rotationSpeed: Double = 0.5
    var wasPlaying: Bool = false
    
    private init() {}
}


class SettingsViewController: UIViewController {
    
    static var savedRotationSpeed: Double = 0.5 // Static property to save rotation speed
    static var wasPlaying: Bool = false // Static property to save audio state
    
    var rotationSpeed: Double {
        get { return SettingsViewController.savedRotationSpeed }
        set { SettingsViewController.savedRotationSpeed = newValue }
    }
    
    
    
    var audioPlayer: AVAudioPlayer?
    
    @IBOutlet weak var betaTap: UILabel!
    
    @IBOutlet weak var catImage: UIImageView!
    
    @IBOutlet weak var audioControlButton: UIButton!
    
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
    
    //    @IBAction func audioControlButton(_ sender: UIButton) {
    //        if audioPlayer?.isPlaying == true {
    //            audioPlayer?.pause()
    //            audioControlButton.setTitle("▶️", for: .normal) // Set to play symbol when paused
    //            print("Paused the song.")
    //        } else {
    //            audioPlayer?.play()
    //            audioControlButton.setTitle("⏸", for: .normal) // Set to pause symbol when playing
    //            print("Resumed the song.")
    //        }
    //    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        
        
        // Create a background view
        let backgroundView = UIView(frame: view.bounds)
        backgroundView.backgroundColor = UIColor(patternImage: UIImage(named: "starry_night")!) // Replace "starry_night" with your image file name
        view.insertSubview(backgroundView, at: 0)
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize audio player with the new path
        if let path = Bundle.main.path(forResource: "eastersong", ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                print("Audio player initialized.")
            } catch {
                print("Could not initialize audio player: \(error.localizedDescription)")
            }
        } else {
            print("Could not find audio file.")
        }
        
        
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audioPlayer?.stop() // Stop the song when view will disappear
        print("Stopped the song.")
    }
    
    
    @objc private func imageTapped() {
        
        rotationSpeed += 0.03
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.toValue = NSNumber(value: Double.pi * 2.0 * rotationSpeed)
        rotationAnimation.duration = 1.0
        rotationAnimation.isCumulative = true
        rotationAnimation.repeatCount = Float.greatestFiniteMagnitude
        catImage.layer.add(rotationAnimation, forKey: "rotationAnimation")
        // Play the song when cat is tapped
        if audioPlayer?.play() == true {
            //                   audioControlButton.isHidden = false // Show the audio control button
            //                   audioControlButton.setTitle("⏸", for: .normal) // Set to pause symbol when playing
            print("Started the song.")
        } else {
            print("Failed to start the song.")
        }
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
