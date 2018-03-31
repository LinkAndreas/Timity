//
//  EmptyTableBackgroundView.swift
//  Timity
//
//  Created by Andreas Link on 3/18/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit
import SnapKit

class EmptyTableBackgroundView:ThemeableView{
    ///Public properties
    
    ///Private properties
    private var image:UIImage?
    private var title:String
    private var message:String
    
    private lazy var logoView = UIView()
    private lazy var logoImageView = UIImageView()
    private lazy var logoTitleLabel = UILabel()
    private lazy var logoMessageLabel = UILabel()
    
    ///Initialization
    init(title:String, message:String, image:UIImage?) {
        
        ///Assign private properties
        self.title = title
        self.message = message
        self.image = image

        ///Let superclass initialize itself
        super.init(frame: CGRect.zero)
        
        ///Configure View
        configureView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
    
    ///Instance methods
    private func configureView(){
        
        ///Setup Logo Container View
        addSubview(logoView)
        
        ///Setup Logo Image View
        if let logo = image?.withRenderingMode(UIImageRenderingMode.alwaysTemplate){
            logoImageView.image = logo
            logoImageView.contentMode = .scaleAspectFit
            logoImageView.alpha = 0.65
            logoView.addSubview(logoImageView)
            
            ///Setup constraints
            logoImageView.snp.makeConstraints{ make in
                make.top.equalTo(logoView)
                make.centerX.equalTo(logoView)
                make.height.width.equalTo(75)
            }
        }
        
        ///Setup Logo Label
        logoTitleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        logoTitleLabel.textAlignment = .center
        logoTitleLabel.text = title
        logoView.addSubview(logoTitleLabel)
        
        logoMessageLabel.font = UIFont.preferredFont(forTextStyle: .body)
        logoMessageLabel.textAlignment = .center
        logoMessageLabel.numberOfLines = 0
        logoMessageLabel.text = message
        logoView.addSubview(logoMessageLabel)
        
        logoTitleLabel.snp.makeConstraints{ make in
            make.top.equalTo(logoImageView.snp.bottom).offset(11)
            make.left.right.equalTo(logoView)
            make.height.greaterThanOrEqualTo(0)
        }
        
        logoMessageLabel.snp.makeConstraints{ make in
            make.top.equalTo(logoTitleLabel.snp.bottom).offset(11)
            make.left.right.equalTo(logoView)
            make.height.greaterThanOrEqualTo(0)
            make.bottom.equalTo(logoView)
        }
        
        logoView.snp.makeConstraints{ make in
            make.left.right.equalTo(self)
            make.center.equalTo(self)
            make.height.greaterThanOrEqualTo(0)
        }
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Setup background color
        backgroundColor = theme.backgroundColor
        logoTitleLabel.backgroundColor = theme.backgroundColor
        logoMessageLabel.backgroundColor = theme.backgroundColor
        
        ///Setup logoLabel colors
        logoTitleLabel.textColor = theme.textColor
        logoMessageLabel.textColor = theme.lightTextColor
        
        ///Assign appropriate tint color to logo image view
        logoImageView.tintColor = theme.highlightColor
    }
    
    func show(){
        UIView.animate(withDuration: 1.25){ [weak self] in
            self?.alpha = 1.0
        }
    }
    
    func hide(){
        alpha = 0.0
    }
}
