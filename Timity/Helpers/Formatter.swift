//
//  Formatter.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/10/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

class Formatter {
    
    ///Properties
    static var dateFormatter = DateFormatter()
    static var dateComponentsFormatter = DateComponentsFormatter()

    //MARK: Date/Time Formatting using preconfigured styles
    static func format(date:Date, style:DateFormatterStyle)->String{
        
        switch style {
        case .date:
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .none
        case .time:
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short
        case .dateAndTime:
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
        }
        
        return dateFormatter.string(from: date)
    }
    
    //MARK: Date/Time Formatting from given Format String
    static func format(date:Date, dateFormat:String)->String{
        dateFormatter.dateFormat = dateFormat
        return dateFormatter.string(from: date)
    }
    
    //MARK: Date Components Formatting using preconfigured styles
    static func format(timeInterval:TimeInterval, style:DateComponentsFormatter.UnitsStyle)->String?{
        dateComponentsFormatter.unitsStyle = style
        dateComponentsFormatter.allowedUnits = [.hour, .minute]
        return dateComponentsFormatter.string(from: timeInterval)
    }
}

///DateFormatter style
enum DateFormatterStyle{
    case date
    case time
    case dateAndTime
}
