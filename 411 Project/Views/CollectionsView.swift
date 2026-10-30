import SwiftUI
import SwiftData

struct CollectionsView: View {
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \UserCollection.dateCreated, order: .reverse)
    private var collections: [UserCollection]
    
    @State private var isShowingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {}) {
                        Label("All Cards", systemImage: "book.pages")
                    }
                }
                
                Section("My Sets") {
                    ForEach(collections) { collection in
                        NavigationLink {
                            SetDetailView(
                                setId: collection.setCode!,
                                setName: collection.name
                            )
                        } label: {
                            Text(collection.name)
                        }
                        .frame(height:50)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(collections[index])
                        }
                        try? modelContext.save()
                    }

                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Label("Add a Collection", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Collections")
            .sheet(isPresented: $isShowingAddSheet) {
                AddCollectionSheet()
                    .modelContext(modelContext)
            }
        }
    }
}

#Preview {
    CollectionsView()
        .modelContainer(for: [OwnedCard.self, UserCollection.self], inMemory: true)
}
