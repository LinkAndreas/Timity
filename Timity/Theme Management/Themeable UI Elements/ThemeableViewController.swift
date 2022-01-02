//
//  ThemeableViewController.swift
//  Timity
//
//  Created by Andreas Link on 1/19/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class ThemeableViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ///Setup large title Display mode
        navigationController?.navigationBar.prefersLargeTitles = true
        
        updateAccordingToTheme(ThemeManager.shared.currentTheme)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        ///Register to be notified about theme changes
        if !ThemeManager.shared.delegates.containsDelegate(self){
            ThemeManager.shared.delegates.addDelegate(self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    deinit {
        ///Deregister from theme changes
        ThemeManager.shared.delegates.removeDelegate(self)
    }
    
    ///Update the UI according to the given theme
    func updateAccordingToTheme(_ theme:Theme){
        ///Setup background color
        view.backgroundColor = theme.backgroundColor
        
        ///Update NavigationBar
        if let navigationBar = navigationController?.navigationBar{
            navigationBar.tintColor = theme.highlightColor
            navigationBar.barTintColor = theme.navigationBarColor
            navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor:theme.textColor]
            navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor:theme.textColor,
                                                      NSAttributedString.Key.font:UIFont.boldSystemFont(ofSize: 32.0)]
        }
        
        ///Update Status bar
        setNeedsStatusBarAppearanceUpdate()
    }
    
    ///Set status bar style according to current theme
    override var preferredStatusBarStyle: UIStatusBarStyle{
        return ThemeManager.shared.currentTheme.statusBarStyle
    }

}

extension ThemeableViewController:ThemeManagerDelegate{
    func currentThemeDidChangeTo(_ theme: Theme) {
        updateAccordingToTheme(theme)
    }
}
