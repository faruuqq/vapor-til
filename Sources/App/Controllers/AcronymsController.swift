//
//  AcronymsController.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 16/10/22.
//

import Vapor
import Fluent

struct AcronymsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let acronymsRoutes = routes.grouped("api", "acronyms")
//        routes.get("api", "acronyms", use: getAllHandler(_:))
        acronymsRoutes.on(.GET, use: getAllHandler(_:))
        acronymsRoutes.on(.POST, use: createHandler(_:))
        acronymsRoutes.on(.GET, ":acronymID", use: getHandlerById(_:))
        acronymsRoutes.on(.PUT, ":acronymID", use: updateHandler(_:))
        acronymsRoutes.on(.DELETE, ":acronymID", use: deleteHandler(_:))
        acronymsRoutes.on(.GET, "search", use: searchHandler(_:))
        acronymsRoutes.on(.GET, "first", use: getFirstHandler(_:))
        acronymsRoutes.on(.GET, "sorted", use: sortingHandler(_:))
        acronymsRoutes.on(.GET, ":acronymID", "user", use: getUserHandler(_:))
        acronymsRoutes.on(.POST, ":acronymID", "categories", ":categoryID", use: addCategoriesHandler(_:))
        acronymsRoutes.on(.GET, ":acronymID", "categories", use: getCategoriesHandler(_:))
        acronymsRoutes.on(.DELETE, ":acronymID", "categories", ":categoryID", use: removeCategoriesHandler(_:))
    }
    
    func getAllHandler(_ req: Request) async throws -> [Acronym] {
        try await Acronym.query(on: req.db).all()
    }
    
    /// Save data to database
    func createHandler(_ req: Request) async throws -> Acronym {
//        let acronym = try req.content.decode(Acronym.self)
//        try await acronym.save(on: req.db)
//        return acronym
        let data = try req.content.decode(CreateAcronymData.self)
        let acronym = Acronym(
            short: data.short,
            long: data.long,
            userID: data.userID)
        try await acronym.save(on: req.db)
        return acronym
    }
    
    /// Get spesific data by UUID in database
    func getHandlerById(_ req: Request) async throws -> Acronym {
        guard let data = try await Acronym.find(
            req.parameters.get("acronymID"),
            on: req.db)
        else { throw Abort(.notFound) }
        return data
    }
    
    /// Update data in database
    func updateHandler(_ req: Request) async throws -> Acronym {
//        let acronym = try await getHandlerById(req)
//        let updatedAcronym = try req.content.decode(Acronym.self)
//        acronym.short = updatedAcronym.short
//        acronym.long = updatedAcronym.long
//        try await acronym.save(on: req.db)
//        return acronym
        let acronym = try await getHandlerById(req)
        let updatedAcronym = try req.content.decode(CreateAcronymData.self)
        acronym.short = updatedAcronym.short
        acronym.long = updatedAcronym.long
        acronym.$user.id = updatedAcronym.userID
        try await acronym.save(on: req.db)
        return acronym
    }
    
    /// Delete data in database
    func deleteHandler(_ req: Request) async throws -> HTTPStatus {
        let acronym = try await getHandlerById(req)
        try await acronym.delete(on: req.db)
        return .noContent
    }
    
    /// Search
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
    
    func getUserHandler(_ req: Request) async throws -> User {
        let acronym = try await getHandlerById(req)
        let user = try await acronym.$user.get(on: req.db)
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

}

struct CreateAcronymData: Content {
    let short: String
    let long: String
    let userID: UUID
}
