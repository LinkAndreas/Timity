//
//  Component.swift
//  Timity
//
//  Created by Andreas Link on 1/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation
import UIKit

protocol ComponentViewModelDelegate:class {
    func resultDidChange()
}

protocol Component{
    ///Business Logic
    func resignFirstResponder()
    func numberOfRowsInSection(section:Int)->Int
    func heightForRowAt(indexPath:IndexPath, tableView:UITableView)->CGFloat
    func titleForHeader()->String
    func titleForFooter()->String
    func cellForRowAt(indexPath:IndexPath, tableView:UITableView)->UITableViewCell
    func didSelectRowAt(indexPath:IndexPath, tableView:UITableView)
    func shouldHighlightRowAt(indexPath:IndexPath, tableView:UITableView)->Bool
    func shouldScrollToCell(indexPath:IndexPath, tableView:UITableView)->Bool
    func shouldScrollToNextCell(indexPath:IndexPath, tableView:UITableView)->Bool
    func updateComponent()
}

///Declare optional methods
extension Component{
    func resignFirstResponder(){}
    func shouldHighlightRowAt(indexPath:IndexPath, tableView:UITableView)->Bool{ return true }
    func shouldScrollToCell(indexPath:IndexPath, tableView:UITableView)->Bool{ return true }
    func shouldScrollToNextCell(indexPath:IndexPath, tableView:UITableView)->Bool{ return false }
    func updateComponent(){}
}
