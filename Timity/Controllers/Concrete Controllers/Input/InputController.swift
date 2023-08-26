//
//  InputController.swift
//  Timity
//
//  Created by Andreas Link on 1/19/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit
import Photos

class InputController: ThemeableTableViewController {
    
    ///Properties
    var viewModel:InputControllerViewModel?
    private var rightBarButton:UIBarButtonItem?
    private var isNext:Bool?
    private var currentlyPickingImage = false
    private var needToRefreshDetailView:Bool{
        guard let detailNC = splitViewController?.viewControllers[safe:1] as? UINavigationController else {return false}
        if let oc = (detailNC.topViewController as? OutputController){
            delegate = oc
            return false
        }else{
            return true
        }
    }
    var delegate:OutputControllerDelegate?
    
    ///Lifecyle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    ///Called after prepareForSegue was being called
    func injectDependencies(viewModel:InputControllerViewModel, isNext:Bool){
        self.viewModel = viewModel
        self.isNext = isNext
    }
    
    private func setupUI(){
        
        ///Configure LargeTitles
        navigationItem.largeTitleDisplayMode = UIDevice.current.userInterfaceIdiom == .pad ? .never : .always

        ///Disable scrollIndicators
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        
        ///Set NavigationItem name
        navigationItem.title = viewModel?.name
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let viewModel = viewModel{
            switch viewModel.type {
            case .addEventController, .modifyEventController:
                ///Show Placeholder
                showPlaceholder()
            default:
                ///Present Content
                showContent(isNextButton: false)
            }
        }
        
        ///Update RightBarButton
        updateRightBarButton()
        
        ///Register to be notified for orientation changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(InputController.orientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
        
        ///Listen to imagePicker requests
        listenToImagePickerRequests()
    
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        ///Only activate NameChooser if not currently picking an image
        if currentlyPickingImage {
            currentlyPickingImage = false
            return
        }
        ///Check if we are of type addEventController
        guard let viewModel = viewModel else {return}
        if viewModel.type == .addEventController{
            guard let nameChooser = viewModel.components[0] as? NameChooserComponent else {return}
            nameChooser.viewModel.activate()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        ///Remove ourselves as observer of orientation changes
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        
        ///Remove ourselves as observer
        stopListeningToImagePickerRequests()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        ///Update RightBarButton
        updateRightBarButton()
    }
    
    @objc func orientationDidChange(){
        updateRightBarButton()
        showContent(isNextButton: false)
    }
    
    ///Update next button
    @objc func updateRightBarButton(){
        guard let viewModel = viewModel else {return}
        
        ///Setup rightBar button (but only if not collapsed)
        rightBarButton = UIBarButtonItem(title: viewModel.titleForRightBarButton(), style: .done, target: self, action: #selector(rightBarButtonPressed(_:)))
        if let splitVC = self.splitViewController{
            if splitVC.isCollapsed{
                ///iPhone
                navigationItem.rightBarButtonItem = rightBarButton
            }else{
                ///iPad
                if viewModel.isCalculator(){
                    navigationItem.rightBarButtonItem = nil
                }else{
                    navigationItem.rightBarButtonItem = rightBarButton
                }
            }
        }
    }
    
    ///Next button - action
    @objc func rightBarButtonPressed(_ sender: Any){
        guard let viewModel = viewModel else {return}
        if viewModel.isCalculator() {
            AppRatingEventSystem.default.send(event: .usedCalculator)
            showContent(isNextButton: true)
        }else{
            ///Update DataStorage
            _ = viewModel.updateDataStorage()
            viewModel.resetDataStorageDependencies()
            
            if viewModel.type == .addEventController {
                AppRatingEventSystem.default.send(event: .eventAdded)
            }
            
            ///Dismiss EventController
            _ = self.navigationController?.popViewController(animated: true)
        }
    }
    
    private func showPlaceholder(){
        ///Present Default Detail view if not collapsed
        guard let splitVC = splitViewController else {return}
        if !splitVC.isCollapsed{
            performSegue(withIdentifier: "showPlaceholder", sender: self)
        }
    }
    
    func showContent(isNextButton:Bool){
        guard let splitVC = splitViewController else {return}
        if !isNextButton && splitVC.isCollapsed{
            return
        }
        
        ///Do not show detailView when modifying/adding an event
        if let type = viewModel?.type{
            if (type == .addEventController || type == .modifyEventController){
                return
            }
        }
        
        ///Refresh the detail view in the first instance
        if needToRefreshDetailView || isNextButton{
            ///View not yet there
            performSegue(withIdentifier: "segueToOutputController", sender: self)
        }else{
            ///View already there
            let input = obtainInput()
            delegate?.inputDidUpdate(input)
        }
    }
}

extension InputController{
    // MARK: - Table view
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.components.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.components[section].numberOfRowsInSection(section: section) ?? 0
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return viewModel?.components[indexPath.section].heightForRowAt(indexPath:indexPath, tableView:tableView) ?? 0.0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel?.components[section].titleForHeader() ?? ""
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return viewModel?.components[section].titleForFooter() ?? ""
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return viewModel?.components[indexPath.section].cellForRowAt(indexPath: indexPath, tableView: tableView) ?? UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        ///Deselect Row again
        tableView.deselectRow(at: indexPath, animated: true)
        
        ///Tell all other components to resignFirstResponder
        viewModel?.resignFirstResponderOfAllComponentsExceptFor(indices: [indexPath.section])
        
        ///Use dispatch after to ensure that the keyboard is properly dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0, execute: { [weak self] in
            self?.viewModel?.components[indexPath.section].didSelectRowAt(indexPath: indexPath, tableView: tableView)
            self?.tableView.beginUpdates()
            self?.tableView.endUpdates()
            
            guard let viewModel = self?.viewModel else {return}
            if viewModel.components[indexPath.section].shouldScrollToNextCell(indexPath: indexPath, tableView: tableView){
                ///Case: next Cell should be scrolled into visible area
                let indexPathOfNextCell = IndexPath(row: indexPath.row + 1, section: indexPath.section)
                self?.tableView.scrollToRow(at: indexPathOfNextCell,
                                      at: .bottom,
                                      animated: true)
            }else{
                if viewModel.components[indexPath.section].shouldScrollToCell(indexPath: indexPath, tableView: tableView){
                    ///Case: current Cell should be scrolled into visible area
                    self?.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                }
            }
        })
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return viewModel?.components[indexPath.section].shouldHighlightRowAt(indexPath: indexPath, tableView: tableView) ?? true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToOutputController"{
            guard let dnc = segue.destination as? UINavigationController else {return}
            guard let dvc = dnc.topViewController as? OutputController else {return}
            delegate = dvc
            let input = obtainInput()
            delegate?.inputDidUpdate(input)
        }
    }
    
    func obtainInput()->Input?{
        guard let viewModel = viewModel else {return nil}
        switch viewModel.type {
        case .eventCalculator:
            
            let eventCalculatorOutputNavigationTitle = NSLocalizedString("output_event_calculator_navigation_title",
                                                                         comment: "Navigation title of the output of the event calculator.")
            
            ///Retrieve information for the OutputController
            guard let eventChooser = viewModel.components[0] as? EventChooserComponent else {return nil}
            let date = eventChooser.result()
            return Input(type: .eventCalculatorResult, data: [eventCalculatorOutputNavigationTitle, date])
            
        case .timeCalculator:
            
            let timeCalculatorOutputNavigationTitle = NSLocalizedString("output_time_calculator_navigation_title",
                                                                        comment: "Navigation title of the output of the time calculator.")
            
            ///Retrieve information for the OutputController
            guard let eventChooser = viewModel.components[0] as? EventChooserComponent else {return nil}
            guard let componentsChooser = viewModel.components[1] as? ComponentsChooserComponent else {return nil}
            let date = eventChooser.result()
            let componentsTuple = componentsChooser.result()
            return Input(type: .timeCalculatorResult, data: [timeCalculatorOutputNavigationTitle, date, componentsTuple])
            
        case .durationCalculator:
            
            let durationCalculatorOutputNavigationTitle = NSLocalizedString("output_duration_calculator_navigation_title",
                                                                            comment: "Navigation title of the output of the duration calculator.")
            
            ///Retrieve information for the OutputController
            guard let eventChooser1 = viewModel.components[0] as? EventChooserComponent else {return nil}
            guard let eventChooser2 = viewModel.components[1] as? EventChooserComponent else {return nil}
            let startDate = eventChooser1.result()
            let endDate = eventChooser2.result()
            return Input(type: .durationCalculatorResult, data: [durationCalculatorOutputNavigationTitle, startDate, endDate])
            
        case .addEventController:
            return nil
            
        case .modifyEventController:
            return nil
        }
    }
}

///Conform to ComponentDelegate protocol
extension InputController:ComponentViewModelDelegate{
    func resultDidChange() {
        guard let viewModel = viewModel else {return}
        if viewModel.isCalculator(){
            ///Update UI immediately in case of a calculator
            showContent(isNextButton: false)
        }
    }
}

//MARK: - UINavigationControllerDelegate, UIImagePickerControllerDelegate
extension InputController:UINavigationControllerDelegate,UIImagePickerControllerDelegate{
    
    func listenToImagePickerRequests(){
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(self.selectPicture(_:)),
                       name: NSNotification.Name(rawValue: "imagePickerRequest"),
                       object: nil)
    }
    
    func stopListeningToImagePickerRequests(){
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: NSNotification.Name(rawValue: "imagePickerRequest"), object: nil)
    }
    
    @objc func selectPicture(_ notification: NSNotification) {
        guard let imageView = notification.userInfo?["imageView"] as? UIImageView else {return}
        
        //Photos
        let photoStatus = PHPhotoLibrary.authorizationStatus()
        switch photoStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                guard let self = self else { return }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    switch status {
                    case .authorized:
                        ///Case 1: Access to photos granted
                        self.showImagePicker(from: imageView, inputController:self)

                    default:
                        ///Case 2: Access to photos not granted -> show Alert
                        self.indicateAccessToPhotosDenied()
                    }
                }
            }

        case .authorized:
            showImagePicker(from: imageView, inputController: self)

        case .denied, .restricted, .limited:
            indicateAccessToPhotosDenied()

        @unknown default:
            break
        }
    }
    
    private func showImagePicker(from view:UIView, inputController:InputController?){
        guard let splitVC = splitViewController else {return}
        let picker = UIImagePickerController()
        picker.allowsEditing = false
        picker.delegate = self
        
        if UIDevice.current.userInterfaceIdiom == .pad && !splitVC.isCollapsed{
            ///iPad ---> Popover
            picker.modalPresentationStyle = .popover
            let popover = picker.popoverPresentationController!
            popover.delegate = self
            popover.permittedArrowDirections = .left
            
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        inputController?.currentlyPickingImage = true
        inputController?.present(picker, animated: true)
    }
    
    private func indicateAccessToPhotosDenied(){
        ///Notify that the image did not get selected
        let nc = NotificationCenter.default
        nc.post(name: Notification.Name("imageDidNotGetSelected"), object: nil)
        
        ///Generate localized strings
        let accessDeniedTitle = NSLocalizedString("alert_photo_access_denied_title",
                                                  comment: "Alert title indicating that the photo access is denied in settings.")
        let accessDeniedMessage = NSLocalizedString("alert_photo_access_denied_message",
                                                    comment: "Alert message indicating that the photo access is denied in settings.")
        
        AlertManager.shared.showAlertWith(title: accessDeniedTitle,
                                      message: accessDeniedMessage)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        
        ///Notify that the image did not get selected
        let nc = NotificationCenter.default
        nc.post(name: Notification.Name("imageDidNotGetSelected"), object: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        guard let image = info[.originalImage] as? UIImage else { return }
        
        var userInfo = [AnyHashable:Any]()
        if let imageData = image.jpegData(compressionQuality: 0.15){
            userInfo = ["imageData":imageData]
        }

        ///Notify that the image got selected
        let nc = NotificationCenter.default
        nc.post(name: Notification.Name("imageGotSelected"), object: nil, userInfo: userInfo)
        
        picker.dismiss(animated:true)
    }
}


///Conform to PopovercontrollerDelegate
extension InputController:UIPopoverPresentationControllerDelegate{
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}
