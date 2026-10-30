import SwiftUI
import SwiftData

struct CardDetailView: View {
    let card: PokemonCard
    let setCode: String
    let ownedCardsForSet: [OwnedCard]
    let prices: [String: [String: Double]]

    // 1. Direct synchronous lookup for this card's price map
    private var cardVariantPrices: [String: Double]? {
        prices[card.number]
    }

    // 2. Derive variants directly from the card metadata
    private var availableVariants: [CardVariant] {
        card.mappedVariants
    }

    // Filter owned records for this card
    private var cardOwnedRecords: [OwnedCard] {
        ownedCardsForSet.filter { $0.cardId == card.id }
    }

    private var totalQuantity: Int {
        cardOwnedRecords.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // High-res image
                AsyncImage(url: URL(string: card.images.large ?? card.images.small)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: 280)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(radius: 6)

                // Header Info
                VStack(spacing: 4) {
                    Text(card.name)
                        .font(.title2.bold())
                    Text("#\(card.number) • Total Owned: \(totalQuantity)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Variant Tracker Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Variants")
                        .font(.headline)

                    CardVariantTrackerView(
                        cardId: card.id,
                        setCode: setCode,
                        cardNumber: card.number,
                        availableVariants: availableVariants,
                        variantPrices: cardVariantPrices,
                        ownedVariants: cardOwnedRecords
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
