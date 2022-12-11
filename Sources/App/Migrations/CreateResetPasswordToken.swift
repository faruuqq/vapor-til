//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 11/12/22.
//

import Fluent

struct CreateResetPasswordToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("reset-password")
            .id()
            .field("value", .string, .required)
            .field("userID", .uuid, .required,
                   .references("users", "id", onDelete: .cascade))
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("reset-password")
            .delete()
    }
}
