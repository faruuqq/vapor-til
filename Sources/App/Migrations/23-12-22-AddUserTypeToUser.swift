//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 23/12/22.
//

import Fluent

struct AddUserTypeToUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        let userType = try await database.enum("user_type")
            .case("admin")
            .case("standard")
            .case("restricted")
            .create()
        
        try await database.schema("users")
            .field("user_type", userType, .required)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.enum("user_type")
            .delete()
    }
}
