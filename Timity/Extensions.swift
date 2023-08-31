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

extension UIColor {
    /**
     Initializes a `UIColor` from the given hex string representation
     - Parameter hex: The `String` which is used to calculate the rgb values
        The format of hex has to be of format "#RRGGBB" or "#AARRGGBB" where
            RR encodes the value for red in a hexadecimal integer
            GG encodes the value for green in a hexadecimal integer
            BB encodes the value for blue in a hexadecimal integer
            AA encodes the value for alpha in a hexadecimal integer
     - Returns: `UIColor` for the given hexadecimal value or nil
     */
    convenience init?(hex: String?) {
        guard let hex = hex else { return nil }

        var normalizedHex: String = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedHex = normalizedHex.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var rValue: CGFloat = 0.0
        var gValue: CGFloat = 0.0
        var bValue: CGFloat = 0.0
        var aValue: CGFloat = 1.0

        let length: Int = normalizedHex.count

        guard Scanner(string: normalizedHex).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            rValue = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            gValue = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            bValue = CGFloat(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            aValue = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            rValue = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            gValue = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            bValue = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: rValue, green: gValue, blue: bValue, alpha: aValue)
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

extension UIWindowScene {
    static var active: UIWindowScene {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive })
        return activeScene ?? scenes.first!
    }
}
