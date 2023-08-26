//
//  AlertManager.swift
//  Timity
//
//  Created by Andreas Link on 26.08.23.
//  Copyright © 2023 Andreas Link. All rights reserved.
//

import UIKit
import MessageUI

final class AlertManager {
    static let shared = AlertManager()
    
    func showAlertWith(title:String, message:String){
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let dismissAction = UIAlertAction(
            title: NSLocalizedString(
                "common_ok_button",
                comment: "String representing the ok button text in an user alert dialog."
            ),
            style: .default,
            handler: { _ in }
        )
        controller.addAction(dismissAction)
        show(controller: controller)
    }

    func showFeedbackMailComposer() {
        if MFMailComposeViewController.canSendMail() {
            let controller = MailComposer.makeController()
            show(controller: controller)
        } else {
            ///Failed to send mail
            let mailCouldNotBeComposedTitle = NSLocalizedString("alert_mail_composer_mail_could_not_be_composed_title", comment: "Alert title indicating that the mail could not be composed in info controller")
            let mailCouldNotBeComposedMessage = NSLocalizedString("alert_mail_composer_mail_could_not_be_composed_message", comment: "Alert message indicating that the mail could not be composed in info controller")
            showAlertWith(
                title: mailCouldNotBeComposedTitle,
                message: mailCouldNotBeComposedMessage
            )
        }
    }

    private func show(controller: UIViewController) {
        let parent = UIWindowScene.active.windows.first?.rootViewController
        parent?.present(controller, animated: true)
    }
}
