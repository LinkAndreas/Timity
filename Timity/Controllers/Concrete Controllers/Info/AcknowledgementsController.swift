//
//  AcknowledgementsController.swift
//  Timity
//
//  Created by Andreas Link on 3/1/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit

class AcknowledgementsController: ThemeableViewController {
    
    ///IBOutlets
    @IBOutlet weak var legalNotesTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupNavBar()
    }
    
    func setupNavBar(){
        ///Set Navigation Bar Title
        navigationItem.title = NSLocalizedString("acknowledgements_navigation_title", comment: "The navigation title of the acknowledgements controller.")
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        ///Configure TextView
        legalNotesTextView.textColor = theme.textColor
    }
    
}
