//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 27/11/22.
//

import Vapor

struct UsersController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let usersRoute = routes.grouped("api", "users")
        usersRoute.on(.POST, use: createHandler(_:))
        usersRoute.on(.GET, use: getAllHandler(_:))
        usersRoute.on(.GET, ":userID", use: getHandler(_:))
        usersRoute.on(.GET, ":userID", "acronyms", use: getAcronymsHandler(_:))
    }
    
    func createHandler(_ req: Request) async throws -> User {
        let user = try req.content.decode(User.self)
        try await user.save(on: req.db)
        return user
    }
    
    func getAllHandler(_ req: Request) async throws -> [User] {
        try await User.query(on: req.db).all()
    }
    
    func getHandler(_ req: Request) async throws -> User {
        guard let data = try await User
            .find(req.parameters.get("userID"), on: req.db)
        else { throw Abort(.notFound) }
        return data
    }
    
    func getAcronymsHandler(_ req: Request) async throws -> [Acronym] {
        let data = try await getHandler(req)
        let acronyms = try await data.$acronyms.get(on: req.db)
        return acronyms
    }
}
