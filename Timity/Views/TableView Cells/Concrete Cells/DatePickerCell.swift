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
    private var heightConstraint: NSLayoutConstraint?
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var viewModel:DatePickerCellViewModel?{
        didSet{
            viewModel?.delegate = self
            configureDatePicker()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        heightConstraint = contentView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint?.priority = .init(999)
        heightConstraint?.isActive = true
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)

        appDelegate.picker.setValue(theme.textColor, forKeyPath: "textColor")
        appDelegate.picker.preferredDatePickerStyle = .wheels
        appDelegate.picker.setValue(false, forKeyPath: "highlightsToday")
    }
    
    func configureDatePicker(){
        guard let viewModel = viewModel else { return }
        
        heightConstraint?.isActive = viewModel.isHidden
        
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
        
        if viewModel.isHidden {
            separatorInset = UIEdgeInsets(top: 0, left: 10000, bottom: 0, right: 0)
        } else {
            separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        }
    }
}

extension DatePickerCell:DatePickerCellViewModelDelegate{
    func isHiddenDidChangeTo(_ isHidden: Bool) {
        configureDatePicker()
    }
}
