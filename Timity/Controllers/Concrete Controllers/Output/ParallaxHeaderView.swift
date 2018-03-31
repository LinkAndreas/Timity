//
//  ParallaxHeaderView.swift
//  Timity
//
//  Created by Andreas Link on 3/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit
import SnapKit
import SwiftImageEffects

class ParallaxHeaderView: UIView {
    
    ///Properties
    var image:UIImage?{
        didSet{
            if let image = image{
                ///Regular imageView
                imageView.image = image
                
                ///Setup Blurred Image View (Hide it initially -> alpha = 0.0)
                bluredImageView.image = image.appliedBlur(withRadius: 10.0,
                                                          tintColor: UIColor.white.withAlphaComponent(0.2),
                                                          saturationDeltaFactor: 1.0,
                                                          maskImage: nil)!
            }
        }
    }
    private var shouldSetupConstraints = true

    ///UIElements
    private var scrollView = UIScrollView()
    private var imageView = UIImageView()
    private var bluredImageView = UIImageView()
    private var height:CGFloat{
        return frame.size.height
    }
    
    ///Initialization
    init(){
        super.init(frame: CGRect.zero)
        configureView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("ParallaxHeaderView does not support NSCoding")
    }
    
    ///Instance methods
    private func configureView(){
        ///Setup ScrollView
        addSubview(scrollView)
        scrollView.snp.makeConstraints{ make in
            make.centerX.equalTo(self)
            make.width.equalTo(self)
            make.height.equalTo(self)
            make.top.equalTo(self)
        }
        
        ///Setup Image View
        imageView.contentMode = .scaleAspectFill
        scrollView.addSubview(imageView)
        imageView.snp.makeConstraints{ make in
            make.left.right.equalTo(scrollView)
            make.center.equalTo(scrollView)
            make.height.equalTo(scrollView.frameLayoutGuide)
        }
        
        bluredImageView.contentMode = .scaleAspectFill
        bluredImageView.alpha = 0.0
        scrollView.addSubview(bluredImageView)
        bluredImageView.snp.makeConstraints{ make in
            make.left.right.equalTo(scrollView)
            make.center.equalTo(scrollView)
            make.height.equalTo(scrollView.frameLayoutGuide)
        }
    }
    
    ///Public Methods
    func update(with contentOffset:CGPoint){
        ///print(contentOffset.y)
        if (contentOffset.y > 0){
            //Up
            scrollView.contentOffset.y = -max(contentOffset.y * 0.5, 0.0)
            bluredImageView.alpha = min(1.0,max(contentOffset.y/height,0.0))
            clipsToBounds = true
        }else{
            //Down
            var delta:CGFloat = 0.0
            delta = abs(min(0.0, contentOffset.y))
            
            scrollView.snp.updateConstraints{ make in
                make.top.equalTo(self).offset(-delta)
                make.height.equalTo(self).offset(delta)
            }
            
            imageView.snp.updateConstraints{ make in
                make.height.equalTo(scrollView.frameLayoutGuide).offset(2*delta)
            }
            bluredImageView.snp.updateConstraints{ make in
                make.height.equalTo(scrollView.frameLayoutGuide).offset(2*delta)
            }
            
            clipsToBounds = false
        }
    }
}
