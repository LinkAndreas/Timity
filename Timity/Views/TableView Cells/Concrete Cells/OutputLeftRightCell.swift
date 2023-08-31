//
//  OutputLeftRightCell.swift
//  Timity
//
//  Created by Andreas Link on 3/13/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class OutputLeftRightCell: ThemeableTableViewCell {

    ///IBOutlets
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    ///Handle Theme customization
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Update Label Colors
        leftLabel.textColor = theme.textColor
        rightLabel.textColor = theme.textColor
    }

}
