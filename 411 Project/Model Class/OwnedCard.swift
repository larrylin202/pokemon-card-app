// takes in card info and writes it to a collection

import Foundation
import SwiftData

enum CardVariant: String, Codable, CaseIterable, Identifiable {
    case normal = "Normal"
    case holo = "Holo"
    case reverseHolo = "Reverse Holo"
    case firstEdition = "1st Edition"
    
    var id: String { rawValue }
}

@Model
final class OwnedCard {
    @Attribute(.unique) var id: String
    var cardId: String
    var setCode: String
    var cardNumber: String
    var variant: CardVariant
    var quantity: Int
    var dateAdded: Date
    
    init(
        cardId: String,
        setCode: String,
        cardNumber: String,
        variant: CardVariant = .normal,
        quantity: Int = 1,
        dateAdded: Date = Date()
    ) {
        self.id = "\(cardId)_\(variant.rawValue)"
        self.cardId = cardId
        self.setCode = setCode
        self.cardNumber = cardNumber
        self.variant = variant
        self.quantity = quantity
        self.dateAdded = dateAdded
    }
}

extension OwnedCard {
    static func checkCardExists(cardId: String, variant: CardVariant, in context: ModelContext) -> OwnedCard? {
        let targetId = "\(cardId)_\(variant.rawValue)"
        
        var descriptor = FetchDescriptor<OwnedCard>(
            predicate: #Predicate<OwnedCard> {
                card in card.id == targetId
            }
        )
        descriptor.fetchLimit = 1
        
        let matches = try? context.fetch(descriptor)
        return matches?.first
    }
    
    static func addCard(
        cardId: String,
        setCode: String,
        cardNumber: String,
        variant: CardVariant,
        in context: ModelContext
    ) {
        if let existingCard = checkCardExists(cardId: cardId, variant: variant, in: context) {
            existingCard.quantity += 1
        } else {
            let newCard = OwnedCard(
                cardId: cardId,
                setCode: setCode,
                cardNumber: cardNumber,
                variant: variant,
                quantity: 1
            )
            context.insert(newCard)
        }
    }
    
    static func removeCard(
        cardId: String,
        variant: CardVariant,
        in context: ModelContext
    ) {
        if let existingCard = checkCardExists(cardId: cardId, variant: variant, in: context) {
            existingCard.quantity -= 1
            
            if existingCard.quantity <= 0 {
                context.delete(existingCard)
            }
        }
    }
}
