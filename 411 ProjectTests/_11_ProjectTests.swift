//
//  _11_ProjectTests.swift
//  411 ProjectTests
//
//  Created by Larry on 8/28/26.
//

import Testing
import SwiftData
@testable import _11_Project

@MainActor
func createTestContainer() throws -> ModelContainer {
    let schema = Schema([OwnedCard.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}

@Suite("OwnedCard SwiftData Tests")
@MainActor
struct OwnedCardTests {

    @Test("Adding a new card creates exactly 1 record with quantity 1")
    func testAddNewCard() throws {
        // 1. Arrange: isolated in-memory context
        let container = try createTestContainer()
        let context = container.mainContext

        // 2. Act: add a card that isn't in the database yet
        OwnedCard.addCard(
            cardId: "sv1-025",
            setCode: "sv1",
            cardNumber: "025",
            variant: .normal,
            in: context
        )

        // 3. Assert: verify card was inserted
        let found = OwnedCard.checkCardExists(cardId: "sv1-025", variant: .normal, in: context)
        #expect(found != nil)
        #expect(found?.quantity == 1)
        #expect(found?.id == "sv1-025_Normal")
    }

    @Test("Adding an existing card increments quantity instead of creating duplicates")
    func testIncrementExistingCard() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // Add the same card twice
        OwnedCard.addCard(cardId: "sv1-025", setCode: "sv1", cardNumber: "025", variant: .normal, in: context)
        OwnedCard.addCard(cardId: "sv1-025", setCode: "sv1", cardNumber: "025", variant: .normal, in: context)

        // Fetch all cards in the container to check for duplicates
        let descriptor = FetchDescriptor<OwnedCard>()
        let allCards = try context.fetch(descriptor)

        #expect(allCards.count == 1)
        #expect(allCards.first?.quantity == 2)
    }

    @Test("Removing a card with quantity 1 deletes it from database")
    func testRemoveCardDeletesAtZero() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // Add card once, then remove it
        OwnedCard.addCard(cardId: "sv1-025", setCode: "sv1", cardNumber: "025", variant: .normal, in: context)
        OwnedCard.removeCard(cardId: "sv1-025", variant: .normal, in: context)

        let found = OwnedCard.checkCardExists(cardId: "sv1-025", variant: .normal, in: context)
        #expect(found == nil)
    }
    
    @Test("Adding different variants of the same card ID creates distinct records")
        func testVariantsCreateDistinctRecords() throws {
            let container = try createTestContainer()
            let context = container.mainContext

            let cardId = "sv1-025"
            let setCode = "sv1"
            let cardNumber = "025"

            // 1. Add normal variant twice
            OwnedCard.addCard(cardId: cardId, setCode: setCode, cardNumber: cardNumber, variant: .normal, in: context)
            OwnedCard.addCard(cardId: cardId, setCode: setCode, cardNumber: cardNumber, variant: .normal, in: context)

            // 2. Add holo variant once
            OwnedCard.addCard(cardId: cardId, setCode: setCode, cardNumber: cardNumber, variant: .holo, in: context)

            // 3. Fetch all records
            let allCards = try context.fetch(FetchDescriptor<OwnedCard>())

            // Verify total records
            #expect(allCards.count == 2)

            // Verify individual variant records and counts
            let normalRecord = OwnedCard.checkCardExists(cardId: cardId, variant: .normal, in: context)
            let holoRecord = OwnedCard.checkCardExists(cardId: cardId, variant: .holo, in: context)

            #expect(normalRecord?.quantity == 2)
            #expect(normalRecord?.id == "sv1-025_Normal")

            #expect(holoRecord?.quantity == 1)
            #expect(holoRecord?.id == "sv1-025_Holo")
        }
}
