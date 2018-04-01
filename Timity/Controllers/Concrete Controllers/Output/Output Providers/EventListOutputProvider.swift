//
//  EventListOutputProvider.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/10/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class EventListOutputProvider: OutputProvider {
    ///Associated localized Strings
    let eventListOutputNavigationTitle = NSLocalizedString("output_event_list_navigation_title",
                                                           comment: "Navigation title of the output of the event list.")
    let eventDetailsHeader = NSLocalizedString("output_event_list_event_details_header",
                                               comment: "Header of the event details section in the output of the event list.")
    let eventDetailsFooter = NSLocalizedString("output_event_list_event_details_footer",
                                               comment: "Footer of the event details section in the output of the event list.")
    let eventDetailsName = NSLocalizedString("output_event_list_event_details_name",
                                             comment: "String preceding the event's name of the event list")
    let eventDetailsWeekday = NSLocalizedString("output_event_list_event_details_weekday",
                                             comment: "String preceding the event's weekday of the event list.")
    let eventDetailsDate = NSLocalizedString("output_event_list_event_details_date",
                                                comment: "String preceding the event's date of the event list.")
    let eventDetailsTime = NSLocalizedString("output_event_list_event_details_time",
                                                comment: "String preceding the event's time of the event list.")
    override func individualComponentsHeader(for timeCategory:TimeCategory)->String{
        switch timeCategory {
        case .now:
            return NSLocalizedString("output_event_list_individual_components_header_now",
                                     comment: "Now header of the individual units components of the output of the event list.")
        case .past:
            return NSLocalizedString("output_event_list_individual_components_header_past",
                                     comment: "Past header of the individual units components of the output of the event list.")
        case .future:
            return NSLocalizedString("output_event_list_individual_components_header_future",
                                     comment: "Future header of the individual units components of the output of the event list.")
        }
    }
    
    override func individualComponentsFooter(for timeCategory:TimeCategory)->String{
        switch timeCategory {
        case .now:
            return NSLocalizedString("output_event_list_individual_components_footer_now",
                                     comment: "Now footer of the individual units components of the output of the event list.")
        case .past:
            return NSLocalizedString("output_event_list_individual_components_footer_past",
                                     comment: "Past footer of the individual units components of the output of the event list.")
        case .future:
            return NSLocalizedString("output_event_list_individual_components_footer_future",
                                     comment: "Future footer of the individual units components of the output of the event list.")
        }
    }
    
    override func combinedComponentsHeader(for timeCategory: TimeCategory) -> String {
        switch timeCategory{
        case .now:
            return NSLocalizedString("output_event_list_combined_components_header_now",
                                     comment: "Now header of the combined units component of the event list.")
        case .past:
            return NSLocalizedString("output_event_list_combined_components_header_past",
                                     comment: "Past header of the combined units component of the event list.")
        case .future:
            return NSLocalizedString("output_event_list_combined_components_header_future",
                                     comment: "Future header of the combined units component of the event list.")
        }
    }
    
    override func combinedComponentsFooter(for timeCategory: TimeCategory) -> String {
        switch timeCategory{
        case .now:
            return NSLocalizedString("output_event_list_combined_components_footer_now",
                              comment: "Now footer of the combined units component of the event list.")
        case .past:
            return NSLocalizedString("output_event_list_combined_components_footer_past",
                                     comment: "Past footer of the combined units component of the event list.")
        case .future:
            return NSLocalizedString("output_event_list_combined_components_footer_future",
                                     comment: "Future footer of the combined units component of the event list.")
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
        let eventName = input.data[1] as! String
        let eventDate = input.data[2] as! Date
        let eventImage = input.data[3] as! Data?
        let weekdayString = Formatter.format(date: eventDate, dateFormat: "EEEE")
        let dateString = Formatter.format(date: eventDate, style: .date)
        let timeString = Formatter.format(date: eventDate, style: .time)
        
        ///Compute Sections
        var sections = [Section]()
        
        ///Section: Header Image
        if let eventImage = eventImage{
            let rowEventImage = Row(id: ID().header().eventImage().value,
                                    value: ImageValue(imageData: eventImage))
            let headerImage = Section(id: ID().header().value,
                                      header: "",
                                      footer: "",
                                      rows: [rowEventImage])
            sections.append(headerImage)
        }
        
        ///Section: Event Details
        let rowEventName = Row(id: ID().event().eventName().value,
                               value: LeftRightValue(leftText: eventDetailsName,
                                                     rightText: eventName)
        )
        let rowEventWeekday = Row(id: ID().event().eventWeekday().value,
                               value: LeftRightValue(leftText: eventDetailsWeekday,
                                                     rightText: weekdayString)
        )
        let rowEventDate = Row(id: ID().event().eventDate().value,
                               value: LeftRightValue(leftText: eventDetailsDate,
                                                     rightText: dateString)
        )
        let rowEventTime = Row(id: ID().event().eventTime().value,
                               value: LeftRightValue(leftText: eventDetailsTime,
                                                     rightText: timeString)
        )
        
        let eventDetails = Section(id: ID().event().value,
                                   header: eventDetailsHeader,
                                   footer: eventDetailsFooter,
                                   rows: [rowEventName, rowEventWeekday, rowEventDate, rowEventTime])
        
        sections.append(eventDetails)
        
        ///Section: Individual Components
        let individualComponentRows = rowsForIntComponents(identifier: "individualComponents",
                                                           startDate: eventDate,
                                                           endDate: Date(),
                                                           showSeconds: true)
        
        
        let individualComponents = Section(id: ID().individualComponents().value,
                                           header: individualComponentsHeader(startDate: eventDate, endDate: Date()),
                                           footer: individualComponentsFooter(startDate: eventDate, endDate: Date()),
                                           rows: individualComponentRows)
        
        sections.append(individualComponents)
        
        ///Section: Combined Components
        let combinedComponentRows = rowsForDoubleComponents(identifier: "combinedComponents",
                                                            startDate: eventDate,
                                                            endDate: Date(),
                                                            showSeconds: true)
        
        let combinedComponents = Section(id: ID().combinedComponents().value,
                                           header: combinedComponentsHeader(startDate: eventDate, endDate: Date()),
                                           footer: combinedComponentsFooter(startDate: eventDate, endDate: Date()),
                                           rows: combinedComponentRows)
        
        sections.append(combinedComponents)
        
        ///Notify delegate about new sections
        delegate?.sectionsDidUpdate(sections)
    }
}












