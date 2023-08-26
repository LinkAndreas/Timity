//
//  Theme.swift
//  Timity
//
//  Created by Andreas Link on 27/09/2016.
//  Copyright © 2016 Andreas Link. All rights reserved.
//

import UIKit
import MulticastDelegate

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
    var currentTheme: Theme {
        switch Settings.shared.themeType {
        case .light:
            return lightTheme

        case .dark:
            return darkTheme

        case .black:
            return blackTheme

        case .automaticLightDark:
            return UIWindowScene.active.traitCollection.userInterfaceStyle == .dark ? darkTheme : lightTheme

        case .automaticLightBlack:
            return UIWindowScene.active.traitCollection.userInterfaceStyle == .dark ? blackTheme : lightTheme
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
    private var darkTheme: Theme{
        return Theme(
            backgroundColor: UIColor(hex: "#222222")!,
            foregroundColor: UIColor(hex: "#333333")!,
            textColor: .white,
            lightTextColor: .gray,
            navigationBarColor: UIColor(hex:"#1F1F1F")!,
            separatorColor: .white,
            shadowColor: UIColor.black,
            logoColor: .gray,
            userInterfaceStyle: .dark,
            activityIndicatorStyle: .medium
        )
    }
    
    private var lightTheme: Theme{
        return Theme(
            backgroundColor: .white,
            foregroundColor: UIColor(hex: "#f9f9f9")!,
            textColor: .black,
            lightTextColor: .lightGray,
            navigationBarColor: UIColor(hex: "#F4F4F4")!,
            separatorColor: .black,
            shadowColor: UIColor(hex: "#3b3b3b")!,
            logoColor: .darkGray,
            userInterfaceStyle: .light,
            activityIndicatorStyle: .medium
        )
    }

    private var blackTheme: Theme {
        return Theme(
            backgroundColor: .black,
            foregroundColor: UIColor(hex: "#222222")!,
            textColor: .white,
            lightTextColor: .gray,
            navigationBarColor: .black,
            separatorColor: .white,
            shadowColor: .black,
            logoColor: .gray,
            userInterfaceStyle: .dark,
            activityIndicatorStyle: .medium
        )
    }
    
    ///Avoid instance creation of `UITheme` (according to singleton pattern)
    private init() {
        registerObservers()
    }

    deinit {
        removeObservers()
    }
    
    ///Update Keyboard
    private func updateKeyboard(theme:Theme){
        ///Set keyboard color according to theme
        switch Settings.shared.themeType {
        case .light:
            UITextField.appearance().keyboardAppearance = .light

        case .dark, .black:
            UITextField.appearance().keyboardAppearance = .dark

        case .automaticLightDark, .automaticLightBlack:
            if UIWindowScene.active.traitCollection.userInterfaceStyle == .dark {
                UITextField.appearance().keyboardAppearance = .dark
            } else {
                UITextField.appearance().keyboardAppearance = .light
            }
        }
    }
}

extension ThemeManager {
    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleWindowDidBecomeVisibleNotification(notification:)),
            name: UIWindow.didBecomeVisibleNotification,
            object: nil
        )
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func handleWindowDidBecomeVisibleNotification(notification: Notification) {
        guard let window = notification.object as? UIWindow else { return }

        window.currentThemeDidChangeTo(ThemeManager.shared.currentTheme)

        if !ThemeManager.shared.delegates.containsDelegate(window) {
            ThemeManager.shared.delegates.addDelegate(window)
        }
    }
}

extension UIWindow: ThemeManagerDelegate {
    func currentThemeDidChangeTo(_ theme: Theme) {
        tintColor = theme.highlightColor

        switch Settings.shared.themeType {
        case .light:
            overrideUserInterfaceStyle = .light
            UIApplication.shared.statusBarStyle = .darkContent

        case .dark:
            overrideUserInterfaceStyle = .dark
            UIApplication.shared.statusBarStyle = .lightContent

        case .black:
            overrideUserInterfaceStyle = .dark
            UIApplication.shared.statusBarStyle = .lightContent

        case .automaticLightDark, .automaticLightBlack:
            overrideUserInterfaceStyle = .unspecified
            UIApplication.shared.statusBarStyle = .default
        }
    }
}

extension ThemeManager {
    func userInterfaceStyleChanged() {
        updateTheme()
    }
}
