//
//  AppRatingPopupLocalization.swift
//  Timity
//
//  Created by Andreas Link on 26.08.23.
//  Copyright © 2023 Andreas Link. All rights reserved.
//

import Foundation

struct AppRatingPopupLocalization {
    let headline: String
    let dismissButtonTitleLimitNotReached: String
    let dismissButtonTitleLimitReached: String
}

extension AppRatingPopupLocalization {
    static let `default` = AppRatingPopupLocalization(
        headline: NSLocalizedString(
            "popup_app_rating_headline",
            comment: "Headline of the App Rating Popup"
        ),
        dismissButtonTitleLimitNotReached: NSLocalizedString(
            "popup_app_rating_dismiss_button_title_limit_not_reached",
            comment: "Dismiss Button Title of the App Rating Popup (Trigger left)"
        ),
        dismissButtonTitleLimitReached: NSLocalizedString(
            "popup_app_rating_dismiss_button_title_limit_reached",
            comment: "Dismiss Button Title of the App Rating Popup (Limit reached)"
        )
    )
}
