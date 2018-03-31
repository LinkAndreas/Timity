//
//  ThemeableView.swift
//  Timity
//
//  Created by Andreas Link on 3/18/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class ThemeableView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        ///Register to be notified about theme changes
        if !ThemeManager.shared.delegates.containsDelegate(self){
            ThemeManager.shared.delegates.addDelegate(self)
        }
        
        ///Initially update according to theme
        updateAccordingToTheme(ThemeManager.shared.currentTheme)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        ///Deregister from theme changes
        ThemeManager.shared.delegates.removeDelegate(self)
    }
    
    ///Update the UI according to the given theme
    func updateAccordingToTheme(_ theme:Theme){
        
        ///Setup background color
        self.backgroundColor = theme.backgroundColor
    }
}

extension ThemeableView:ThemeManagerDelegate{
    func currentThemeDidChangeTo(_ theme: Theme) {
        updateAccordingToTheme(theme)
    }
}
