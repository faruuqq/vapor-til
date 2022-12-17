//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 17/12/22.
//

import Fluent

struct AddTwitterToUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("twitterURL", .string)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("twitterURL")
            .update()
    }
}
