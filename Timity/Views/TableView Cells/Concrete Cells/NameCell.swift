//
//  NameCell.swift
//  Timity
//
//  Created by Andreas Link on 2/11/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class NameCell: ThemeableTableViewCell {
    
    ///IBOutlets
    @IBOutlet weak var nameTextField: UITextField!
    
    ///Properties
    var viewModel:NameCellViewModel?{
        didSet{
            setupUI()
            viewModel?.delegate = self
        }
    }
    
    private func setupUI(){
        nameTextField.removeTarget(nil, action: nil, for: .allEvents)
        nameTextField.addTarget(self, action: #selector(textChanged(textField:)), for: .editingChanged)
        nameTextField.isUserInteractionEnabled = false
        nameTextField.delegate = self
        nameTextField.text = viewModel?.name
        nameTextField.returnKeyType = .done
    }
    
    ///Handle Theme customization
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Update Label Colors
        nameTextField.textColor = theme.textColor
        nameTextField.backgroundColor = theme.backgroundColor
        
        ///Set placeholder
        let eventName = NSLocalizedString("input_event_list_event_name_chooser_placeholder", comment: "Placeholder text for specifying the name of the event.")
        nameTextField.attributedPlaceholder = NSAttributedString(string:eventName, attributes:[NSAttributedStringKey.foregroundColor: theme.lightTextColor])
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        //Activate valueTextField as soon as tableCell gets pressed
        nameTextField.isUserInteractionEnabled = true
        nameTextField.becomeFirstResponder()
    }
    
    @objc func textChanged(textField:UITextField){
        guard let text = textField.text else {return}
        viewModel?.name = text
    }
    
}

extension NameCell: UITextFieldDelegate{
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        nameTextField.isUserInteractionEnabled = false
        guard let newName = textField.text else {return}
        viewModel?.name = newName
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool{
        nameTextField.isUserInteractionEnabled = false
        textField.resignFirstResponder()
        return true
    }
}

extension NameCell:NameCellViewModelDelegate{
    func textFieldDidBecomeActive() {
        nameTextField.isUserInteractionEnabled = true
        nameTextField.becomeFirstResponder()
    }
    
    func textFieldDidBecomeInactive() {
        nameTextField.isUserInteractionEnabled = false
        nameTextField.resignFirstResponder()
    }
}
