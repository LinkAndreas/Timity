//
//  TimityUITests.swift
//  TimityUITests
//
//  Created by Andreas Link on 1/18/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import XCTest

class TimityUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAddingMyBirthday() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        
        let app = XCUIApplication()
        let tablesQuery = app.tables
        tablesQuery.staticTexts["Ereignisliste"].tap()
        app.navigationBars["Ereignisse"].buttons["Hinzufügen"].tap()
        
        let shiftButton = app.buttons["shift"]
        shiftButton.tap()
        
        let textField = tablesQuery.children(matching: .cell).element(boundBy: 0).children(matching: .textField).element
        textField.typeText("Andreas Link's Geburtstag")
        
        tablesQuery.staticTexts["31.03.2018"].tap()

        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "18.")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "April")
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "1992")
        
        
        tablesQuery.staticTexts["18.04.1992"].tap()
        
        app.navigationBars["Ereignis hinzufügen"].buttons["Sichern"].tap()

        
    }
    
//    func pickPhotoFromImagePickerAtInvertedIndex(index: UInt) {
//
//        tables.buttons["Camera Roll"].tap()
//        let collectionView = collectionViews["PhotosGridView"]
//        collectionView.cells.elementBoundByIndex(collectionView.cells.count - 1 - index).tap()
//    }
    
}
