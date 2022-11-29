//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 29/11/22.
//

import Fluent
import Vapor

struct CreateAdmin: AsyncMigration {
    func prepare(on database: Database) async throws {
        let passwordHash: String
        passwordHash = try Bcrypt.hash("password")
        let user = User(
            name: "Admin",
            username: "admin",
            password: passwordHash)
        try await user.save(on: database)
    }
    
    func revert(on database: Database) async throws {
        try await User.query(on: database).filter(\.$username == "admin")
            .delete()
    }
}
