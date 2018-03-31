//
//  MenuViewModel.swift
//  Timity
//
//  Created by Andreas Link on 1/19/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation
import UIKit

struct MenuViewModel {
    let activities = [Activity(name: NSLocalizedString("menu_item_event_list_title", comment: "Menu item referring to the event list."),
                               description: NSLocalizedString("menu_item_event_list_description", comment:"Event List Menu Item description."),
                               segueIdentifier: "segueToEventList",
                               imageName: "list"),
                      Activity(name: NSLocalizedString("menu_item_event_calculator_title", comment: "Menu item referring to the event calculator"),
                               description: NSLocalizedString("menu_item_event_calculator_description", comment: "Event Calculator Menu Item description."),
                               segueIdentifier: "segueToEventCalculator",
                               imageName: "clock"),
                      Activity(name: NSLocalizedString("menu_item_time_calculator_title", comment: "Menu item referring to the time calculator"),
                               description: NSLocalizedString("menu_item_time_calculator_description", comment: "Time Calculator Menu Item description."),
                               segueIdentifier: "segueToTimeCalculator",
                               imageName: "time"),
                      Activity(name: NSLocalizedString("menu_item_duration_calculator_title", comment: "Menu item referring to the duration calculator"),
                               description: NSLocalizedString("menu_item_duration_calculator_description", comment: "Duration Calculator Menu Item description."),
                               segueIdentifier: "segueToDurationCalculator",
                               imageName: "duration"),
                      Activity(name: NSLocalizedString("menu_item_solar_calculator_title", comment: "Menu item referring to the solar calculator"),
                               description: NSLocalizedString("menu_item_solar_calculator_description", comment: "Solar Calculator Menu Item description."),
                               segueIdentifier: "segueToSolarCalculator",
                               imageName: "sun"),
                      Activity(name: NSLocalizedString("menu_item_settings_title", comment: "Menu item referring to settings"),
                               description: NSLocalizedString("menu_item_settings_description", comment: "Settings Menu Item description."),
                               segueIdentifier: "segueToSettings",
                               imageName: "settings"),
                      Activity(name: NSLocalizedString("menu_item_info_title", comment:"Menu item referring to infos"),
                               description: NSLocalizedString("menu_item_info_description", comment: "Info Menu Item description."),
                               segueIdentifier: "segueToInfo",
                               imageName: "info")]
    
    func isSegueToSolarCalculator(indexPath:IndexPath)->Bool{
        return indexPath.section == 0 && activities[indexPath.row].segueIdentifier == "segueToSolarCalculator"
    }
}

struct Activity{
    let name:String
    let description:String
    let segueIdentifier:String
    let imageName:String
}
