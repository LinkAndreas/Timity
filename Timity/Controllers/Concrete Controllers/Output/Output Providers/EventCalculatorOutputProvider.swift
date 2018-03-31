//
//  EventCalculatorOutputProvider.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/10/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class EventCalculatorOutputProvider: OutputProvider {
    
    ///Generate localized strings
    let eventCalculatorOutputNavigationTitle = NSLocalizedString("output_event_calculator_navigation_title",
                                                                 comment: "Navigation title of the output of the event calculator.")
    let operationDetailsHeader = NSLocalizedString("output_event_calculator_operation_details_header",
                                                   comment: "Header of the event information section in the output of the event calculator.")
    let operationDetailsFooter = NSLocalizedString("output_event_calculator_operation_details_footer",
                                                   comment: "Footer of the event information section in the output of the event calculator.")
    let operationDetailsDate = NSLocalizedString("output_event_calculator_operation_details_date",
                                                 comment: "String preceding the event's date of the event calculator.")
    
    
    override func individualComponentsHeader(for timeCategory:TimeCategory)->String{
        switch timeCategory {
        case .now:
            return NSLocalizedString("output_event_calculator_individual_components_header_now",
                                     comment: "Now header of the individual units component of the event calculator")
        case .past:
            return NSLocalizedString("output_event_calculator_individual_components_header_past",
                                     comment: "Past header of the individual units component of the event calculator")
        case .future:
            return NSLocalizedString("output_event_calculator_individual_components_header_future",
                                     comment: "Future header of the individual units component of the event calculator.")
        }
    }
    
    override func individualComponentsFooter(for timeCategory:TimeCategory)->String{
        switch timeCategory {
        case .now:
            return NSLocalizedString("output_event_calculator_individual_components_footer_now",
                                     comment: "Now footer of the individual units component of the event calculator")
        case .past:
            return NSLocalizedString("output_event_calculator_individual_components_footer_past",
                                     comment: "Past footer of the individual units component of the event calculator")
        case .future:
            return NSLocalizedString("output_event_calculator_individual_components_footer_future",
                                     comment: "Future footer of the individual units component of the event calculator.")
        }
    }
    
    override func combinedComponentsHeader(for timeCategory: TimeCategory) -> String {
        switch timeCategory{
        case .now:
            return NSLocalizedString("output_event_calculator_combined_components_header_now",
                                     comment: "Now header of the combined units component of the event calculator.")
        case .past:
            return NSLocalizedString("output_event_calculator_combined_components_header_past",
                                     comment: "Past header of the combined units component of the event calculator.")
        case .future:
            return NSLocalizedString("output_event_calculator_combined_components_header_future",
                                     comment: "Future header of the combined units component of the event calculator.")
        }
    }
    
    override func combinedComponentsFooter(for timeCategory: TimeCategory) -> String {
        switch timeCategory{
        case .now:
            return NSLocalizedString("output_event_calculator_combined_components_footer_now",
                                     comment: "Now footer of the combined units component of the event calculator.")
        case .past:
            return NSLocalizedString("output_event_calculator_combined_components_footer_past",
                                     comment: "Past footer of the combined units component of the event calculator.")
        case .future:
            return NSLocalizedString("output_event_calculator_combined_components_footer_future",
                                     comment: "Future footer of the combined units component of the event calculator.")
        }
    }
    
    override func start() {
        ///Compute Sections
        computeSections()
        
        ///Start a timer in case the output should be computed periodically
        timer = Timer(fire: Calculations.dateOfNextFullSeond(Date())!, interval: 1.0, repeats: true, block:{
            [weak self] _ in
            self?.computeSections()
        })
        RunLoop.current.add(timer!, forMode: .commonModes)
    }
    
    override func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    override func computeSections() {
        ///Obtain associated input data
        let eventDate = input.data[1] as! Date
        let dateString = Formatter.format(date: eventDate, style: .dateAndTime)
        
        ///Compute Sections
        
        ///Section: Event Details
        let rowEventDate = Row(id: ID().info().eventDate().value,
                               value: LeftRightValue(leftText: operationDetailsDate,
                                                     rightText: dateString)
        )
        
        let eventDetails = Section(id: ID().info().value,
                                   header: operationDetailsHeader,
                                   footer: operationDetailsFooter,
                                   rows: [rowEventDate])
        
        ///Section: Individual Components
        let individualComponentRows = rowsForIntComponents(identifier: "individualComponents",
                                                           startDate: eventDate,
                                                           endDate: Date(),
                                                           showSeconds: true)
        
        
        let individualComponents = Section(id: ID().individualComponents().value,
                                           header: individualComponentsHeader(startDate: eventDate, endDate: Date()),
                                           footer: individualComponentsFooter(startDate: eventDate, endDate: Date()),
                                           rows: individualComponentRows)
        
        ///Section: Combined Components
        let combinedComponentRows = rowsForDoubleComponents(identifier: "combinedComponents",
                                                            startDate: eventDate,
                                                            endDate: Date(),
                                                            showSeconds: true)
        
        let combinedComponents = Section(id: ID().combinedComponents().value,
                                         header: combinedComponentsHeader(startDate: eventDate, endDate: Date()),
                                         footer: combinedComponentsFooter(startDate: eventDate, endDate: Date()),
                                         rows: combinedComponentRows)
        
        ///Notify delegate about new sections
        delegate?.sectionsDidUpdate([eventDetails,
                                     individualComponents,
                                     combinedComponents])
    }
}
