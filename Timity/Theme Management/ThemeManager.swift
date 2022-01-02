//
//  Theme.swift
//  Timity
//
//  Created by Andreas Link on 27/09/2016.
//  Copyright © 2016 Andreas Link. All rights reserved.
//

import Foundation
import UIKit
import MulticastDelegateSwift

protocol ThemeManagerDelegate {
    func currentThemeDidChangeTo(_ theme:Theme)
}

/**
 Handles the theme management within the application.
 */
class ThemeManager {
    ///The singleton instance provided by `Theme`.
    static var shared = ThemeManager()
    
    ///Delegates
    var delegates = MulticastDelegate<ThemeManagerDelegate>()
    
    ///The theme type to be used.
    var currentTheme:Theme{
        switch Settings.shared.themeType {
        case .black:
            return blackTheme
        case .dark:
            return darkTheme
        case .light:
            return lightTheme
        }
    }
    
    func updateTheme(){
        updateKeyboard(theme: currentTheme)
        
        ///Notify delegates about changes
        delegates |> {
            [weak self] delegate in
            guard let currentTheme = self?.currentTheme else {return}
            delegate.currentThemeDidChangeTo(currentTheme)
        }
    }
    
    ///Avalaible Themes
    private var blackTheme:Theme{
        return Theme(type: .black,
                     backgroundColor: .black,
                     textColor: .white,
                     lightTextColor: .gray,
                     navigationBarColor: .black,
                     separatorColor: .white,
                     logoColor: .gray,
                     statusBarStyle: .lightContent,
                     activityIndicatorStyle:.white)
    }
    private var darkTheme:Theme{
        return Theme(type: .dark,
                     backgroundColor: UIColor(hexString: "#222222")!,
                     textColor: .white,
                     lightTextColor: .gray,
                     navigationBarColor: UIColor(hexString:"#1F1F1F")!,
                     separatorColor: .white,
                     logoColor: .gray,
                     statusBarStyle: .lightContent,
                     activityIndicatorStyle:.white)
    }
    
    private var lightTheme:Theme{
        return Theme(type: .light,
                     backgroundColor: .white,
                     textColor: .black,
                     lightTextColor: .lightGray,
                     navigationBarColor: UIColor(hexString: "#F4F4F4")!,
                     separatorColor: .black,
                     logoColor: .darkGray,
                     statusBarStyle: .default,
                     activityIndicatorStyle:.gray)
    }
    
    ///Avoid instance creation of `UITheme` (according to singleton pattern)
    private init() {}
    
    ///Update Keyboard
    private func updateKeyboard(theme:Theme){
        ///Set keyboard color according to theme
        switch theme.type {
        case .black, .dark:
            UITextField.appearance().keyboardAppearance = .dark
        case .light:
            UITextField.appearance().keyboardAppearance = .light
        }
    }
}
