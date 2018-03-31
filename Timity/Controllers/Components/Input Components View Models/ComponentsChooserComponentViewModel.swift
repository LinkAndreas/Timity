//
//  ComponentsChooserComponentswift
//  Timity
//
//  Created by Andreas Link on 1/24/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//
import Foundation

enum ComponentsChooserComponentCellType{
    case addOrSubtract(AddOrSubtractCellViewModel)
    case componentChooser(ComponentSelectionCellViewModel)
    
    func viewModel()->CellViewModel{
        switch self {
        case .addOrSubtract(let addOrSubtractCellViewModel):
            return addOrSubtractCellViewModel
        case .componentChooser(let labelCellViewModel):
            return labelCellViewModel
        }
    }
}

class ComponentsChooserComponentViewModel {
    var title:String
    var footer:String
    var isAdding:Bool = true{
        didSet{
            delegate?.resultDidChange()
        }
    }
    var components:IntDateComponents{
        didSet{
            delegate?.resultDidChange()
        }
    }
    var currentComponentChooser:Int? = nil
    var textFieldTag = -42
    var result:(comps:IntDateComponents,isAdding:Bool){
        return (components, isAdding)
    }
    
    ///Cell View Models
    private var cellViewModels:[ComponentsChooserComponentCellType]
    weak var delegate:ComponentViewModelDelegate?
    
    init(title:String, footer:String) {
        self.title = title
        self.footer = footer
        
        self.components = IntDateComponents(years: 0, months: 0, weeks:0, days: 0, hours: 0, minutes: 0, seconds: 0)
        
        ///Generate localized strings
        let addString = NSLocalizedString("component_components_chooser_add", comment: "String representing the add operation in the components chooser component.")
        let subtractString = NSLocalizedString("component_components_chooser_subtract", comment: "String representing the subtract operation in the components chooser component.")
        
        let yearsString = NSLocalizedString("component_years", comment: "String preceding years in the components chooser component.")
        let monthsString = NSLocalizedString("component_months", comment: "String preceding months in the components chooser component.")
        let weeksString = NSLocalizedString("component_weeks", comment: "String preceding weeks in the components chooser component.")
        let daysString = NSLocalizedString("component_days", comment: "String preceding days in the components chooser component.")
        let hoursString = NSLocalizedString("component_hours", comment: "String preceding hours in the components chooser component.")
        let minutesString = NSLocalizedString("component_minutes", comment: "String preceding minutes in the components chooser component.")

        ///Initialize cell view models
        self.cellViewModels = [.addOrSubtract(AddOrSubtractCellViewModel(firstItem: addString,
                                                                         secondItem: subtractString)),
                               .componentChooser(ComponentSelectionCellViewModel(componentTag: 1,
                                                                                 componentName:yearsString)),
                               .componentChooser(ComponentSelectionCellViewModel(componentTag: 2,
                                                                                 componentName:monthsString)),
                               .componentChooser(ComponentSelectionCellViewModel(componentTag: 3,
                                                                                 componentName:weeksString)),
                               .componentChooser(ComponentSelectionCellViewModel(componentTag: 4,
                                                                                 componentName:daysString)),
                               .componentChooser(ComponentSelectionCellViewModel(componentTag: 5,
                                                                                 componentName:hoursString)),
                               .componentChooser(ComponentSelectionCellViewModel(componentTag: 6,
                                                                                 componentName:minutesString))
        ]
    }
    
    func cellViewModelForCellAt(row:Int)->CellViewModel{
        return cellViewModels[row].viewModel()
    }
    
    func cellTypeForCellAt(row:Int)->ComponentsChooserComponentCellType{
        return cellViewModels[row]
    }
    
    func updateSelectedValue(_ value:Int){
        switch textFieldTag {
        case 1:
            components.years = value
        case 2:
            components.months = value
        case 3:
            components.weeks = value
        case 4:
            components.days = value
        case 5:
            components.hours = value
        case 6:
            components.minutes = value
        default:
            break
        }
    }
    
    //MARK: Keyboard Navigation
    func activate(row:Int){
        guard let cell = cellViewModelForCellAt(row: row) as? ComponentSelectionCellViewModel else {return}
        cell.activate()
    }
    
    func deactivate(){
        if textFieldTag == -42 {return}
        guard let cell = cellViewModelForCellAt(row: textFieldTag) as? ComponentSelectionCellViewModel else {return}
        cell.deactivate()
    }
    
    func nextTextField(){
        ///Check if the last textfield got reached
        if textFieldTag + 1 == cellViewModels.count{
            deactivate()
        }else{
            guard let cell = cellViewModelForCellAt(row: textFieldTag + 1) as? ComponentSelectionCellViewModel else {return}
            cell.activate()
        }
    }
    
    func previousTextField(){
        ///Check if the last textfield got reached
        if textFieldTag - 1 == 0{
            deactivate()
        }else{
            guard let cell = cellViewModelForCellAt(row: textFieldTag - 1) as? ComponentSelectionCellViewModel else {return}
            cell.activate()
        }
    }

}
