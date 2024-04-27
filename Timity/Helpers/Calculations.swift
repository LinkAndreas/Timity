//
//  Calculations.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/10/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

struct DoubleDateComponents {
    var years:Double
    var months:Double
    var weeks:Double?
    var days:Double
    var hours:Double
    var minutes:Double
    var seconds:Double
}

struct IntDateComponents {
    var years:Int
    var months:Int
    var weeks:Int?
    var days:Int
    var hours:Int
    var minutes:Int
    var seconds:Int
}

class Calculations {
    
    //properties
    static let calendar = NSCalendar.current
    
    //MARK: - Add/Subtract components to date
    static func calculateDateByAddingOrSubtractingComponents(years:Int, months:Int, weeks:Int?, days:Int, hours:Int, minutes:Int, originalDate:Date, isAdding:Bool)->Date?{
        let calendar = NSCalendar.current
        var offsetComponents = DateComponents()
        
        var sign = 0
        if isAdding {
            //Case add
            sign = 1
        }else{
            //Case minus
            sign = -1
        }
        
        //Set offset component
        offsetComponents.year = years*sign
        offsetComponents.month = months*sign
        if let weeks = weeks{
            offsetComponents.weekOfYear = weeks*sign
        }
        offsetComponents.day = days*sign
        offsetComponents.hour = hours*sign
        offsetComponents.minute = minutes*sign
        
        return calendar.date(byAdding: offsetComponents, to: originalDate)
    }
    
    static func calculateIndividualComponents(startDate:Date, endDate:Date)->[String:Int]{
        
        let range = calendar.dateComponents([.second,.minute,.hour,.day,.month,.year], from: startDate, to: endDate)
        
        ///Individual
        return ["years": range.year!,
                "months": range.month!,
                "days": range.day!,
                "hours": range.hour!,
                "minutes": range.minute!,
                "seconds": range.second!]
        
    }
    
    static func calculateCombinedComponents(startDate:Date, endDate:Date)->[String:Double]{
        
        let interval = Double(Int(startDate.timeIntervalSince(endDate)))
        
        ///Combined
        return ["years": interval * 0.0000000316887646,
                "months": interval * 0.000000380265176,
                "days": interval * 0.0000115740741,
                "hours": interval * 0.000277777778,
                "minutes": interval * 0.0166666667,
                "seconds": interval]
    }
    
    //replace time of given date with 00:00
    static func normalizeTimeOfDate(date:Date)->Date{
        return NSCalendar.current.startOfDay(for: date)
    }
    
    static func dateWithoutSeconds(_ date:Date)->Date{
        return dateWithComponents(date, components: [.year, .month, .day, .hour, .minute])
    }
    
    static func dateWithoutTime(_ date:Date)->Date{
        return dateWithComponents(date, components: [.year, .month, .day])
    }
    
    static func dateWithComponents(_ date:Date, components:Set<Calendar.Component>)->Date{
        let components = calendar.dateComponents(components, from: date)
        return calendar.date(from: components)!
    }
    
    static func dateOfNextFullSeond(_ date:Date)->Date?{
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let currentDateWithoutMilliseconds = calendar.date(from: components)!
        var dateComponents = DateComponents()
        dateComponents.second = 1
        return calendar.date(byAdding: dateComponents, to: currentDateWithoutMilliseconds)
    }
}
