//
//  ImageCellViewModel.swift
//  Timity
//
//  Created by Andreas Link on 2/11/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

protocol ImageCellViewModelDelegate: AnyObject {
    func imageDataDidChange(imageData:Data?)
}

extension ImageCellViewModelDelegate {
    func imageDataDidChange(imageData:Data?){}
}

class ImageCellViewModel:CellViewModel{
    weak var delegate:ImageCellViewModelDelegate?
    weak var componentDelegate:ComponentViewModelDelegate?
    var imageData:Data?{
        didSet{
            delegate?.imageDataDidChange(imageData: imageData)
            componentDelegate?.resultDidChange()
        }
    }
    
    init(imageData:Data?) {
        self.imageData = imageData
    }
    
}

