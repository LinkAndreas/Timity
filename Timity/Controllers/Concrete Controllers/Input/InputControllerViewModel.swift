//
//  InputControllerViewModel.swift
//  Timity
//
//  Created by Andreas Link on 1/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation
import CoreData

enum InputControllerType{
    case eventCalculator
    case timeCalculator
    case durationCalculator
    case addEventController
    case modifyEventController
}

class InputControllerViewModel {
    ///DataStorage
    var eventToModify:Event?
    var managedObjectContext:NSManagedObjectContext?
    
    ///Array containing the Calculator components to be shown within the calculator
    var name:String
    var type:InputControllerType
    var components:[Component]
    
    init(name:String, type:InputControllerType, components:[Component]) {
        self.name = name
        self.type = type
        self.components = components
    }
    
    ///Set components to their original state except for given indices
    func resignFirstResponderOfAllComponentsExceptFor(indices:[Int]){
        if components.count <= 0 { return }
        for i in 0..<components.count{
            if !indices.contains(i){
                components[i].resignFirstResponder()
            }
        }
    }
    
    func titleForRightBarButton()->String{
        ///Generate localized strings
        let saveString = NSLocalizedString("input_right_bar_button_save", comment: "Name of the Save button placed at the top right corner of the view.")
        let nextString = NSLocalizedString("input_right_bar_button_next", comment: "Name of the Next button placed at the top right corner of the view.")
        
        switch type {
        case .addEventController,.modifyEventController:
            return saveString
        default:
            return nextString
        }
    }
    
    func isCalculator()->Bool{
        switch type {
        case .addEventController,.modifyEventController:
            return false
        default:
            return true
        }
    }
    
    ///Handle Management of Core Data
    func resetDataStorageDependencies(){
        managedObjectContext = nil
        eventToModify = nil
    }
    
    ///Returns true iff event was successfully added
    func updateDataStorage()->Bool{
        guard let moc = managedObjectContext else {return false}
        
        ///Obtain necessary information beforehand
        guard let nameChooser = components[0] as? NameChooserComponent else {return false}
        guard let eventChooser = components[1] as? EventChooserComponent else {return false}
        guard let imageChooser = components[2] as? ImageChooserComponent else {return false}

        switch type {
        case .addEventController:
            let eventName = nameChooser.result()
            ///Check if the user filled in the name, otherwise return
            if eventName == ""{
                ///Generate localized strings
                let noNameAlertTitleString = NSLocalizedString("alert_add_controller_no_name_provided_title", comment: "Alert title indicating that no name was provided.")
                let noNameAlertMessageString = NSLocalizedString("alert_add_controller_no_name_provided_message", comment: "Alert message indicating that no name was provided.")
                
                AlertManager.shared.showAlertWith(title: noNameAlertTitleString,
                                              message: noNameAlertMessageString)
                return false
            }
            let newEvent = Event(context: moc)
            newEvent.nameOfEvent = eventName
            newEvent.dateOfEvent = eventChooser.result()
            newEvent.dateOfCreation = Date()
            newEvent.imageOfEvent = imageChooser.result()
            break
        case .modifyEventController:
            guard let event = eventToModify else {return false}
            let eventName = nameChooser.result()
            if eventName == ""{
                ///Generate localized strings
                let noNameAlertTitleString = NSLocalizedString("alert_modify_controller_no_name_provided_title", comment: "Alert title indicating that no name was provided.")
                let noNameAlertMessageString = NSLocalizedString("alert_modify_controller_no_name_provided_message", comment: "Alert message indicating that no name was provided.")
                
                AlertManager.shared.showAlertWith(title: noNameAlertTitleString,
                                              message: noNameAlertMessageString)
                return false
            }
            event.nameOfEvent = eventName
            event.dateOfEvent = eventChooser.result()
            event.dateOfCreation = Date()
            event.imageOfEvent = imageChooser.result()
            break
        default:
            break
        }
        
        /// Save the context.
        do {
            try moc.save()
        } catch {
            ///If an error occured: return
            let _ = error as NSError
            return false
        }
        ///Indicate that an event was successfully added
        return type == .addEventController
    }
}
