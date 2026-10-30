import SwiftUI
import SwiftData

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system
    @AppStorage("autoCreateCollectionOnAdd") private var autoCreateCollectionOnAdd: Bool = true
    @State private var showingResetAlert = false
    @State private var showingResetConfirmation = false
    
    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Collection Management") {
                Toggle("Auto-Track New Sets", isOn: $autoCreateCollectionOnAdd)
                Text("Automatically adds a set to your Collections list when you add or scan a card from that set.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section(header: Text("Support me!")) {
                if let url = URL(string: "https://ko-fi.com/haywiyre") {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Leave a donation!")
                        }
                    }
                }
            }
            
            Section(header: Text("Danger Zone")) {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    Label("Reset All Data", systemImage: "trash.fill")
                }
            }
        }
        .navigationTitle("Settings")
        .safeAreaInset(edge: .bottom) {
            Text("Beta 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 12)
        }
        .confirmationDialog(
            "Reset All Data?",
            isPresented: $showingResetAlert,
            titleVisibility: .visible
        ) {
            Button("Erase All Cards & Settings", role: .destructive) {
                Task {
                    await resetAllUserData()
                    showingResetConfirmation = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all scanned cards, created collections, cached files, and custom settings. This cannot be undone.")
        }
        .alert("Data Reset Complete", isPresented: $showingResetConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The app has been restored to its default state.")
        }
    }
    
    @MainActor
    private func resetAllUserData() async {
        // 1. Wipe SwiftData Entities
        do {
            try modelContext.delete(model: OwnedCard.self)
            try modelContext.delete(model: UserCollection.self)
            try modelContext.save()
            print(" SwiftData records erased.")
        } catch {
            print("❌ Failed to delete SwiftData models: \(error.localizedDescription)")
        }

        // 2. Reset UserDefaults / AppStorage
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        // Restore default state values immediately
        appearance = .system
        autoCreateCollectionOnAdd = true

        // 3. Clear Cached Files and API Lookups
        do {
            try await PokemonAPIService.shared.clearCache()
        } catch {
            print("⚠️ Failed to remove cache directory files: \(error.localizedDescription)")
        }
    }
}

//#Preview {
//    NavigationStack {
//        SettingsView()
//    }
//}
