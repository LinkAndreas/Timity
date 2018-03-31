//
//  OutputBasicCell.swift
//  Timity
//
//  Created by Andreas Link on 1/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class OutputBasicCell: ThemeableTableViewCell {
    
    ///IBOutlets
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    ///Handle Theme customization
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Update Label Colors
        label.textColor = theme.textColor
    }
    
}

