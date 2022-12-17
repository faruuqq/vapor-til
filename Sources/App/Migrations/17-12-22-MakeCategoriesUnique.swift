//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 17/12/22.
//

import Fluent

struct MakeCategoriesUnique: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("categories")
            .unique(on: "name")
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("categories")
            .deleteUnique(on: "name")
            .update()
    }
}
