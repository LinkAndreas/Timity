//
//  NameCellViewModel.swift
//  Timity
//
//  Created by Andreas Link on 2/11/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation


protocol NameCellViewModelDelegate:class {
    func nameDidChange(name:String)
    func textFieldDidBecomeActive()
    func textFieldDidBecomeInactive()
}

extension NameCellViewModelDelegate {
    func nameDidChange(name:String){}
}

class NameCellViewModel:CellViewModel{
    weak var delegate:NameCellViewModelDelegate?
    weak var componentDelegate:ComponentViewModelDelegate?
    var name:String{
        didSet{
            delegate?.nameDidChange(name: name)
            componentDelegate?.resultDidChange()
        }
    }
    
    init(name:String) {
        self.name = name
    }
    
    func activate(){
        delegate?.textFieldDidBecomeActive()
    }
    
    func deactivate(){
        delegate?.textFieldDidBecomeInactive()
    }
    
}
