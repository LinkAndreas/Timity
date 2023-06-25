
//
//  ActivityCell.swift
//  Timity
//
//  Created by Andreas Link on 26/09/2016.
//  Copyright © 2016 Andreas Link. All rights reserved.
//

import UIKit

class ActivityCell: ThemeableTableViewCell {
    
    ///Outlets
    @IBOutlet weak var titelLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    @IBOutlet weak var activityImageView: UIImageView!
    
    ///Properties
    var activity:Activity?{
        didSet{
            guard let activity = activity else {return}
            ///Configure accessability identifier
            self.accessibilityIdentifier = activity.accessabilityIdentifier
            
            ///Configure Labels
            titelLabel.text = activity.name
            bodyLabel.text = activity.description
            
            ///Configure activity icons as template
            activityImageView.contentMode = .scaleAspectFit
            activityImageView.image = UIImage(named: activity.imageName)?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        }
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Setup background colors
        backgroundColor = theme.backgroundColor
        
        ///Setup Text Colors
        titelLabel.textColor = theme.textColor
        bodyLabel.textColor = theme.textColor
        
        ///Setup tint colors
        activityImageView.tintColor = theme.highlightColor
    }
}
