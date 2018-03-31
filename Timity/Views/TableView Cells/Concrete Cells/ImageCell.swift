//
//  NameCell.swift
//  Timity
//
//  Created by Andreas Link on 2/11/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class ImageCell: ThemeableTableViewCell {
    
    ///IBOutlets
    @IBOutlet weak var eventImageView:UIImageView!
    @IBOutlet weak var trashImageView: UIImageView!
    
    ///Properties
    var viewModel:ImageCellViewModel?{
        didSet{
            setupUI()
            viewModel?.delegate = self
            listenToImageGotSelectedNotififcations()
        }
    }
    private var isPlaceholderVisible:Bool = true
    
    deinit {
        stopListeningForImageGotSelectedNotifications()
    }
    
    private func setupUI(){
        updateImageViews(viewModel?.imageData)
    }
    
    func updateImageViews(_ imageData:Data?){
        ///Update EventImageView
        eventImageView.contentMode = .scaleAspectFill
        eventImageView.layer.borderWidth = 1
        eventImageView.layer.masksToBounds = false
        eventImageView.clipsToBounds = true
        if let imageData = viewModel?.imageData{
            isPlaceholderVisible = false
            eventImageView.image = UIImage(data:imageData)
        }else{
            isPlaceholderVisible = true
            eventImageView.image = UIImage(named: "cameraIcon")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        }
        
        ///Update TrashImageView
        trashImageView.image = UIImage(named: "trashIcon")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        trashImageView.isHidden = isPlaceholderVisible
    }
    
    ///Handle Theme customization
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)

        ///Update ImageViews
        eventImageView.layer.borderColor = theme.textColor.cgColor
        eventImageView.tintColor = theme.highlightColor
        trashImageView.tintColor = theme.highlightColor
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        guard let touchLocation = touches.first?.location(in: contentView) else {return}
        guard let eventImageFrame = eventImageView?.frame else {return}
        guard let trashFrame = trashImageView?.frame else {return}
        
        ///Check if ImageView Got hit
        if eventImageFrame.contains(touchLocation){
            chooseImage()
        }else if trashFrame.contains(touchLocation){
            deleteImage()
        }
    }
    
    private func chooseImage(){
        //Activate imagePicker as soon as tableCell gets pressed
        let imageViewDict:[String: UIImageView] = ["imageView": eventImageView]
        
        // post a notification
        let nc = NotificationCenter.default
        nc.post(name: NSNotification.Name(rawValue: "imagePickerRequest"),
                object: nil,
                userInfo: imageViewDict)
    }
    
    private func deleteImage(){
        viewModel?.imageData = nil
    }
    
    ///Listen for imageGotSelected notfifications
    private func listenToImageGotSelectedNotififcations(){
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(imageGotSelected(_:)), name: NSNotification.Name("imageGotSelected"), object: nil)
    }
    
    private func stopListeningForImageGotSelectedNotifications(){
        let nc = NotificationCenter.default
        nc.removeObserver(self)
    }
    
    @objc private func imageGotSelected(_ notification:Notification){
        guard let imageData = notification.userInfo?["imageData"] as? Data else {return}
        viewModel?.imageData = imageData
    }
    
}

extension ImageCell:ImageCellViewModelDelegate{
    func imageDataDidChange(imageData: Data?) {
        updateImageViews(imageData)
    }
}

