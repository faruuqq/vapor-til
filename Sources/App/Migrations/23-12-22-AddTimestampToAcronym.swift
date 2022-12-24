//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 23/12/22.
//

import Fluent

struct AddTimestampToAcronym: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("acronyms")
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("acronyms")
            .deleteField("created_at")
            .deleteField("updated_at")
            .update()
    }
}
