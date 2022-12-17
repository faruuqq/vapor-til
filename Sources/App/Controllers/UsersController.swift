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
        let usersV2Route = routes.grouped("api", "V2", "users")
        usersRoute.on(.GET, use: getAllHandler(_:))
        usersRoute.on(.GET, ":userID", use: getHandler(_:))
        usersRoute.on(.GET, ":userID", "acronyms", use: getAcronymsHandler(_:))
        
        let basicAuthMiddleware = User.authenticator()
        let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
        basicAuthGroup.on(.POST, "login", use: loginHandler(_:))
        
        let tokenAuthMiddleware = Token.authenticator()
        let guardAuthMiddleware = User.guardMiddleware()
        let tokenAuthGroup = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        tokenAuthGroup.post(use: createHandler(_:))
    }
    
    func createHandler(_ req: Request) async throws -> User.Public {
        let user = try req.content.decode(User.self)
        user.password = try Bcrypt.hash(user.password)
        try await user.save(on: req.db)
        return user.convertToPublic()
    }
    
    func getAllHandler(_ req: Request) async throws -> [User.Public] {
        try await User.query(on: req.db).all().convertToPublic()
    }
    
    func getHandler(_ req: Request) async throws -> User.Public {
        guard let user = try await User
            .find(req.parameters.get("userID"), on: req.db)
        else { throw Abort(.notFound) }
        return user.convertToPublic()
    }
    
    func getV2Handler(_ req: Request) async throws -> User.PublicV2 {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return user.convertToPublicV2()
    }
    
    func getAcronymsHandler(_ req: Request) async throws -> [Acronym] {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let acronyms = try await user.$acronyms.get(on: req.db)
        return acronyms
    }
    
    func loginHandler(_ req: Request) async throws -> Token {
        let user = try req.auth.require(User.self)
        let token = try Token.generate(for: user)
        try await token.save(on: req.db)
        return token
    }
}
