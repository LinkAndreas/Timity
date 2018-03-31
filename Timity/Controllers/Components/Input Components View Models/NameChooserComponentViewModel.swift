//
//  NameChooserComponentViewModel.swift
//  Timity
//
//  Created by Andreas Link on 2/11/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

class NameChooserComponentViewModel {
    var title:String
    var footer:String
    
    var result:String{
        return cellViewModel.name
    }
    weak var delegate:ComponentViewModelDelegate?
    
    ///Cell View Models
    var cellViewModel:NameCellViewModel
    
    init(title:String, footer:String, name:String) {
        self.title = title
        self.footer = footer
        self.cellViewModel = NameCellViewModel(name: name)
        self.cellViewModel.componentDelegate = self
    }
    
    func numberOfRowsIn(section:Int)->Int{
        return 1
    }
    
    func heightForRowAt(indexPath:IndexPath)->Float{
        return 44.0
    }
    
    func activate(){
        cellViewModel.activate()
    }
    
    func deactivate(){
        cellViewModel.deactivate()
    }
}

extension NameChooserComponentViewModel:ComponentViewModelDelegate{
    func resultDidChange() {
        delegate?.resultDidChange()
    }
}
