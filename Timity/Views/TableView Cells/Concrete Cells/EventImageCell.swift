//
//  EventImageCell.swift
//  Timity
//
//  Created by Andreas Link on 3/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class EventImageCell: ThemeableTableViewCell {

    ///IBOutlets
    @IBOutlet weak var eventImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        setupUI()
    }
    
    private func setupUI(){
        eventImageView.contentMode = .scaleAspectFill
        eventImageView.layer.borderWidth = 2.0
        eventImageView.layer.masksToBounds = false
        eventImageView.clipsToBounds = true
        eventImageView.layer.cornerRadius = eventImageView.frame.height/2
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Setup eventImageView border color
        eventImageView.layer.borderColor = theme.lightTextColor.cgColor
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
