//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 27/11/22.
//

import Vapor

struct CategoriesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let categoriesRoute = routes.grouped("api", "categories")
        categoriesRoute.on(.POST, use: createHandler(_:))
        categoriesRoute.on(.GET, use: getAllHandler(_:))
        categoriesRoute.on(.GET, ":categoryID", use: getHandler(_:))
        categoriesRoute.on(.GET, ":categoryID", "acronyms", use: getAcronymsHandler(_:))
    }
    
    func createHandler(_ req: Request) async throws -> Category {
        let category = try req.content.decode(Category.self)
        try await category.save(on: req.db)
        return category
    }
    
    func getAllHandler(_ req: Request) async throws -> [Category] {
        try await Category.query(on: req.db).all()
    }
    
    func getHandler(_ req: Request) async throws -> Category {
        guard let category = try await Category.find(req.parameters.get("categoryID"), on: req.db)
        else { throw Abort(.notFound) }
        return category
    }
    
    func getAcronymsHandler(_ req: Request) async throws -> [Acronym] {
        let category = try await getHandler(req)
        let acronyms = try await category.$acronyms.get(on: req.db)
        return acronyms
    }
}
