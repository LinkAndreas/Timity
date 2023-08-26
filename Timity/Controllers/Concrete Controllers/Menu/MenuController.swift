//
//  MenuController.swift
//  Timity
//
//  Created by Andreas Link on 1/19/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit
import CoreLocation

class MenuController: ThemeableTableViewController {

    ///Properties
    let viewModel = MenuViewModel()
    
    ///Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        ///Setup UI
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        ///Show placeholder
        showPlaceholder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    private func setupUI(){
        ///Configure LargeTitles
        navigationItem.largeTitleDisplayMode = UIDevice.current.userInterfaceIdiom == .pad ? .never : .always
        
        ///Set navigationBarTitle
        navigationItem.title = NSLocalizedString("general_app_name",
                                                 comment: "The name of the app, shown as a title of the navigation controller.")
        ///Disable scrollIndicators
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
    }
    
    private func showPlaceholder(){
        ///Present Default Detail view if not collapsed
        guard let splitVC = splitViewController else {return}
        if !splitVC.isCollapsed{
            performSegue(withIdentifier: "showPlaceholder", sender: self)
        }
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "segueToEventList"{
            guard let dvc = segue.destination as? EventListController else {return}
            ///Inject dependencies
            let viewModel = EventListViewModel()
            dvc.injectDependencies(viewModel: viewModel)
            
        }else if segue.identifier == "segueToEventCalculator"{
            
            guard let dvc = segue.destination as? InputController else {return}
            
            ///Create required components for InputController
            let headerString = NSLocalizedString("input_event_calculator_event_chooser_header",
                                                 comment: "Header of the event calculator's date and time picker.")
            let footerString = NSLocalizedString("input_event_calculator_event_chooser_footer",
                                                 comment: "Footer instructions, indicating that the user should specify date and time accordingly.")
            let eventChooser = EventChooserComponent(title: headerString, footer: footerString, date: Date(), time: Date(), tableView: tableView)
            eventChooser.viewModel.delegate = dvc
            
            ///Inject dependencies
            let eventCalculatorString = NSLocalizedString("input_event_calculator_name",
                                                          comment: "The name of the event calculator.")
            let viewModel = InputControllerViewModel(
                name: eventCalculatorString,
                type:.eventCalculator,
                components: [eventChooser]
            )
            dvc.injectDependencies(viewModel: viewModel, isNext: true)
            
        }else if segue.identifier == "segueToTimeCalculator"{
            
            guard let dvc = segue.destination as? InputController else {return}

            ///Create required components for InputController
            let headerString = NSLocalizedString("input_time_calculator_event_chooser_header",
                                                 comment: "Header of the time calculator's date and time picker.")
            let footerString = NSLocalizedString("input_time_calculator_event_chooser_footer",
                                                 comment: "Footer instructions, indicating that the user should specify date and time accordingly.")
            let eventChooser = EventChooserComponent(title: headerString, footer: footerString, date: Date(), time: Date(), tableView: tableView)
            eventChooser.viewModel.delegate = dvc
            
            let componentsHeaderString = NSLocalizedString("input_time_calculator_components_chooser_header",
                                                           comment: "Header of the date and time components section.")
            let componentsFooterString = NSLocalizedString("input_time_calculator_components_chooser_footer",
                                                           comment: "Footer instructions, indicating that the user should specify date and time components as well as whether they should be added/subtracted.")
            let componentsChooser = ComponentsChooserComponent(title: componentsHeaderString, footer: componentsFooterString, tableView: tableView)
            componentsChooser.viewModel.delegate = dvc
            
            ///Inject dependencies
            let timeCalculatorString = NSLocalizedString("input_time_calculator_name",
                                                         comment: "Name of the time calculator")
            let viewModel = InputControllerViewModel(
                name: timeCalculatorString,
                type:.timeCalculator,
                components: [eventChooser, componentsChooser]
            )
            dvc.injectDependencies(viewModel: viewModel, isNext: true)
            
        }else if segue.identifier == "segueToDurationCalculator"{
            
            guard let dvc = segue.destination as? InputController else {return}
            
            ///Create required components for InputController
            let firstHeaderString = NSLocalizedString("input_duration_calculator_first_event_chooser_header",
                                                      comment: "Section header indicating the first event.")
            let secondHeaderString = NSLocalizedString("input_duration_calculator_second_event_chooser_header",
                                                       comment: "Section header indicating the second event.")
            let firstFooterString = NSLocalizedString("input_duration_calculator_first_event_chooser_footer",
                                                      comment: "Footer instructions, indicating to specify the date and time of the first event.")
            let secondFooterString = NSLocalizedString("input_duration_calculator_second_event_chooser_footer",
                                                       comment: "Footer instructions, indicating to specify the date and time of the second event.")
            
            let eventChooser1 = EventChooserComponent(title: firstHeaderString, footer: firstFooterString, date: Date(), time: Date(), tableView: tableView)
            let eventChooser2 = EventChooserComponent(title: secondHeaderString, footer: secondFooterString, date: Date(), time: Date(), tableView: tableView)
            eventChooser1.viewModel.delegate = dvc
            eventChooser2.viewModel.delegate = dvc
            
            ///Inject dependencies
            let durationCalculatorString = NSLocalizedString("input_duration_calculator_name", comment: "Name of the duration calculator.")
            let viewModel = InputControllerViewModel(
                name: durationCalculatorString,
                type:.durationCalculator,
                components: [eventChooser1, eventChooser2]
            )
            dvc.injectDependencies(viewModel: viewModel, isNext: true)
            
        }else if segue.identifier == "segueToSolarCalculator"{
            
            guard let nc = segue.destination as? UINavigationController else {return}
            guard let dvc = nc.topViewController as? OutputController else {return}
            
            let solarCalculatorOutputNavigationTitle = NSLocalizedString("output_solar_calculator_navigation_title",
                                                                        comment: "Navigation title of the output of the solar calculator.")
            
            ///Inject dependencies
            let input = Input(type: .solarCalculatorResult, data: [solarCalculatorOutputNavigationTitle])
            dvc.inputDidUpdate(input)
        }
    }
}

extension MenuController{
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.activities.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        ///Configure Activity cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "activityCell", for: indexPath) as! ActivityCell
        cell.activity = viewModel.activities[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 106
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        /// Return false if you do not want the specified item to be editable.
        return false
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        var shouldPerformSegue = true
        if viewModel.isSegueToEventList(indexPath: indexPath){
            showPlaceholder()
        }else if viewModel.isSegueToSolarCalculator(indexPath: indexPath){
            ///Check if LocationManager is ready for Location Updates
            if !LocationManager.shared.isReadyForLocationUpdates(){
                shouldPerformSegue = false
            }
        }
    
        ///Perform Segue
        if shouldPerformSegue{
            performSegue(withIdentifier: viewModel.activities[indexPath.row].segueIdentifier, sender: indexPath)
        }
        
        ///Deselect Row again
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
