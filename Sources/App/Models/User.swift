//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 27/11/22.
//

import Vapor
import Fluent
import FluentPostgresDriver

final class User: Model, Content {
    static let schema: String = "users"
    
    @ID
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "username")
    var username: String
    
    @Field(key: "password")
    var password: String
    
    @Field(key: "twitterURL")
    var twitterURL: String?
    
    @Field(key: "email")
    var email: String
    
    @OptionalField(key: "picture")
    var profilePicture: String?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Enum(key: "user_type")
    var userType: UserType
    
    @Children(for: \.$user)
    var acronyms: [Acronym]
    
    init() {}
    
    init(name: String,
         username: String,
         password: String,
         email: String,
         twitterURL: String? = nil,
         userType: UserType = .standard) {
        self.name = name
        self.username = username
        self.password = password
        self.email = email
        self.twitterURL = twitterURL
        self.userType = userType
    }
    
    final class Public: Content {
        var id: UUID?
        var name: String
        var username: String
        
        init(id: UUID? = nil, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
        }
    }
    
    final class PublicV2: Content {
        var id: UUID?
        var name: String
        var username: String
        var twitterURL: String?
        
        init(id: UUID? = nil,
             name: String,
             username: String,
             twitterURL: String? = nil) {
            self.id = id
            self.name = name
            self.username = username
            self.twitterURL = twitterURL
        }
    }
}

// MARK: - User
extension User {
    func convertToPublic() -> User.Public {
        return User.Public(id: id, name: name, username: username)
    }
    
    func convertToPublicV2() -> User.PublicV2 {
        return User.PublicV2(
            id: id,
            name: name,
            username: username,
            twitterURL: twitterURL)
    }
}

// MARK: - Collection
extension Collection where Element: User {
    func convertToPublic() -> [User.Public] {
        return self.map { $0.convertToPublic() }
    }
    
    func convertToPublicV2() -> [User.PublicV2] {
        return self.map { $0.convertToPublicV2() }
    }
}

// MARK: - BasicAuthenticatable
extension User: ModelAuthenticatable {
    static var usernameKey: KeyPath<User, Field<String>> {
        \User.$username
    }
    
    static var passwordHashKey: KeyPath<User, Field<String>> {
        \User.$password
    }
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
}

// MARK: - ModelSessionAuthenticatable
extension User: ModelSessionAuthenticatable {}

// MARK: - ModelCredentialsAuthenticatable
extension User: ModelCredentialsAuthenticatable {}

// MARK: - LifecycleHandler
extension User: AsyncModelMiddleware {
    typealias Model = User
    
    func create(model: User, on db: Database, next: AnyAsyncModelResponder) async throws {
        let count = try await User.query(on: db).filter(\.$username == model.username).count()
        guard count == 0 else {
            throw Abort(.badRequest, reason: "Username already exists")
        }
        try await next.create(model, on: db)
    }
}
