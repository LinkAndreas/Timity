//
//  AppDelegate.swift
//  Timity
//
//  Created by Andreas Link on 1/18/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
    lazy var picker = UIDatePicker()
    var detailVC:UIViewController?
    
    // MARK: Lifecycle
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        ///Update the theme initially
        ThemeManager.shared.updateTheme()
        
        ///Override point for customization after application launch.
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        
        ///Set splitViewController minimum and maximum clumn width
        let minimumWidth = min(splitViewController.view.bounds.width, splitViewController.view.bounds.height)
        splitViewController.minimumPrimaryColumnWidth = minimumWidth / 2.3
        splitViewController.maximumPrimaryColumnWidth = minimumWidth
        
        ///Make Master and Detail view visible by default
        splitViewController.preferredDisplayMode = .allVisible
        
        ///Set SplitVC Background color
        splitViewController.view.backgroundColor = .clear
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }
    
    // MARK: - Split view
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        if let _ = (secondaryViewController as? UINavigationController)?.topViewController as? TimityViewController {
            return true
        }else if let _ = (secondaryViewController as? UINavigationController)?.topViewController as? OutputController {
            return false
        }else if let _ = (secondaryViewController as? UINavigationController)?.topViewController as? SettingsController {
            return false
        }
        
        ///General rule
        ///true: secondaryViewController thrown away
        ///false: secondaryViewController pushed onto primary viewcontrollers navigation stack
        return false
    }
    
    // Correctly Handle Portrait to Landscape transition for iPhone 6/7 Plus
    func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController?{
        
        guard let nc = primaryViewController as? UINavigationController else {return nil}
        guard let vc = nc.topViewController else {return nil}
        
        ///Specify the secondary controller
        if  vc.isKind(of: MenuController.self) || vc.isKind(of: EventListController.self){
            detailVC = nil
            detailVC = (UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "timityNavigationController"))
            return detailVC
        }else if let type = (vc as? InputController)?.viewModel?.type {
            if type == .addEventController || type == .modifyEventController{
                detailVC = nil
                detailVC = (UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "timityNavigationController"))
                return detailVC
            }else{
                guard let inputVC = vc as? InputController  else {return nil}
                guard let onc = (UIStoryboard(name: "InputController", bundle: nil).instantiateViewController(withIdentifier: "outputNavigationController")) as? UINavigationController else {return  nil}
                guard let oc = onc.topViewController as? OutputController else {return nil}
                
                //Setup outputController
                inputVC.delegate = oc
                inputVC.delegate?.inputDidUpdate(inputVC.obtainInput())
                detailVC = nil
                detailVC = onc
                return detailVC
            }
        }else{
            return nil
        }
    }
    
    // MARK: - Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        
        let container = NSPersistentContainer(name: "Timity")
        
        //Enable Lightweight Migration to new CoreData store
        let storeURL = try! FileManager
            .default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Timity.sqlite")
        
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
