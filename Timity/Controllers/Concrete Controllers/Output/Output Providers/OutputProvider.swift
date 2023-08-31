//
//  OutputProvider.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/10/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

protocol OutputProviderDelegate: AnyObject{
    func sectionsDidUpdate(_ sections:[Section])
}

enum TimeCategory{
    case now
    case past
    case future
}

class OutputProvider{
    
    ///Generate localized strings
    let operationString = NSLocalizedString("operation",
                                        comment: "String preceding the operation type.")
    let yearsString = NSLocalizedString("component_years",
                                        comment: "String preceding years.")
    let monthsString = NSLocalizedString("component_months",
                                         comment: "String preceding months.")
    let weeksString = NSLocalizedString("component_weeks",
                                        comment: "String preceding weeks.")
    let daysString = NSLocalizedString("component_days",
                                       comment: "String preceding days.")
    let hoursString = NSLocalizedString("component_hours",
                                        comment: "String preceding hours.")
    let minutesString = NSLocalizedString("component_minutes",
                                          comment: "String preceding minutes.")
    let secondsString = NSLocalizedString("component_seconds",
                                          comment: "String preceding seconds.")
    
    var labels:[String:String]{
        return ["years":yearsString,
                "months":monthsString,
                "weeks":weeksString,
                "days":daysString,
                "hours":hoursString,
                "minutes":minutesString,
                "seconds":secondsString]
    }
    
    ///Properties
    weak var delegate:OutputProviderDelegate?
    var input:Input
    var timer:Timer?
    
    init(input:Input) {
        self.input = input
    }
    
    ///LifeCycle
    func start(){
        fatalError("start must be overriden")
    }
    
    ///Meant to be overriden
    @objc func computeSections(){
        fatalError("computeSections must be overriden")
    }
    
    func stop(){
        fatalError("stop must be overriden")
    }
    
    func individualComponentsHeader(for timeCategory:TimeCategory)->String{
        fatalError("individualComponentsHeader now must be overriden")
    }
    
    func individualComponentsFooter(for timeCategory:TimeCategory)->String{
        fatalError("individualComponentsFooter now must be overriden")
    }
    
    func combinedComponentsHeader(for timeCategory:TimeCategory)->String{
        fatalError("combinedComponentsHeader now must be overriden")
    }
    
    func combinedComponentsFooter(for timeCategory:TimeCategory)->String{
        fatalError("combinedComponentsFooter now must be overriden")
    }
    
    ///Background View
    func dataForEmptyBackgroundView()->(title:String, message:String, image:UIImage?)?{
        return nil
    }
}

extension OutputProvider{
    
    func rowsFor(values:[(left:String, right:String, key:String)],
                 identifier:String)->[Row] {
        ///Configure cellViewModels
        var rows = [Row]()
        
        for value in values{
            let leftRightValue = LeftRightValue(leftText: value.left, rightText: value.right)
            rows.append(Row(id: "\(identifier)_\(value.key)", value: leftRightValue))
        }
        return rows
    }
    
    func rowsForChosenComponents(identifier:String, chosenComponents:IntDateComponents)->[Row]{
        var chosenValues = [(left:String, right:String, key:String)]()
        
        ///Add chosen components
        if chosenComponents.years != 0 {
            chosenValues.append((labels["years"]!,"\(String(abs(chosenComponents.years)))","years"))
        }
        if chosenComponents.months != 0 {
            chosenValues.append((labels["months"]!,"\(String(abs(chosenComponents.months)))","months"))
        }
        if let weeks = chosenComponents.weeks{
            if weeks != 0 {
                chosenValues.append((labels["weeks"]!,"\(String(abs(weeks)))","weeks"))
            }
        }
        if chosenComponents.days != 0 {
            chosenValues.append((labels["days"]!,"\(String(abs(chosenComponents.days)))","days"))
        }
        if chosenComponents.hours != 0 {
            chosenValues.append((labels["hours"]!,"\(String(abs(chosenComponents.hours)))","hours"))
        }
        if chosenComponents.minutes != 0 {
            chosenValues.append((labels["minutes"]!,"\(String(abs(chosenComponents.minutes)))","minutes"))
        }
        
        return rowsFor(values: chosenValues, identifier: identifier)
    }
    
    func rowsForIntComponents(identifier:String,
                              startDate:Date,
                              endDate:Date,
                              showSeconds:Bool)->[Row] {
        
        ///Determine range components
        let individualUnits = Calculations.calculateIndividualComponents(startDate: startDate,
                                                                         endDate: endDate)
        
        var values = [(left:String, right:String, key:String)]()
        for key in ["years","months","days","hours","minutes","seconds"]{
            if !showSeconds && key == "seconds"{continue}
            if
                let value = individualUnits[key],
                let leftText = labels[key]{
                
                if value != 0 || key == "seconds"{
                    values.append((leftText, String(abs(value)),key))
                }
            }
        }
        return rowsFor(values: values, identifier: identifier)
    }
    
    func rowsForDoubleComponents(identifier:String,
                                 startDate:Date,
                                 endDate:Date,
                                 showSeconds:Bool)->[Row] {
        ///Configure cellViewModels
        var rows = [Row]()
        
        ///Determine range components
        let combinedUnits = Calculations.calculateCombinedComponents(startDate: startDate,
                                                                     endDate: endDate)
        for key in ["years","months","days","hours","minutes","seconds"]{
            if !showSeconds && key == "seconds"{continue}
            if
                let value = combinedUnits[key],
                let leftText = labels[key]{
                
                ///For all keys check whether the value is !=0, except for seconds:they are always added
                var addRow = true
                if key != "seconds"{
                    if value == 0 {addRow = false}
                }
                
                if addRow{
                    if (abs(value)).roundTo(places: 2) > 0{
                        let leftRightValue = LeftRightValue(leftText: leftText,
                                                            rightText: String(format: "%.2f", abs(value)))
                        rows.append(Row(id: "\(identifier)_\(key)", value: leftRightValue))
                    }
                }
            }
        }
        return rows
    }
    
    func individualComponentsHeader(startDate:Date, endDate:Date)->String{
        if startDate == endDate{
            return individualComponentsHeader(for: .now)
        }else if startDate < endDate{
            return individualComponentsHeader(for: .past)
        }else{
            return individualComponentsHeader(for: .future)
        }
    }
    
    func individualComponentsFooter(startDate:Date, endDate:Date)->String{
        if startDate == endDate{
            return individualComponentsFooter(for: .now)
        }else if startDate < endDate{
            return individualComponentsFooter(for: .past)
        }else{
            return individualComponentsFooter(for: .future)
        }
    }
    
    func combinedComponentsHeader(startDate:Date, endDate:Date)->String{
        if startDate == endDate{
            return combinedComponentsHeader(for: .now)
        }else if startDate < endDate{
            return combinedComponentsHeader(for: .past)
        }else{
            return combinedComponentsHeader(for: .future)
        }
    }
    
    func combinedComponentsFooter(startDate:Date, endDate:Date)->String{
        if startDate == endDate{
            return combinedComponentsFooter(for: .now)
        }else if startDate < endDate{
            return combinedComponentsFooter(for: .past)
        }else{
            return combinedComponentsFooter(for: .future)
        }
    }
}
























