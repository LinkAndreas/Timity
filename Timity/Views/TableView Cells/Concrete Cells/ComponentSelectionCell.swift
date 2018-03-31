//
//  ComponentSelectionCell.swift
//  Timity
//
//  Created by Andreas Link on 1/13/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

protocol ComponentSelectionCellDelegate:class {
    func nextButtonPressed(tag:Int)
    func previousButtonPressed(tag:Int)
}

class ComponentSelectionCell: ThemeableTableViewCell {
    
    ///IBOutlets
    @IBOutlet weak var componentNameLabel: UILabel!
    @IBOutlet weak var valueTextField: UITextField!
    
    ///Properties
    weak var delegate:ComponentSelectionCellDelegate?
    var viewModel:ComponentSelectionCellViewModel?{
        didSet{
            setupUI()
            viewModel?.delegate = self
        }
    }
    
    private func setupUI(){
        guard let viewModel = viewModel else {return}
        componentNameLabel.text = viewModel.componentName
        valueTextField.isUserInteractionEnabled = false
        valueTextField.tag = viewModel.componentTag
        valueTextField.keyboardType = .numberPad
        valueTextField.returnKeyType = .done
    }
    
    ///Handle Theme customization
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)

        ///Set Label Color
        componentNameLabel?.textColor = theme.textColor
        componentNameLabel?.backgroundColor = theme.backgroundColor
        valueTextField?.textColor = theme.textColor
        valueTextField?.backgroundColor = theme.backgroundColor
        
        ///Set placeholder color
        let componentPlaceholderString = NSLocalizedString("input_time_calculator_components_placeholder", comment: "A placeholder value shown if no input is provided for the respective component.")
        valueTextField?.attributedPlaceholder = NSAttributedString(string:componentPlaceholderString,
                                                                   attributes:[NSAttributedStringKey.foregroundColor: theme.lightTextColor])
    }
}

extension ComponentSelectionCell:ComponentSelectionCellViewModelDelegate{
    
    func componentNameDidChangeTo(_ componentName: String) {
        componentNameLabel.text = componentName
    }
    
    func textFieldDidBecomeActive() {
        valueTextField.isUserInteractionEnabled = true
        valueTextField.becomeFirstResponder()
    }
    
    func textFieldDidBecomeInactive() {
        valueTextField.isUserInteractionEnabled = false
        valueTextField.resignFirstResponder()
    }
}

