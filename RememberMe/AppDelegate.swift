import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import CoreData
import UserNotifications
import CoreLocation
import BackgroundTasks
import AVFoundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    var geofenceManager: GeofenceManager!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Set up audio session
           let audioSession = AVAudioSession.sharedInstance()
           do {
               try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowAirPlay, .mixWithOthers])
               try audioSession.setActive(true)
           } catch let error as NSError {
               if error.code == AVAudioSession.ErrorCode.insufficientPriority.rawValue {
                   print("Insufficient priority to set up audio session. Deferring setup.")
                   // Defer the audio session setup to a later point or handle it differently
               } else {
                   print("Failed to set up audio session: \(error)")
               }
           }

        // Configure Firebase
        FirebaseApp.configure()

        // Request notification authorization
        requestNotificationAuthorization()

        // Setup notification categories
        setupNotificationCategory()

        // Initialize GeofenceManager
        geofenceManager = GeofenceManager()

        // Set AppDelegate as the UNUserNotificationCenter's delegate
        UNUserNotificationCenter.current().delegate = self

        // Register for background refresh task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "misiaszek.RememberMe.refreshGeofences", using: nil) { task in
            self.handleGeofenceRefresh(task: task as! BGAppRefreshTask)
        }

        // Schedule the initial background task
        scheduleGeofenceRefresh()

        // Handling remote notification if the app is launched by tapping the notification
        if let notification = launchOptions?[.remoteNotification] as? [String: AnyObject],
           let locationName = notification["locationName"] as? String {
            // Delay navigation until the HomeViewController is ready
            DispatchQueue.main.async {
                self.navigateToHomeViewController(with: locationName)
            }
        }

        return true
    }

    func updateLocationInFirestore(location: CLLocation) {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userEmail)
        let locationData = ["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude]
        
        userRef.updateData(["location": locationData]) { error in
            if let error = error {
                print("Error updating location: \(error.localizedDescription)")
            } else {
                print("Location updated successfully")
            }
        }
    }


         // MARK: UNUserNotificationCenterDelegate
         

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let locationName = userInfo["locationName"] as? String {
            // Post a notification to inform the app that a location should be loaded
            NotificationCenter.default.post(name: NSNotification.Name("LoadLocationFromNotification"), object: nil, userInfo: ["locationName": locationName])
            
            // Navigate to HomeViewController
            navigateToHomeViewController(with: locationName)
        }
        
        completionHandler()
    }

    private func navigateToHomeViewController(with locationName: String) {
        DispatchQueue.main.async {
            if let rootViewController = self.window?.rootViewController as? UINavigationController,
               let homeViewController = rootViewController.viewControllers.first(where: { $0 is HomeViewController }) as? HomeViewController {
                // HomeViewController exists in navigation stack, pop to it
                rootViewController.popToViewController(homeViewController, animated: true)
                homeViewController.LoadPlacesNotes(for: locationName)
            } else {
                // HomeViewController is not in the stack (or the root is not a UINavigationController)
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                if let newHomeViewController = storyboard.instantiateViewController(withIdentifier: "HomeViewControllerID") as? HomeViewController {
                    newHomeViewController.LoadPlacesNotes(for: locationName)
                    self.window?.rootViewController = UINavigationController(rootViewController: newHomeViewController)
                    self.window?.makeKeyAndVisible()
                }
            }
        }
    }

         // MARK: Navigation
         



    // MARK: Background Tasks

    private func handleGeofenceRefresh(task: BGAppRefreshTask) {
        // Ensure a new refresh task is scheduled
        scheduleGeofenceRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Refresh your geofences here
        if let currentLocation = self.geofenceManager.locationManager.location {
            self.geofenceManager.refreshGeofences(currentLocation: currentLocation) { success in
                task.setTaskCompleted(success: success)
            }
        } else {
            // No location available; consider the task incomplete
            task.setTaskCompleted(success: false)
        }
    }

    private func scheduleGeofenceRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "misiaszek.RememberMe.refreshGeofences")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60 * 60) // Example: one hour from now

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule geofence refresh: \(error)")
        }
    }

    // MARK: - Notification Authorization & Category Setup

    func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification access granted")
            } else {
                print("Notification access denied")
                if let error = error {
                    print("Error requesting authorization: \(error)")
                }
            }
        }
    }

    func setupNotificationCategory() {
        let viewLastThreeNotesAction = UNNotificationAction(identifier: "viewLastThreeNotes", title: "View last three notes", options: [.foreground])
        let category = UNNotificationCategory(identifier: "notesCategory", actions: [viewLastThreeNotesAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - App Life Cycle & Core Data Stack
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationCenter.default.post(name: NSNotification.Name("appDidBecomeActive"), object: nil)
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "YourAppName")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
