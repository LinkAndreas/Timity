//
//  Theme.swift
//  Timity
//
//  Created by Andreas Link on 1/19/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

/**
 Determines the theme to be used within the app.
 */
struct Theme {
    let type: ThemeType
    let backgroundColor: UIColor
    var highlightColor: UIColor{
        let themeType = Settings.shared.themeType
        return Settings.shared.highlightColor.color(for: themeType)
    }
    let textColor: UIColor
    let lightTextColor: UIColor
    let navigationBarColor: UIColor
    let separatorColor: UIColor
    let logoColor: UIColor
    let statusBarStyle: UIStatusBarStyle
    let userInterfaceStyle: UIUserInterfaceStyle
    let activityIndicatorStyle: UIActivityIndicatorView.Style
}
