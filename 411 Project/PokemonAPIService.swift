import Foundation

actor PokemonAPIService {
    static let shared = PokemonAPIService()
    
    // Synchronously readable dictionary: [setCode: setName]
    // Accessible on the main thread without needing async/await
    @MainActor static var setLookup: [String: String] = [:]

    // Replace with your GitHub Pages base URL
    private let baseURL = "https://larrylin202.github.io/pokemon-card-api/api_data"
    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    // In-memory list of all sets
    private(set) var sets: [SetManifestItem] = []

    // MARK: - Sets Manifest (Permanent Cache)
    func fetchSetsManifest() async throws -> [SetManifestItem] {
        let url = URL(string: "\(baseURL)/sets_manifest.json")!
        let data = try await fetchWithCache(from: url, localFilename: "sets_manifest.json")
        let decoded = try JSONDecoder().decode([SetManifestItem].self, from: data)

        // Cache sets in memory
        self.sets = decoded

        // Populate the static lookup dictionary on the main thread
        await MainActor.run {
            Self.setLookup = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0.name) })
        }

        return decoded
    }

    // MARK: - Individual Set Cards (Permanent Cache)
    func fetchCards(for setCode: String) async throws -> [PokemonCard] {
        let url = URL(string: "\(baseURL)/sets/\(setCode).json")!
        let data = try await fetchWithCache(from: url, localFilename: "\(setCode).json")
        return try JSONDecoder().decode([PokemonCard].self, from: data)
    }

    // MARK: - Daily Cached Prices with Offline Fallback
    func fetchPrices(for setCode: String) async throws -> [String: [String: Double]] {
        let filename = "\(setCode)_prices.json"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        let url = URL(string: "\(baseURL)/prices/\(filename)")!
        
        let oneDayInSeconds: TimeInterval = 86_400

        // 1. If cached within the last 24 hours, serve immediately from disk
        if isCacheValid(at: fileURL, maxAge: oneDayInSeconds),
           let cachedData = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: cachedData) {
            print("📦 [Prices] Serving \(setCode) prices from local 24-hour cache.")
            return decoded
        }

        // 2. Cache is stale or missing: Attempt network fetch
        do {
            print("🌐 [Prices] Fetching fresh daily prices for \(setCode)...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            // Save fresh data to disk
            try? data.write(to: fileURL)
            return try JSONDecoder().decode([String: [String: Double]].self, from: data)
            
        } catch {
            print("⚠️ [Prices] Network failed for \(setCode). Attempting offline fallback.")
            
            // 3. Fallback: If network fails, serve stale cache regardless of age
            if fileManager.fileExists(atPath: fileURL.path),
               let cachedData = try? Data(contentsOf: fileURL),
               let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: cachedData) {
                print("💾 [Prices] Recovered using existing offline cached prices for \(setCode).")
                return decoded
            }
            
            // No cache exists and no network available
            throw error
        }
    }
    
    // MARK: - Permanent Caching Helper (Manifests & Cards)
    private func fetchWithCache(from url: URL, localFilename: String) async throws -> Data {
        let fileURL = cacheDirectory.appendingPathComponent(localFilename)

        if fileManager.fileExists(atPath: fileURL.path) {
            return try Data(contentsOf: fileURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        try? data.write(to: fileURL)
        return data
    }

    // MARK: - Timestamp Verification Helper
    private func isCacheValid(at fileURL: URL, maxAge: TimeInterval) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modificationDate) < maxAge
    }
    
    // MARK: - Cache Management
    func clearCache() throws {
        // 1. Clear files stored in the caches directory
        let fileURLs = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        for url in fileURLs where url.pathExtension == "json" {
            try fileManager.removeItem(at: url)
        }
        
        // 2. Clear in-memory manifests
        self.sets = []
        
        Task { @MainActor in
            Self.setLookup = [:]
        }
        
        print("🧹 [PokemonAPIService] All cached JSON manifests and card data cleared.")
    }
}
