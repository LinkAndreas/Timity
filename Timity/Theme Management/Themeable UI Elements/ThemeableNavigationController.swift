//
//  ThemeableNavigationController.swift
//  Timity
//
//  Created by Andreas Link on 02.01.22.
//  Copyright © 2022 Andreas Link. All rights reserved.
//

import UIKit

class ThemeableNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()

        updateAccordingToTheme(ThemeManager.shared.currentTheme)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        ///Register to be notified about theme changes
        if !ThemeManager.shared.delegates.containsDelegate(self){
            ThemeManager.shared.delegates.addDelegate(self)
        }
    }

    ///Update the UI according to the given theme
    func updateAccordingToTheme(_ theme:Theme) {}
}

extension ThemeableNavigationController:ThemeManagerDelegate{
    func currentThemeDidChangeTo(_ theme: Theme) {
        updateAccordingToTheme(theme)
    }
}
