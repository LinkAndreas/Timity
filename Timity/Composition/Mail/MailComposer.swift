//
//  MailComposer.swift
//  Timity
//
//  Created by Andreas Link on 26.08.23.
//  Copyright © 2023 Andreas Link. All rights reserved.
//

import MessageUI
import UIKit

enum MailComposer {
    static func makeController() -> UIViewController {
        let mailComposeDelegate = MailComposerDelegate()
        let additionalInformationString = NSLocalizedString("info_action_send_mail_to_developer_additional_information", comment: "String representing the additional information string as shown in the email to the developer that can be send from the info controller.")
        let subjectString = NSLocalizedString("info_action_send_mail_to_developer_subject", comment: "String representing the subject title in the mail to the developer that can be send in the info controller.")
        
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = mailComposeDelegate
        controller.setToRecipients(["timity@appleteam.de"])
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
        
        controller.setMessageBody(htmlContent, isHTML: true)
        controller.setSubject(subjectString)
        controller.navigationBar.tintColor = ThemeManager.shared.currentTheme.highlightColor
        return controller
    }
}

extension MailComposer {
    ///Source: http://swiftdeveloperblog.com/code-examples/determine-current-device-model/
    private static func determineDeviceIdentifier()->String{
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private static func determineBundleVersion()->String{
        return "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")"
    }
}

private final class MailComposerDelegate: NSObject, MFMailComposeViewControllerDelegate {
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true)
    }
}
