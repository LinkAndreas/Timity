//
//  LeftRightLabelCellViewModel.swift
//  Timity
//
//  Created by Andreas Link on 1/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

enum RightLabelStatus {
    case normal
    case highlighted
}

protocol LeftRightLabelCellViewModelDelegate: AnyObject {
    func leftTextDidChangeTo(_ leftText:String)
    func rightTextDidChangeTo(_ rightText:String)
    func statusDidChangeTo(_ status:RightLabelStatus)
}

class LeftRightLabelCellViewModel:CellViewModel{
    weak var delegate:LeftRightLabelCellViewModelDelegate?
    var leftText:String{
        didSet{
            delegate?.leftTextDidChangeTo(leftText)
        }
    }
    var rightText:String{
        didSet{
            delegate?.rightTextDidChangeTo(rightText)
        }
    }
    var status:RightLabelStatus{
        didSet{
            delegate?.statusDidChangeTo(status)
        }
    }
    
    init(leftText:String, rightText:String) {
        self.leftText = leftText
        self.rightText = rightText
        self.status = .normal
    }
}
