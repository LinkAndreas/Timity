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
    func appRatingPopupDismissCountDidUpdateTo(_ appRatingPopupDismissCount:Int)
    func isAppRatingPopupAnsweredDidUpdateTo(_ isAppRatingAnswered:Bool)
}

extension SettingsDelegate{
    func themeTypeDidUpdateTo(_ themeType:ThemeType){}
    func highlightColorDidUpdateTo(_ highlightColor:HighlightColor){}
    func sortByDidUpdateTo(_ sortBy:SortBy){}
    func sortingOrderDidUpdateTo(_ sortingOrder:SortingOrder){}
    func lastLocationDidUpdateTo(_ location:CLLocationCoordinate2D){}
    func appRatingPopupDismissCountDidUpdateTo(_ appRatingPopupDismissCount:Int){}
    func isAppRatingPopupAnsweredDidUpdateTo(_ isAppRatingAnswered:Bool){}
}

protocol Setting:CustomStringConvertible{}

enum ThemeType: String, Setting {
    case light = "light"
    case dark = "dark"
    case black = "black"
    case automaticLightDark = "autoamtic_light_dark"
    case automaticLightBlack = "autoamtic_light_black"
    
    var description: String{
        switch self {
        case .light:
            return NSLocalizedString("settings_theme_type_light", comment: "String representing the light theme type in settings.")

        case .dark:
            return NSLocalizedString("settings_theme_type_dark", comment: "String representing the dark theme type in settings.")

        case .black:
            return NSLocalizedString("settings_theme_type_black", comment: "String representing the black theme type in settings.")

        case .automaticLightDark:
            return NSLocalizedString("settings_theme_type_automatic_light_dark", comment: "String representing the automatic light dark theme type in settings.")

        case .automaticLightBlack:
            return NSLocalizedString("settings_theme_type_automatic_light_black", comment: "String representing the automatic light black theme type in settings.")
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
    var themeType: ThemeType{
        get{
            guard let rawValue = UserDefaults.standard.string(forKey: "themeType") else { return .automaticLightDark }
            return ThemeType(rawValue: rawValue) ?? .automaticLightDark
        }

        set {
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
    
    var highlightColor: HighlightColor{
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
    
    var sortBy: SortBy{
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
    
    var sortingOrder: SortingOrder{
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
    
    var isAppRatingPopupAnswered: Bool {
        get{
            return UserDefaults.standard.bool(forKey: "isAppRatingPopupAnswered")
        }
        set{
            UserDefaults.standard.set(newValue, forKey: "isAppRatingPopupAnswered")
            UserDefaults.standard.synchronize()
            
            ///Notify delegates about changes
            delegates |> {
                delegate in
                delegate.isAppRatingPopupAnsweredDidUpdateTo(newValue)
            }
        }
    }
    
    var appRatingPopupDismissCount: Int{
        get { UserDefaults.standard.integer(forKey: "appRatingPopupDismissCount") }
        set {
            UserDefaults.standard.set(newValue, forKey: "appRatingPopupDismissCount")
            UserDefaults.standard.synchronize()
            
            ///Notify delegates about changes
            delegates |> {
                delegate in
                delegate.appRatingPopupDismissCountDidUpdateTo(newValue)
            }
        }
    }
    
    ///Methods
    init() {
        registerInitialUserDefaults()
    }
    
    ///Register Inital Values
    func registerInitialUserDefaults(){
        UserDefaults.standard.register(defaults: ["themeType" : ThemeType.automaticLightDark.rawValue])
        UserDefaults.standard.register(defaults: ["highlightColor" : HighlightColor.orange.rawValue])
        UserDefaults.standard.register(defaults: ["sortBy" : SortBy.dateOfEvent.rawValue])
        UserDefaults.standard.register(defaults: ["sortingOrder" : SortingOrder.descending.rawValue])
        UserDefaults.standard.register(defaults: ["isAppRatingPopupAnswered" : false])
        UserDefaults.standard.register(defaults: ["appRatingPopupDismissCount" : 0])
        UserDefaults.standard.synchronize()
    }
}
