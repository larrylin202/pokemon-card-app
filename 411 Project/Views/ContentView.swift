import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import PhotosUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("autoAddToCollection") private var autoAddToCollection = true
    @AppStorage("autoCreateCollectionOnAdd") private var autoCreateCollectionOnAdd: Bool = true

    var body: some View {
        ZStack {
            // Live camera view (or dark background on Simulator)
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
                .background(Color.black.opacity(0.85))

            // Main UI Overlay
            VStack {
                // Top status bar
                HStack {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Photos", systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    if cameraManager.isProcessing {
                        ProgressView()
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Toggle(isOn: $autoAddToCollection) {
                        Label("Auto-Add", systemImage: autoAddToCollection ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                            .font(.subheadline.bold())
                    }
                    .toggleStyle(.button)
                    .tint(autoAddToCollection ? .green : .secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())

                }
                .padding()

                Spacer()

                // Identified Card & Price Display Card
                if let card = cameraManager.identifiedCard {
                    HStack(spacing: 14) {
                        AsyncImage(url: URL(string: card.images.small)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            default:
                                ProgressView()
                            }
                        }
                        .frame(width: 65, height: 90)
                        .cornerRadius(8)
                        .shadow(radius: 3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.name)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("#\(card.number)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if let price = cameraManager.cardPrice {
                                Text(String(format: "$%.2f", price))
                                    .font(.title3.bold())
                                    .foregroundColor(.green)
                            } else {
                                Text("No price data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    // Triggers a subtle success buzz whenever a new card is recognized and auto-added
                    .sensoryFeedback(.success, trigger: cameraManager.identifiedCard?.id) { oldId, newId in
                        // Only buzz if autoAddToCollection is true and a valid new card appeared
                        return autoAddToCollection && newId != nil
                    }
                } else if !cameraManager.recognizedText.isEmpty && !cameraManager.isProcessing {
                    // Debug / Fallback status readouts
                    Text(cameraManager.recognizedText)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                // Shutter Button (For physical device testing)
                Button {
                    cameraManager.captureAndProcessCard()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 60, height: 60)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 24)
                .disabled(cameraManager.isProcessing)
            }
        }
        .animation(.easeInOut, value: cameraManager.identifiedCard?.id)
        .onAppear {
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
        }
        .onChange(of: cameraManager.identifiedCard) {
            guard autoAddToCollection, let card = cameraManager.identifiedCard else { return }
            
            // Derive setCode from card.id (e.g., "sv1-025" -> "sv1") or cameraManager
            let setCode = card.id.components(separatedBy: "-").first ?? ""
            
            OwnedCard.addCard(
                cardId: card.id,
                setCode: setCode,
                cardNumber: card.number,
                variant: .normal,
                in: modelContext
            )
            
            if autoCreateCollectionOnAdd {
                // Looks up the human-readable name or falls back to uppercase code
                
                let setName = PokemonAPIService.setLookup[setCode] ?? setCode.uppercased()

                UserCollection.addCollection(
                    setCode: setCode,
                    setName: setName,
                    in: modelContext
                )
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        cameraManager.processCustomImage(image)
                    }
                }
            }
        }
    }
}
