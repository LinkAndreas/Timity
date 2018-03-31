//
//  EventListViewModel.swift
//  Timity
//
//  Created by Andreas Link on 1/30/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

class EventListViewModel{
    
    func eventCellViewModelFor(_ event:Event)->EventCellViewModel?{
        guard let title = event.nameOfEvent else {return nil}
        guard let date = event.dateOfEvent else {return nil}
        let body = Formatter.format(date: date, style: .dateAndTime)
        let explanantion = generateExplanation(date: date)
        let imageData = event.imageOfEvent
        return EventCellViewModel(title: title, body: body, explanation: explanantion, imageData: imageData)
    }
    
    ///Create an explanation for the explanationLabel depending on the given number of days
    func generateExplanation(date:Date)->String{
        
        let calendar = Calendar.current
        
        let normalizedDate = Calculations.dateWithoutTime(date)
        let normalizedToday = Calculations.dateWithoutTime(Date())
        let normalizedCombinedComponents = Calculations.calculateCombinedComponents(startDate: normalizedDate,
                                                                                    endDate: normalizedToday)
        ///Round up!
        let numberOfDays = Int(abs(normalizedCombinedComponents["days"]!))
        
        if calendar.isDateInToday(date) {
            let todayString = NSLocalizedString("input_event_list_cell_today",
                                                comment: "Today string placed at the bottom right corner of the cell to indicate that the event is happening today.")
            return todayString
        }else{
            ///Generate formatted strings
            let pastStringDay = NSLocalizedString("input_event_list_cell_past_day",
                                                  comment: "Past string placed at the bottom right corner of the cell indicating that the event has happened one day in the past.")
            let pastStringDays = NSLocalizedString("input_event_list_cell_past_days",
                                                   comment: "Past string placed at the bottom right corner of the cell indicating that the event has happened multiple days in the past.")
            let futureStringDay = NSLocalizedString("input_event_list_cell_future_day",
                                                    comment: "Future string placed at the bottom right corner of the cell indicating that the event will happen in one day.")
            let futureStringDays = NSLocalizedString("input_event_list_cell_future_days",
                                                     comment: "Future string placed at the bottom right corner of the cell indicating that the event will happen in multiple days.")
            
            if normalizedCombinedComponents["days"]! < 0 {
                ///Case 1: Past
                if numberOfDays == 1{
                    return pastStringDay
                }else{
                    return String(format:pastStringDays,"\(numberOfDays)")
                }
            }else{
                ///Case 2: Future
                if numberOfDays == 1{
                    return futureStringDay
                }else{
                    return String(format:futureStringDays,"\(numberOfDays)")
                }
            }
        }
    }
}
