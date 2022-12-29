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
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let textColor: UIColor
    let lightTextColor: UIColor
    let navigationBarColor: UIColor
    let separatorColor: UIColor
    let shadowColor: UIColor
    let logoColor: UIColor
    let userInterfaceStyle: UIUserInterfaceStyle
    let activityIndicatorStyle: UIActivityIndicatorView.Style
}

extension Theme {
    var highlightColor: UIColor {
        let isDark: Bool

        switch Settings.shared.themeType {
        case .light:
            isDark = false

        case .dark, .black:
            isDark = true

        case .automaticLightDark, .automaticLightBlack:
            isDark = UIWindowScene.app.traitCollection.userInterfaceStyle == .dark
        }

        if isDark {
            switch Settings.shared.highlightColor {
            case .red:
                return UIColor(hex:"#F62F38")!
            case .orange:
                return UIColor(hex:"#f77f00")!
            case .yellow:
                return UIColor(hex:"#F9CE20")!
            case .green:
                return UIColor(hex:"#08a045")!
            case .tealBlue:
                return UIColor(hex:"#6CC7F9")!
            case .blue:
                return UIColor(hex:"#008dd5")!
            case .purple:
                return UIColor(hex:"#615aa1")!
            case .pink:
                return UIColor(hex:"#F61459")!
            }
        } else {
            switch Settings.shared.highlightColor {
            case .red:
                return UIColor(hex:"#F62F38")!
            case .orange:
                return UIColor(hex:"#f56416")!
            case .yellow:
                return UIColor(hex:"#ffb001")!
            case .green:
                return UIColor(hex:"#08a045")!
            case .tealBlue:
                return UIColor(hex:"#6CC7F9")!
            case .blue:
                return UIColor(hex:"#008dd5")!
            case .purple:
                return UIColor(hex:"#930581")!
            case .pink:
                return UIColor(hex:"#F61459")!
            }
        }
    }
}
