//
//  EventWithImageCell.swift
//  Timity
//
//  Created by Andreas Link on 01/10/2016.
//  Copyright © 2016 Andreas Link. All rights reserved.
//

import UIKit

class EventWithImageCell: ThemeableTableViewCell {

    ///IBOutlets
    @IBOutlet weak var imageEventView: UIImageView!
    @IBOutlet weak var eventView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    @IBOutlet weak var explanationLabel: UILabel!
    
    ///Properties
    var viewModel:EventCellViewModel?{
        didSet{
            updateLabels()
        }
    }
    
    private func updateLabels(){
        guard let viewModel = viewModel else {return}
        titleLabel.text = viewModel.title
        bodyLabel.text = viewModel.body
        explanationLabel.text = viewModel.explanation
        if let imageData = viewModel.imageData{
            imageEventView.image = UIImage(data:imageData)
        }
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Set clear backgroundColor
        backgroundColor = theme.backgroundColor
        
        ///Configure label font
        titleLabel.font = UIFont.preferredFont(forTextStyle:.headline)
        bodyLabel.font = UIFont.preferredFont(forTextStyle:.subheadline)
        explanationLabel.font = UIFont.preferredFont(forTextStyle:.caption1)
        
        ///Configure label colors
        titleLabel.textColor = theme.textColor
        bodyLabel.textColor = theme.textColor
        explanationLabel.textColor = theme.textColor
        
        ///Set imageView content mode
        imageEventView.contentMode = .scaleAspectFill
        imageEventView.clipsToBounds = true
    }

}
