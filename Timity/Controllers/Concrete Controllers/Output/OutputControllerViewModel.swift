//
//  OutputControllerViewModel.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/9/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

protocol OutputControllerViewModelDelegate:class {
    func apply(changes:SectionChanges)
}

class ID{
    var value = ""
    
    ///Section IDs
    func header()->ID{ value = "header"; return self }
    func event()->ID{ value = "event"; return self }
    func operation()->ID{ value = "operation"; return self }
    func firstEvent()->ID{ value = "firstEvent"; return self }
    func secondEvent()->ID{ value = "secondEvent"; return self }
    func individualComponents()->ID{ value = "individualComponents"; return self }
    func combinedComponents()->ID{ value = "combinedComponents"; return self }
    func chosenComponents()->ID{ value = "chosenComponents"; return self }
    func result()->ID{ value = "result"; return self }
    func officialSolar()->ID{ value = "official"; return self }
    func civilSolar()->ID{ value = "civil"; return self }
    func nauticalSolar()->ID{ value = "nautical"; return self }
    func astronomicalSolar()->ID{ value = "astronomical"; return self }

    ///Row IDs
    func years()->ID{ value = "\(value)_years"; return self }
    func months()->ID{ value = "\(value)_months"; return self }
    func weeks()->ID{ value = "\(value)_weeks"; return self }
    func days()->ID{ value = "\(value)_days"; return self }
    func hours()->ID{ value = "\(value)_hours"; return self }
    func minutes()->ID{ value = "\(value)_minutes"; return self }
    func seconds()->ID{ value = "\(value)_seconds"; return self }
    
    func eventName()->ID{ value = "\(value)_eventName"; return self }
    func eventWeekday()->ID{ value = "\(value)_weekday"; return self }
    func eventDate()->ID{ value = "\(value)_eventDate"; return self }
    func eventTime()->ID{ value = "\(value)_eventTime"; return self }
    func eventImage()->ID{ value = "\(value)_eventImage"; return self }
    func firstEventDate()->ID{ value = "\(value)_firstEventDate"; return self }
    func secondEventDate()->ID{ value = "\(value)_secondEventDate"; return self }
    func operationType()->ID{ value = "\(value)_operationType"; return self }

    func sunrise()->ID{ value = "\(value)_sunrise"; return self }
    func sunset()->ID{ value = "\(value)_sunset"; return self }
    func daylight()->ID{ value = "\(value)_daylight"; return self }
}

struct Section{
    var id:String
    var header:String
    var footer:String
    var rows:[Row]
}

struct Row:Equatable{
    var id:String
    var value:Identifiable
    
    static func ==(lhs: Row, rhs: Row) -> Bool {
        return lhs.id == rhs.id && lhs.value.data == rhs.value.data
    }
}

protocol Identifiable{
    var data:Data { get }
}

struct LeftRightValue:Identifiable{
    var leftText:String
    var rightText:String
    
    var data:Data{
        return "\(leftText)_\(rightText)".data(using: .utf8)!
    }
}

struct ImageValue:Identifiable{
    var imageData:Data
    
    var data:Data{
        return imageData
    }
}

class OutputControllerViewModel:NSObject {
    
    ///Properties
    weak var delegate:OutputControllerViewModelDelegate?
    var sections = [Section]()
    
    /**
     Updates the tableViewData dynamically by determining which section/rows need to be inserted, updated or removed.
     - parameter sections: Array containing the section data
     */
    func update(sections:[Section]){
        let oldSections = makeComparable(sections:self.sections)
        let newSections = makeComparable(sections:sections)
        
        let changes = TableViewChangeManager.computeChanges(oldSections: oldSections,
                                                            newSections: newSections)
        self.sections = sections
        delegate?.apply(changes: changes)
    }
    
    /**
     Converts the given sections into a comparable data format to be analyzed by the TableViewChangeManager
     - parameter sections: Array containing the section data
     - returns: Array containing comparable sections to be used by the TableViewChangeManager
     - warning: Please ensure that generated identifiers are unique!
     */
    private func makeComparable(sections: [Section]) -> [ComparableSection<Row>] {
        var comparableSections = [ComparableSection<Row>]()
        
        for enumeratedSection in sections.enumerated(){
            var comparableRows = [ComparableRow<Row>]()
            for enumeratedRow in enumeratedSection.element.rows.enumerated(){
                let comparableRow = ComparableRow(identifier: "\(enumeratedSection.element.id)_\(enumeratedRow.element.id)",
                                                  value: enumeratedRow.element,
                                                  index: enumeratedRow.offset)
                comparableRows.append(comparableRow)
            }
            
            let comparableSection = ComparableSection(identifier: enumeratedSection.element.id,
                                                      header: enumeratedSection.element.header,
                                                      footer: enumeratedSection.element.footer,
                                                      value: comparableRows,
                                                      index: enumeratedSection.offset)
            comparableSections.append(comparableSection)
        }
        return comparableSections
    }
}

//Mark: TableView DataSource
extension OutputControllerViewModel: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        
        if let leftRightValue = row.value as? LeftRightValue{
            if let cell = tableView.dequeueReusableCell(withIdentifier: "outputLeftRightCell", for: indexPath) as? OutputLeftRightCell{
                cell.leftLabel.text = leftRightValue.leftText
                cell.rightLabel.text = leftRightValue.rightText
                return cell
            }
        }else if let imageValue = row.value as? ImageValue{
            if let cell = tableView.dequeueReusableCell(withIdentifier: "eventImageCell", for: indexPath) as? EventImageCell{
                cell.eventImageView.image = UIImage(data:imageValue.imageData)
                return cell
            }
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].header
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footer
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = sections[indexPath.section].rows[indexPath.row]
        
        if let _ = row.value as? ImageValue{
            return 190.0
        }
        return 44.0
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let _ = sections[section].rows.first?.value as? ImageValue{
            return 10.0
        }else{
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if let _ = sections[section].rows.first?.value as? ImageValue{
            return 5.0
        }else{
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}
