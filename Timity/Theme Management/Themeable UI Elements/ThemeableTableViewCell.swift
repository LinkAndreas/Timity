//
//  ThemeableTableViewCell.swift
//  Timity
//
//  Created by Andreas Link on 1/20/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class ThemeableTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        updateAccordingToTheme(ThemeManager.shared.currentTheme)
        
        ///Register to be notified about theme changes
        if !ThemeManager.shared.delegates.containsDelegate(self){
            ThemeManager.shared.delegates.addDelegate(self)
        }
    }
    
    deinit {
        ///Deregister from theme changes
        ThemeManager.shared.delegates.removeDelegate(self)
    }
    
    ///Update the UI according to the given theme
    func updateAccordingToTheme(_ theme:Theme){
        backgroundColor = theme.backgroundColor
    }
}

extension ThemeableTableViewCell:ThemeManagerDelegate{
    func currentThemeDidChangeTo(_ theme: Theme) {
        updateAccordingToTheme(theme)
    }
}
