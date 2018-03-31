//
//  GradientView.swift
//  Timity
//
//  Created by Andreas Link on 1/11/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation
import UIKit

/**
 Shows a gradient for a given color range a view.
 # Purpose:
 Ment to replace the regular background underneath the content.
 */
@IBDesignable class GradientView:UIView{
    
    ///MARK: Properties
    
    /// The layer containing the gradient
    var gradientLayer = CAGradientLayer()
    /// The color range used by the gradient
    var colors: [UIColor] = [.black, .white] {
        didSet {
            updateGradient(colors)
        }
    }
    
    ///MARK: Initialization
    
    ///Init from Code
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    ///Init from Interface Builder
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    ///Common Init
    func commonInit() {
        ///Set the gradient layer's size to its parents' size
        gradientLayer.frame = bounds
        ///Insert the gradient layer as the lowest sublayer
        layer.insertSublayer(gradientLayer, at: 0)
        ///Update the gradient with the given colors
        updateGradient(colors)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        ///Set the gradient layer's size to its parents' size
        gradientLayer.frame = bounds
    }
    
    /**
     Updates the gradient with the given colors
     - parameter gradientColors: The colors the gradient should contain.
     */
    func updateGradient(_ gradientColors: [UIColor]) {
        gradientLayer.colors = gradientColors.map({color in return color.cgColor})
    }
}
