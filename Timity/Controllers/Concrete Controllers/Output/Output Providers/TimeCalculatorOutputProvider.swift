//
//  TimeCalculatorOutputProvider.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/13/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class TimeCalculatorOutputProvider: OutputProvider {

    ///Generate localized strings
    let timeCalculatorOutputNavigationTitle = NSLocalizedString("output_time_calculator_navigation_title",
                                                                comment: "Navigation title of the output of the time calculator.")
    let eventDetailsHeader = NSLocalizedString("output_time_calculator_event_details_header",
                                                   comment: "Header of the event section in the output of the time calculator.")
    let eventDetailsFooter = NSLocalizedString("output_time_calculator_event_details_footer",
                                                   comment: "Footer of the event section in the output of the time calculator.")
    let eventDetailsWeekday = NSLocalizedString("output_time_calculator_event_details_weekday",
                                                  comment: "String preceding the event's weekday of the time calculator.")
    let eventDetailsDate = NSLocalizedString("output_time_calculator_event_details_date",
                                                    comment: "String preceding the event's date of the time calculator.")
    let eventDetailsTime = NSLocalizedString("output_time_calculator_event_details_time",
                                                    comment: "String preceding the event's time of the time calculator.")
    
    let chosenComponentsHeader = NSLocalizedString("output_time_calculator_chosen_components_header",
                                                   comment: "Header of the chosen components section in the output of the time calculator.")
    let chosenComponentsFooter = NSLocalizedString("output_time_calculator_chosen_components_footer",
                                                   comment: "Footer of the chosen components section in the output of the time calculator.")
    
    let resultHeader = NSLocalizedString("output_time_calculator_result_header",
                                         comment: "Header of the result section in the output of the time calculator.")
    let resultFooterAdd = NSLocalizedString("output_time_calculator_result_footer_add",
                                            comment: "Footer of the result section for an adding operation in the output of the time calculator.")
    let resultFooterSubtract = NSLocalizedString("output_time_calculator_result_footer_subtract",
                                                 comment: "Footer of the result section for a subtract operation in the output of the time calculator.")
    let resultWeekday = NSLocalizedString("output_time_calculator_result_weekday",
                                        comment: "String preceding the result's weekday of the time calculator.")
    let resultDate = NSLocalizedString("output_time_calculator_result_date",
                                        comment: "String preceding the result's date of the time calculator.")
    let resultTime = NSLocalizedString("output_time_calculator_result_time",
                                        comment: "String preceding the result's time of the time calculator.")
    
    let operationHeader = NSLocalizedString("output_time_calculator_operation_header",
                                               comment: "Header of the operation section in the output of the time calculator.")
    let operationFooter = NSLocalizedString("output_time_calculator_operation_footer",
                                               comment: "Footer of the operation section in the output of the time calculator.")
    let operation = NSLocalizedString("operation",
                                      comment: "String preceding the operation type.")
    let operationAdd = NSLocalizedString("operation_add",
                                         comment: "String representing the add operation of the time calculator.")
    let operationSubtract = NSLocalizedString("operation_subtract",
                                              comment: "String representing the subtract operation of the time calculator.")
    
    override func start() {
        ///Compute Sections
        computeSections()
    }
    
    override func stop() {}
    
    override func computeSections() {
        ///Obtain associated input data
        let sourceDate = input.data[1] as! Date
        let sourceWeekdayString = Formatter.format(date: sourceDate, dateFormat:"EEEE")
        let sourceDateString = Formatter.format(date: sourceDate, style: .date)
        let sourceTimeString = Formatter.format(date: sourceDate, style: .time)
        let tuple = input.data[2] as! (comps:IntDateComponents, isAdding:Bool)
        
        ///Determine result date
        let result = Calculations.calculateDateByAddingOrSubtractingComponents(years: tuple.comps.years,
                                                                               months: tuple.comps.months,
                                                                               weeks: tuple.comps.weeks,
                                                                               days: tuple.comps.days,
                                                                               hours: tuple.comps.hours,
                                                                               minutes: tuple.comps.minutes,
                                                                               originalDate: sourceDate,
                                                                               isAdding: tuple.isAdding)!
        let resultWeekdayString = Formatter.format(date: result, dateFormat:"EEEE")
        let resultDateString = Formatter.format(date: result, style: .date)
        let resultTimeString = Formatter.format(date: result, style: .time)
        
        
        ///Section: Event Details
        let sourceWeekdayRow = Row(id: ID().event().eventWeekday().value,
                                 value: LeftRightValue(leftText: eventDetailsWeekday,
                                                       rightText: sourceWeekdayString)
        )
        let sourceDateRow = Row(id: ID().event().eventDate().value,
                                 value: LeftRightValue(leftText: eventDetailsDate,
                                                       rightText: sourceDateString)
        )
        let sourceTimeRow = Row(id: ID().event().eventTime().value,
                                 value: LeftRightValue(leftText: eventDetailsTime,
                                                       rightText: sourceTimeString)
        )
        
        let eventDetails = Section(id: ID().event().value,
                                       header: eventDetailsHeader,
                                       footer: eventDetailsFooter,
                                       rows: [sourceWeekdayRow, sourceDateRow, sourceTimeRow])
        
        ///Section: Operation Details
        let operationRow = Row(id: ID().operation().operationType().value,
                               value: LeftRightValue(leftText: operation,
                                                     rightText: tuple.isAdding ? operationAdd : operationSubtract)
        )
        
        let operationDetails = Section(id: ID().operation().value,
                                       header: operationHeader,
                                       footer: operationFooter,
                                       rows: [operationRow])
        
        
        ///Section: Individual Components
        
        let chosenComponentRows = rowsForChosenComponents(identifier: "chosenComponents",
                                                          chosenComponents: tuple.comps)
        
        
        let chosenComponents = Section(id: ID().chosenComponents().value,
                                           header: chosenComponentsHeader,
                                           footer: chosenComponentsFooter,
                                           rows: chosenComponentRows)
        
        ///Section: Result Details
        let resultWeekdayRow = Row(id: ID().result().eventWeekday().value,
                                   value: LeftRightValue(leftText: resultWeekday,
                                                         rightText: resultWeekdayString)
        )
        let resultDateRow = Row(id: ID().result().eventDate().value,
                                value: LeftRightValue(leftText: resultDate,
                                                      rightText: resultDateString)
        )
        let resultTimeRow = Row(id: ID().result().eventTime().value,
                                value: LeftRightValue(leftText: resultTime,
                                                      rightText: resultTimeString)
        )
        
        let resultFooter = tuple.isAdding ? resultFooterAdd : resultFooterSubtract
        let resultDetails = Section(id: ID().result().value,
                                       header: resultHeader,
                                       footer: resultFooter,
                                       rows: [resultWeekdayRow, resultDateRow, resultTimeRow])
        
        ///Notify delegate about new sections
        delegate?.sectionsDidUpdate([eventDetails,
                                     operationDetails,
                                     chosenComponents,
                                     resultDetails])
    }
}
