//
//  EventChooserComponent.swift
//  Timity
//
//  Created by Andreas Link on 1/13/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation
import UIKit

class EventChooserComponent {
    
    ///Properties
    var viewModel:EventChooserComponentViewModel
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var tableView:UITableView
    
    ///Result
    func result()->Date{
        return viewModel.result
    }
    
    ///Initialization
    init(title:String, footer:String, date:Date, time:Date, tableView:UITableView) {
        ///Setup Model
        viewModel = EventChooserComponentViewModel(title:title, footer: footer, date: date, time: time)
        self.tableView = tableView
    }
}

extension EventChooserComponent:Component{
    
    func numberOfRowsInSection(section: Int) -> Int {
        return viewModel.numberOfRowsIn(section:section)
    }
    
    func resignFirstResponder() {
        dismissPicker()
    }
    
    func heightForRowAt(indexPath: IndexPath, tableView:UITableView) -> CGFloat {
        return CGFloat(viewModel.heightForRowAt(indexPath:indexPath))
    }
    
    func titleForHeader() -> String {
        return viewModel.title
    }
    
    func titleForFooter() -> String {
        return viewModel.footer
    }
    
    func cellForRowAt(indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
        
        switch viewModel.cellTypeForCellAt(indexPath: indexPath) {
        case .dateLabel(let labelCellViewModel), .timeLabel(let labelCellViewModel):
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: LeftRightLabelCell.self), for: indexPath) as! LeftRightLabelCell
            cell.viewModel = labelCellViewModel
            return cell
        case .datePicker(let pickerCellViewModel), .timePicker(let pickerCellViewModel):
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: DatePickerCell.self), for: indexPath) as! DatePickerCell
            cell.viewModel = pickerCellViewModel
            cell.selectionStyle = .none
            return cell
        }
    }
    
    func didSelectRowAt(indexPath: IndexPath, tableView: UITableView) {
        
        ///Check whether an associated picker cell needs to be shown
        let typeOfSelectedCell = viewModel.cellTypeForCellAt(indexPath: indexPath)
        
        switch typeOfSelectedCell {
        case .dateLabel(_):
            switch viewModel.state{
            case .onlyDatePickerVisible:
                dismissPicker()
            case .onlyTimePickerVisible, .bothHidden:
                viewModel.state = .onlyDatePickerVisible
                observeDatePickerChanges()
            }
        case .timeLabel(_):
            switch viewModel.state{
            case .onlyTimePickerVisible:
                dismissPicker()
            case .onlyDatePickerVisible, .bothHidden:
                viewModel.state = .onlyTimePickerVisible
                observeTimePickerChanges()
            }
        case .datePicker(_),.timePicker(_):
            return
        }
    }
    
    func shouldHighlightRowAt(indexPath: IndexPath, tableView: UITableView) -> Bool {
        let typeOfSelectedCell = viewModel.cellTypeForCellAt(indexPath: indexPath)
        
        switch typeOfSelectedCell {
        case .dateLabel(_), .timeLabel(_):
            return true
        case .datePicker(_),.timePicker(_):
            return false
        }
    }
    
    func shouldScrollToNextCell(indexPath:IndexPath, tableView:UITableView)-> Bool {
        let typeOfSelectedCell = viewModel.cellTypeForCellAt(indexPath: indexPath)
        
        switch typeOfSelectedCell {
        case .dateLabel(_), .timeLabel(_):
            switch viewModel.state{
            case .bothHidden:
                return false
            case .onlyDatePickerVisible, .onlyTimePickerVisible:
                return true
            }
        case .datePicker(_),.timePicker(_):
            return false
        }
    }
    
    @objc func dateValueChanged(picker: UIDatePicker){
        viewModel.date = picker.date
    }
    
    @objc func timeValueChanged(picker: UIDatePicker){
        viewModel.time = picker.date
    }
    
    private func observeDatePickerChanges(){
        appDelegate.picker.addTarget(self, action: #selector(dateValueChanged(picker:)), for: .valueChanged)
    }
    
    private func observeTimePickerChanges(){
        appDelegate.picker.addTarget(self, action: #selector(timeValueChanged(picker:)), for: .valueChanged)
    }
    
    private func dismissPicker(){
        viewModel.state = .bothHidden
        appDelegate.picker.removeTarget(nil, action: nil, for: .allEvents)
        appDelegate.picker.removeFromSuperview()
    }
}
