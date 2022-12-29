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
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
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

        updateAccordingToTheme(ThemeManager.shared.currentTheme)

        ///Register to be notified about theme changes
        if !ThemeManager.shared.delegates.containsDelegate(self){
            ThemeManager.shared.delegates.addDelegate(self)
        }
        
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
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
            detailVC = (UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "placeholder"))
            return detailVC
        }else if let type = (vc as? InputController)?.viewModel?.type {
            if type == .addEventController || type == .modifyEventController{
                detailVC = nil
                detailVC = (UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "placeholder"))
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
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

extension AppDelegate:ThemeManagerDelegate{
    func currentThemeDidChangeTo(_ theme: Theme) {
        updateAccordingToTheme(theme)
    }

    ///Update the UI according to the given theme
    func updateAccordingToTheme(_ theme:Theme){
        window?.overrideUserInterfaceStyle = theme.userInterfaceStyle
    }
}
