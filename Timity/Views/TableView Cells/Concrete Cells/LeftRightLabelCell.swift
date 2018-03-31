//
//  LeftRightLabelCell.swift
//  Timity
//
//  Created by Andreas Link on 1/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class LeftRightLabelCell: ThemeableTableViewCell {

    ///IBOutlets
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightLabel: UILabel!
    
    ///Properties
    var viewModel:LeftRightLabelCellViewModel?{
        didSet{
            setupUI()
            viewModel?.delegate = self
        }
    }
    var normalColor:UIColor?
    var highlightColor:UIColor?
    
    private func setupUI(){
        leftLabel.text = viewModel?.leftText
        rightLabel.text = viewModel?.rightText
    }
    
    ///Handle Theme customization
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Remember colors
        normalColor = theme.textColor
        highlightColor = theme.highlightColor
        
        ///Update Label Colors
        leftLabel.textColor = theme.textColor
        rightLabel.textColor = theme.textColor
        leftLabel.backgroundColor = theme.backgroundColor
        rightLabel.backgroundColor = theme.backgroundColor
    }

}

extension LeftRightLabelCell:LeftRightLabelCellViewModelDelegate{
    func leftTextDidChangeTo(_ leftText: String) {
        leftLabel.text = leftText
    }
    
    func rightTextDidChangeTo(_ rightText: String) {
        rightLabel.text = rightText
    }
    
    func statusDidChangeTo(_ status: RightLabelStatus) {
        switch status{
        case .normal:
            self.rightLabel.textColor = self.normalColor
        case .highlighted:
            self.rightLabel.textColor = self.highlightColor
        }
    }
}
