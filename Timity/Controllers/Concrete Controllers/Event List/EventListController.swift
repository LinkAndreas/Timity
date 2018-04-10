//
//  EventListController.swift
//  Timity
//
//  Created by Andreas Link on 27/09/2016.
//  Copyright © 2016 Andreas Link. All rights reserved.
//

import UIKit
import CoreData
import SnapKit

class EventListController: ThemeableTableViewController {
    
    ///Properties
    var viewModel:EventListViewModel?
    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    var managedObjectContext: NSManagedObjectContext?
    var outputController: OutputController?
    var _fetchedResultsController: NSFetchedResultsController<Event>?
    var delegate:OutputControllerDelegate?
    
    ///Private Properties
    private var needToRefreshDetailView = true
    private var backgroundView:EmptyTableBackgroundView?

    override func viewDidLoad() {
        super.viewDidLoad()
        ///Setup UI
        setupUI()
        
        ///Set managed Object context
        managedObjectContext = appDelegate?.persistentContainer.viewContext
    }
    
    ///Called after prepareForSegue was being called
    func injectDependencies(viewModel:EventListViewModel){
        self.viewModel = viewModel
    }
    
    private func setupUI(){
        
        ///Configure LargeTitles
        navigationItem.largeTitleDisplayMode = UI_USER_INTERFACE_IDIOM() == .pad ? .never : .always

        ///Disable scrollIndicators
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        
        ///Set NavigationBar title
        navigationItem.title = NSLocalizedString("input_event_list_navigation_title",
                                                 comment: "The title of the navigationItem of the event list.")
        
        ///Allow selection during editing
        tableView.allowsSelectionDuringEditing = true
        
        ///Add an edit and an add button
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addEvent(_:)))
        navigationItem.rightBarButtonItems = [addButton,editButtonItem]
        
        if let split = splitViewController {
            let controllers = split.viewControllers
            if let nc = controllers[controllers.count-1] as? UINavigationController{
                outputController = nc.topViewController as? OutputController
            }
        }
        
        ///Setup BackgroundView
        setupBackgroundView()
    }
    
    func setupBackgroundView(){
        let title = NSLocalizedString("input_event_list_empty_title",
                                      comment: "Title indicating that the event list is currently empty.")
        let message = NSLocalizedString("input_event_list_empty_message",
                                        comment: "Message indicating that the event list is currently empty.")
        let logo = UIImage(named:"list")
        
        backgroundView = EmptyTableBackgroundView(title: title,
                                                  message: message,
                                                  image: logo)
        tableView.backgroundView = backgroundView
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Setup background color
        tableView.backgroundColor = theme.backgroundColor
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        ///Set delegate if Outputcontroller already exists
        if let outputVC = (splitViewController?.viewControllers[safe: 1] as? UINavigationController)?.topViewController as? OutputController{
            self.delegate = outputVC
        }
        
        ///Handle Clear selection
        clearSelection()
        
        ///Reload tableView to ensure that after editing newly added images are being shown
        updateFetchResultsController()
        
        ///Reset editButton
        setEditing(false, animated: true)
        
        ///Register to be notified about Settings changes
        if !Settings.shared.delegates.containsDelegate(self){
            Settings.shared.delegates.addDelegate(self)
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        ///Deregister from Settings changes
        Settings.shared.delegates.removeDelegate(self)
    }
    
    func clearSelection(){
        guard let shouldClearSelection = splitViewController?.isCollapsed else {return}
        guard let selectedRow = tableView.indexPathForSelectedRow else {return}
        if shouldClearSelection{
            tableView.deselectRow(at: selectedRow, animated: true)
        }
    }
    
    //MARK: - Adding a new event
    
    @objc func addEvent(_ sender:Any){
        performSegue(withIdentifier: "segueToEventController", sender: self)
    }
    
    private func obtainInput()->Input?{
        ///Fetch selected event information
        guard let indexPath = tableView.indexPathForSelectedRow else {return nil}
        let event = fetchedResultsController.object(at: indexPath)
        guard let eventName = event.nameOfEvent else {return nil}
        guard let eventDate = event.dateOfEvent else {return nil}
        let eventImage = event.imageOfEvent
        
        ///Inject dependencies
        return Input(type: .eventListResult, data: [eventName, eventName, eventDate, eventImage])
    }
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showEventListDetail" {
            guard let dnc = segue.destination as? UINavigationController else {return}
            guard let dvc = dnc.topViewController as? OutputController else {return}
            
            ///Inject dependencies
            delegate = dvc
            dvc.inputDidUpdate(obtainInput())
            
        }else if segue.identifier == "segueToEventController"{
            if let dvc = segue.destination as? InputController{
                ///Create required components for InputController
                var nameChooser:NameChooserComponent!
                var eventChooser:EventChooserComponent!
                var imageChooser:ImageChooserComponent!
                
                var controllerName:String!
                var type:InputControllerType!
                
                if tableView.isEditing{
                    controllerName = NSLocalizedString("input_event_list_modify_navigation_title",
                                                       comment: "Title of the navigation item of the modify input controller.")
                    type = .modifyEventController
                    var name:String!
                    var date:Date!
                    var imageData:Data?
                    if let event = sender as? Event {
                        name = event.nameOfEvent ?? ""
                        date = event.dateOfEvent ?? Date()
                        imageData = event.imageOfEvent
                    }else{
                        name = ""
                        date = Date()
                        imageData = nil
                    }
                    
                    ///Generate strings ()
                    let nameChooserHeader = NSLocalizedString("input_event_list_modify_name_chooser_header",
                                                              comment: "Header of the name chooser of the modify controller.")
                    let nameChooserFooter = NSLocalizedString("input_event_list_modify_name_chooser_footer",
                                                              comment: "Footer of the name chooser of the modify controller.")
                    let eventChooserHeader = NSLocalizedString("input_event_list_modify_event_chooser_header",
                                                               comment: "Header of the event chooser of the modify controller.")
                    let eventChooserFooter = NSLocalizedString("input_event_list_modify_event_chooser_footer",
                                                               comment: "Footer of the event chooser of the modify controller.")
                    let imageChooserHeader = NSLocalizedString("input_event_list_modify_image_chooser_header",
                                                               comment: "Header of the image chooser of the modify controller.")
                    let imageChooserFooter = NSLocalizedString("input_event_list_modify_image_chooser_footer",
                                                               comment: "Footer of the image chooser of the modify controller.")
                    
                    nameChooser = NameChooserComponent(title: nameChooserHeader, footer: nameChooserFooter, name: name, tableView: tableView)
                    eventChooser = EventChooserComponent(title: eventChooserHeader, footer: eventChooserFooter, date: date, time: date, tableView: tableView)
                    imageChooser = ImageChooserComponent(title: imageChooserHeader, footer: imageChooserFooter, image: imageData, tableView: tableView)
                    nameChooser.viewModel.delegate = dvc
                    eventChooser.viewModel.delegate = dvc
                    imageChooser.viewModel.delegate = dvc
                }else{
                    controllerName = NSLocalizedString("input_event_list_add_navigation_title", comment: "Title of the navigation item of the add input controller.")
                    type = .addEventController
                    
                    ///Generate localized strings
                    let nameChooserHeader = NSLocalizedString("input_event_list_add_name_chooser_header",
                                                              comment: "Header of the name chooser of the add controller.")
                    let nameChooserFooter = NSLocalizedString("input_event_list_add_name_chooser_footer",
                                                              comment: "Footer of the name chooser of the add controller.")
                    let eventChooserHeader = NSLocalizedString("input_event_list_add_event_chooser_header",
                                                               comment: "Header of the event chooser of the add controller.")
                    let eventChooserFooter = NSLocalizedString("input_event_list_add_event_chooser_footer",
                                                               comment: "Footer of the event chooser of the add controller.")
                    let imageChooserHeader = NSLocalizedString("input_event_list_add_image_chooser_header",
                                                               comment: "Header of the image chooser of the add controller.")
                    let imageChooserFooter = NSLocalizedString("input_event_list_add_image_chooser_footer",
                                                               comment: "Footer of the image chooser of the add controller.")
                    
                    nameChooser = NameChooserComponent(title: nameChooserHeader, footer: nameChooserFooter, name: "", tableView: tableView)
                    eventChooser = EventChooserComponent(title: eventChooserHeader, footer: eventChooserFooter, date: Date(), time: Date(), tableView: tableView)
                    imageChooser = ImageChooserComponent(title: imageChooserHeader, footer: imageChooserFooter, image: nil, tableView: tableView)
                    nameChooser.viewModel.delegate = dvc
                    eventChooser.viewModel.delegate = dvc
                    imageChooser.viewModel.delegate = dvc
                }
                
                ///Inject dependencies
                let viewModel = InputControllerViewModel(name: controllerName, type:type, components: [nameChooser, eventChooser, imageChooser])
                
                ///If row got selected: pass associated event to modify it
                if let indexPath = tableView.indexPathForSelectedRow{
                    let event = fetchedResultsController.object(at: indexPath)
                    viewModel.eventToModify = event
                }
                
                ///Pass managedObjectContext to be able to add/modify events
                viewModel.managedObjectContext = managedObjectContext
                dvc.injectDependencies(viewModel: viewModel, isNext: false)
            }
        }
    }
    
    ///Forward editButton behavior to tableView
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: true)
    }
}

//MARK: FetchedResultController
extension EventListController: NSFetchedResultsControllerDelegate{
    
    //MARK: - Table View
    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        
        ///Check whether the event list is empty and show a user message accordingly
        if sectionInfo.numberOfObjects == 0{
            backgroundView?.show()
        }else{
            backgroundView?.hide()
        }
        
        return sectionInfo.numberOfObjects
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else {return UITableViewCell()}
        let event = fetchedResultsController.object(at: indexPath)
        
        if event.imageOfEvent == nil {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "eventCell", for: indexPath) as? EventCell else {return UITableViewCell()}
            cell.viewModel = viewModel.eventCellViewModelFor(event)
            return cell
        }else{
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "eventWithImageCell", for: indexPath) as? EventWithImageCell else {return UITableViewCell()}
            cell.viewModel = viewModel.eventCellViewModelFor(event)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing{
            ///Determine previous event information
            let event = fetchedResultsController.object(at: indexPath)
            ///Perform segue
            performSegue(withIdentifier: "segueToEventController", sender: event)
        }else{
            showContent()
        }
        ///Deselect Row again
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func showContent(){
        guard let splitVC = splitViewController else {return}
        
        needToRefreshDetailView = (splitVC.viewControllers[safe: 1] as? UINavigationController)?.topViewController as? OutputController == nil
        
        ///Refresh the detail view in the first instance
        if needToRefreshDetailView || splitVC.isCollapsed{
            ///View not yet there
            needToRefreshDetailView = false
            performSegue(withIdentifier: "showEventListDetail", sender: self)
        }else{
            ///View already there
            delegate?.inputDidUpdate(obtainInput())
        }
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let context = fetchedResultsController.managedObjectContext
            context.delete(fetchedResultsController.object(at: indexPath))
            
            do {
                try context.save()
            } catch {
                /// Replace this implementation with code to handle the error appropriately.
                /// fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    //MARK: - Fetched results controller
    
    private func updateFetchResultsController(){
        ///Ensure that the cache is deleted before setting a new predicate or sort descriptor
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: "Event_List_Cache")
        _fetchedResultsController = nil
        tableView.reloadData()
    }
    
    var fetchedResultsController: NSFetchedResultsController<Event> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        
        fetchRequest.fetchBatchSize = 20
        
        var sortDescriptors = [NSSortDescriptor]()
        
        switch Settings.shared.sortBy {
        case .nameOfEvent:
            sortDescriptors.append(
                NSSortDescriptor(key: Settings.shared.sortBy.rawValue,
                                 ascending: (Settings.shared.sortingOrder == .ascending),
                                 selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            )
        case .dateOfEvent, .dateOfCreation:
            sortDescriptors.append(
                NSSortDescriptor(key: Settings.shared.sortBy.rawValue,
                                 ascending: (Settings.shared.sortingOrder == .ascending))
            )
        }
        fetchRequest.sortDescriptors = sortDescriptors
        
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext!, sectionNameKeyPath: nil, cacheName: "Event_List_Cache")
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        return _fetchedResultsController!
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            return
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            let cell = tableView.cellForRow(at: indexPath!)!
            if let cell = cell as? EventCell{
                cell.viewModel = viewModel?.eventCellViewModelFor(anObject as! Event)
            }
            if let cell = cell as? EventWithImageCell{
                cell.viewModel = viewModel?.eventCellViewModelFor(anObject as! Event)
            }
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

extension EventListController:SettingsDelegate{
    func sortByDidUpdateTo(_ sortBy: SortBy) {
        updateFetchResultsController()
    }
    
    func sortingOrderDidUpdateTo(_ sortingOrder: SortingOrder) {
        updateFetchResultsController()
    }
}
