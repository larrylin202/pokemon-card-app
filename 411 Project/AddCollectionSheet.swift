import SwiftUI
import SwiftData

struct AddCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var trackedCollections: [UserCollection]
    
    @State private var allSets: [SetManifestItem] = []
    @State private var searchText = ""
    @State private var isLoading = false

    private var availableSets: [SetManifestItem] {
        let trackedCodes = Set(trackedCollections.compactMap { $0.setCode })
        
        return allSets
            .filter { !trackedCodes.contains($0.id) }
            .filter {
                searchText.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText)
            }
            // Sort newest release date first
            .sorted { $0.releaseDate > $1.releaseDate }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && allSets.isEmpty {
                    ProgressView("Loading sets...")
                } else if availableSets.isEmpty {
                    ContentUnavailableView(
                        "No Sets Found",
                        systemImage: "tray",
                        description: Text(searchText.isEmpty ? "All available sets are tracked." : "No sets match '\(searchText)'.")
                    )
                } else {
                    List(availableSets, id: \.id) { item in
                        Button {
                            UserCollection.addCollection(
                                setCode: item.id,
                                setName: item.name,
                                in: modelContext
                            )
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(item.id.uppercased())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search sets...")
                }
            }
            .navigationTitle("Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if allSets.isEmpty {
                    isLoading = true
                    defer { isLoading = false }
                    if let loadedSets = try? await PokemonAPIService.shared.fetchSetsManifest() {
                        allSets = loadedSets
                    }
                }
            }
        }
    }
}
