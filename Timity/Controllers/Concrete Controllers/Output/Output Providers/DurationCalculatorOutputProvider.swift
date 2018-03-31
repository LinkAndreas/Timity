//
//  DurationCalculatorOutputProvider.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/13/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class DurationCalculatorOutputProvider: OutputProvider {

    ///Generate localized strings
    let durationCalculatorOutputNavigationTitle = NSLocalizedString("output_duration_calculator_navigation_title",
                                                                    comment: "Navigation title of the output of the duration calculator.")
    
    let operationDetailsHeader = NSLocalizedString("output_duration_calculator_operation_details_header",
                                                   comment: "Header of the event information section in the output of the duration calculator.")
    let operationDetailsFooter = NSLocalizedString("output_duration_calculator_operation_details_footer",
                                                   comment: "Footer of the event information section in the output of the duration calculator.")
    let operationDetailsFirstDate = NSLocalizedString("output_duration_calculator_operation_details_first_date",
                                                      comment: "String preceding the first event's date of the duration calculator.")
    let operationDetailsSecondDate = NSLocalizedString("output_duration_calculator_operation_details_second_date",
                                                       comment: "String preceding the second event's date of the duration calculator.")
    
    override func individualComponentsHeader(for timeCategory:TimeCategory)->String{
        switch timeCategory {
        case .now:
            return NSLocalizedString("output_duration_calculator_individual_components_header_equal",
                              comment: "Header of the individual components of the duration calculator indicating that both events are equal.")
        case .past, .future:
            return NSLocalizedString("output_duration_calculator_individual_components_header_unequal",
                                     comment: "Header of the individual components of the duration calculator indicating that both events are not equal.")
        }
    }
    
    override func individualComponentsFooter(for timeCategory:TimeCategory)->String{
        switch timeCategory {
        case .now:
            return NSLocalizedString("output_duration_calculator_individual_components_footer_equal",
                                     comment: "Footer of the individual components of the duration calculator indicating that both events are equal.")
        case .past, .future:
            return NSLocalizedString("output_duration_calculator_individual_components_footer_unequal",
                                     comment: "Footer of the individual components of the duration calculator indicating that both events are not equal.")
        }
    }
    
    override func combinedComponentsHeader(for timeCategory: TimeCategory) -> String {
        switch timeCategory{
        case .now:
            return NSLocalizedString("output_duration_calculator_combined_components_header_equal",
                                     comment: "Header of the combined units component of the duration calculator indicating that both events are equal.")
        case .past, .future:
            return NSLocalizedString("output_duration_calculator_combined_components_header_unequal",
                                     comment: "Header of the combined units component of the duration calculator indicating that both events are not equal.")
        }
    }
    
    override func combinedComponentsFooter(for timeCategory: TimeCategory) -> String {
        switch timeCategory{
        case .now:
            return NSLocalizedString("output_duration_calculator_combined_components_footer_equal",
                                     comment: "Footer of the combined units component of the duration calculator indicating that both events are equal.")
        case .past, .future:
            return NSLocalizedString("output_duration_calculator_combined_components_footer_unequal",
                                     comment: "Footer of the combined units component of the duration calculator indicating that both events are not equal.")
        }
    }
    
    override func start() {
        ///Compute Sections
        computeSections()
    }
    
    override func stop() {}
    
    override func computeSections() {
        ///Obtain associated input data
        let firstDate = input.data[1] as! Date
        let secondDate = input.data[2] as! Date
        let firstDateString = Formatter.format(date: firstDate, style: .dateAndTime)
        let secondDateString = Formatter.format(date: secondDate, style: .dateAndTime)
        
        ///Section: Event Details
        let firstEventRow = Row(id: ID().info().firstEventDate().value,
                               value: LeftRightValue(leftText: operationDetailsFirstDate,
                                                     rightText: firstDateString)
        )
        
        let secondEventRow = Row(id: ID().info().secondEventDate().value,
                                value: LeftRightValue(leftText: operationDetailsSecondDate,
                                                      rightText: secondDateString)
        )
        
        let operationDetails = Section(id: ID().operation().value,
                                   header: operationDetailsHeader,
                                   footer: operationDetailsFooter,
                                   rows: [firstEventRow, secondEventRow])
        
        ///Section: Individual Components
        let individualComponentRows = rowsForIntComponents(identifier: "individualComponents",
                                                           startDate: firstDate,
                                                           endDate: secondDate,
                                                           showSeconds: false)
        
        
        
        let individualComponents = Section(id: ID().individualComponents().value,
                                           header: individualComponentsHeader(startDate: firstDate, endDate: secondDate),
                                           footer: individualComponentsFooter(startDate: firstDate, endDate: secondDate),
                                           rows: individualComponentRows)
        
        ///Section: Combined Components
        let combinedComponentRows = rowsForDoubleComponents(identifier: "combinedComponents",
                                                            startDate: firstDate,
                                                            endDate: secondDate,
                                                            showSeconds: true)
        
        let combinedComponents = Section(id: ID().combinedComponents().value,
                                         header: combinedComponentsHeader(startDate: firstDate, endDate: secondDate),
                                         footer: combinedComponentsFooter(startDate: firstDate, endDate: secondDate),
                                         rows: combinedComponentRows)
        
        ///Notify delegate about new sections
        delegate?.sectionsDidUpdate([operationDetails,
                                     individualComponents,
                                     combinedComponents])
    }
    
}
