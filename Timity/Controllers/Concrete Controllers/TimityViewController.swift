//
//  TimityViewController.swift
//  Timity
//
//  Created by Andreas Link on 1/19/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class TimityViewController: ThemeableViewController {

    ///IBOutlets
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var logoLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setupUI(){
        ///Configure LargeTitles
        navigationItem.largeTitleDisplayMode = UI_USER_INTERFACE_IDIOM() == .pad ? .never : .always

        ///Configure logoImage as Template
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.image = UIImage(named: "logo")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        logoImageView.alpha = 0.45
        logoLabel.alpha = 0.45
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Configure colors according to theme
        logoLabel.textColor = theme.textColor
        logoImageView.tintColor = theme.logoColor
    }
}
