//
//  SceneDelegate.swift
//  RememberMe
//
//  Created by William Misiaszek on 3/13/23.
//

import UIKit
import FirebaseCore
import FirebaseAuth


class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    @objc func showInitialViewController() {
        let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let initialViewController = mainStoryboard.instantiateViewController(withIdentifier: "StartViewController") // Replace "StartViewController" with the appropriate identifier for your initial view controller
        
        // Create a new UIWindowScene to replace the current one
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let newWindow = UIWindow(windowScene: windowScene)
            newWindow.rootViewController = initialViewController
            newWindow.makeKeyAndVisible()
            self.window = newWindow
        }
    }



    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // Check if the user is already logged in
        if let _ = Auth.auth().currentUser {
            // User is already logged in, set the root view controller to HomeViewController
            let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let menuController = mainStoryboard.instantiateViewController(withIdentifier: "HomeMenuController") as! MenuController
            window.rootViewController = menuController
        } else {
            // If user is not logged in, set the root view controller to your initial view controller (e.g., Login or Signup view controller)
            let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let initialViewController = mainStoryboard.instantiateViewController(withIdentifier: "StartViewController") // Replace "InitialViewController" with the appropriate identifier

            window.rootViewController = initialViewController
        }
        
        window.makeKeyAndVisible()
        NotificationCenter.default.addObserver(self, selector: #selector(showInitialViewController), name: .didSignOut, object: nil)

    }


    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }


}

extension Notification.Name {
    static let didSignOut = Notification.Name("didSignOut")
}


