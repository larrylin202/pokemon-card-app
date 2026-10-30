import SwiftUI
import SwiftData

@main
struct PokemonCardScannerApp: App {
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(appearance.colorScheme)
                .task {
                    _ = try? await PokemonAPIService.shared.fetchSetsManifest()
                }
        }
        .modelContainer(for: [OwnedCard.self, UserCollection.self])
    }
}
