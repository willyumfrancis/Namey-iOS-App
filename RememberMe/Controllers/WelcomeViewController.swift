//
//  LogInViewController.swift
//  RememberMe
//
//  Created by William Misiaszek on 3/13/23.
//

import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

class WelcomeViewController: UIViewController {

    
    @IBOutlet weak var StartTitle: UILabel!
    var currentCharacterIndex = 0
      var displayText: String = "Namey"
      var animationTimer: Timer?

      override func viewDidLoad() {
          super.viewDidLoad()
          
          // Initialize the StartTitle with an empty string
          StartTitle.text = ""
          
          // Start the animation
          startTextAnimation()
      }
      
      func startTextAnimation() {
          // Invalidate any existing timer
          animationTimer?.invalidate()
          
          // Create a new timer
          animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
              guard let self = self else { return }
              
              if self.currentCharacterIndex < self.displayText.count {
                  // Get the next character from the displayText string
                  let nextCharacter = self.displayText[self.displayText.index(self.displayText.startIndex, offsetBy: self.currentCharacterIndex)]
                  
                  // Append the character to the StartTitle text
                  self.StartTitle.text?.append(nextCharacter)
                  
                  // Increment the currentCharacterIndex
                  self.currentCharacterIndex += 1
              } else {
                  // Stop the timer when all characters have been displayed
                  timer.invalidate()
              }
          }
      }
      
      // Call this function to restart the animation
      func restartTextAnimation() {
          currentCharacterIndex = 0
          StartTitle.text = ""
          startTextAnimation()
      }
  }


