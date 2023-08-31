//
//  OutputController.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/9/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

protocol OutputControllerDelegate: AnyObject {
    func inputDidUpdate(_ input: Input?)
}

class OutputController: ThemeableTableViewController {
    
    ///Properties
    fileprivate let viewModel = OutputControllerViewModel()
    var outputProvider:OutputProvider?
    var emptyTableBackgroundView:EmptyTableBackgroundView?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        ///Setup UI
        setupUI()
        
        ///Register ourseleves as delegate of the associated model
        viewModel.delegate = self
        
        ///Register TableView Datasource
        tableView.dataSource = viewModel
        tableView.delegate = viewModel
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupNavBar()
    }
    
    private func setupUI(){
        
        ///Disable Seperators
        tableView.separatorStyle = .none
        
        ///Disable scrollIndicators
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        
        ///Configure dynamic cell size
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = UITableView.automaticDimension
        
        ///Setup controls for SplitViewController
        navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        navigationItem.leftItemsSupplementBackButton = true
    }
    
    private func setupNavBar(){
        ///Configure LargeTitles
        navigationItem.largeTitleDisplayMode = .never
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        outputProvider?.stop()
        outputProvider?.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        outputProvider?.stop()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
    }
}

extension OutputController:OutputControllerViewModelDelegate{
    func apply(changes: SectionChanges) {
        
        let criticalSections = changes.deletes.union(changes.inserts).union(changes.reloads)
        let criticalRows = changes.updates.deletes + changes.updates.inserts
        
        var indexPathsToBeUpdated = [IndexPath]()
        
        ///MORE LIGHTWEIGHT UPDATE: only reload entire tableView when sections/rows got added or removed
        if (!criticalSections.isEmpty || !criticalRows.isEmpty){
            
            tableView.beginUpdates()
            
            tableView.deleteSections(changes.deletes, with: .automatic)
            tableView.insertSections(changes.inserts, with: .automatic)
            tableView.reloadSections(changes.reloads, with: .fade)

            tableView.deleteRows(at: changes.updates.deletes, with: .fade)
            tableView.insertRows(at: changes.updates.inserts, with: .fade)
            
            tableView.endUpdates()
            
            ///Update all cells
            for section in 0..<viewModel.numberOfSections(in: tableView){
                for row in 0..<viewModel.tableView(tableView, numberOfRowsInSection: section){
                    indexPathsToBeUpdated.append(IndexPath(row: row, section: section))
                }
            }
        }else{
            ///Only update cells that need to be updated
            indexPathsToBeUpdated = changes.updates.reloads
        }
        
        ///Update all indexPaths
        for indexPath in indexPathsToBeUpdated{
            if let cell = tableView.cellForRow(at: indexPath) as? OutputLeftRightCell{
                if let data = viewModel.sections[indexPath.section].rows[indexPath.row].value as? LeftRightValue{
                    cell.leftLabel.text = data.leftText
                    cell.rightLabel.text = data.rightText
                }
            }else if let cell = tableView.cellForRow(at: indexPath) as? EventImageCell{
                if let data = viewModel.sections[indexPath.section].rows[indexPath.row].value as? ImageValue{
                    cell.eventImageView.image = UIImage(data:data.imageData)
                }
            }
        }
    }
}

extension OutputController:OutputProviderDelegate{
    func sectionsDidUpdate(_ sections: [Section]) {
        viewModel.update(sections: sections)
        
        ///Show/Hide empty data source according to numberOfSections
        if sections.count == 0{
            emptyTableBackgroundView?.show()
        }else{
            emptyTableBackgroundView?.hide()
        }
    }
}

extension OutputController:OutputControllerDelegate{
    func inputDidUpdate(_ input: Input?) {

        guard let input = input else {return}
        
        ///Set Navigation item title
        if let navigationTitle = input.data[0] as? String{
            navigationItem.title = navigationTitle
        }
        
        ///Stop any previous OutputProvider
        outputProvider?.stop()
        
        switch input.type {
        case .eventListResult:
            outputProvider = EventListOutputProvider(input:input)
        case .eventCalculatorResult:
            outputProvider = EventCalculatorOutputProvider(input:input)
        case .timeCalculatorResult:
            outputProvider = TimeCalculatorOutputProvider(input:input)
        case .durationCalculatorResult:
            outputProvider = DurationCalculatorOutputProvider(input:input)
        case .solarCalculatorResult:
            outputProvider = SolarOutputProvider(input:input)
        }
        
        ///Register the delegate
        outputProvider?.delegate = self
        
        ///Setup EmptyDataBackgroundView
        setupEmptyDataBackgroundView()
        
        ///Generate Output to be shown by the OutputController
        outputProvider?.start()
        
    }
    
    private func setupEmptyDataBackgroundView(){
        if let emptyBackgroundData = outputProvider?.dataForEmptyBackgroundView(){
            ///Create emptyTableBackgroundView
            emptyTableBackgroundView = EmptyTableBackgroundView(title: emptyBackgroundData.title,
                                                                message: emptyBackgroundData.message,
                                                                image: emptyBackgroundData.image)
            ///Assign emptyTableBackgroundView
            tableView.backgroundView = emptyTableBackgroundView
        }else{
            tableView.backgroundView = nil
        }
    }

}
