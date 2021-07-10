//
//  DatePickerCellViewModel.swift
//  Timity
//
//  Created by Andreas Link on 1/24/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation
import UIKit

protocol DatePickerCellViewModelDelegate:class {
    func isHiddenDidChangeTo(_ isHidden:Bool)
}

class DatePickerCellViewModel:CellViewModel{
    weak var delegate:DatePickerCellViewModelDelegate?
    
    var isHidden:Bool{
        didSet{
            delegate?.isHiddenDidChangeTo(isHidden)
        }
    }
    var date:Date
    var datePickerMode: UIDatePicker.Mode
    
    init(date:Date, datePickerMode: UIDatePicker.Mode) {
        self.isHidden = true
        self.date = date
        self.datePickerMode = datePickerMode
    }
}
