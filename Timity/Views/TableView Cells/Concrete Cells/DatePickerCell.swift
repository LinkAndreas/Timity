//
//  DatePickerCell.swift
//  Timity
//
//  Created by Andreas Link on 1/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class DatePickerCell: ThemeableTableViewCell {
    ///Properties
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var viewModel:DatePickerCellViewModel?{
        didSet{
            viewModel?.delegate = self
            configureDatePicker()
        }
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        appDelegate.picker.setValue(false, forKey: "highlightsToday")
        appDelegate.picker.setValue(theme.textColor, forKeyPath: "textColor")
    }
    
    func configureDatePicker(){
        guard let viewModel = viewModel else { return }
        if !viewModel.isHidden{
            ///Cleanup datePicker before reusing it
            
            ///->Remove any previous targets !!!
            appDelegate.picker.removeTarget(nil, action: nil, for: .allEvents)
            ///->Remove the reusable picker from any previous superview
            appDelegate.picker.removeFromSuperview()
            
            ///Set datePicker mode
            appDelegate.picker.date = viewModel.date
            appDelegate.picker.datePickerMode = viewModel.datePickerMode
            
            ///Add Picker to cell
            contentView.addSubview(appDelegate.picker)
            appDelegate.picker.adaptSizeOfView(contentView)
        }
    }
}

extension DatePickerCell:DatePickerCellViewModelDelegate{
    func isHiddenDidChangeTo(_ isHidden: Bool) {
        configureDatePicker()
    }
}
