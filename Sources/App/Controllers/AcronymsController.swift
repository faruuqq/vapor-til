//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 27/11/22.
//

import Vapor
import Fluent
import FluentSQL

struct AcronymsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let acronymsRoutes = routes.grouped("api", "acronyms")
        acronymsRoutes.on(.GET, use: getAllHandler(_:))
        acronymsRoutes.on(.GET, ":acronymID", use: getHandlerById(_:))
        acronymsRoutes.on(.GET, "search", use: searchHandler(_:))
        acronymsRoutes.on(.GET, "first", use: getFirstHandler(_:))
        acronymsRoutes.on(.GET, "sorted", use: sortingHandler(_:))
        acronymsRoutes.on(.GET, ":acronymID", "user", use: getUserHandler(_:))
        acronymsRoutes.on(.GET, ":acronymID", "categories", use: getCategoriesHandler(_:))
        acronymsRoutes.on(.GET, "mostRecent", use: getMostRecentAcronyms(_:))
        acronymsRoutes.on(.GET, "users", use: getAcronymsWithUser(_:))
        acronymsRoutes.on(.GET, "raw", use: getAllAcronymsRaw(_:))
        
        let tokenAuthMiddleware = Token.authenticator()
        let guardAuthMiddleware = User.guardMiddleware()
        let tokenAuthGroup = acronymsRoutes.grouped(
            tokenAuthMiddleware,
            guardAuthMiddleware)
        tokenAuthGroup.post(use: createHandler(_:))
        tokenAuthGroup.delete(":acronymID", use: deleteHandler(_:))
        tokenAuthGroup.put(":acronymID", use: updateHandler(_:))
        tokenAuthGroup.post(":acronymID", "categories", ":categoryID", use: addCategoriesHandler(_:))
        tokenAuthGroup.delete(":acronymID", "categories", ":categoryID", use: removeCategoriesHandler(_:))
    }
    
    func getAllHandler(_ req: Request) async throws -> [Acronym] {
        try await Acronym.query(on: req.db).all()
    }
    
    func createHandler(_ req: Request) async throws -> Acronym {
        let data = try req.content.decode(CreateAcronymData.self)
        let user = try req.auth.require(User.self)
        let acronym = try Acronym(
            short: data.short,
            long: data.long,
            userID: user.requireID())
        try await acronym.save(on: req.db)
        return acronym
    }
    
    func getHandlerById(_ req: Request) async throws -> Acronym {
        guard let data = try await Acronym.find(
            req.parameters.get("acronymID"),
            on: req.db)
        else { throw Abort(.notFound) }
        return data
    }
    
    func updateHandler(_ req: Request) async throws -> Acronym {
        let acronym = try await getHandlerById(req)
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        let updatedAcronym = try req.content.decode(CreateAcronymData.self)
        acronym.short = updatedAcronym.short
        acronym.long = updatedAcronym.long
        acronym.$user.id = userID
        try await acronym.save(on: req.db)
        return acronym
    }
    
    func deleteHandler(_ req: Request) async throws -> HTTPStatus {
        let acronym = try await getHandlerById(req)
        try await acronym.delete(on: req.db)
        return .noContent
    }
    
    func searchHandler(_ req: Request) async throws -> [Acronym] {
        guard let searchTerm = req.query[String.self, at: "term"] else { throw Abort(.badRequest) }
        
        // Filter Single Field
        let _ = try await Acronym.query(on: req.db)
            .filter(\.$short ~~ searchTerm)
            .all()
        
        // Filter All Field
        let filteredAllField = try await Acronym.query(on: req.db)
            .group(.or) { or in
                or.filter(\.$short ~~ searchTerm)
                or.filter(\.$long ~~ searchTerm)
            }
            .all()
        return filteredAllField
    }
    
    func getFirstHandler(_ req: Request) async throws -> Acronym {
        guard let firstAcronym = try await Acronym.query(on: req.db)
            .first()
        else { throw Abort(.notFound) }
        return firstAcronym
    }
    
    func sortingHandler(_ req: Request) async throws -> [Acronym] {
        return try await Acronym.query(on: req.db)
            .sort(\.$short, .ascending)
            .all()
    }
    
    func getUserHandler(_ req: Request) async throws -> User.Public {
        let acronym = try await getHandlerById(req)
        let user = try await acronym.$user.get(on: req.db).convertToPublic()
        return user
    }
    
    private func getCategoryHandlerById(_ req: Request) async throws -> Category {
        guard let data = try await Category.find(
            req.parameters.get("categoryID"),
            on: req.db)
        else { throw Abort(.notFound) }
        return data
    }
    
    func addCategoriesHandler(_ req: Request) async throws -> HTTPStatus {
        let acronymQuery = try await getHandlerById(req)
        let categoryQuery = try await getCategoryHandlerById(req)
        
        try await acronymQuery.$categories.attach(categoryQuery, on: req.db)
        return .created
    }
    
    func getCategoriesHandler(_ req: Request) async throws -> [Category] {
        let acronymQuery = try await getHandlerById(req)
        let allData = try await acronymQuery.$categories.query(on: req.db).all()
        return allData
    }
    
    func removeCategoriesHandler(_ req: Request) async throws -> HTTPStatus {
        let acronymQuery = try await getHandlerById(req)
        let categoryQuery = try await getCategoryHandlerById(req)
        try await acronymQuery.$categories.detach(categoryQuery, on: req.db)
        return .noContent
    }
    
    func getMostRecentAcronyms(_ req: Request) async throws -> [Acronym] {
        let acronyms = try await Acronym.query(on: req.db).sort(\.$updatedAt, .descending).all()
        return acronyms
    }
    
    func getAcronymsWithUser(_ req: Request) async throws -> [AcronymWithUser] {
        let acronyms = try await Acronym.query(on: req.db).join(User.self, on: \Acronym.$user.$id == \User.$id).all()
        let acronymWithUser = try acronyms.map { acronym in
            let user = try acronym.joined(User.self)
            return AcronymWithUser(
                id: acronym.id,
                short: acronym.short,
                long: acronym.long,
                user: user.convertToPublic())
        }
        return acronymWithUser
    }
    
    func getAllAcronymsRaw(_ req: Request) async throws -> [Acronym] {
        guard let sql = req.db as? SQLDatabase else {
            throw Abort(.badRequest)
        }
        
        let acronyms = try await sql.raw("SELECT * FROM acronyms").all(decoding: Acronym.self)
        return acronyms
    }

}

struct CreateAcronymData: Content {
    let short: String
    let long: String
}

struct AcronymWithUser: Content {
    let id: UUID?
    let short: String
    let long: String
    let user: User.Public
}
