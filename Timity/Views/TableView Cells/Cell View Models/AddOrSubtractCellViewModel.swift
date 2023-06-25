//
//  AddOrSubtractCellViewModel.swift
//  Timity
//
//  Created by Andreas Link on 1/24/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

protocol AddOrSubtractCellViewModelDelegate: AnyObject {
    func firstItemDidChangeTo(_ firstItem: String)
    func secondItemDidChangeTo(_ firstItem: String)
    func selectedOperationTypeDidChangeTo(_ selectedOperationType:OperationType)
}

extension AddOrSubtractCellViewModelDelegate{
    func firstItemDidChangeTo(_ firstItem: String){}
    func secondItemDidChangeTo(_ firstItem: String){}
    func selectedOperationTypeDidChangeTo(_ selectedOperationType:OperationType){}
}

class AddOrSubtractCellViewModel:CellViewModel{
    weak var delegate:AddOrSubtractCellViewModelDelegate?
    var firstItem: String{
        didSet{
            delegate?.firstItemDidChangeTo(firstItem)
        }
    }
    var secondItem: String{
        didSet{
            delegate?.secondItemDidChangeTo(secondItem)
        }
    }
    var selectedOperationType:OperationType = .add{
        didSet{
            delegate?.selectedOperationTypeDidChangeTo(selectedOperationType)
        }
    }
    
    init(firstItem: String, secondItem: String) {
        self.firstItem = firstItem
        self.secondItem = secondItem
    }
}
