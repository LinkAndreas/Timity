//
//  ImageChooserComponent.swift
//  Timity
//
//  Created by Andreas Link on 2/11/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation
import UIKit

class ImageChooserComponent {
    
    ///Properties
    var viewModel:ImageChooserComponentViewModel
    private var tableView:UITableView
    
    ///Result
    func result()->Data?{
        return viewModel.result
    }
    
    ///Initialization
    init(title:String, footer:String, image:Data?, tableView:UITableView) {
        ///Setup Model
        viewModel = ImageChooserComponentViewModel(title:title, footer: footer, imageData:image)
        self.tableView = tableView
    }
}

extension ImageChooserComponent:Component{
    
    func numberOfRowsInSection(section: Int) -> Int {
        return viewModel.numberOfRowsIn(section:section)
    }
    
    func resignFirstResponder() {

    }
    
    func titleForHeader() -> String {
        return viewModel.title
    }
    
    func titleForFooter() -> String {
        return viewModel.footer
    }
    
    func cellForRowAt(indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ImageCell.self), for: indexPath) as! ImageCell
        cell.viewModel = viewModel.cellViewModel
        cell.selectionStyle = .none
        return cell
    }
    
    func didSelectRowAt(indexPath: IndexPath, tableView: UITableView) {
        return
    }
    
    func shouldScrollToCell(indexPath:IndexPath, tableView:UITableView)-> Bool {
        return false
    }
}
