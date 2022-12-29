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

        ///Generate localized strings
        let mailCouldNotBeComposedTitle = NSLocalizedString("alert_mail_composer_mail_could_not_be_composed_title", comment: "Alert title indicating that the mail could not be composed in info controller")
        let mailCouldNotBeComposedMessage = NSLocalizedString("alert_mail_composer_mail_could_not_be_composed_message", comment: "Alert message indicating that the mail could not be composed in info controller")
        
        let additionalInformationString = NSLocalizedString("info_action_send_mail_to_developer_additional_information", comment: "String representing the additional information string as shown in the email to the developer that can be send from the info controller.")
        let subjectString = NSLocalizedString("info_action_send_mail_to_developer_subject", comment: "String representing the subject title in the mail to the developer that can be send in the info controller.")
        
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["timity@appleteam.de"])
            let systemVersion = "iOS \(UIDevice.current.systemVersion)"
            let deviceIdentifier = determineDeviceIdentifier()
            let bundleVersion = determineBundleVersion()
            
            let htmlContent =
            """
            <p>&nbsp</p>
            <p>
            [\(additionalInformationString)]<br>
            <b>Device Identifier:</b> \(deviceIdentifier)<br>
            <b>System Version:</b> \(systemVersion)<br>
            <b>Bundle Version:</b> \(bundleVersion)
            </p>
            """
            
            mail.setMessageBody(htmlContent, isHTML: true)
            mail.setSubject(subjectString)
            mail.navigationBar.tintColor = ThemeManager.shared.currentTheme.highlightColor
            
            present(mail, animated: true)
        } else {
            ///Failed to send mail
            Settings.shared.showAlertWith(title: mailCouldNotBeComposedTitle,
                                          message: mailCouldNotBeComposedMessage)
        }
    }
    
    ///Source: http://swiftdeveloperblog.com/code-examples/determine-current-device-model/
    private func determineDeviceIdentifier()->String{
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private func determineBundleVersion()->String{
        return "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")"
    }
}

extension InfoController:MFMailComposeViewControllerDelegate{
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}

extension InfoController{
    //MARK: TableView
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                ///Rate Timity
                SKStoreReviewController.requestReview(in: .app)
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

