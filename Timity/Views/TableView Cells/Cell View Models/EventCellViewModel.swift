//
//  EventCellViewModel.swift
//  Timity
//
//  Created by Andreas Link on 1/30/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

class EventCellViewModel:CellViewModel {

    var title:String
    var body:String
    var explanation:String
    var imageData:Data?
    
    init(title:String, body:String, explanation:String, imageData:Data?) {
        self.title = title
        self.body = body
        self.explanation = explanation
        self.imageData = imageData
    }
}
