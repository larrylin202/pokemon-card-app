import SwiftUI
import SwiftData

struct SetDetailView: View {
    let setId: String
    let setName: String
    
    
    @Environment(\.modelContext) private var modelContext
    
    // Query owned cards for this specific set
    @Query private var ownedCards: [OwnedCard]
    
    @State private var setCards: [PokemonCard] = []
    @State private var isLoading = true
    @State private var prices: [String: [String: Double]] = [:]
    @State private var errorMessage: String?

    // 3-column binder grid layout
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // Initialize @Query with a dynamic predicate matching setId
    init(setId: String, setName: String) {
        self.setId = setId
        self.setName = setName
        
        let targetSet = setId
        _ownedCards = Query(
            filter: #Predicate<OwnedCard> { card in
                card.setCode == targetSet
            },
            sort: \.cardNumber
        )
    }

    // Set of owned card IDs for instant O(1) membership checks
    private var ownedCardIds: Set<String> {
        Set(ownedCards.map { $0.cardId })
    }
    

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading set...")
                    .padding(.top, 40)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Failed to Load Cards",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(setCards, id: \.id) { card in
                        let isOwned = ownedCardIds.contains(card.id)
                        
                        NavigationLink {
                            CardDetailView(
                                card: card,
                                setCode: setId,
                                ownedCardsForSet: ownedCards,
                                prices: prices
                            )
                        } label: {
                            VStack(spacing: 4) {
                                AsyncImage(url: URL(string: card.images.small)) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.2))
                                        .aspectRatio(0.714, contentMode: .fit)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .opacity(isOwned ? 1.0 : 0.35)
                                .grayscale(isOwned ? 0.0 : 0.9)

                                Text("#\(card.number)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(isOwned ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)                    }
                }
                .padding()
            }
        }
        .navigationTitle(setName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                async let fetchedCards = PokemonAPIService.shared.fetchCards(for: setId)
                async let fetchedPrices = PokemonAPIService.shared.fetchPrices(for: setId)
                
                let (cards, priceMap) = try await (fetchedCards, fetchedPrices)
                
                self.setCards = cards
                self.prices = priceMap
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
