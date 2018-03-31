//
//  ComponentsChooserComponent.swift
//  Timity
//
//  Created by Andreas Link on 1/13/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation
import UIKit

class ComponentsChooserComponent:NSObject{
    
    ///Properties
    var viewModel:ComponentsChooserComponentViewModel
    private var tableView:UITableView
    
    ///Keyboard Properties
    let keyBoardAccessoryView = UIToolbar()
    lazy var doneButton = UIBarButtonItem(barButtonSystemItem: .done,
                                          target: self, action: #selector(doneButtonPressed(_:)))
    lazy var nextButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem(rawValue: 106)!,
                                          target: self, action: #selector(nextButtonPressed(_:)))
    lazy var previousButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem(rawValue: 105)!,
                                              target: self, action: #selector(previousButtonPressed(_:)))
    
    ///Result
    func result()->(comps:IntDateComponents,isAdding:Bool){
        return viewModel.result
    }
    
    ///Initialization
    init(title:String, footer:String, tableView:UITableView) {
        self.viewModel = ComponentsChooserComponentViewModel(title:title, footer: footer)
        self.tableView = tableView
        super.init()
        setupKeyboardInput()
        updateAccordingToTheme(ThemeManager.shared.currentTheme)
        
        ///Register to be notified about theme changes
        if !ThemeManager.shared.delegates.containsDelegate(self){
            ThemeManager.shared.delegates.addDelegate(self)
        }
    }
    
    deinit {
        //Deregister from theme changes
        ThemeManager.shared.delegates.removeDelegate(self)
    }
    
    func updateAccordingToTheme(_ theme: Theme) {
        ///Set button color to highlight color
        doneButton.tintColor = theme.highlightColor
        nextButton.tintColor = theme.highlightColor
        previousButton.tintColor = theme.highlightColor
        
        ///Set keyboard color
        keyBoardAccessoryView.barTintColor = theme.backgroundColor
    }
    
    private func setupKeyboardInput(){
        
        ///Setup Keyboard Accessory View
        keyBoardAccessoryView.sizeToFit()
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        
        ///Set Space between next/previous button
        fixedSpace.width = 20.0
        
        ///Configure Toolbar (Accessory Input) Layout
        keyBoardAccessoryView.items = [previousButton,
                                       fixedSpace,
                                       nextButton,
                                       flexibleSpace,
                                       doneButton]
    }
}

extension ComponentsChooserComponent:Component{
    
    func numberOfRowsInSection(section: Int) -> Int {
        return 7
    }
    
    func heightForRowAt(indexPath: IndexPath, tableView:UITableView) -> CGFloat {
        return 44.0
    }
    
    func titleForHeader() -> String {
        return viewModel.title
    }
    
    func titleForFooter() -> String {
        return viewModel.footer
    }
    
    func cellForRowAt(indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
        
        switch viewModel.cellTypeForCellAt(row: indexPath.row) {
        case .addOrSubtract(let addOrSubtractCellViewModel):
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: AddOrSubtractCell.self), for: indexPath) as! AddOrSubtractCell
            cell.viewModel = addOrSubtractCellViewModel
            cell.addOrSubtractSegmentedControl.removeTarget(nil, action: nil, for: .allEvents)
            cell.addOrSubtractSegmentedControl.addTarget(self, action: #selector(ComponentsChooserComponent.changeOperationType), for: .valueChanged)
            return cell
        case .componentChooser(let componentChooserCellViewModel):
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ComponentSelectionCell.self), for: indexPath) as! ComponentSelectionCell
            cell.viewModel = componentChooserCellViewModel
            cell.valueTextField.delegate = self
            cell.valueTextField.removeTarget(nil, action: nil, for: .allEvents)
            cell.valueTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
            cell.valueTextField.inputAccessoryView = keyBoardAccessoryView
            cell.selectionStyle = .none
            return cell
        }
    }
    
    func didSelectRowAt(indexPath: IndexPath, tableView: UITableView) {
        switch viewModel.cellTypeForCellAt(row: indexPath.row) {
        case .addOrSubtract(_ ):
            return
        case .componentChooser(_):
            guard let cell = viewModel.cellViewModelForCellAt(row: indexPath.row) as? ComponentSelectionCellViewModel else { return }
            viewModel.activate(row:indexPath.row)
            viewModel.textFieldTag = cell.componentTag
        }
    }
    
    func resignFirstResponder() {
        viewModel.deactivate()
    }
    
    func shouldHighlightRowAt(indexPath: IndexPath, tableView: UITableView) -> Bool {
        switch viewModel.cellTypeForCellAt(row: indexPath.row) {
        case .addOrSubtract(_ ):
            return false
        case .componentChooser(_):
            return true
        }
    }
}

extension ComponentsChooserComponent:ThemeManagerDelegate{
    func currentThemeDidChangeTo(_ theme: Theme) {
        updateAccordingToTheme(theme)
    }
}

//MARK: Keyboard toolbar actions
extension ComponentsChooserComponent{
    
    @objc func doneButtonPressed(_ sender: Any){
        viewModel.deactivate()
    }
    
    @objc func nextButtonPressed(_ sender: Any){
        viewModel.nextTextField()
    }
    
    @objc func previousButtonPressed(_ sender: Any){
        viewModel.previousTextField()
    }
}

extension ComponentsChooserComponent{
    @objc func changeOperationType(sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            viewModel.isAdding = true
        case 1:
            viewModel.isAdding = false
        default:
            break
        }
    }
}

extension ComponentsChooserComponent: UITextFieldDelegate{
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        ///prevent any input other than "0123456789"
        let inverseSet = NSCharacterSet(charactersIn:"0123456789").inverted
        let components = string.components(separatedBy: inverseSet)
        return string == components.joined(separator: "")
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        viewModel.textFieldTag = textField.tag
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.isUserInteractionEnabled = false
        saveTextFieldValue(textField)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool{
        viewModel.deactivate()
        return true
    }
    
    @objc func textFieldDidChange(textField: UITextField) {
        saveTextFieldValue(textField)
    }
    
    private func saveTextFieldValue(_ textField:UITextField){
        guard let text = textField.text else {return}
        let selectedValue = Int(text) ?? 0
        viewModel.updateSelectedValue(selectedValue)
    }
}
