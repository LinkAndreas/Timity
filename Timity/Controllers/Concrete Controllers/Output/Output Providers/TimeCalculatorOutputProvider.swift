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
    let operationDetailsHeader = NSLocalizedString("output_time_calculator_operation_details_header",
                                                   comment: "Header of the event information section in the output of the time calculator.")
    let operationDetailsFooter = NSLocalizedString("output_time_calculator_operation_details_footer",
                                                   comment: "Footer of the event information section in the output of the time calculator.")
    let operationDetailsEvent = NSLocalizedString("output_time_calculator_operation_details_event",
                                                  comment: "String preceding the event's date of the time calculator.")
    let operationDetailsOperation = NSLocalizedString("output_time_calculator_operation_details_operation",
                                                      comment: "String preceding the operation type of the time calculator.")
    let operationDetailsOperationAdd = NSLocalizedString("output_time_calculator_operation_details_operation_add",
                                                         comment: "String representing the add operation of the time calculator.")
    let operationDetailsOperationSubtract = NSLocalizedString("output_time_calculator_operation_details_operation_subtract",
                                                              comment: "String representing the subtract operation of the time calculator.")
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
    let resultEvent = NSLocalizedString("output_time_calculator_result_event",
                                        comment: "String preceding the result's event of the time calculator.")
    
    override func start() {
        ///Compute Sections
        computeSections()
    }
    
    override func stop() {}
    
    override func computeSections() {
        ///Obtain associated input data
        let sourceDate = input.data[1] as! Date
        let sourceEventString = Formatter.format(date: sourceDate, style: .dateAndTime)
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
        let resultEventString = Formatter.format(date: result, style: .dateAndTime)
        
        
        ///Section: Event Details
        let sourceEventRow = Row(id: ID().info().eventDate().value,
                                 value: LeftRightValue(leftText: operationDetailsEvent,
                                                       rightText: sourceEventString)
        )
        let operationRow = Row(id: ID().info().operation().value,
                            value: LeftRightValue(leftText: operationDetailsOperation,
                                                  rightText: tuple.isAdding ? operationDetailsOperationAdd : operationDetailsOperationSubtract)
        )
        
        let operationDetails = Section(id: ID().info().value,
                                       header: operationDetailsHeader,
                                       footer: operationDetailsFooter,
                                       rows: [sourceEventRow, operationRow])
        
        ///Section: Individual Components
        
        let chosenComponentRows = rowsForChosenComponents(identifier: "chosenComponents", chosenComponents: tuple.comps)
        
        
        let chosenComponents = Section(id: ID().chosenComponents().value,
                                           header: chosenComponentsHeader,
                                           footer: chosenComponentsFooter,
                                           rows: chosenComponentRows)
        
        ///Section: Event Details
        let resultEventRow = Row(id: ID().result().eventDate().value,
                                 value: LeftRightValue(leftText: resultEvent,
                                                       rightText: resultEventString)
        )
        
        let resultFooter = tuple.isAdding ? resultFooterAdd : resultFooterSubtract
        let resultDetails = Section(id: ID().result().value,
                                       header: resultHeader,
                                       footer: resultFooter,
                                       rows: [resultEventRow])
        
        ///Notify delegate about new sections
        delegate?.sectionsDidUpdate([operationDetails,
                                     chosenComponents,
                                     resultDetails])
    }
}
