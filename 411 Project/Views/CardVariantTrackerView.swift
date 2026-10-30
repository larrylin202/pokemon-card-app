import SwiftUI
import SwiftData

struct CardVariantTrackerView: View {
    let cardId: String
    let setCode: String
    let cardNumber: String
    let availableVariants: [CardVariant]
    let variantPrices: [String: Double]? // [variantKey: price]
    let ownedVariants: [OwnedCard]

    @Environment(\.modelContext) private var modelContext

    private var quantityByVariant: [CardVariant: Int] {
        Dictionary(
            ownedVariants.map { ($0.variant, $0.quantity) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        VStack(spacing: 10) {
            // Only iterates over variants the card actually has!
            ForEach(availableVariants, id: \.self) { variant in
                let currentCount = quantityByVariant[variant] ?? 0
                let price = getPrice(for: variant)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(variant.rawValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(currentCount > 0 ? .primary : .secondary)

                        if let price {
                            Text(price, format: .currency(code: "USD"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No price")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button {
                            OwnedCard.removeCard(
                                cardId: cardId,
                                variant: variant,
                                in: modelContext
                            )
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(currentCount > 0 ? .red : .gray.opacity(0.3))
                        }
                        .disabled(currentCount == 0)

                        Text("\(currentCount)")
                            .font(.subheadline.monospacedDigit().bold())
                            .frame(minWidth: 20)

                        Button {
                            OwnedCard.addCard(
                                cardId: cardId,
                                setCode: setCode,
                                cardNumber: cardNumber,
                                variant: variant,
                                in: modelContext
                            )
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func getPrice(for variant: CardVariant) -> Double? {
        guard let variantPrices else { return nil }
        switch variant {
        case .normal: return variantPrices["normal"]
        case .holo: return variantPrices["holofoil"]
        case .reverseHolo: return variantPrices["reverseHolofoil"]
        case .firstEdition: return variantPrices["1stEditionHolofoil"]
        }
    }
}
