//
//  AppRatingPopupPresenter.swift
//  Timity
//
//  Created by Andreas Link on 26.08.23.
//  Copyright © 2023 Andreas Link. All rights reserved.
//

struct AppRatingPopupPresenter {
    private let popupDismissCount: Int
    private let maxPopupDismissCount: Int
    private let localization: AppRatingPopupLocalization

    init(
        popupDismissCount: Int,
        maxPopupDismissCount: Int,
        localization: AppRatingPopupLocalization = .default
    ) {
        self.popupDismissCount = popupDismissCount
        self.maxPopupDismissCount = maxPopupDismissCount
        self.localization = localization
    }
    
    var headline: String {
        localization.headline
    }
    
    var dismissButtonTitle: String {
        if popupDismissCount < maxPopupDismissCount - 1 {
            return localization.dismissButtonTitleLimitNotReached
        } else {
            return localization.dismissButtonTitleLimitReached
        }
    }
}
