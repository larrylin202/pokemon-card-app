import Foundation
import SwiftData

@Model
final class UserCollection {
    // this is not card info, this is info about the set
    @Attribute(.unique) var id: String //id of set or UUID for custom
    var name: String //name of the binder, name of set
    var setCode: String? // set code
    
    // binder info
    var isCustom: Bool
    var binderColumns: Int
    var binderRows: Int
    var dateCreated: Date
    
    init(
        id: String,
        name: String,
        setCode: String?,
        isCustom: Bool,
        binderColumns: Int,
        binderRows: Int,
        dateCreated: Date
    ) {
        self.id = id
        self.name = name
        self.setCode = setCode
        self.isCustom = isCustom
        self.binderColumns = binderColumns
        self.binderRows = binderRows
        self.dateCreated = dateCreated
    }
}

extension UserCollection {
    static func getAllCollections(in context: ModelContext) -> [UserCollection] {
        let descriptor = FetchDescriptor<UserCollection>(
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    static func checkForCollection(setCode targetSetCode: String, in context: ModelContext) -> UserCollection? {
        let target: String? = targetSetCode
        var descriptor = FetchDescriptor<UserCollection>(
            predicate: #Predicate<UserCollection> {
                set in set.setCode == target
            }
        )
        
        descriptor.fetchLimit = 1
        
        let matches = try? context.fetch(descriptor)
        return matches?.first
    }
    
    static func addCustomCollection(name: String, in context: ModelContext) {
        let setCode: String = UUID().uuidString
        
        let newCollection = UserCollection(
            id: setCode,
            name: name,
            setCode: nil,
            isCustom: false,
            binderColumns: 3,
            binderRows: 3,
            dateCreated: Date()
        )
        context.insert(newCollection)
        
        do {
            try context.save()
            print("Successfully added collection: \(name)")
        } catch {
            print("Failed to save collection: \(error)")
        }
    }
    
    static func addCollection(setCode: String, setName: String, in context: ModelContext) {
        // check that collection doesn't already exist
        guard checkForCollection(setCode: setCode, in: context) == nil  else { return }
        let newCollection = UserCollection(
            id: setCode,
            name: setName,
            setCode: setCode,
            isCustom: false,
            binderColumns: 3,
            binderRows: 3,
            dateCreated: Date()
        )
        context.insert(newCollection)
        
        do {
            try context.save()
            print("Successfully added collection: \(setName)")
        } catch {
            print("Failed to save collection: \(error)")
        }
    }
    
    static func removeCollection(setCode: String, in context: ModelContext) {
        guard let existingCollection = checkForCollection(setCode: setCode, in: context) else { return }
        
        context.delete(existingCollection)
    }
}
