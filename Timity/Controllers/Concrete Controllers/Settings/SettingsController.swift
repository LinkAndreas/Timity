//
//  SettingsController.swift
//  Timity
//
//  Created by Andreas Link on 2/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class SettingsController: ThemeableTableViewController {
    
    ///Settings
    let themeTypes:[ThemeType] = [.black,.dark,.light]
    let highlightColors:[HighlightColor] = [.red,.orange,.yellow,.green,.tealBlue,.blue,.purple,.pink]
    let sortBys:[SortBy] = [.nameOfEvent,.dateOfEvent,.dateOfCreation]
    let sortingOrders:[SortingOrder] = [.ascending,.descending]
    
    var sections:[(header:String, footer:String, settings:[Setting])]{
        return [
            (
                NSLocalizedString("settings_theme_type_header", comment: "Header of the highlight color section in settings."),
                NSLocalizedString("settings_theme_type_footer", comment: "Footer of the highlight color section in settings."),
                themeTypes
            ),
            
            (
                NSLocalizedString("settings_highlight_color_header", comment: "Header of the highlight color section in settings."),
                NSLocalizedString("settings_highlight_color_footer", comment: "Footer of the highlight color section in settings."),
                highlightColors
            ),
            
            (
                NSLocalizedString("settings_sort_by_header", comment: "Header of the sort by section in settings."),
                NSLocalizedString("settings_sort_by_footer", comment: "Footer of the sort by section in settings."),
                sortBys
            ),
            
            (
                NSLocalizedString("settings_sorting_order_header", comment: "Header of the sorting order section in settings."),
                NSLocalizedString("settings_sorting_order_footer", comment: "Footer of the sorting order section in settings."),
                sortingOrders)
        ]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupNavBar()
    }
    
    private func setupNavBar(){
        ///Configure LargeTitles
        navigationItem.largeTitleDisplayMode = .never
        
        ///Setup Navigation Title
        navigationItem.title = NSLocalizedString("settings_navigation_title", comment: "Navigation title of settings.")
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        ///Set tableView tintColor to set tintcolor of all cells
        tableView.tintColor = theme.highlightColor
    }
}

extension SettingsController{
    //MARK: TableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].settings.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].header
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footer
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "basicLabelCell", for: indexPath) as? OutputBasicCell else {return UITableViewCell()}
        cell.label.text = sections[indexPath.section].settings[indexPath.row].description
        
        ///Update checkmarks accordingly
        let setting = sections[indexPath.section].settings[indexPath.row]
        
        if let themeType = setting as? ThemeType{
            cell.accessoryType = themeType == Settings.shared.themeType ? .checkmark : .none
        }else if let highlightColor = setting as? HighlightColor{
            cell.accessoryType = highlightColor == Settings.shared.highlightColor ? .checkmark : .none
        }else if let sortBy = setting as? SortBy{
            cell.accessoryType = sortBy == Settings.shared.sortBy ? .checkmark : .none
        }else if let sortingOrder = setting as? SortingOrder{
            cell.accessoryType = sortingOrder == Settings.shared.sortingOrder ? .checkmark : .none
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let setting = sections[indexPath.section].settings[indexPath.row]

        ///Compute Rows to reload
        var rowsIndexPaths = Set<IndexPath>()
        rowsIndexPaths.insert(indexPath)
        
        if let themeType = setting as? ThemeType{
            rowsIndexPaths.insert(indexPathForSetting(Settings.shared.themeType)!)
            Settings.shared.themeType = themeType
        }else if let highlightColor = setting as? HighlightColor{
            rowsIndexPaths.insert(indexPathForSetting(Settings.shared.highlightColor)!)
            Settings.shared.highlightColor = highlightColor
        }else if let sortBy = setting as? SortBy{
            rowsIndexPaths.insert(indexPathForSetting(Settings.shared.sortBy)!)
            Settings.shared.sortBy = sortBy
        }else if let sortingOrder = setting as? SortingOrder{
            rowsIndexPaths.insert(indexPathForSetting(Settings.shared.sortingOrder)!)
            Settings.shared.sortingOrder = sortingOrder
        }

        ///Update Checkmarks according to settings
        tableView.beginUpdates()
        tableView.reloadRows(at: Array(rowsIndexPaths), with: .fade)
        tableView.endUpdates()
    
        ///Deselect row again
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
    
    private func indexPathForSetting(_ setting:Setting)->IndexPath?{
        if let themeType = setting as? ThemeType{
            return IndexPath(row: themeTypes.firstIndex(of: themeType)!, section: 0)
        }else if let highlightColor = setting as? HighlightColor{
            return IndexPath(row: highlightColors.firstIndex(of: highlightColor)!, section: 1)
        }else if let sortBy = setting as? SortBy{
            return IndexPath(row: sortBys.firstIndex(of: sortBy)!, section: 2)
        }else if let sortingOrder = setting as? SortingOrder{
            return IndexPath(row: sortingOrders.firstIndex(of: sortingOrder)!, section: 3)
        }
        return nil
    }
}


