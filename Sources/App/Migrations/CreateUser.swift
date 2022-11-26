//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 26/11/22.
//

import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("name", .string, .required)
            .field("username", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("useres")
            .delete()
    }
}
