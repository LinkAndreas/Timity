//
//  UserInterfaceStyleObservingWindow.swift
//  Timity
//
//  Created by Andreas Link on 29.12.22.
//  Copyright © 2022 Andreas Link. All rights reserved.
//

import UIKit

final class UserInterfaceStyleObservingWindow: UIWindow {
    private var onUserInterfaceStyleChanged: (() -> Void)?

    func setOnUserInterfaceStyleChanged(handler: @escaping (() -> Void)) {
        onUserInterfaceStyleChanged = handler
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }

        onUserInterfaceStyleChanged?()
    }
}
