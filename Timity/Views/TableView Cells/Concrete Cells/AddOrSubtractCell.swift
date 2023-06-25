//
//  AddOrSubtractCell.swift
//  Timity
//
//  Created by Andreas Link on 1/13/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

///Enum representing the type of operation
enum OperationType {
    case add
    case subtract
}

class AddOrSubtractCell: ThemeableTableViewCell {
    
    ///IBOutlets
    @IBOutlet weak var addOrSubtractSegmentedControl: UISegmentedControl!
    
    ///Properties
    var viewModel:AddOrSubtractCellViewModel?{
        didSet{
            setupUI()
            viewModel?.delegate = self
        }
    }
    
    private func setupUI(){
        ///Setup segmented control
        addOrSubtractSegmentedControl.setTitle(viewModel?.firstItem, forSegmentAt: 0)
        addOrSubtractSegmentedControl.setTitle(viewModel?.secondItem, forSegmentAt: 1)
        addOrSubtractSegmentedControl.selectedSegmentIndex = 0
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)

        addOrSubtractSegmentedControl.tintColor = theme.highlightColor
        addOrSubtractSegmentedControl.backgroundColor = theme.backgroundColor
    }
    
}

extension AddOrSubtractCell:AddOrSubtractCellViewModelDelegate{
    
}
