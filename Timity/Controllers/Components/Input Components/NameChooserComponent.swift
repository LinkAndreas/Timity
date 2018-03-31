//
//  NameChooserComponent.swift
//  Timity
//
//  Created by Andreas Link on 2/11/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation
import UIKit

class NameChooserComponent {
    
    ///Properties
    var viewModel:NameChooserComponentViewModel
    private var tableView:UITableView
    
    ///Result
    func result()->String{
        return viewModel.result
    }
    
    ///Initialization
    init(title:String, footer:String, name:String, tableView:UITableView) {
        ///Setup Model
        viewModel = NameChooserComponentViewModel(title:title, footer: footer, name:name)
        self.tableView = tableView
    }
}

extension NameChooserComponent:Component{
    
    func numberOfRowsInSection(section: Int) -> Int {
        return viewModel.numberOfRowsIn(section:section)
    }
    
    func resignFirstResponder() {
        viewModel.deactivate()
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
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: NameCell.self), for: indexPath) as! NameCell
        cell.viewModel = viewModel.cellViewModel
        cell.selectionStyle = .none
        return cell
    }
    
    func didSelectRowAt(indexPath: IndexPath, tableView: UITableView) {
        return
    }
}
