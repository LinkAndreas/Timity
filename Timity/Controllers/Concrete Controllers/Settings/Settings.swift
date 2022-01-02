//
//  Settings.swift
//  Timity
//
//  Created by Andreas Link on 2/23/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import CoreLocation
import MulticastDelegate
import UIKit

protocol SettingsDelegate {
    func themeTypeDidUpdateTo(_ themeType:ThemeType)
    func highlightColorDidUpdateTo(_ highlightColor:HighlightColor)
    func sortByDidUpdateTo(_ sortBy:SortBy)
    func sortingOrderDidUpdateTo(_ sortingOrder:SortingOrder)
    func lastLocationDidUpdateTo(_ location:CLLocationCoordinate2D)
    func numberOfAppLaunchesDidUpdateTo(_ numberOfAppLaunches:Int)
}

extension SettingsDelegate{
    func themeTypeDidUpdateTo(_ themeType:ThemeType){}
    func highlightColorDidUpdateTo(_ highlightColor:HighlightColor){}
    func sortByDidUpdateTo(_ sortBy:SortBy){}
    func sortingOrderDidUpdateTo(_ sortingOrder:SortingOrder){}
    func lastLocationDidUpdateTo(_ location:CLLocationCoordinate2D){}
    func numberOfAppLaunchesDidUpdateTo(_ numberOfAppLaunches:Int){}
}

protocol Setting:CustomStringConvertible{}

enum ThemeType:String, Setting{
    case black = "black"
    case dark = "dark"
    case light = "light"
    
    var description: String{
        switch self {
        case .black:
            return NSLocalizedString("settings_theme_type_black", comment: "String representing the black theme type in settings.")
        case .dark:
            return NSLocalizedString("settings_theme_type_dark", comment: "String representing the dark theme type in settings.")
        case .light:
            return NSLocalizedString("settings_theme_type_light", comment: "String representing the light theme type in settings.")
        }
    }
}

enum HighlightColor:String, Setting{
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case tealBlue = "teal blue"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    
    var description: String{
        switch self {
        case .red:
            return NSLocalizedString("settings_highlight_color_red", comment: "String representing the red highlight color in settings.")
        case .orange:
            return NSLocalizedString("settings_highlight_color_orange", comment: "String representing the orange highlight color in settings.")
        case .yellow:
            return NSLocalizedString("settings_highlight_color_yellow", comment: "String representing the yellow highlight color in settings.")
        case .green:
            return NSLocalizedString("settings_highlight_color_green", comment: "String representing the green highlight color in settings.")
        case .tealBlue:
            return NSLocalizedString("settings_highlight_color_teal_blue", comment: "String representing the teal blue highlight color in settings.")
        case .blue:
            return NSLocalizedString("settings_highlight_color_blue", comment: "String representing the blue highlight color in settings.")
        case .purple:
            return NSLocalizedString("settings_highlight_color_purple", comment: "String representing the purple highlight color in settings.")
        case .pink:
            return NSLocalizedString("settings_highlight_color_pink", comment: "String representing the pink highlight color in settings.")
        }
    }
    
    func color(for themeType:ThemeType)->UIColor{
        switch themeType {
        case .black, .dark:
            switch self {
            case .red:
                return UIColor(hexString:"#F62F38")!
            case .orange:
                return UIColor(hexString:"#f77f00")!
            case .yellow:
                return UIColor(hexString:"#F9CE20")!
            case .green:
                return UIColor(hexString:"#08a045")!
            case .tealBlue:
                return UIColor(hexString:"#6CC7F9")!
            case .blue:
                return UIColor(hexString:"#008dd5")!
            case .purple:
                return UIColor(hexString:"#615aa1")!
            case .pink:
                return UIColor(hexString:"#F61459")!
            }
        case .light:
            switch self {
            case .red:
                return UIColor(hexString:"#F62F38")!
            case .orange:
                return UIColor(hexString:"#f56416")!
            case .yellow:
                return UIColor(hexString:"#ffb001")!
            case .green:
                return UIColor(hexString:"#08a045")!
            case .tealBlue:
                return UIColor(hexString:"#6CC7F9")!
            case .blue:
                return UIColor(hexString:"#008dd5")!
            case .purple:
                return UIColor(hexString:"#930581")!
            case .pink:
                return UIColor(hexString:"#F61459")!
            }
        }
    }
}

enum SortBy:String, Setting {
    case nameOfEvent = "nameOfEvent"
    case dateOfEvent = "dateOfEvent"
    case dateOfCreation = "dateOfCreation"
    
    var description: String{
        switch self {
        case .nameOfEvent:
            return NSLocalizedString("settings_sort_by_name_of_event", comment: "String representing the sort by name of event option in settings.")
        case .dateOfEvent:
            return NSLocalizedString("settings_sort_by_date_of_event", comment: "String representing the sort by date of event option in settings.")
        case .dateOfCreation:
            return NSLocalizedString("settings_sort_by_date_of_creation", comment: "String representing the sort by date of creation option in settings.")
        }
    }
}

enum SortingOrder:String, Setting{
    case ascending = "ascending"
    case descending = "descending"
    
    func isAscending()->Bool{
        return self == .ascending
    }
    
    var description: String{
        switch self {
        case .ascending:
            return NSLocalizedString("settings_sorting_order_ascending", comment: "String representing the ascending sorting order in settings.")
        case .descending:
            return NSLocalizedString("settings_sorting_order_descending", comment: "String representing the descending sorting order in settings.")
        }
    }
}

class Settings{
    static let shared = Settings()
    private var alertControllerAlreadyShown = false

    ///Delegates
    var delegates = MulticastDelegate<SettingsDelegate>()
    
    ///Settings Properties
    var themeType:ThemeType{
        get{
            return ThemeType(rawValue:UserDefaults.standard.string(forKey: "themeType")!)!
        }
        set{
            UserDefaults.standard.set(newValue.rawValue, forKey: "themeType")
            UserDefaults.standard.synchronize()
            ThemeManager.shared.updateTheme()
            
            ///Notify delegates about changes
            delegates |> {
                delegate in
                delegate.themeTypeDidUpdateTo(newValue)
            }
        }
    }
    
    var highlightColor:HighlightColor{
        get{
            return HighlightColor(rawValue:UserDefaults.standard.string(forKey: "highlightColor")!)!
        }
        set{
            UserDefaults.standard.set(newValue.rawValue, forKey: "highlightColor")
            UserDefaults.standard.synchronize()
            ThemeManager.shared.updateTheme()

            ///Notify delegates about changes
            delegates |> {
                delegate in
                delegate.highlightColorDidUpdateTo(newValue)
            }
        }
    }
    
    var sortBy:SortBy{
        get{
            return SortBy(rawValue:UserDefaults.standard.string(forKey:"sortBy")!)!
        }
        set{
            UserDefaults.standard.set(newValue.rawValue, forKey: "sortBy")
            UserDefaults.standard.synchronize()
            
            ///Notify delegates about changes
            delegates |> {
                delegate in
                delegate.sortByDidUpdateTo(newValue)
            }
        }
    }
    
    var sortingOrder:SortingOrder{
        get{
            return SortingOrder(rawValue:UserDefaults.standard.string(forKey:"sortingOrder")!)!
        }
        set{
            UserDefaults.standard.set(newValue.rawValue, forKey: "sortingOrder")
            UserDefaults.standard.synchronize()
            
            ///Notify delegates about changes
            delegates |> {
                delegate in
                delegate.sortingOrderDidUpdateTo(newValue)
            }
        }
    }
    var lastLocation:CLLocationCoordinate2D?{
        get{
            guard let lastLocation = UserDefaults.standard.dictionary(forKey:"lastLocation") as? [String:Double] else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lastLocation["latitude"]!, longitude: lastLocation["longitude"]!)
        }
        set{
            guard let newLocation = newValue else {return}
            UserDefaults.standard.set(["latitude":newLocation.latitude,"longitude":newLocation.longitude], forKey: "lastLocation")
            UserDefaults.standard.synchronize()
            
            ///Notify delegates about changes
            delegates |> {
                delegate in
                delegate.lastLocationDidUpdateTo(newLocation)
            }
        }
    }
    
    var numberOfAppLaunches:Int{
        get{
            return UserDefaults.standard.integer(forKey:"numberOfAppLaunches")
        }
        set{
            UserDefaults.standard.set(newValue, forKey: "numberOfAppLaunches")
            UserDefaults.standard.synchronize()
            
            ///Notify delegates about changes
            delegates |> {
                delegate in
                delegate.numberOfAppLaunchesDidUpdateTo(newValue)
            }
        }
    }
    var numberOfLaunchesUntilReviewRequest = 35
    
    ///Methods
    init() {
        registerInitialUserDefaults()
    }
    
    ///Register Inital Values
    func registerInitialUserDefaults(){
        UserDefaults.standard.register(defaults: ["themeType" : ThemeType.dark.rawValue])
        UserDefaults.standard.register(defaults: ["highlightColor" : HighlightColor.orange.rawValue])
        UserDefaults.standard.register(defaults: ["sortBy" : SortBy.dateOfEvent.rawValue])
        UserDefaults.standard.register(defaults: ["sortingOrder" : SortingOrder.descending.rawValue])
        UserDefaults.standard.synchronize()
    }
    
    //MARK: Notify Users
    func showAlertWith(title:String, message:String){
        
        ///Create AlertController
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        
        ///Generate localized strings
        let okString = NSLocalizedString("common_ok_button", comment: "String representing the ok button text in an user alert dialog.")
        
        ///Add OK button to dismiss the alert
        let dismiss = UIAlertAction(title: okString, style: .default){
            [weak self] _ in
            self?.alertControllerAlreadyShown = false
        }
        alert.addAction(dismiss)
        
        ///Present the alert
        if !alertControllerAlreadyShown{
            alertControllerAlreadyShown = true
            
            let win = UIWindow(frame: UIScreen.main.bounds)
            let vc = ThemeableViewController()
            vc.view.backgroundColor = .clear
            win.rootViewController = vc
            win.windowLevel = UIWindow.Level.alert + 1
            win.makeKeyAndVisible()
            vc.present(alert, animated: true, completion: nil)
        }
    }
}
