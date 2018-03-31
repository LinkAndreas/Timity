//
//  TableViewChangeManager.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/9/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

//Mark: DataStructures to store changes that need to be done by the tableView
struct SectionChanges {
    var inserts:IndexSet
    var deletes:IndexSet
    var reloads:IndexSet
    var updates:CellChanges
    
    init(inserts:IndexSet = IndexSet(),
         deletes:IndexSet = IndexSet(),
         reloads:IndexSet = IndexSet(),
         updates:CellChanges = CellChanges()) {
        self.inserts = inserts
        self.deletes = deletes
        self.reloads = reloads
        self.updates = updates
    }
}

struct CellChanges {
    var inserts:[IndexPath]
    var deletes:[IndexPath]
    var reloads:[IndexPath]
    
    init(inserts:[IndexPath] = [],
         deletes:[IndexPath] = [],
         reloads:[IndexPath] = []) {
        self.inserts = inserts
        self.deletes = deletes
        self.reloads = reloads
    }
}

//Mark: DataStructures to identify sections/rows that need to be inserted/updated/removed
struct ComparableSection<T:Equatable>:Equatable{
    var identifier:String
    var header:String
    var footer:String
    var value:[ComparableRow<T>]
    var index:Int
    
    static func == (lhs: ComparableSection, rhs: ComparableSection) -> Bool{
        return lhs.identifier == rhs.identifier && lhs.header == rhs.header && lhs.footer == rhs.footer && lhs.value == rhs.value
    }
}

struct ComparableRow<T:Equatable>:Equatable{
    var identifier:String
    var value:T
    var index:Int
    
    static func == (lhs: ComparableRow, rhs: ComparableRow) -> Bool{
        return lhs.identifier == rhs.identifier && lhs.value == rhs.value
    }
}

//Mark: TableViewChangeManager: implementing logic to compute changes between old and new tableViewData
class TableViewChangeManager{
    static func computeChanges<T>(oldSections:[ComparableSection<T>],
                                  newSections:[ComparableSection<T>])->SectionChanges{
        var sectionChanges = SectionChanges()
        let uniqueSectionIdentifiers = (oldSections + newSections).map{$0.identifier}.filterDuplicates()
        
        var cellChanges = CellChanges()
        
        for sectionIdentifier in uniqueSectionIdentifiers{
            let oldSection = oldSections.filter{$0.identifier == sectionIdentifier}.first
            let newSection = newSections.filter{$0.identifier == sectionIdentifier}.first
            
            ///Determine whether the section was updated, inserted or removed
            if
                let oldSection = oldSection,
                let newSection = newSection{
                ///Case 1: The section associated with the given identifier was updated
                if (oldSection.header != newSection.header) || (oldSection.footer != newSection.footer){
                    sectionChanges.reloads.insert(oldSection.index)
                }
                
                computeCellChanges(oldSection: oldSection,
                                   newSection: newSection,
                                   cellChanges: &cellChanges)
            }else if let newSection = newSection{
                ///Case 2: The section associated with the given identifier was added
                sectionChanges.inserts.insert(newSection.index)
            }else if let oldSection = oldSection{
                ///Case 3: The section associated with the given identifier was deleted
                sectionChanges.deletes.insert(oldSection.index)
            }
        }
        sectionChanges.updates = cellChanges
        return sectionChanges
    }
    
    static func computeCellChanges<T>(oldSection:ComparableSection<T>, newSection:ComparableSection<T>, cellChanges:inout CellChanges){
        
        let oldCells = oldSection.value
        let newCells = newSection.value
        
        let uniqueCellIdentifiers = (oldCells + newCells).map{$0.identifier}.filterDuplicates()
        
        for cellIdentifier in uniqueCellIdentifiers{
            let oldCell = oldCells.filter{$0.identifier == cellIdentifier}.first
            let newCell = newCells.filter{$0.identifier == cellIdentifier}.first
            ///Determine whether the cell was updated, inserted or removed
            if
                let oldCell = oldCell,
                let newCell = newCell{
                ///Case 1: The cell associated with the given identifier was updated
                if oldCell.value != newCell.value{
                    let indexPath = IndexPath(row: oldCell.index, section: oldSection.index)
                    cellChanges.reloads.append(indexPath)
                }
            }else if let newCell = newCell{
                ///Case 2: The cell associated with the given identifier was added
                let indexPath = IndexPath(row: newCell.index, section: newSection.index)
                cellChanges.inserts.append(indexPath)
            }else if let oldCell = oldCell{
                ///Case 3: The cell associated with the given identifier was deleted
                let indexPath = IndexPath(row: oldCell.index, section: oldSection.index)
                cellChanges.deletes.append(indexPath)
            }
        }
    }
}
