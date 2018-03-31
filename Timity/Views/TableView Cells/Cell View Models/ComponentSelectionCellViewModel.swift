//
//  ComponentSelectionCellViewModel.swift
//  Timity
//
//  Created by Andreas Link on 1/23/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

protocol ComponentSelectionCellViewModelDelegate:class {
    func componentNameDidChangeTo(_ componentName:String)
    func selectedValueDidChangeTo(_ selectedValue:Int)
    func textFieldDidBecomeActive()
    func textFieldDidBecomeInactive()
}

extension ComponentSelectionCellViewModelDelegate{
    func selectedValueDidChangeTo(_ selectedValue:Int){}
}

class ComponentSelectionCellViewModel:CellViewModel{
    weak var delegate:ComponentSelectionCellViewModelDelegate?
    var componentTag:Int
    var componentName:String{
        didSet{
            delegate?.componentNameDidChangeTo(componentName)
        }
    }
    var selectedValue:Int{
        didSet{
            delegate?.selectedValueDidChangeTo(selectedValue)
        }
    }
    var nextButtonCallback:((Int)->())?
    var previousButtonCallback:((Int)->())?
    
    init(componentTag:Int, componentName:String) {
        self.componentTag = componentTag
        self.componentName = componentName
        self.selectedValue = 0
    }
    
    func activate(){
        delegate?.textFieldDidBecomeActive()
    }
    
    func deactivate(){
        delegate?.textFieldDidBecomeInactive()
    }
}
