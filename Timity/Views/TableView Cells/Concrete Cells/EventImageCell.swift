//
//  EventImageCell.swift
//  Timity
//
//  Created by Andreas Link on 3/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import SnapKit
import UIKit

class EventImageCell: ThemeableTableViewCell {
    ///IBOutlets
    @IBOutlet weak var eventImageView: UIImageView!
    
    private let imageSize = UIFontMetrics(forTextStyle: .headline)
        .scaledValue(for: 190)
    
    private var imageWidthConstraint: NSLayoutConstraint?
    
    override func awakeFromNib() {
        super.awakeFromNib()

        setupLayout()
        setupUI()
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            eventImageView.widthAnchor.constraint(equalToConstant: imageSize),
            eventImageView.heightAnchor.constraint(equalToConstant: imageSize)
        ])
    }
    
    private func setupUI(){
        eventImageView.layer.cornerRadius = imageSize/2.0
        eventImageView.contentMode = .scaleAspectFill
        eventImageView.layer.borderWidth = 2.0
        eventImageView.layer.masksToBounds = false
        eventImageView.clipsToBounds = true
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Setup eventImageView border color
        eventImageView.layer.borderColor = theme.lightTextColor.cgColor
    }
}
