//
//  ThemeableSplitViewController.swift
//  Timity
//
//  Created by Andreas Link on 1/19/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class ThemeableSplitViewController: UISplitViewController {
    ///Set status bar style according to current theme
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return ThemeManager.shared.currentTheme.statusBarStyle
    }
}
