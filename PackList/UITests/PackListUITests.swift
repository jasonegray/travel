import XCTest

final class PackListUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - 1: App launch shows Trips screen

    func testAppLaunchShowsTripsScreen() {
        let tripsTab = app.tabBars.buttons["Trips"]
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 5), "Trips tab should be visible after launch")
        XCTAssertTrue(app.navigationBars["Trips"].waitForExistence(timeout: 5), "Trips navigation bar should be present")
    }

    // MARK: - 2: Create trip wizard opens and can be dismissed

    func testCreateTripWizardOpens() {
        // Tap the + button in the nav bar (SF Symbol "plus" → accessibility label "Add")
        // Fall back to the "New Trip" empty-state button if no trips exist
        let addButton = app.navigationBars.buttons.matching(
            NSPredicate(format: "label == 'Add' OR label == 'plus'")
        ).firstMatch

        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        } else {
            let newTripButton = app.buttons["New Trip"]
            XCTAssertTrue(newTripButton.waitForExistence(timeout: 3), "Expected Add button or New Trip button on home screen")
            newTripButton.tap()
        }

        // Wizard is present when Cancel appears (first step always shows Cancel)
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Wizard should show Cancel button")

        // Dismiss
        cancelButton.tap()

        // Back on Trips screen
        XCTAssertTrue(app.navigationBars["Trips"].waitForExistence(timeout: 3), "Should return to Trips screen after Cancel")
    }

    // MARK: - 3: Bag cards section appears after trip creation

    func testBagCardsSectionAppearsAfterTripCreation() throws {
        app.tabBars.buttons["Trips"].tap()

        if app.staticTexts["No trips planned"].waitForExistence(timeout: 3) {
            try createMinimalTrip()
        }

        let bagsHeader = app.staticTexts["Bags"]
        XCTAssertTrue(bagsHeader.waitForExistence(timeout: 10),
                      "Bags section with bag cards should appear on home screen after trip creation")
    }

    // MARK: - 4: Info tab share button exists

    func testInfoTabShareButtonExists() throws {
        app.tabBars.buttons["Trips"].tap()

        // Create a trip if none exist
        if app.staticTexts["No trips planned"].waitForExistence(timeout: 3) {
            try createMinimalTrip()
        }

        // Trip name contains "·" (separator between destination and date range)
        let tripNameText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '·'")
        ).firstMatch
        XCTAssertTrue(tripNameText.waitForExistence(timeout: 10), "Trip card should be visible on home screen")
        tripNameText.tap()

        // TripDetailView shows a segmented picker — tap Info
        let infoSegment = app.buttons["Info"]
        XCTAssertTrue(infoSegment.waitForExistence(timeout: 5), "Info segment should be visible in trip detail")
        infoSegment.tap()

        // Share button from ShareLink in TripInfoView toolbar
        let shareButton = app.buttons["Share"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 3), "Share button should be visible on Info tab")
    }

    // MARK: - 4: Add custom item flow

    func testAddCustomItemFlow() throws {
        app.tabBars.buttons["Trips"].tap()

        // Create a trip if none exist
        if app.staticTexts["No trips planned"].waitForExistence(timeout: 3) {
            try createMinimalTrip()
        }

        // Navigate to trip detail via trip card (same path as testInfoTabShareButtonExists)
        let tripCard = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '·'")
        ).firstMatch
        XCTAssertTrue(tripCard.waitForExistence(timeout: 10), "Trip card should be visible on home screen")
        tripCard.tap()

        // TripDetailView opens on packing tab — look for the + button (identified by accessibilityIdentifier)
        let addButton = app.buttons.matching(identifier: "addItemButton").firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add item button should appear in packing toolbar")
        addButton.tap()

        // Sheet appears — fill in the item name
        let nameField = app.textFields["customItemNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Item name field should appear in add item sheet")
        nameField.tap()
        nameField.typeText("My Custom Snack")

        // Tap the Add confirmation button in the sheet's nav bar
        let confirmButton = app.buttons.matching(identifier: "confirmAddItemButton").firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3), "Add button should be enabled after entering name")
        confirmButton.tap()

        // The Miscellaneous section auto-expands — item should be visible
        let customItemText = app.staticTexts["My Custom Snack"]
        XCTAssertTrue(customItemText.waitForExistence(timeout: 5), "Custom item should appear in packing list after adding")

    }

    // MARK: - 5: Archive trip flow

    func testArchiveTripFlow() throws {
        app.tabBars.buttons["Trips"].tap()

        // Create a trip if none exist
        if app.staticTexts["No trips planned"].waitForExistence(timeout: 3) {
            try createMinimalTrip()
        }

        // Find a trip card (trip name contains '·' from the auto-generated "Destination · Month Day–Day" format)
        let tripCard = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '·'")
        ).firstMatch
        XCTAssertTrue(tripCard.waitForExistence(timeout: 10), "Trip card must be visible on home screen")
        tripCard.tap()

        // Wait for trip detail to load
        let detailMenu = app.buttons["trip_detail_menu"]
        XCTAssertTrue(detailMenu.waitForExistence(timeout: 5), "Three-dot menu must be present in trip detail")

        // Step 1: Mark trip as completed if not already
        detailMenu.tap()
        if app.buttons["Mark as Completed"].waitForExistence(timeout: 2) {
            app.buttons["Mark as Completed"].tap()
            // Wait for completed or archived banner to confirm state has updated
            _ = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'Completed' OR label CONTAINS 'Archived'")
            ).firstMatch.waitForExistence(timeout: 5)
        } else {
            // Trip is already completed — dismiss menu by tapping toolbar area
            app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
        }

        // Step 2: Archive trip via three-dot menu
        XCTAssertTrue(detailMenu.waitForExistence(timeout: 3), "Three-dot menu must still be accessible")
        detailMenu.tap()
        let archiveButton = app.buttons["Archive Trip"]
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 3),
                      "Archive Trip must appear in menu for completed trips")
        archiveButton.tap()

        // Should navigate back to Trips screen after archiving
        XCTAssertTrue(app.navigationBars["Trips"].waitForExistence(timeout: 5),
                      "Should return to Trips screen after archiving")

        // Archived section toggle must appear
        let archivedToggle = app.buttons["archived_section_toggle"]
        XCTAssertTrue(archivedToggle.waitForExistence(timeout: 3),
                      "Archived section must be visible on Trips screen after archiving a trip")
    }

    // MARK: - Wizard helper

    private func createMinimalTrip() throws {
        let addButton = app.navigationBars.buttons.matching(
            NSPredicate(format: "label == 'Add' OR label == 'plus'")
        ).firstMatch

        if addButton.exists {
            addButton.tap()
        } else {
            app.buttons["New Trip"].tap()
        }

        // Step 1: Activities — Conference pre-selected, Continue enabled
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5), "Continue should appear on Activities step")
        app.buttons["Continue"].tap()

        // Step 2: Name/Destination — destination required for canContinue
        // Use a Canadian city so region = .canada and the medical step is skipped (7 steps total)
        let destField = app.textFields["e.g. Orlando, Tokyo, Paris"]
        XCTAssertTrue(destField.waitForExistence(timeout: 5), "Destination field should appear")
        destField.tap()
        destField.typeText("Toronto, Canada")
        // Dismiss keyboard (submitLabel = .search) so Continue button is not blocked
        destField.typeText("\n")
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5),
                      "Continue should appear after entering destination")
        app.buttons["Continue"].tap()

        // Step 3: Dates — defaults are 7 and 10 days from now, already valid
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()

        // Steps 4–N: Binary choices — tap Continue until confirm step appears.
        // Canada/US: 3 steps (carry-on, laundry, interac); others: 4 (+ medical).
        for _ in 0..<4 {
            if app.buttons["Generate My List"].waitForExistence(timeout: 1) { break }
            XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
            app.buttons["Continue"].tap()
        }

        // Final step: Confirm
        let generateButton = app.buttons["Generate My List"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5), "Generate My List button should appear on confirm step")
        generateButton.tap()

        // Wait for wizard to dismiss and trip card to load
        XCTAssertTrue(app.navigationBars["Trips"].waitForExistence(timeout: 15), "Should return to Trips after trip creation")
    }
}
