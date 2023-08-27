//
//  ImageChooserComponentViewModel.swift
//  Timity
//
//  Created by Andreas Link on 2/11/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

class ImageChooserComponentViewModel {
    var title:String
    var footer:String
    
    var result:Data?{
        return cellViewModel.imageData
    }
    weak var delegate:ComponentViewModelDelegate?
    
    ///Cell View Models
    var cellViewModel:ImageCellViewModel
    
    init(title:String, footer:String, imageData:Data?) {
        self.title = title
        self.footer = footer
        self.cellViewModel = ImageCellViewModel(imageData: imageData)
        self.cellViewModel.componentDelegate = self
    }
    
    func numberOfRowsIn(section:Int)->Int{
        return 1
    }
}

extension ImageChooserComponentViewModel:ComponentViewModelDelegate{
    func resultDidChange() {
        delegate?.resultDidChange()
    }
}

