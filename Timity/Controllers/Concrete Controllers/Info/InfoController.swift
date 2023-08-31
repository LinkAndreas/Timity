//
//  InfoController.swift
//  Timity
//
//  Created by Andreas Link on 2/22/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit
import StoreKit
import MessageUI

class InfoController: ThemeableTableViewController {
    
    ///IBOutlets
    @IBOutlet weak var rateTimityCell: OutputBasicCell!
    @IBOutlet weak var sendMailCell: OutputBasicCell!
    @IBOutlet weak var acknowledgementsCell: OutputBasicCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI(){
        
        ///Generate localized strings
        let rateTimityString = NSLocalizedString("info_action_rate_timity", comment: "Name of the rate timiy action as shown in the info controller.")
        let sendMailString = NSLocalizedString("info_action_send_mail_to_developer", comment: "Name of the send mail to developer action as shown in the info controller.")
        let showAcknowledgementsString = NSLocalizedString("info_action_show_acknowledgements", comment: "Name of the show acknowledgements action as shown in the info controller.")
        
        rateTimityCell.label.text = rateTimityString
        sendMailCell.label.text = sendMailString
        acknowledgementsCell.label.text = showAcknowledgementsString
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupNavBar()
    }
    
    private func setupNavBar(){
        ///Configure LargeTitles
        navigationItem.largeTitleDisplayMode = .never
        
        ///Generate Navigation Bar title
        let infoNavigationTitle = NSLocalizedString("info_navigation_title", comment: "Navigation title of the info controller.")
        navigationItem.title = infoNavigationTitle
    }
    
    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)
        
        rateTimityCell.label.textColor = theme.highlightColor
        sendMailCell.label.textColor = theme.highlightColor
        acknowledgementsCell.label.textColor = theme.highlightColor
    }
    
    func sendMailToDeveloper(){
        AlertManager.shared.showFeedbackMailComposer()
    }
}

extension InfoController{
    //MARK: TableView
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                ///Rate Timity
                SKStoreReviewController.requestReview(in: .active)
            }else if indexPath.row == 1 {
                ///Send Mail to Developer
                sendMailToDeveloper()
            }
        }else if indexPath.section == 1 {
            ///Show Acknowledgements
            performSegue(withIdentifier: "segueToAcknowledgements", sender: nil)
        }
        
        ///Deselect row again
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return NSLocalizedString("info_section_feedback_header", comment: "Header of the feedback section in info controller")
        }else if section == 1 {
            return NSLocalizedString("info_section_acknowledgements_header", comment: "Header of the acknowledgements section in info controller")
        }else{
            return ""
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0{
            return NSLocalizedString("info_section_feedback_footer", comment: "Footer of the feedback section in info controller")
        }else if section == 1 {
            return NSLocalizedString("info_section_acknowledgements_footer", comment: "Footer of the acknowledgements section in info controller")
        }else{
            return ""
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
}

///Conform to PopovercontrollerDelegate
extension InfoController:UIPopoverPresentationControllerDelegate{
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

