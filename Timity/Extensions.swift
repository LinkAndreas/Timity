//
//  Extensions.swift
//  Timity
//
//  Created by Andreas Link on 1/19/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation
import UIKit
import MessageUI

extension Date{
    
    /**
     Combines date and time into a single date
     - parameter date: the date containing: year, month and day
     - parameter time: the time containing: hour, minute, second and timezone
     - returns: combined date and time in a single date
     */
    static func mergeDateWithTime(from date:Date, and time:Date)->Date?{
        let calendar = NSCalendar.current
        var dateComponents = calendar.dateComponents([.year,.month,.day], from: date)
        let timeComponents = calendar.dateComponents([.hour,.minute,.second,.timeZone], from: time)
        
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second
        dateComponents.timeZone = timeComponents.timeZone
        
        return calendar.date(from: dateComponents)
    }
}

///Allow to create colors from hex
extension UIColor {
    public convenience init?(hexString:String){
        let r,g,b:CGFloat
        if hexString.hasPrefix("#"){
            let start = hexString.index(hexString.startIndex, offsetBy: 1)
            let hexColor = String(hexString[start...])
            
            if hexColor.count == 6{
                let scanner = Scanner(string: hexColor)
                var hexNumber:UInt64 = 0
                if scanner.scanHexInt64(&hexNumber){
                    r = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    b = CGFloat((hexNumber & 0x000000ff) >> 0) / 255
                    
                    self.init(red:r,green:g,blue:b,alpha:1.0)
                    return
                }
            }
        }
        return nil
    }
}

extension UIView{
    func adaptSizeOfView(_ view:UIView?){
        guard let view = view else{ return }
        self.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[subview]-0-|", options: .directionLeadingToTrailing, metrics:nil, views:["subview":self]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[subview]-0-|", options: .directionLeadingToTrailing, metrics:nil, views:["subview":self]))
    }
}


extension Double {
    /// Rounds the double to decimal places value
    func roundTo(places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension UITableViewCell {
    
    func hideSeparator() {
        self.separatorInset = UIEdgeInsets(top: 0, left: self.bounds.size.width, bottom: 0, right: 0)
    }
    
    func showSeparator() {
        self.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

extension Collection{
    subscript (safe index:Index)->Element?{
        return indices.contains(index) ? self[index] : nil
    }
}

extension Array where Element: Hashable {
    
    /// Remove duplicates from the array, preserving the items order
    func filterDuplicates() -> Array<Element> {
        var set = Set<Element>()
        var filteredArray = Array<Element>()
        for item in self {
            if set.insert(item).inserted {
                filteredArray.append(item)
            }
        }
        return filteredArray
    }
}

//Source: https://gist.github.com/axldyb/9839c003e77701d1e7d1
extension UIImage {
    func cropsToSquare() -> UIImage? {
        guard let cgImage = self.cgImage else {return nil}
        let refWidth = CGFloat(cgImage.width)
        let refHeight = CGFloat(cgImage.height)
        let cropSize = refWidth > refHeight ? refHeight : refWidth
        
        let x = (refWidth - cropSize) / 2.0
        let y = (refHeight - cropSize) / 2.0
        
        let cropRect = CGRect(x: x, y: y, width:cropSize, height:cropSize)
        guard let imageRef = cgImage.cropping(to: cropRect) else {return nil}
        let cropped = UIImage(cgImage: imageRef, scale: 0.0, orientation: self.imageOrientation)
        
        return cropped
    }
}
