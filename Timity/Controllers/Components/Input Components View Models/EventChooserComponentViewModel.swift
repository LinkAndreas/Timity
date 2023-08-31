//
//  EventChooserComponentViewModel.swift
//  Timity
//
//  Created by Andreas Link on 1/24/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

enum EventChooserState {
    case onlyDatePickerVisible
    case onlyTimePickerVisible
    case bothHidden
}

enum EventChooserCellType{
    case dateLabel(LeftRightLabelCellViewModel)
    case timeLabel(LeftRightLabelCellViewModel)
    case datePicker(DatePickerCellViewModel)
    case timePicker(DatePickerCellViewModel)
    
    func viewModel()->CellViewModel{
        switch self {
        case .dateLabel(let dateLabelCellViewModel):
            return dateLabelCellViewModel
        case .timeLabel(let timeLabelCellViewModel):
            return timeLabelCellViewModel
        case .datePicker(let datePickerCellViewModel):
            return datePickerCellViewModel
        case .timePicker(let timePickerCellViewModel):
            return timePickerCellViewModel
        }
    }
}

class EventChooserComponentViewModel {
    weak var delegate:ComponentViewModelDelegate?
    var title:String
    var footer:String
    
    var state:EventChooserState{
        didSet{
            switch state {
            case .onlyDatePickerVisible:
                datePickerCellViewModel.date = date
                datePickerCellViewModel.datePickerMode = .date
                
                datePickerCellViewModel.isHidden = false
                timePickerCellViewModel.isHidden = true
                
                dateLeftRightCellViewModel.status = .highlighted
                timeLeftRightCellViewModel.status = .normal
            case .onlyTimePickerVisible:
                timePickerCellViewModel.date = time
                timePickerCellViewModel.datePickerMode = .time
                
                datePickerCellViewModel.isHidden = true
                timePickerCellViewModel.isHidden = false
                
                dateLeftRightCellViewModel.status = .normal
                timeLeftRightCellViewModel.status = .highlighted
            case .bothHidden:
                datePickerCellViewModel.isHidden = true
                timePickerCellViewModel.isHidden = true
                
                dateLeftRightCellViewModel.status = .normal
                timeLeftRightCellViewModel.status = .normal
            }
        }
    }
    var result:Date{
        ///Delete seconds:
        let result = Date.mergeDateWithTime(from: date, and: time)!
        let resultWithoutSeconds = Calculations.dateWithoutSeconds(result)
        ///print("[Date Picker] Date chosen: \(result), Date saved: \(resultWithoutSeconds)")
        return resultWithoutSeconds
    }
    var date:Date{
        didSet{
            dateLeftRightCellViewModel.rightText = Formatter.format(date: date, style: .date)
            delegate?.resultDidChange()
        }
    }
    var time:Date{
        didSet{
            timeLeftRightCellViewModel.rightText = Formatter.format(date: time, style: .time)
            delegate?.resultDidChange()
        }
    }
    
    ///Cell View Models
    private var cellViewModels:[EventChooserCellType]
    
    var dateLeftRightCellViewModel:LeftRightLabelCellViewModel{
        return cellViewModels[0].viewModel() as! LeftRightLabelCellViewModel
    }
    
    var datePickerCellViewModel:DatePickerCellViewModel{
        return cellViewModels[1].viewModel() as! DatePickerCellViewModel
    }
    
    var timeLeftRightCellViewModel:LeftRightLabelCellViewModel{
        return cellViewModels[2].viewModel() as! LeftRightLabelCellViewModel
    }
    
    var timePickerCellViewModel:DatePickerCellViewModel{
        return cellViewModels[3].viewModel() as! DatePickerCellViewModel
    }
    
    init(title:String, footer:String, date:Date, time:Date) {
        self.title = title
        self.footer = footer
        self.date = date
        self.time = time
        self.state = .bothHidden
        
        ///Generate localizedStrings
        let dateString = NSLocalizedString("component_event_chooser_date", comment: "String preceding the date within the event chooser component.")
        let timeString = NSLocalizedString("component_event_chooser_time", comment: "String preceding the time within the event chooser component.")

        self.cellViewModels = [.dateLabel(LeftRightLabelCellViewModel(leftText: dateString,
                                                                      rightText: Formatter.format(date: date, style: .date))),
                               .datePicker(DatePickerCellViewModel(date:date, datePickerMode:.date)),
                               .timeLabel(LeftRightLabelCellViewModel(leftText: timeString,
                                                                      rightText: Formatter.format(date: time, style: .time))),
                               .timePicker(DatePickerCellViewModel(date:time, datePickerMode:.time))]
    }
    
    func numberOfRowsIn(section:Int)->Int{
        return 4
    }
    
    func cellViewModelForCellAt(indexPath:IndexPath)->CellViewModel{
        return cellViewModels[indexPath.row].viewModel()
    }
    
    func cellTypeForCellAt(indexPath:IndexPath)->EventChooserCellType{
        return cellViewModels[indexPath.row]
    }
}
