//
//  Models+Testable.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 06/11/22.
//

@testable import App
import Fluent
import Vapor

// MARK: - User
extension User {
    static func create(
        name: String = "Luke",
        username: String? = nil,
        on database: Database
    ) throws -> User {
        let createUsername: String
        if let suppliedUsername = username {
            createUsername = suppliedUsername
        } else {
            createUsername = UUID().uuidString
        }
        
        let password = try Bcrypt.hash("password")
        let user = User(name: name, username: createUsername, password: password)
        try user.save(on: database).wait()
        return user
    }
}

// MARK: - Acronym
extension Acronym {
    static func create(
        short: String = "TIL",
        long: String = "Today I Learned",
        user: User? = nil,
        on database: Database
    ) throws -> Acronym {
        var acronymsUser = user
        
        if acronymsUser == nil {
            acronymsUser = try User.create(on: database)
        }
        
        let acronym = Acronym(
            short: short,
            long: long,
            userID: acronymsUser!.id!)
        try acronym.save(on: database).wait()
        return acronym
    }
}

// MARK: - Acronyms Categories
extension App.Category {
    static func create(
        name: String = "random category",
        on database: Database
    ) throws -> App.Category {
        let category = Category(name: name)
        try category.save(on: database).wait()
        return category
    }
}
