//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 27/11/22.
//

import Vapor
import Fluent

struct UsersController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let usersRoute = routes.grouped("api", "users")
        let usersV2Route = routes.grouped("api", "V2", "users")
        usersV2Route.on(.GET, use: getV2AllHandler(_:))
        usersV2Route.on(.GET, ":userID", use: getV2Handler(_:))
        usersRoute.on(.GET, use: getAllHandler(_:))
        usersRoute.on(.GET, ":userID", use: getHandler(_:))
        usersRoute.on(.GET, ":userID", "acronyms", use: getAcronymsHandler(_:))
        usersRoute.on(.GET, "acronyms", use: getAllUserWithAcronyms(_:))
        
        let basicAuthMiddleware = User.authenticator()
        let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
        basicAuthGroup.on(.POST, "login", use: loginHandler(_:))
        
        let tokenAuthMiddleware = Token.authenticator()
        let guardAuthMiddleware = User.guardMiddleware()
        let tokenAuthGroup = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        tokenAuthGroup.post(use: createHandler(_:))
        tokenAuthGroup.delete(":userID", use: deleteHandler(_:))
        tokenAuthGroup.post(":userID", "restore", use: restoreHandler(_:))
        tokenAuthGroup.delete(":userID", "force", use: forceDeleteHandler(_:))
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
    
    func getV2AllHandler(_ req: Request) async throws -> [User.PublicV2] {
        try await User.query(on: req.db).all().convertToPublicV2()
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
    
    func deleteHandler(_ req: Request) async throws -> HTTPStatus {
        let requestUser = try req.auth.require(User.self)
        guard requestUser.userType == .admin else {
            throw Abort(.forbidden)
        }
        
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        try await user.delete(force: false, on: req.db)
        return .noContent
    }
    
    func restoreHandler(_ req: Request) async throws -> HTTPStatus {
        guard let userID = req.parameters.get("userID"),
              let userUUID = UUID(uuidString: userID) else {
            throw Abort(.badRequest)
        }
        let users = try await User.query(on: req.db).withDeleted().all()
        guard let user = users.filter({ $0.id == userUUID }).first else {
            throw Abort(.notFound)
        }
        try await user.restore(on: req.db)
        return .ok
    }
    
    func forceDeleteHandler(_ req: Request) async throws -> HTTPStatus {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await user.delete(force: true, on: req.db)
        return .noContent
    }
    
    func getAllUserWithAcronyms(_ req: Request) async throws -> [UserWithAcronyms] {
        let users = try await User.query(on: req.db).all()
        let userWithAcronyms = try users.compactMap { user in
            try user.$acronyms.query(on: req.db).all().map { acronyms in
                UserWithAcronyms(
                    id: user.id,
                    name: user.name,
                    username: user.username,
                    acronyms: acronyms)
                
            }.wait()
        }
        return userWithAcronyms
    }
}

struct UserWithAcronyms: Content {
    let id: UUID?
    let name: String
    let username: String
    let acronyms: [Acronym]
}
