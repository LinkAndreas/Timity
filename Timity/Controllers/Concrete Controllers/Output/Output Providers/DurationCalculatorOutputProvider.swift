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
    
    let firstEventDetailsHeader = NSLocalizedString("output_duration_calculator_first_event_details_header",
                                                   comment: "Header of the first event information section in the output of the duration calculator.")
    let firstEventDetailsFooter = NSLocalizedString("output_duration_calculator_first_event_details_footer",
                                                   comment: "Footer of the first event information section in the output of the duration calculator.")
    
    let secondEventDetailsHeader = NSLocalizedString("output_duration_calculator_second_event_details_header",
                                                    comment: "Header of the second event information section in the output of the duration calculator.")
    let secondEventDetailsFooter = NSLocalizedString("output_duration_calculator_second_event_details_footer",
                                                    comment: "Footer of the second event information section in the output of the duration calculator.")
    
    let firstEventDetailsWeekday = NSLocalizedString("output_duration_calculator_first_event_details_weekday",
                                                      comment: "String preceding the first event's weekday of the duration calculator.")
    let firstEventDetailsDate = NSLocalizedString("output_duration_calculator_first_event_details_date",
                                                       comment: "String preceding the first event's date of the duration calculator.")
    let firstEventDetailsTime = NSLocalizedString("output_duration_calculator_first_event_details_time",
                                                  comment: "String preceding the first event's time of the duration calculator.")
    
    let secondEventDetailsWeekday = NSLocalizedString("output_duration_calculator_second_event_details_weekday",
                                                     comment: "String preceding the second event's weekday of the duration calculator.")
    let secondEventDetailsDate = NSLocalizedString("output_duration_calculator_second_event_details_date",
                                                  comment: "String preceding the second event's date of the duration calculator.")
    let secondEventDetailsTime = NSLocalizedString("output_duration_calculator_second_event_details_time",
                                                  comment: "String preceding the second event's time of the duration calculator.")
    
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
        
        let firstEventWeekdayString = Formatter.format(date: firstDate, dateFormat:"EEEE")
        let firstEventDateString = Formatter.format(date: firstDate, style: .date)
        let firstEventTimeString = Formatter.format(date: firstDate, style: .time)
        
        let secondEventWeekdayString = Formatter.format(date: secondDate, dateFormat:"EEEE")
        let secondEventDateString = Formatter.format(date: secondDate, style: .date)
        let secondEventTimeString = Formatter.format(date: secondDate, style: .time)
        
        ///Section: First Event Details
        let firstEventDetailsWeekdayRow = Row(id: ID().firstEventDate().eventWeekday().value,
                               value: LeftRightValue(leftText: firstEventDetailsWeekday,
                                                     rightText: firstEventWeekdayString)
        )
        
        let firstEventDetailsDateRow = Row(id: ID().firstEventDate().eventDate().value,
                                value: LeftRightValue(leftText: firstEventDetailsDate,
                                                      rightText: firstEventDateString)
        )
        
        let firstEventDetailsTimeRow = Row(id: ID().firstEventDate().eventTime().value,
                                           value: LeftRightValue(leftText: firstEventDetailsTime,
                                                                 rightText: firstEventTimeString)
        )
        
        let firstEventDetails = Section(id: ID().firstEventDate().value,
                                   header: firstEventDetailsHeader,
                                   footer: firstEventDetailsFooter,
                                   rows: [firstEventDetailsWeekdayRow, firstEventDetailsDateRow, firstEventDetailsTimeRow])
        
        ///Section: Second Event Details
        let secondEventDetailsWeekdayRow = Row(id: ID().secondEventDate().eventWeekday().value,
                                              value: LeftRightValue(leftText: secondEventDetailsWeekday,
                                                                    rightText: secondEventWeekdayString)
        )
        
        let secondEventDetailsDateRow = Row(id: ID().secondEventDate().eventDate().value,
                                           value: LeftRightValue(leftText: secondEventDetailsDate,
                                                                 rightText: secondEventDateString)
        )
        
        let secondEventDetailsTimeRow = Row(id: ID().secondEventDate().eventTime().value,
                                           value: LeftRightValue(leftText: secondEventDetailsTime,
                                                                 rightText: secondEventTimeString)
        )
        
        let secondEventDetails = Section(id: ID().secondEventDate().value,
                                        header: secondEventDetailsHeader,
                                        footer: secondEventDetailsFooter,
                                        rows: [secondEventDetailsWeekdayRow, secondEventDetailsDateRow, secondEventDetailsTimeRow])
        
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
        delegate?.sectionsDidUpdate([firstEventDetails,
                                     secondEventDetails,
                                     individualComponents,
                                     combinedComponents])
    }
    
}
